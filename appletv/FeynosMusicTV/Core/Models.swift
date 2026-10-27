import Foundation

struct Song: Codable, Identifiable, Hashable {
    let id: String
    var title: String?
    var album: String?
    var albumId: String?
    var artist: String?
    var artistId: String?
    var coverArt: String?
    var duration: Int?
    var track: Int?
    var discNumber: Int?
    var year: Int?
    var genre: String?
    var starred: String?
    var musicBrainzId: String?

    var name: String { title ?? "Unknown song" }
    var artistName: String { artist ?? "" }
    var seconds: Int { duration ?? 0 }
}

struct Album: Codable, Identifiable, Hashable {
    let id: String
    var name: String?
    var artist: String?
    var artistId: String?
    var coverArt: String?
    var songCount: Int?
    var duration: Int?
    var year: Int?
    var genre: String?
    var starred: String?
    var song: [Song]?

    var title: String { name ?? "Unknown album" }
    var songs: [Song] { song ?? [] }
}

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    var name: String?
    var coverArt: String?
    var albumCount: Int?
    var starred: String?
    var artistImageUrl: String?
    var album: [Album]?

    enum CodingKeys: String, CodingKey { case id, name, coverArt, albumCount, starred, artistImageUrl, album }

    init(id: String, name: String?) {
        self.id = id
        self.name = name
    }

    // Similar artists that aren't in your library come without an id.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        coverArt = try? c.decodeIfPresent(String.self, forKey: .coverArt)
        albumCount = try? c.decodeIfPresent(Int.self, forKey: .albumCount)
        starred = try? c.decodeIfPresent(String.self, forKey: .starred)
        artistImageUrl = try? c.decodeIfPresent(String.self, forKey: .artistImageUrl)
        album = try? c.decodeIfPresent([Album].self, forKey: .album)
    }

    var title: String { name ?? "Unknown artist" }
}

struct ArtistInfo: Codable {
    var biography: String?
    var largeImageUrl: String?
    var similarArtist: [Artist]?
}

struct Playlist: Codable, Identifiable, Hashable {
    let id: String
    var name: String?
    var comment: String?
    var owner: String?
    var songCount: Int?
    var duration: Int?
    var coverArt: String?
    var entry: [Song]?

    var title: String { name ?? "Playlist" }
    var songs: [Song] { entry ?? [] }
}

struct Genre: Codable, Hashable {
    var value: String?
    var songCount: Int?
    var albumCount: Int?
}

struct SearchResult: Codable {
    var artist: [Artist]?
    var album: [Album]?
    var song: [Song]?
}

struct LyricLine: Codable, Hashable {
    var start: Int?
    var value: String?
}

struct Lyrics {
    let synced: Bool
    let lines: [LyricLine]
}

// ---- Subsonic response envelope ----

struct SongList: Codable { var song: [Song]? }
struct AlbumList: Codable { var album: [Album]? }
struct PlaylistList: Codable { var playlist: [Playlist]? }
struct GenreList: Codable { var genre: [Genre]? }
struct ArtistIndex: Codable { var artist: [Artist]? }
struct ArtistsIndex: Codable { var index: [ArtistIndex]? }
struct StructuredLyrics: Codable { var synced: Bool?; var line: [LyricLine]? }
struct LyricsList: Codable { var structuredLyrics: [StructuredLyrics]? }
struct PlainLyrics: Codable { var value: String? }
struct SubsonicErrorBody: Codable { var code: Int?; var message: String? }

struct SubsonicResponse: Codable {
    var status: String?
    var error: SubsonicErrorBody?
    var albumList2: AlbumList?
    var album: Album?
    var artists: ArtistsIndex?
    var artist: Artist?
    var artistInfo2: ArtistInfo?
    var topSongs: SongList?
    var similarSongs: SongList?
    var similarSongs2: SongList?
    var randomSongs: SongList?
    var songsByGenre: SongList?
    var searchResult3: SearchResult?
    var playlists: PlaylistList?
    var playlist: Playlist?
    var starred2: SearchResult?
    var genres: GenreList?
    var lyricsList: LyricsList?
    var lyrics: PlainLyrics?
}

struct SubsonicEnvelope: Codable {
    let response: SubsonicResponse
    enum CodingKeys: String, CodingKey { case response = "subsonic-response" }
}

// ---- Local data ----

struct Play: Codable {
    let song: Song
    let at: Date
}

struct Mix: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let createdAt: Date
    let coverArt: String?
    let songs: [Song]
}

/// A track as ListenBrainz knows it.
struct LbTrack: Hashable {
    let title: String
    let artist: String
    var album: String? = nil
    var mbid: String? = nil
    var listenedAt: Date? = nil
    var count: Int = 0
}

struct LbPlaylistRef: Hashable, Identifiable {
    let mbid: String
    let title: String
    let date: String?
    var id: String { mbid }
}

struct CoverEntry: Codable {
    let albumId: String
    var name: String
    var artist: String
    var coverArt: String?
    var hash: String?
    var missing: Bool
    var url: String?
    var source: String?
    var checkedAt: Date
}

struct CoverCandidate: Hashable, Identifiable {
    let url: String
    let thumb: String
    let source: String
    let title: String
    let artist: String
    var id: String { url }
}

enum RepeatMode: Int, Codable {
    case off, all, one
}
