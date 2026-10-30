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

/// Smooths the bars so they rise fast and fall slowly.
final class VisSmoother {
    var shown = [Float](repeating: 0, count: AudioTap.bandCount)
    func step(_ target: [Float]) -> [Float] {
        for i in shown.indices {
            let t = i < target.count ? target[i] : 0
            shown[i] = t > shown[i] ? shown[i] + (t - shown[i]) * 0.6 : shown[i] - (shown[i] - t) * 0.12
        }
        return shown
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
        TimelineView(.animation) { _ in
            Canvas { gc, size in
                let frame = AudioTap.shared.frame()
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
