import AVFoundation
import MediaToolbox

/// Reads the audio as it plays (through an audio-mix tap) so the visualizer can draw it.
final class AudioTap: @unchecked Sendable {
    static let shared = AudioTap()
    static let bandCount = 48
    private let n = 1024
    private var ring = [Float](repeating: 0, count: 1024)
    private var pos = 0
    private let lock = NSLock()
    private var sampleRate: Double = 44100
    private var isFloat = true
    private var lastWrite = Date.distantPast

    fileprivate func setFormat(rate: Double, isFloat: Bool) {
        lock.lock()
        sampleRate = rate > 0 ? rate : 44100
        self.isFloat = isFloat
        lock.unlock()
    }

    fileprivate func write(_ list: UnsafeMutableAudioBufferListPointer, frames: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard isFloat, frames > 0, list.count > 0, let d0 = list[0].mData else { return }
        lastWrite = Date()
        let p0 = d0.assumingMemoryBound(to: Float.self)
        let inter = Int(list[0].mNumberChannels)
        let p1 = list.count > 1 ? list[1].mData?.assumingMemoryBound(to: Float.self) : nil
        for i in 0..<frames {
            let v: Float
            if inter > 1 {
                v = (p0[i * inter] + p0[i * inter + 1]) * 0.5
            } else if let p1 {
                v = (p0[i] + p1[i]) * 0.5
            } else {
                v = p0[i]
            }
            ring[pos] = v
            pos = (pos + 1) % n
        }
    }

    /// Current bands (0...1), a short waveform (-1...1) and whether audio arrived recently.
    func frame() -> (bands: [Float], wave: [Float], fresh: Bool) {
        lock.lock()
        let samples = Array(ring[pos...] + ring[..<pos])
        let rate = sampleRate
        let fresh = Date().timeIntervalSince(lastWrite) < 0.25
        lock.unlock()
        guard fresh else { return ([Float](repeating: 0, count: Self.bandCount), [Float](repeating: 0, count: 128), false) }

        var re = [Float](repeating: 0, count: n)
        var im = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let w = Float(0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(n - 1)))
            re[i] = samples[i] * w
        }
        Self.fft(&re, &im)
        var bands = [Float](repeating: 0, count: Self.bandCount)
        let lo = 40.0, hi = min(16000.0, rate / 2)
        for b in 0..<Self.bandCount {
            let f0 = lo * pow(hi / lo, Double(b) / Double(Self.bandCount))
            let f1 = lo * pow(hi / lo, Double(b + 1) / Double(Self.bandCount))
            let i0 = max(1, min(n / 2 - 1, Int(f0 / rate * Double(n))))
            let i1 = max(i0 + 1, min(n / 2, Int(f1 / rate * Double(n))))
            var peak: Float = 0
            for i in i0..<i1 { peak = max(peak, (re[i] * re[i] + im[i] * im[i]).squareRoot()) }
            let db = 20 * log10(Double(peak) / Double(n / 4) + 1e-9)
            bands[b] = Float(max(0, min(1, (db + 60) / 60)))
        }
        var wave = [Float](repeating: 0, count: 128)
        for i in 0..<128 { wave[i] = samples[n - 256 + i * 2] }
        return (bands, wave, true)
    }

    private static func fft(_ x: inout [Float], _ y: inout [Float]) {
        let n = x.count
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j ^= bit
            if i < j {
                x.swapAt(i, j)
                y.swapAt(i, j)
            }
        }
        var len = 2
        while len <= n {
            let ang = -2 * Float.pi / Float(len)
            let wr = cos(ang), wi = sin(ang)
            var i = 0
            while i < n {
                var cr: Float = 1, ci: Float = 0
                for k in 0..<(len / 2) {
                    let a = i + k, b = i + k + len / 2
                    let vr = x[b] * cr - y[b] * ci
                    let vi = x[b] * ci + y[b] * cr
                    x[b] = x[a] - vr
                    y[b] = y[a] - vi
                    x[a] += vr
                    y[a] += vi
                    let nr = cr * wr - ci * wi
                    ci = cr * wi + ci * wr
                    cr = nr
                }
                i += len
            }
            len <<= 1
        }
    }

    /// Adds the tap to a song. Playback works the same if the tap can't be added.
    func attach(to item: AVPlayerItem) {
        Task { @MainActor in
            guard let track = try? await item.asset.loadTracks(withMediaType: .audio).first else { return }
            var callbacks = MTAudioProcessingTapCallbacks(
                version: kMTAudioProcessingTapCallbacksVersion_0,
                clientInfo: nil,
                init: { _, _, storageOut in storageOut.pointee = nil },
                finalize: nil,
                prepare: { _, _, format in
                    let f = format.pointee
                    AudioTap.shared.setFormat(rate: f.mSampleRate, isFloat: (f.mFormatFlags & kAudioFormatFlagIsFloat) != 0)
                },
                unprepare: nil,
                process: { tap, frames, _, bufferList, framesOut, flagsOut in
                    guard MTAudioProcessingTapGetSourceAudio(tap, frames, bufferList, flagsOut, nil, framesOut) == noErr else { return }
                    AudioTap.shared.write(UnsafeMutableAudioBufferListPointer(bufferList), frames: Int(framesOut.pointee))
                })
            var tapOut: Unmanaged<MTAudioProcessingTap>?
            guard MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tapOut) == noErr,
                  let tap = tapOut?.takeRetainedValue() else { return }
            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
        }
    }
}
