import Foundation

/// Tidies the artist list: entries like "Eminem & D12", "Eminem ft. CeeLo Green" or
/// "Eminem, Dr. Dre & 50 Cent" are folded under "Eminem", whose page then shows their albums too.
/// An entry is only folded when the first name is an artist of its own in the library, so band
/// names such as "Mumford & Sons" or "Earth, Wind & Fire" stay as they are.
@MainActor
enum ArtistGroups {
    private static let splitter = try! NSRegularExpression(
        pattern: #"\s*(?:,|&|\+|/|;|\s(?:feat\.?|ft\.?|featuring|vs\.?|x|with|and)\s)\s*"#, options: [.caseInsensitive])
    private static var members: [String: [Artist]]?

    private static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The first artist named in a combined entry, or nil if the name isn't a combination.
    static func primaryName(_ name: String) -> String? {
        let ns = name as NSString
        guard let m = splitter.firstMatch(in: name, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let first = ns.substring(to: m.range.location).trimmingCharacters(in: .whitespaces)
        return first.isEmpty || first.count >= name.trimmingCharacters(in: .whitespaces).count ? nil : first
    }

    /// Main artists only; the combined entries are remembered for each main artist's page.
    static func group(_ all: [Artist]) -> [Artist] {
        var byName: [String: Artist] = [:]
        for a in all where byName[key(a.title)] == nil { byName[key(a.title)] = a }
        var found: [String: [Artist]] = [:]
        let shown = all.filter { a in
            if let p = primaryName(a.title), let main = byName[key(p)], main.id != a.id {
                found[main.id, default: []].append(a)
                return false
            }
            return true
        }
        members = found
        return shown.map { a in
            guard let extra = found[a.id] else { return a }
            var copy = a
            copy.albumCount = (a.albumCount ?? 0) + extra.reduce(0) { $0 + ($1.albumCount ?? 0) }
            return copy
        }
    }

    /// The combined entries filed under this artist (loads the artist list if needed).
    static func membersOf(_ artist: Artist) async -> [Artist] {
        if members == nil, let all = try? await Subsonic.shared.artists() { _ = group(all) }
        return members?[artist.id] ?? []
    }
}
