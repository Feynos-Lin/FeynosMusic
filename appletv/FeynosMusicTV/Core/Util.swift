import CryptoKit
import Foundation

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func md5(_ s: String) -> String { md5(Data(s.utf8)) }

func md5(_ d: Data) -> String {
    Insecure.MD5.hash(data: d).map { String(format: "%02x", $0) }.joined()
}

func randomSalt() -> String {
    String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let s = Int(seconds)
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
    return String(format: "%d:%02d", s / 60, s % 60)
}

func totalDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    return h > 0 ? "\(h) hr \(m) min" : "\(m) min"
}

func timeAgo(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f.localizedString(for: date, relativeTo: Date())
}

func stripHtml(_ s: String) -> String {
    s.replacingOccurrences(of: "<a [^>]*>.*?</a>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Drops "(Remastered)", "[Live]", " - 2011 Remaster" and similar from titles.
func cleanTitle(_ t: String) -> String {
    let a = t.replacingOccurrences(of: "\\s*[(\\[][^)\\]]*[)\\]]", with: "", options: .regularExpression)
    let b = a.replacingOccurrences(
        of: "\\s+-\\s+.*(remaster|version|edit|mix|live|mono|stereo).*", with: "",
        options: [.regularExpression, .caseInsensitive])
    let r = b.trimmingCharacters(in: .whitespaces)
    return r.isEmpty ? t : r
}

/// Lowercase, punctuation-free form used to compare titles and artists.
func norm(_ s: String) -> String {
    cleanTitle(s).lowercased()
        .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
}

func similar(_ a: String, _ b: String) -> Bool {
    let x = norm(a), y = norm(b)
    if x.isEmpty || y.isEmpty { return false }
    return x == y || (x.count >= 3 && y.contains(x)) || (y.count >= 3 && x.contains(y))
}

/// Navidrome album cover ids look like "al-<albumId>_<hex>".
func albumIdFromCover(_ coverId: String?) -> String? {
    guard let c = coverId, c.hasPrefix("al-") else { return nil }
    let rest = c.dropFirst(3)
    let id = rest.split(separator: "_").first.map(String.init) ?? String(rest)
    return id.isEmpty ? nil : id
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

extension String {
    var pathEncoded: String { addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self }
    var queryEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

// tvOS apps may only keep files in Caches (it can be cleared when the box is low on space).
// Your history also lives on Navidrome and ListenBrainz, so nothing important is lost.
enum Disk {
    static var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FeynosMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func save<T: Encodable>(_ value: T, _ name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: dir.appendingPathComponent(name), options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
