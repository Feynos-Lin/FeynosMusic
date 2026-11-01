import AVFoundation
import Accelerate

/// Backup for the visualizer: when the live audio tap gets no sound (it can't read some server
/// streams), this downloads the song once, works out its levels ahead of time and plays them
/// back in step with the music.
final class AudioAnalysis: @unchecked Sendable {
    static let shared = AudioAnalysis()
    static let fps = 30.0
    static let waveCount = 64

    private let lock = NSLock()
    private var readyId: String?
    private var bands: [UInt8] = []   // frames * bandCount
    private var waves: [Int8] = []    // frames * waveCount
    private var frames = 0
    private var working: String?
    private var failed: Set<String> = []

    /// Starts analysing a song unless it is done, in progress or couldn't be read.
    func need(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        if readyId == id || working == id || failed.contains(id) { return }
        working = id
        Task.detached(priority: .utility) { await self.run(id) }
    }

    /// Bands (0...1) and waveform (-1...1) for a moment in the song, once it has been analysed.
    func frame(_ id: String, at time: Double) -> (bands: [Float], wave: [Float])? {
        lock.lock()
        defer { lock.unlock() }
        guard readyId == id, frames > 0, time.isFinite, time >= 0 else { return nil }
        let i = min(frames - 1, Int(time * Self.fps))
        let nb = AudioTap.bandCount, nw = Self.waveCount
        let b = (0..<nb).map { Float(bands[i * nb + $0]) / 255 }
        let w = (0..<nw).map { Float(waves[i * nw + $0]) / 127 }
        return (b, w)
    }

    private func run(_ id: String) async {
        // A small MP3 copy decodes everywhere; fall back to the original file if transcoding is off.
        var result: (bands: [UInt8], waves: [Int8], frames: Int)?
        for mp3 in [true, false] {
            guard let url = await MainActor.run(body: { Self.url(id, mp3: mp3) }) else { break }
            if let r = await Self.analyse(url, id: id) {
                result = r
                break
            }
        }
        lock.lock()
        if working == id { working = nil }
        if let result {
            readyId = id
            bands = result.bands
            waves = result.waves
            frames = result.frames
        } else {
            failed.insert(id)
        }
        lock.unlock()
    }

    @MainActor private static func url(_ id: String, mp3: Bool) -> URL? {
        mp3 ? Subsonic.shared.url("stream", [("id", id), ("format", "mp3"), ("maxBitRate", "128")])
            : Subsonic.shared.url("stream", [("id", id), ("format", "raw")])
    }

    private static func analyse(_ url: URL, id: String) async -> (bands: [UInt8], waves: [Int8], frames: Int)? {
        guard let result = try? await URLSession.shared.download(from: url) else { return nil }
        let (tmp, resp) = result
        guard (resp as? HTTPURLResponse)?.statusCode ?? 200 < 300 else { return nil }
        let type = ((resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        let ext = type.contains("mpeg") || type.contains("mp3") ? "mp3"
            : type.contains("flac") ? "flac"
            : type.contains("mp4") || type.contains("m4a") || type.contains("aac") ? "m4a"
            : type.contains("wav") ? "wav"
            : type.contains("ogg") || type.contains("opus") ? "ogg"
            : (url.pathExtension.isEmpty ? "mp3" : url.pathExtension)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("vis-\(abs(id.hashValue)).\(ext)")
        try? FileManager.default.removeItem(at: file)
        guard (try? FileManager.default.moveItem(at: tmp, to: file)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: file) }
        return decode(file)
    }

    private static func decode(_ path: URL) -> (bands: [UInt8], waves: [Int8], frames: Int)? {
        guard let file = try? AVAudioFile(forReading: path) else { return nil }
        let format = file.processingFormat
        let rate = format.sampleRate > 0 ? format.sampleRate : 44100
        let channels = Int(format.channelCount)
        guard channels > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32768) else { return nil }

        let n = 1024, half = n / 2
        let log2n = vDSP_Length(10)
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        let hop = rate / fps
        let nb = AudioTap.bandCount, nw = waveCount
        let lo = 40.0, hi = min(16000.0, rate / 2)
        let ranges: [(Int, Int)] = (0..<nb).map { b in
            let f0 = lo * pow(hi / lo, Double(b) / Double(nb))
            let f1 = lo * pow(hi / lo, Double(b + 1) / Double(nb))
            let i0 = max(1, min(half - 1, Int(f0 / rate * Double(n))))
            let i1 = max(i0 + 1, min(half, Int(f1 / rate * Double(n))))
            return (i0, i1)
        }

        var mono: [Float] = []        // samples not yet fully used
        var monoStart = 0             // song position of mono[0], in samples
        var nextFrame = 0
        var outBands: [UInt8] = [], outWaves: [Int8] = []
        var windowed = [Float](repeating: 0, count: n)
        var real = [Float](repeating: 0, count: half), imag = [Float](repeating: 0, count: half)
        var mags = [Float](repeating: 0, count: half)

        while true {
            buffer.frameLength = 0
            do { try file.read(into: buffer) } catch { break }
            let count = Int(buffer.frameLength)
            if count == 0 { break }
            guard let data = buffer.floatChannelData else { return nil }
            let start = mono.count
            mono.append(contentsOf: repeatElement(0, count: count))
            for c in 0..<channels {
                let p = data[c]
                for i in 0..<count { mono[start + i] += p[i] / Float(channels) }
            }
            // Analyse every frame whose window is now fully read.
            while true {
                let center = Int(Double(nextFrame) * hop)
                let s = center - half - monoStart
                if s + n > mono.count { break }
                for i in 0..<n {
                    let k = s + i
                    windowed[i] = (k >= 0 ? mono[k] : 0) * window[i]
                }
                real.withUnsafeMutableBufferPointer { rp in
                    imag.withUnsafeMutableBufferPointer { ip in
                        var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                        windowed.withUnsafeBufferPointer { wp in
                            wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                                vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                            }
                        }
                        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                        vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))
                    }
                }
                for (i0, i1) in ranges {
                    var peak: Float = 0
                    for i in i0..<i1 { peak = max(peak, mags[i]) }
                    // zrip results are twice the size of a plain FFT, hence n / 2.
                    let db = 20 * log10(Double(peak) / Double(n / 2) + 1e-9)
                    outBands.append(UInt8(max(0, min(1, (db + 60) / 60)) * 255))
                }
                for i in 0..<nw {
                    let k = s + half - nw + i * 2
                    let v = k >= 0 && k < mono.count ? mono[k] : 0
                    outWaves.append(Int8(max(-1, min(1, v)) * 127))
                }
                nextFrame += 1
            }
            // Drop samples no later window needs.
            let keepFrom = Int(Double(nextFrame) * hop) - half - monoStart
            if keepFrom > 0 {
                let drop = min(keepFrom, mono.count)
                mono.removeFirst(drop)
                monoStart += drop
            }
        }
        return nextFrame > 0 ? (outBands, outWaves, nextFrame) : nil
    }
}
