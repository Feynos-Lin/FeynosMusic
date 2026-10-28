import UIKit
import Foundation

// MARK: - Matching ListenBrainz tracks to your library

@MainActor
enum Matcher {
    static func match(_ t: LbTrack) async -> Song? {
        let key = norm(t.artist) + "|" + norm(t.title)
        if let c = Store.shared.cachedMatch(key), c.song != nil || Date().timeIntervalSince(c.at) < 7 * 86400 { return c.song }
        let firstArtist = t.artist.components(separatedBy: CharacterSet(charactersIn: ",&")).first?
            .replacingOccurrences(of: " feat.", with: "").trimmingCharacters(in: .whitespaces) ?? t.artist
        var best: Song?
        var bestScore = 0
        for q in Array(Set(["\(cleanTitle(t.title)) \(firstArtist)", cleanTitle(t.title)])) {
            guard let results = try? await Subsonic.shared.search(q, songs: 25) else { return nil }
            for s in results {
                let sc = score(s, t)
                if sc > bestScore {
                    bestScore = sc
                    best = s
                }
            }
            if bestScore >= 85 { break }
        }
        let result = bestScore >= 60 ? best : nil
        Store.shared.cacheMatch(key, result)
        return result
    }

    static func matchAll(_ tracks: [LbTrack]) async -> [Song?] {
        var out: [Song?] = []
        for t in tracks { out.append(await match(t)) }
        return out
    }

    private static func score(_ s: Song, _ t: LbTrack) -> Int {
        if let m = t.mbid, !m.isEmpty, s.musicBrainzId == m { return 100 }
        let st = norm(s.name), tt = norm(t.title)
        if st.isEmpty || tt.isEmpty { return 0 }
        var sc: Int
        if st == tt { sc = 50 } else if st.hasPrefix(tt) || tt.hasPrefix(st) { sc = 35 } else if st.contains(tt) || tt.contains(st) { sc = 25 } else { return 0 }
        let sa = norm(s.artistName), a = norm(t.artist)
        if sa.isEmpty || a.isEmpty {
        } else if sa == a { sc += 50 } else if a.contains(sa) || sa.contains(a) { sc += 40 } else if a.split(separator: " ").contains(where: { $0.count > 2 && sa.contains($0) }) { sc += 20 }
        return sc
    }
}

// MARK: - Weekly mixes

@MainActor
final class Mixes: ObservableObject {
    static let shared = Mixes()
    @Published private(set) var generating = false

    func maybeGenerate() async {
        let s = AppSettings.shared
        guard s.loggedIn, Date().timeIntervalSince1970 - s.lastMixGen > 7 * 86400 else { return }
        await generate(quiet: true)
    }

    private func interleave(_ lists: [[Song]]) -> [Song] {
        var out: [Song] = []
        let m = lists.map(\.count).max() ?? 0
        for i in 0..<m { for l in lists where i < l.count { out.append(l[i]) } }
        return out
    }

    func generate(quiet: Bool = false) async {
        guard !generating else { return }
        generating = true
        defer { generating = false }
        let api = Subsonic.shared, lb = ListenBrainz.shared, store = Store.shared, s = AppSettings.shared
        let day: TimeInterval = 86400
        let now = Date()
        let played = store.playedIds
        let onRepeat = store.topSongs(since: now.addingTimeInterval(-30 * day), limit: 40).map(\.0)
        let allTop = store.topSongs(since: .distantPast, limit: 300).map(\.0)
        let topArtists = store.topArtists(since: now.addingTimeInterval(-90 * day), limit: 8)
        let lbOn = s.lbConnected

        let lbTop = lbOn ? ((try? await lb.topRecordings(range: "month", count: 40)) ?? []) : []
        let lbTopSongs = await Matcher.matchAll(lbTop).compactMap { $0 }
        let lbRefs = lbOn ? ((try? await lb.createdFor()) ?? []) : []

        var result: [Mix] = []
        func add(_ id: String, _ title: String, _ desc: String, _ songs: [Song], min: Int = 5) {
            var seen = Set<String>()
            let list = songs.filter { seen.insert($0.id).inserted }
            guard list.count >= min else { return }
            result.append(Mix(id: id, title: title, description: desc, createdAt: now, coverArt: list.first { $0.coverArt != nil }?.coverArt, songs: list))
        }

        // Weekly Mix
        var similar: [Song] = []
        for a in topArtists.prefix(5) {
            guard let seed = onRepeat.first(where: { $0.artist == a.name }) ?? allTop.first(where: { $0.artist == a.name }) else { continue }
            similar += (try? await api.similarSongs(seed.id, count: 15)) ?? []
        }
        if similar.count < 10 { for a in topArtists.prefix(5) { similar += (try? await api.topSongs(a.name, count: 6)) ?? [] } }
        add("weekly", "Weekly Mix", "Your favourites mixed with songs like them. Refreshed every week.",
            Array(interleave([Array(onRepeat.shuffled().prefix(15)), Array(lbTopSongs.shuffled().prefix(12)), Array(similar.shuffled().prefix(25))]).prefix(50)))

        // Discover Weekly
        var discover: [Song] = []
        if let ref = lbRefs.first(where: { $0.title.localizedCaseInsensitiveContains("Exploration") }),
           let pl = try? await lb.playlist(ref.mbid) {
            discover += await Matcher.matchAll(Array(pl.1.prefix(50))).compactMap { $0 }
        }
        if lbOn, let recs = try? await lb.cfRecommendations(count: 80), !recs.isEmpty {
            let meta = await lb.recordingMetadata(Array(recs.prefix(50)))
            discover += await Matcher.matchAll(meta).compactMap { $0 }
        }
        for a in topArtists.prefix(6) {
            guard let id = a.id, let info = try? await api.artistInfo(id) else { continue }
            for sim in (info.similarArtist ?? []).filter({ !$0.id.isEmpty }).prefix(4) {
                guard let artist = try? await api.artist(sim.id), let album = (artist.album ?? []).randomElement(),
                      let full = try? await api.album(album.id) else { continue }
                discover += full.songs.shuffled().prefix(2)
            }
        }
        for seed in onRepeat.prefix(5) { discover += (try? await api.similarSongs(seed.id, count: 10)) ?? [] }
        var unheard = discover.filter { !played.contains($0.id) }
        if unheard.count < 25 {
            unheard += ((try? await api.randomSongs(150)) ?? []).filter { !played.contains($0.id) }.prefix(35 - unheard.count)
        }
        add("discover", "Discover Weekly", "Songs from your library you haven't played yet, picked for you.", Array(unheard.shuffled().prefix(40)))

        // Artist mixes
        for (i, a) in topArtists.prefix(3).enumerated() {
            var pool = Array(allTop.filter { $0.artist == a.name }.prefix(10))
            pool += (try? await api.topSongs(a.name, count: 10)) ?? []
            if let id = a.id { pool += (try? await api.similarSongsForArtist(id, count: 30)) ?? [] }
            add("artist_\(i)", "\(a.name) Mix", "\(a.name) and artists like them.", Array(pool.shuffled().prefix(40)), min: 8)
        }

        add("repeat", "On Repeat", "The songs you can't stop playing right now.", Array(onRepeat.prefix(30)))
        add("gems", "Forgotten Gems", "Old favourites you haven't played in a while.",
            store.forgotten(before: now.addingTimeInterval(-60 * day), minPlays: 3, limit: 30).shuffled())

        var fresh: [Song] = []
        for al in (try? await api.albumList("newest", size: 12)) ?? [] {
            fresh += ((try? await api.album(al.id))?.songs ?? []).filter { !played.contains($0.id) }.shuffled().prefix(3)
        }
        add("fresh", "Fresh Finds", "New additions to your library you haven't heard yet.", Array(fresh.prefix(40)))

        for ref in lbRefs.prefix(4) {
            guard let pl = try? await lb.playlist(ref.mbid) else { continue }
            let songs = await Matcher.matchAll(Array(pl.1.prefix(60))).compactMap { $0 }
            let title = pl.0.components(separatedBy: " for ").first?.trimmingCharacters(in: .whitespaces) ?? pl.0
            add("lb_\(ref.mbid)", title.isEmpty ? pl.0 : title, "From ListenBrainz, matched to your library.", songs)
        }

        store.saveMixes(result)
        if s.syncMixes {
            for m in result { try? await api.savePlaylist(named: "Feynos · \(m.title)", songs: m.songs) }
        }
        s.lastMixGen = now.timeIntervalSince1970
        if !quiet { toast("Made \(result.count) mixes for you") }
        if s.autoCovers { await Covers.shared.scan(full: false, quiet: true) }
    }
}

// MARK: - Missing cover art

@MainActor
final class Covers: ObservableObject {
    static let shared = Covers()
    @Published private(set) var running = false
    @Published private(set) var phase = ""
    @Published private(set) var done = 0
    @Published private(set) var total = 0
    @Published private(set) var found = 0
    private var cancelled = false
    private var lastMbCall = Date.distantPast
    /// Albums with no match online are tried again after a day.
    private static let retry: TimeInterval = 86400
    private static let noise = "\\b(deluxe|expanded|explicit|clean|remaster(ed)?|anniversary|special|super|edition|version|bonus|tracks?|reissue|complete)\\b"

    // MARK: On-demand lookups
    // When a cover fails to load anywhere in the app, that album is looked up right away
    // instead of waiting for the weekly scan.
    private var asked: [String: Date] = [:]
    private var pending: [String] = []
    private var working = false

    func requestLookup(_ albumId: String?) {
        guard let id = albumId, !id.isEmpty, AppSettings.shared.autoCovers, Store.shared.coverOverride(id) == nil else { return }
        if let t = asked[id], Date().timeIntervalSince(t) < Self.retry { return }
        asked[id] = Date()
        pending.append(id)
        guard !working else { return }
        working = true
        Task {
            while !pending.isEmpty {
                let next = pending.removeFirst()
                await lookupOne(next)
            }
            working = false
        }
    }

    private func lookupOne(_ id: String) async {
        let now = Date()
        if let e = Store.shared.covers[id], e.url != nil || (e.missing && now.timeIntervalSince(e.checkedAt) < Self.retry) { return }
        guard let album = try? await Subsonic.shared.album(id) else { return }
        let best = await bestMatch(artist: album.artist ?? "", album: album.title)
        var e = Store.shared.covers[id] ?? CoverEntry(albumId: id, name: album.title, artist: album.artist ?? "", coverArt: album.coverArt,
                                                     hash: "none", missing: true, url: nil, source: nil, checkedAt: now)
        e.missing = true
        e.checkedAt = now
        if let best {
            e.url = best.url
            e.source = best.source
        }
        Store.shared.setCover(e)
    }

    /// "For All The Dogs (Explicit) [Deluxe Edition] - Remastered" -> "For All The Dogs"
    private func simplify(_ album: String) -> String {
        let a = cleanTitle(album)
            .replacingOccurrences(of: "\\s+[-–:]\\s+.*$", with: "", options: .regularExpression)
            .replacingOccurrences(of: Self.noise, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? album : a
    }

    private func coverNorm(_ s: String) -> String {
        norm(s).replacingOccurrences(of: Self.noise, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func sameName(_ a: String, _ b: String) -> Bool {
        let x = coverNorm(a), y = coverNorm(b)
        if x.isEmpty || y.isEmpty { return false }
        return x == y || (x.count >= 3 && y.contains(x)) || (y.count >= 3 && x.contains(y))
    }

    /// Cover image URL, preferring art the finder picked.
    func artURL(_ coverArt: String?, albumId: String?, size: Int) -> URL? {
        if let o = Store.shared.coverOverride(albumId ?? albumIdFromCover(coverArt)), let u = URL(string: o) { return u }
        return Subsonic.shared.coverURL(coverArt, size: size)
    }

    private func json(_ url: String) async -> [String: Any]? {
        guard let u = URL(string: url) else { return nil }
        var req = URLRequest(url: u)
        req.setValue("FeynosMusicTV/1.0 ( https://github.com/Feynos-Lin/FeynosMusic )", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let result = try? await URLSession.shared.data(for: req),
              ((result.1 as? HTTPURLResponse)?.statusCode ?? 0) < 300 else { return nil }
        return try? JSONSerialization.jsonObject(with: result.0) as? [String: Any]
    }

    private func q(_ s: String) -> String { s.replacingOccurrences(of: "\"", with: "") }

    private func deezer(_ artist: String, _ album: String) async -> [CoverCandidate] {
        let query = artist.isEmpty ? "album:\"\(q(album))\"" : "artist:\"\(q(artist))\" album:\"\(q(album))\""
        let r = await json("https://api.deezer.com/search/album?limit=6&q=\(query.queryEncoded)")
        return (r?["data"] as? [[String: Any]] ?? []).compactMap { d in
            guard let big = d["cover_xl"] as? String ?? d["cover_big"] as? String, !big.contains("/images/cover//") else { return nil }
            return CoverCandidate(url: big, thumb: d["cover_medium"] as? String ?? big, source: "Deezer",
                                  title: d["title"] as? String ?? "", artist: (d["artist"] as? [String: Any])?["name"] as? String ?? "")
        }
    }

    /// Plain keyword search: forgives punctuation and small spelling differences.
    private func deezerLoose(_ artist: String, _ album: String) async -> [CoverCandidate] {
        let r = await json("https://api.deezer.com/search/album?limit=10&q=\("\(artist) \(album)".trimmingCharacters(in: .whitespaces).queryEncoded)")
        return (r?["data"] as? [[String: Any]] ?? []).compactMap { d in
            guard let big = d["cover_xl"] as? String ?? d["cover_big"] as? String, !big.contains("/images/cover//") else { return nil }
            return CoverCandidate(url: big, thumb: d["cover_medium"] as? String ?? big, source: "Deezer",
                                  title: d["title"] as? String ?? "", artist: (d["artist"] as? [String: Any])?["name"] as? String ?? "")
        }
    }

    private func itunes(_ artist: String, _ album: String) async -> [CoverCandidate] {
        let r = await json("https://itunes.apple.com/search?entity=album&limit=6&term=\("\(artist) \(album)".queryEncoded)")
        return (r?["results"] as? [[String: Any]] ?? []).compactMap { d in
            guard let art = d["artworkUrl100"] as? String else { return nil }
            return CoverCandidate(url: art.replacingOccurrences(of: "100x100bb", with: "1000x1000bb"),
                                  thumb: art.replacingOccurrences(of: "100x100bb", with: "300x300bb"), source: "iTunes",
                                  title: d["collectionName"] as? String ?? "", artist: d["artistName"] as? String ?? "")
        }
    }

    private func musicBrainz(_ artist: String, _ album: String) async -> [CoverCandidate] {
        let wait = 1.1 - Date().timeIntervalSince(lastMbCall)
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        lastMbCall = Date()
        let query = artist.isEmpty ? "releasegroup:\"\(q(album))\"" : "releasegroup:\"\(q(album))\" AND artist:\"\(q(artist))\""
        let r = await json("https://musicbrainz.org/ws/2/release-group/?fmt=json&limit=5&query=\(query.queryEncoded)")
        return (r?["release-groups"] as? [[String: Any]] ?? []).compactMap { g in
            guard let id = g["id"] as? String, ((g["score"] as? NSNumber)?.intValue ?? 0) >= 80 else { return nil }
            let credit = (g["artist-credit"] as? [[String: Any]])?.first?["name"] as? String ?? ""
            return CoverCandidate(url: "https://coverartarchive.org/release-group/\(id)/front-1200",
                                  thumb: "https://coverartarchive.org/release-group/\(id)/front-250",
                                  source: "Cover Art Archive", title: g["title"] as? String ?? "", artist: credit)
        }
    }

    private func exists(_ url: String) async -> Bool {
        guard let u = URL(string: url) else { return false }
        var req = URLRequest(url: u)
        req.httpMethod = "HEAD"
        guard let result = try? await URLSession.shared.data(for: req) else { return false }
        return ((result.1 as? HTTPURLResponse)?.statusCode ?? 0) < 300
    }

    func candidates(artist: String, album: String) async -> [CoverCandidate] {
        await musicBrainz(artist, album) + deezer(artist, album) + itunes(artist, album)
    }

    func bestMatch(artist: String, album: String) async -> CoverCandidate? {
        func ok(_ c: CoverCandidate) -> Bool { sameName(c.title, album) && (artist.isEmpty || c.artist.isEmpty || sameName(c.artist, artist)) }
        let simple = simplify(album)
        let names = simple == album ? [album] : [album, simple]
        for n in names { if let d = await deezer(artist, n).first(where: ok) { return d } }
        for n in names { if let d = await deezerLoose(artist, n).first(where: ok) { return d } }
        for n in names { if let d = await itunes(artist, n).first(where: ok) { return d } }
        for c in await musicBrainz(artist, simple).filter(ok) {
            if await exists(c.thumb) { return c }
        }
        // Last try: album name only, but the artist must still agree.
        guard !artist.isEmpty else { return nil }
        return await deezer("", simple).first { ok($0) && sameName($0.artist, artist) }
    }

    func set(_ album: Album, url: String?, source: String?) {
        var e = Store.shared.covers[album.id] ?? CoverEntry(albumId: album.id, name: album.title, artist: album.artist ?? "",
                                                         coverArt: album.coverArt, hash: nil, missing: false, url: nil, source: nil, checkedAt: Date())
        e.url = url
        e.source = source
        Store.shared.setCover(e)
    }

    private func hashOf(_ url: URL?) async -> String? {
        guard let url, let result = try? await URLSession.shared.data(from: url),
              ((result.1 as? HTTPURLResponse)?.statusCode ?? 0) < 300 else { return nil }
        // An image the TV can't decode shows as a blank square, so treat it as missing.
        guard UIImage(data: result.0) != nil else { return nil }
        return md5(result.0)
    }

    func stop() { cancelled = true }

    /// Finds albums that only show the server's placeholder image and looks up real covers.
    func scan(full: Bool, quiet: Bool = false) async {
        guard !running else { return }
        running = true
        cancelled = false
        found = 0
        defer {
            running = false
            phase = ""
        }
        let api = Subsonic.shared
        phase = "Loading albums"
        var albums: [Album] = []
        var offset = 0
        while true {
            guard let page = try? await api.albumList("alphabeticalByName", size: 500, offset: offset) else { break }
            albums += page
            if page.count < 500 { break }
            offset += 500
        }
        var entries = Store.shared.covers
        phase = "Checking artwork"
        total = albums.count
        for (i, al) in albums.enumerated() {
            if cancelled { break }
            done = i + 1
            let old = entries[al.id]
            if !full, let old, old.hash != nil, old.coverArt == al.coverArt { continue }
            let h = al.coverArt == nil ? "none" : (await hashOf(api.coverURL(al.coverArt, size: 64)) ?? "none")
            entries[al.id] = CoverEntry(albumId: al.id, name: al.title, artist: al.artist ?? "", coverArt: al.coverArt, hash: h,
                                        missing: old?.missing ?? false, url: old?.url, source: old?.source, checkedAt: old?.checkedAt ?? .distantPast)
        }
        let present = Set(albums.map(\.id))
        let live = entries.values.filter { present.contains($0.albumId) }
        let fake = await hashOf(api.coverURL("al-feynos-missing-cover-check", size: 64))
        var groups: [String: [CoverEntry]] = [:]
        for e in live { if let h = e.hash { groups[h, default: []].append(e) } }
        var placeholders = Set(groups.filter { $0.value.count >= 3 && Set($0.value.map(\.artist)).count >= 2 }.keys)
        placeholders.insert("none")
        if let fake { placeholders.insert(fake) }

        for var e in live where !placeholders.contains(e.hash ?? "") && e.missing {
            e.missing = false
            if e.source != "manual" { e.url = nil; e.source = nil }
            entries[e.albumId] = e
        }
        let missing = live.filter { placeholders.contains($0.hash ?? "") }
        phase = "Finding artwork online"
        total = missing.count
        done = 0
        let now = Date()
        for (i, var e) in missing.enumerated() {
            if cancelled { break }
            done = i + 1
            let recentlyFailed = e.missing && e.url == nil && now.timeIntervalSince(e.checkedAt) < Self.retry
            if !full && (e.url != nil || recentlyFailed) { continue }
            let best = await bestMatch(artist: e.artist, album: e.name)
            e.missing = true
            e.checkedAt = now
            if let best {
                e.url = best.url
                e.source = best.source
                found += 1
            }
            entries[e.albumId] = e
            Store.shared.setCovers(entries)
        }
        Store.shared.setCovers(entries)
        if !quiet { toast(found == 0 ? "No new cover art found" : "Found cover art for \(found) albums") }
    }
}
