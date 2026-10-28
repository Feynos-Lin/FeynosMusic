import SwiftUI

/// Colour themes. The "-style" ones borrow the colour feel of other music apps (no logos or branding).
struct TVTheme: Identifiable {
    let id: String
    let name: String
    let accent: Color
    let background: Color
    let container: Color

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static let all: [TVTheme] = [
        TVTheme(id: "feynos", name: "Feynos purple", accent: hex(0xA970FF), background: hex(0x0E0E12), container: hex(0x3A2766)),
        TVTheme(id: "spotify", name: "Green & black (Spotify-style)", accent: hex(0x1ED760), background: hex(0x121212), container: hex(0x0F3D22)),
        TVTheme(id: "apple", name: "Rose red (Apple Music-style)", accent: hex(0xFA2D48), background: hex(0x000000), container: hex(0x4A1019)),
        TVTheme(id: "youtube", name: "Red & black (YouTube Music-style)", accent: hex(0xFF0033), background: hex(0x030303), container: hex(0x4A0010)),
        TVTheme(id: "soundcloud", name: "Orange (SoundCloud-style)", accent: hex(0xFF5500), background: hex(0x121212), container: hex(0x4D1C00)),
        TVTheme(id: "tidal", name: "Black & cyan (Tidal-style)", accent: hex(0x33FFEE), background: hex(0x000000), container: hex(0x0B3D3A)),
        TVTheme(id: "amazon", name: "Teal (Amazon Music-style)", accent: hex(0x25D1DA), background: hex(0x0B0F12), container: hex(0x0E3B42)),
        TVTheme(id: "deezer", name: "Violet (Deezer-style)", accent: hex(0xA238FF), background: hex(0x0F0D13), container: hex(0x3B1A66)),
    ]

    static func byId(_ id: String) -> TVTheme { all.first { $0.id == id } ?? all[0] }
}
