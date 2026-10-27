import Foundation

/// ListenBrainz (MetaBrainz): scrobbling, listen history, stats and curated playlists.
@MainActor
final class ListenBrainz {
    static let shared = ListenBrainz()
    private let base = "https://api.listenbrainz.org"
    private var s: AppSettings { .shared }

    private func get(_ path: String, token: String? = nil) async throws -> [String: Any]? {
        guard let u = URL(string: base + path) else { return nil }
        var req = URLRequest(url: u)
        req.timeoutInterval = 30
        let t = token ?? s.lbToken
        if !t.isEmpty { req.setValue("Token \(t)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 204 || code == 404 { return nil }
        guard (200..<300).contains(code) else { throw AppError("ListenBrainz returned HTTP \(code)") }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private var userPath: String { s.lbUser.pathEncoded }

    /// The user name for a valid token, or nil.
    func validate(_ token: String) async throws -> String? {
        let r = try await get("/1/validate-token", token: token.trimmingCharacters(in: .whitespaces))
        guard r?["valid"] as? Bool == true else { return nil }
        return r?["user_name"] as? String
    }

    func submit(_ body: Data) async -> Bool {
        guard !s.lbToken.isEmpty, let u = URL(string: base + "/1/submit-listens") else { return false }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("Token \(s.lbToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        guard let result = try? await URLSession.shared.data(for: req) else { return false }
        return (200..<300).contains((result.1 as? HTTPURLResponse)?.statusCode ?? 0)
    }

    func listenBody(_ type: String, song: Song, at: Date?) -> Data {
        var info: [String: Any] = [
            "media_player": "Feynos Music TV",
            "submission_client": "Feynos Music TV",
            "submission_client_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        ]
        if song.seconds > 0 { info["duration_ms"] = song.seconds * 1000 }
        var meta: [String: Any] = ["artist_name": song.artist ?? "Unknown Artist", "track_name": song.name, "additional_info": info]
        if let a = song.album { meta["release_name"] = a }
        var listen: [String: Any] = ["track_metadata": meta]
        if let at { listen["listened_at"] = Int(at.timeIntervalSince1970) }
        let body: [String: Any] = ["listen_type": type, "payload": [listen]]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    private func track(_ m: [String: Any]?, at: Date? = nil) -> LbTrack? {
        guard let m, let title = m["track_name"] as? String else { return nil }
        let mapping = m["mbid_mapping"] as? [String: Any]
        let extra = m["additional_info"] as? [String: Any]
        return LbTrack(
            title: title, artist: m["artist_name"] as? String ?? "", album: m["release_name"] as? String,
            mbid: mapping?["recording_mbid"] as? String ?? extra?["recording_mbid"] as? String, listenedAt: at)
    }

    func recentListens(count: Int = 100) async throws -> [LbTrack] {
        let r = try await get("/1/user/\(userPath)/listens?count=\(count)")
        let listens = (r?["payload"] as? [String: Any])?["listens"] as? [[String: Any]] ?? []
        return listens.compactMap { l in
            let ts = (l["listened_at"] as? NSNumber)?.doubleValue
            return track(l["track_metadata"] as? [String: Any], at: ts.map { Date(timeIntervalSince1970: $0) })
        }
    }

    func listenCount() async -> Int? {
        guard let r = try? await get("/1/user/\(userPath)/listen-count") else { return nil }
        return ((r["payload"] as? [String: Any])?["count"] as? NSNumber)?.intValue
    }

    func topRecordings(range: String = "month", count: Int = 50) async throws -> [LbTrack] {
        let r = try await get("/1/stats/user/\(userPath)/recordings?range=\(range)&count=\(count)")
        let rows = (r?["payload"] as? [String: Any])?["recordings"] as? [[String: Any]] ?? []
        return rows.compactMap { x in
            guard let title = x["track_name"] as? String else { return nil }
            return LbTrack(
                title: title, artist: x["artist_name"] as? String ?? "", album: x["release_name"] as? String,
                mbid: x["recording_mbid"] as? String, count: (x["listen_count"] as? NSNumber)?.intValue ?? 0)
        }
    }

    func topArtists(range: String = "month", count: Int = 20) async throws -> [(String, Int)] {
        let r = try await get("/1/stats/user/\(userPath)/artists?range=\(range)&count=\(count)")
        let rows = (r?["payload"] as? [String: Any])?["artists"] as? [[String: Any]] ?? []
        return rows.compactMap { x in
            guard let name = x["artist_name"] as? String else { return nil }
            return (name, (x["listen_count"] as? NSNumber)?.intValue ?? 0)
        }
    }

    /// Weekly Jams, Weekly Exploration and the other playlists made for the user.
    func createdFor() async throws -> [LbPlaylistRef] {
        let r = try await get("/1/user/\(userPath)/playlists/createdfor?count=25")
        let rows = r?["playlists"] as? [[String: Any]] ?? []
        return rows.compactMap { x in
            guard let p = x["playlist"] as? [String: Any], let ident = p["identifier"] as? String else { return nil }
            let mbid = ident.split(separator: "/").last.map(String.init) ?? ident
            return LbPlaylistRef(mbid: mbid, title: p["title"] as? String ?? "ListenBrainz playlist", date: p["date"] as? String)
        }
    }

    func playlist(_ mbid: String) async throws -> (String, [LbTrack])? {
        guard let p = try await get("/1/playlist/\(mbid.pathEncoded)")?["playlist"] as? [String: Any] else { return nil }
        let tracks = (p["track"] as? [[String: Any]] ?? []).compactMap { t -> LbTrack? in
            guard let title = t["title"] as? String else { return nil }
            let ident = (t["identifier"] as? String) ?? (t["identifier"] as? [String])?.first
            let mbid = ident?.split(separator: "/").last.map(String.init)
            return LbTrack(title: title, artist: t["creator"] as? String ?? "", album: t["album"] as? String, mbid: mbid)
        }
        return (p["title"] as? String ?? "ListenBrainz playlist", tracks)
    }

    func cfRecommendations(count: Int = 100) async throws -> [String] {
        let r = try await get("/1/cf/recommendation/user/\(userPath)/recording?count=\(count)")
        let rows = (r?["payload"] as? [String: Any])?["mbids"] as? [[String: Any]] ?? []
        return rows.compactMap { $0["recording_mbid"] as? String }
    }

    func recordingMetadata(_ mbids: [String]) async -> [LbTrack] {
        var out: [LbTrack] = []
        for chunk in mbids.chunked(into: 25) {
            guard let r = try? await get("/1/metadata/recording/?recording_mbids=\(chunk.joined(separator: ","))&inc=artist") else {
                continue
            }
            for (mbid, v) in r {
                guard let v = v as? [String: Any],
                      let title = (v["recording"] as? [String: Any])?["name"] as? String else { continue }
                let artist = (v["artist"] as? [String: Any])?["name"] as? String ?? ""
                out.append(LbTrack(title: title, artist: artist, album: (v["release"] as? [String: Any])?["name"] as? String, mbid: mbid))
            }
        }
        return out
    }
}
