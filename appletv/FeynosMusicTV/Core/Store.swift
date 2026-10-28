import Foundation

/// On-device data: listen history, generated mixes, likes, found cover art and pending scrobbles.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var plays: [Play]
    @Published var mixes: [Mix]
    @Published private(set) var covers: [String: CoverEntry]
    @Published var starOverrides: [String: Bool] = [:]
    /// Bumped whenever playlists or mixes change, so screens reload.
    @Published var version = 0

    private(set) var lbQueue: [Data]
    private var matchCache: [String: MatchEntry]

    struct MatchEntry: Codable {
        let song: Song?
        let at: Date
    }

    private static let fileNames = ["plays", "mixes", "covers", "lbqueue", "matches"]

    /// Each profile keeps its own files, e.g. "plays-<profile id>.json".
    private static func file(_ base: String) -> String {
        let id = AppSettings.shared.currentId
        let name = "\(base)-\(id.isEmpty ? "none" : id).json"
        // The first version stored one set of files; they belong to the migrated "default" profile.
        if id == "default", !FileManager.default.fileExists(atPath: Disk.dir.appendingPathComponent(name).path),
           FileManager.default.fileExists(atPath: Disk.dir.appendingPathComponent("\(base).json").path) {
            try? FileManager.default.moveItem(at: Disk.dir.appendingPathComponent("\(base).json"), to: Disk.dir.appendingPathComponent(name))
        }
        return name
    }

    static func deleteFiles(for profileId: String) {
        for base in fileNames { try? FileManager.default.removeItem(at: Disk.dir.appendingPathComponent("\(base)-\(profileId).json")) }
    }

    private init() {
        plays = Disk.load([Play].self, Store.file("plays")) ?? []
        mixes = Disk.load([Mix].self, Store.file("mixes")) ?? []
        covers = Disk.load([String: CoverEntry].self, Store.file("covers")) ?? [:]
        lbQueue = Disk.load([Data].self, Store.file("lbqueue")) ?? []
        matchCache = Disk.load([String: MatchEntry].self, Store.file("matches")) ?? [:]
    }

    /// Loads the current profile's data (after switching profiles).
    func reload() {
        plays = Disk.load([Play].self, Store.file("plays")) ?? []
        mixes = Disk.load([Mix].self, Store.file("mixes")) ?? []
        covers = Disk.load([String: CoverEntry].self, Store.file("covers")) ?? [:]
        lbQueue = Disk.load([Data].self, Store.file("lbqueue")) ?? []
        matchCache = Disk.load([String: MatchEntry].self, Store.file("matches")) ?? [:]
        starOverrides = [:]
        bump()
    }

    func bump() { version += 1 }

    // ---- History ----

    func addPlay(_ song: Song, at: Date) {
        plays.append(Play(song: song, at: at))
        if plays.count > 10_000 { plays.removeFirst(plays.count - 10_000) }
        Disk.save(plays, Store.file("plays"))
    }

    func recentSongs(_ limit: Int) -> [Song] {
        var seen = Set<String>()
        var out: [Song] = []
        for p in plays.reversed() where !seen.contains(p.song.id) {
            seen.insert(p.song.id)
            out.append(p.song)
            if out.count >= limit { break }
        }
        return out
    }

    func topSongs(since: Date, limit: Int) -> [(Song, Int)] {
        var counts: [String: (Song, Int)] = [:]
        for p in plays where p.at >= since {
            counts[p.song.id] = (p.song, (counts[p.song.id]?.1 ?? 0) + 1)
        }
        return counts.values.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }

    func topArtists(since: Date, limit: Int) -> [(name: String, id: String?, count: Int)] {
        var counts: [String: (String?, Int)] = [:]
        for p in plays where p.at >= since {
            guard let a = p.song.artist else { continue }
            counts[a] = (p.song.artistId ?? counts[a]?.0, (counts[a]?.1 ?? 0) + 1)
        }
        return counts.map { (name: $0.key, id: $0.value.0, count: $0.value.1) }.sorted { $0.count > $1.count }.prefix(limit).map { $0 }
    }

    var playedIds: Set<String> { Set(plays.map(\.song.id)) }

    func forgotten(before: Date, minPlays: Int, limit: Int) -> [Song] {
        var stats: [String: (Song, Int, Date)] = [:]
        for p in plays {
            let old = stats[p.song.id]
            stats[p.song.id] = (p.song, (old?.1 ?? 0) + 1, max(old?.2 ?? .distantPast, p.at))
        }
        return stats.values.filter { $0.1 >= minPlays && $0.2 < before }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    func stats(since: Date) -> (plays: Int, minutes: Int, songs: Int, artists: Int) {
        let list = plays.filter { $0.at >= since }
        return (
            list.count, list.reduce(0) { $0 + $1.song.seconds } / 60,
            Set(list.map(\.song.id)).count, Set(list.compactMap(\.song.artist)).count
        )
    }

    func playCounts(lastDays days: Int) -> [(String, Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let f = DateFormatter()
        f.dateFormat = days <= 7 ? "EEE" : "d"
        return (0..<days).map { i in
            let start = cal.date(byAdding: .day, value: i - days + 1, to: today) ?? today
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            return (f.string(from: start), plays.filter { $0.at >= start && $0.at < end }.count)
        }
    }

    // ---- Mixes ----

    func saveMixes(_ list: [Mix]) {
        mixes = list
        Disk.save(list, Store.file("mixes"))
        bump()
    }

    // ---- Likes ----

    func isStarred(_ id: String, _ server: String?) -> Bool { starOverrides[id] ?? (server != nil) }

    // ---- Pending ListenBrainz uploads ----

    func queueListen(_ body: Data) {
        lbQueue.append(body)
        Disk.save(lbQueue, Store.file("lbqueue"))
    }

    func flushListens() async {
        while let first = lbQueue.first {
            guard await ListenBrainz.shared.submit(first) else { return }
            lbQueue.removeFirst()
            Disk.save(lbQueue, Store.file("lbqueue"))
        }
    }

    // ---- ListenBrainz -> library matching cache ----

    func cachedMatch(_ key: String) -> MatchEntry? { matchCache[key] }

    func cacheMatch(_ key: String, _ song: Song?) {
        matchCache[key] = MatchEntry(song: song, at: Date())
        Disk.save(matchCache, Store.file("matches"))
    }

    // ---- Cover art ----

    func coverOverride(_ albumId: String?) -> String? {
        guard let albumId else { return nil }
        return covers[albumId]?.url
    }

    func setCover(_ entry: CoverEntry) {
        covers[entry.albumId] = entry
        Disk.save(covers, Store.file("covers"))
    }

    func setCovers(_ entries: [String: CoverEntry]) {
        covers = entries
        Disk.save(covers, Store.file("covers"))
    }
}
