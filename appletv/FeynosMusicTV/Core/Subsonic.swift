import Foundation

/// Navidrome speaks the Subsonic / OpenSubsonic REST API.
@MainActor
final class Subsonic {
    static let shared = Subsonic()
    private var s: AppSettings { .shared }

    struct Creds {
        let server: String
        let user: String
        let token: String
        let salt: String
    }

    private var current: Creds { Creds(server: s.serverUrl, user: s.username, token: s.token, salt: s.salt) }

    func url(_ endpoint: String, _ params: [(String, String)] = [], creds: Creds? = nil) -> URL? {
        let c = creds ?? current
        var base = c.server
        while base.hasSuffix("/") { base.removeLast() }
        let all: [(String, String)] = [
            ("u", c.user), ("t", c.token), ("s", c.salt), ("v", "1.16.1"), ("c", "FeynosMusicTV"), ("f", "json"),
        ] + params
        let query = all.map { "\($0.0.queryEncoded)=\($0.1.queryEncoded)" }.joined(separator: "&")
        return URL(string: "\(base)/rest/\(endpoint)?\(query)")
    }

    @discardableResult
    func call(_ endpoint: String, _ params: [(String, String)] = [], creds: Creds? = nil) async throws -> SubsonicResponse {
        guard let u = url(endpoint, params, creds: creds) else { throw AppError("Invalid server address") }
        var req = URLRequest(url: u)
        req.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            throw AppError("Server returned HTTP \(h.statusCode)")
        }
        let env: SubsonicEnvelope
        do {
            env = try JSONDecoder().decode(SubsonicEnvelope.self, from: data)
        } catch {
            throw AppError("This doesn't look like a Navidrome server")
        }
        if env.response.status != "ok" { throw AppError(env.response.error?.message ?? "Server error") }
        return env.response
    }

    // ---- Account ----

    func login(server: String, user: String, password: String) async throws {
        var raw = server.trimmingCharacters(in: .whitespaces)
        while raw.hasSuffix("/") { raw.removeLast() }
        let candidates = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? [raw] : ["https://\(raw)", "http://\(raw)"]
        let salt = randomSalt()
        let token = md5(password + salt)
        var last: Error = AppError("Couldn't connect")
        for c in candidates {
            let creds = Creds(server: c, user: user.trimmingCharacters(in: .whitespaces), token: token, salt: salt)
            do {
                try await call("ping", creds: creds)
                s.serverUrl = creds.server
                s.username = creds.user
                s.token = token
                s.salt = salt
                return
            } catch {
                last = error
            }
        }
        throw last
    }

    // ---- Browsing ----

    func albumList(_ type: String, size: Int = 30, offset: Int = 0, genre: String? = nil) async throws -> [Album] {
        var p = [("type", type), ("size", "\(size)"), ("offset", "\(offset)")]
        if let genre { p.append(("genre", genre)) }
        return try await call("getAlbumList2", p).albumList2?.album ?? []
    }

    func album(_ id: String) async throws -> Album {
        guard let a = try await call("getAlbum", [("id", id)]).album else { throw AppError("Album not found") }
        return a
    }

    func artists() async throws -> [Artist] {
        (try await call("getArtists").artists?.index ?? []).flatMap { $0.artist ?? [] }
    }

    func artist(_ id: String) async throws -> Artist {
        guard let a = try await call("getArtist", [("id", id)]).artist else { throw AppError("Artist not found") }
        return a
    }

    func artistInfo(_ id: String) async throws -> ArtistInfo? {
        try await call("getArtistInfo2", [("id", id), ("count", "20")]).artistInfo2
    }

    func topSongs(_ artistName: String, count: Int = 20) async throws -> [Song] {
        try await call("getTopSongs", [("artist", artistName), ("count", "\(count)")]).topSongs?.song ?? []
    }

    func similarSongs(_ id: String, count: Int = 50) async throws -> [Song] {
        try await call("getSimilarSongs", [("id", id), ("count", "\(count)")]).similarSongs?.song ?? []
    }

    func similarSongsForArtist(_ id: String, count: Int = 50) async throws -> [Song] {
        try await call("getSimilarSongs2", [("id", id), ("count", "\(count)")]).similarSongs2?.song ?? []
    }

    func randomSongs(_ size: Int = 50, genre: String? = nil) async throws -> [Song] {
        var p = [("size", "\(size)")]
        if let genre { p.append(("genre", genre)) }
        return try await call("getRandomSongs", p).randomSongs?.song ?? []
    }

    func search(_ q: String) async throws -> SearchResult {
        try await call("search3", [("query", q), ("artistCount", "10"), ("albumCount", "20"), ("songCount", "50")]).searchResult3
            ?? SearchResult()
    }

    func search(_ q: String, songs: Int) async throws -> [Song] {
        try await call("search3", [("query", q), ("artistCount", "0"), ("albumCount", "0"), ("songCount", "\(songs)")])
            .searchResult3?.song ?? []
    }

    func genres() async throws -> [Genre] { try await call("getGenres").genres?.genre ?? [] }

    func songsByGenre(_ genre: String, count: Int = 200) async throws -> [Song] {
        try await call("getSongsByGenre", [("genre", genre), ("count", "\(count)")]).songsByGenre?.song ?? []
    }

    // ---- Playlists ----

    func playlists() async throws -> [Playlist] { try await call("getPlaylists").playlists?.playlist ?? [] }

    func playlist(_ id: String) async throws -> Playlist {
        guard let p = try await call("getPlaylist", [("id", id)]).playlist else { throw AppError("Playlist not found") }
        return p
    }

    /// Creates a playlist, or replaces the songs of `playlistId` when given.
    func createPlaylist(name: String?, songIds: [String], playlistId: String? = nil) async throws {
        var p: [(String, String)] = []
        if let name { p.append(("name", name)) }
        if let playlistId { p.append(("playlistId", playlistId)) }
        p += songIds.map { ("songId", $0) }
        try await call("createPlaylist", p)
    }

    func addToPlaylist(_ id: String, songIds: [String]) async throws {
        try await call("updatePlaylist", [("playlistId", id)] + songIds.map { ("songIdToAdd", $0) })
    }

    func removeFromPlaylist(_ id: String, index: Int) async throws {
        try await call("updatePlaylist", [("playlistId", id), ("songIndexToRemove", "\(index)")])
    }

    func deletePlaylist(_ id: String) async throws { try await call("deletePlaylist", [("id", id)]) }

    /// Saves (or replaces) a playlist by name.
    func savePlaylist(named name: String, songs: [Song]) async throws {
        let existing = try await playlists().first { $0.name == name }
        if let existing {
            try await createPlaylist(name: nil, songIds: songs.map(\.id), playlistId: existing.id)
        } else {
            try await createPlaylist(name: name, songIds: songs.map(\.id))
        }
    }

    // ---- Likes & scrobbles ----

    func starred() async throws -> SearchResult { try await call("getStarred2").starred2 ?? SearchResult() }

    func setStar(_ on: Bool, id: String? = nil, albumId: String? = nil, artistId: String? = nil) async throws {
        var p: [(String, String)] = []
        if let id { p.append(("id", id)) }
        if let albumId { p.append(("albumId", albumId)) }
        if let artistId { p.append(("artistId", artistId)) }
        try await call(on ? "star" : "unstar", p)
    }

    func scrobble(_ id: String, at: Date, submission: Bool) async throws {
        try await call("scrobble", [
            ("id", id), ("time", "\(Int64(at.timeIntervalSince1970 * 1000))"), ("submission", submission ? "true" : "false"),
        ])
    }

    // ---- Lyrics ----

    func lyrics(_ song: Song) async -> Lyrics? {
        if let list = try? await call("getLyricsBySongId", [("id", song.id)]).lyricsList?.structuredLyrics, !list.isEmpty {
            let pick = list.first { $0.synced == true } ?? list[0]
            let lines = pick.line ?? []
            if !lines.isEmpty { return Lyrics(synced: pick.synced == true, lines: lines) }
        }
        guard let artist = song.artist,
              let text = try? await call("getLyrics", [("artist", artist), ("title", song.name)]).lyrics?.value,
              !text.isEmpty else { return nil }
        return parseLrc(text)
    }

    private func parseLrc(_ text: String) -> Lyrics {
        let raw = text.components(separatedBy: .newlines)
        var timed: [LyricLine] = []
        let re = try? NSRegularExpression(pattern: "^\\[(\\d+):(\\d+)(?:[.:](\\d+))?\\](.*)$")
        for line in raw {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard let re, let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) else { continue }
            func g(_ i: Int) -> String {
                guard let r = Range(m.range(at: i), in: t) else { return "" }
                return String(t[r])
            }
            let frac = g(3).isEmpty ? 0 : Int(String((g(3) + "000").prefix(3))) ?? 0
            let ms = (Int(g(1)) ?? 0) * 60_000 + (Int(g(2)) ?? 0) * 1000 + frac
            timed.append(LyricLine(start: ms, value: g(4).trimmingCharacters(in: .whitespaces)))
        }
        if !timed.isEmpty && timed.count >= raw.filter({ !$0.isEmpty }).count / 2 { return Lyrics(synced: true, lines: timed) }
        return Lyrics(synced: false, lines: raw.map { LyricLine(start: nil, value: $0) })
    }

    // ---- URLs ----

    func coverURL(_ id: String?, size: Int = 500) -> URL? {
        guard let id, !id.isEmpty, s.loggedIn else { return nil }
        return url("getCoverArt", [("id", id), ("size", "\(size)")])
    }

    func streamURL(_ id: String) -> URL? {
        var p = [("id", id)]
        if s.maxBitrate > 0 { p.append(("maxBitRate", "\(s.maxBitrate)")) }
        if s.format != "raw" { p.append(("format", s.format)) }
        return url("stream", p)
    }
}
