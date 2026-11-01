import SwiftUI

enum VisStyle {
    static let all = ["off", "bars", "wave", "circle"]
    static func label(_ s: String) -> String {
        switch s {
        case "bars": return "Bars"
        case "wave": return "Wave"
        case "circle": return "Circle"
        default: return "Off"
        }
    }
    static func next(_ s: String) -> String { all[((all.firstIndex(of: s) ?? 0) + 1) % all.count] }
}

/// Smooths the bars so they rise fast and fall slowly, and decides where the sound comes from.
final class VisSmoother {
    var shown = [Float](repeating: 0, count: AudioTap.bandCount)
    private var lastTap = Date.distantPast
    private var playingSince: Date?

    func step(_ target: [Float]) -> [Float] {
        for i in shown.indices {
            let t = i < target.count ? target[i] : 0
            shown[i] = t > shown[i] ? shown[i] + (t - shown[i]) * 0.6 : shown[i] - (shown[i] - t) * 0.12
        }
        return shown
    }

    /// Live sound when the audio tap is working; otherwise the song's analysed levels.
    @MainActor func source() -> (bands: [Float], wave: [Float]) {
        let player = Player.shared
        let tap = AudioTap.shared.frame()
        let now = Date()
        if tap.fresh { lastTap = now }
        if player.isPlaying { playingSince = playingSince ?? now } else { playingSince = nil }
        if tap.fresh || now.timeIntervalSince(lastTap) < 1.5 { return (tap.bands, tap.wave) }
        guard let song = player.current else { return (tap.bands, tap.wave) }
        // The tap has been quiet for a while during playback: use the backup.
        if let since = playingSince, now.timeIntervalSince(since) > 1.2 { AudioAnalysis.shared.need(song.id) }
        if player.isPlaying, let f = AudioAnalysis.shared.frame(song.id, at: player.exactTime) { return f }
        return (tap.bands, tap.wave)
    }
}

/// Album art, or the visualizer in its place when one is switched on.
struct ArtOrVisualizer: View {
    let song: Song
    var corner: CGFloat = 16
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        if settings.visualizer == "off" {
            CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 1000, corner: corner)
        } else {
            ZStack {
                Color.black.opacity(0.3)
                if settings.visualizer == "circle" {
                    CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 600, corner: 1000)
                        .scaleEffect(0.42)
                }
                VisualizerView(style: settings.visualizer)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: corner))
        }
    }
}

struct VisualizerView: View {
    let style: String
    @State private var smoother = VisSmoother()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { gc, size in
                _ = timeline.date // redraw on every tick
                let frame = smoother.source()
                let bands = smoother.step(frame.bands)
                let accent = Color.accentColor
                switch style {
                case "bars":
                    let n = CGFloat(bands.count)
                    let gap = size.width / n * 0.25
                    let w = size.width / n - gap
                    for (i, v) in bands.enumerated() {
                        let h = max(4, CGFloat(v) * size.height * 0.9)
                        let rect = CGRect(x: CGFloat(i) * (w + gap) + gap / 2, y: size.height - h, width: w, height: h)
                        gc.fill(Path(roundedRect: rect, cornerRadius: w / 2),
                                with: .linearGradient(Gradient(colors: [.white, accent]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
                    }
                case "wave":
                    let level = CGFloat(bands.reduce(0, +) / Float(max(bands.count, 1)))
                    var path = Path()
                    for (i, v) in frame.wave.enumerated() {
                        let x = size.width * CGFloat(i) / CGFloat(max(frame.wave.count - 1, 1))
                        let y = size.height / 2 - CGFloat(v) * size.height * 0.45 * (0.6 + level)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    gc.stroke(path, with: .color(accent.opacity(0.35)), lineWidth: 16)
                    gc.stroke(path, with: .color(accent), lineWidth: 6)
                default:
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let m = min(size.width, size.height)
                    let r0 = m * 0.23, maxLen = m * 0.25
                    let n = bands.count * 2
                    for i in 0..<n {
                        let v = CGFloat(bands[i < bands.count ? i : n - 1 - i])
                        let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n) - CGFloat.pi / 2
                        let len = 5 + v * maxLen
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
                        p.addLine(to: CGPoint(x: c.x + cos(a) * (r0 + len), y: c.y + sin(a) * (r0 + len)))
                        gc.stroke(p, with: .color(accent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    }
                }
            }
        }
    }
}

/// The visualizer filling the whole screen. Select changes the style, left and right skip,
/// play/pause works as usual and Menu closes it.
struct FullScreenVisualizer: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showInfo = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        let style = settings.visualizer == "off" ? "bars" : settings.visualizer
        ZStack {
            Color.black
                .overlay {
                    if let song = player.current {
                        CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 600, corner: 0)
                            .frame(width: 2100, height: 2100)
                            .blur(radius: 80)
                            .opacity(0.35)
                    }
                }
                .clipped()
                .ignoresSafeArea()
            if let song = player.current {
                if style == "circle" {
                    CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 800, corner: 1000)
                        .frame(width: 400, height: 400)
                }
            }
            Group {
                if style == "circle" {
                    VisualizerView(style: style).frame(width: 900, height: 900)
                } else {
                    VisualizerView(style: style).padding(.horizontal, 80).padding(.vertical, 120)
                }
            }
            if showInfo, let song = player.current {
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    Text(song.name).font(.title2).bold().lineLimit(1)
                    Text(song.artistName).font(.headline).foregroundStyle(.secondary).lineLimit(1)
                    Text("Select: change style  ·  ◀ ▶ skip  ·  Menu: close")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(60)
                .transition(.opacity)
            }
        }
        .focusable()
        .onTapGesture {
            let next = VisStyle.next(style) == "off" ? "bars" : VisStyle.next(style)
            settings.visualizer = next
            toast("Visualizer: \(VisStyle.label(next))")
            poke()
        }
        .onPlayPauseCommand { player.toggle(); poke() }
        .onMoveCommand { dir in
            switch dir {
            case .left: player.previous()
            case .right: player.next()
            default: break
            }
            poke()
        }
        .onExitCommand { dismiss() }
        .onAppear {
            if settings.visualizer == "off" { settings.visualizer = "bars" }
            poke()
        }
        .onDisappear { hideTask?.cancel() }
    }

    /// Shows the song details for a few seconds.
    private func poke() {
        withAnimation { showInfo = true }
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { withAnimation(.easeOut(duration: 1)) { showInfo = false } }
        }
    }
}
