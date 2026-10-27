import SwiftUI

/// Numbered list of songs used on detail pages.
struct SongListView: View {
    let songs: [Song]
    var numbered = false
    var showCover = true

    var body: some View {
        LazyVStack(spacing: 4) {
            ForEach(Array(songs.enumerated()), id: \.offset) { i, s in
                SongRow(song: s, number: numbered ? (s.track ?? i + 1) : nil, showCover: showCover) {
                    Player.shared.play(songs, start: i)
                }
            }
        }
    }
}

// MARK: - Album

struct AlbumView: View {
    let id: String
    @EnvironmentObject var store: Store
    @State var pickCover = false

    var body: some View {
        Loader(id: id, load: { try await Subsonic.shared.album(id) }) { album in
            let liked = store.isStarred(album.id, album.starred)
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    CollectionHeader(
                        title: album.title,
                        subtitle: album.artist ?? "",
                        meta: ["Album", album.year.map { "\($0)" }, "\(album.songs.count) songs", totalDuration(album.duration ?? 0)]
                            .compactMap { $0 }.joined(separator: " · "),
                        songs: album.songs,
                        art: { CoverImage(coverArt: album.coverArt, albumId: album.id, size: 800) },
                        extra: {
                            Button { Actions.toggleStar(album.id, liked: liked, kind: .album) } label: {
                                Image(systemName: liked ? "heart.fill" : "heart")
                            }
                            Button { Actions.addToPlaylistRequest = album.songs } label: { Image(systemName: "text.badge.plus") }
                            Button { pickCover = true } label: { Image(systemName: "photo.badge.magnifyingglass") }
                            if let artistId = album.artistId {
                                NavigationLink(value: Route.artist(artistId)) { Image(systemName: "person.fill") }
                            }
                        })
                    SongListView(songs: album.songs, numbered: true, showCover: false)
                }
                .padding(40)
            }
            .sheet(isPresented: $pickCover) { CoverPickerSheet(album: album) }
        }
    }
}

// MARK: - Artist

struct ArtistPage {
    let artist: Artist
    let info: ArtistInfo?
    let top: [Song]
}

struct ArtistView: View {
    let id: String
    @EnvironmentObject var store: Store

    var body: some View {
        Loader(id: id, load: {
            let api = Subsonic.shared
            let artist = try await api.artist(id)
            async let info = api.artistInfo(id)
            async let top = api.topSongs(artist.title, count: 20)
            return ArtistPage(artist: artist, info: try? await info, top: (try? await top) ?? [])
        }) { page in
            let artist = page.artist
            let liked = store.isStarred(artist.id, artist.starred)
            let albums = (artist.album ?? []).sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            let image = page.info?.largeImageUrl.flatMap { $0.hasPrefix("http") && !$0.contains("2a96cbd8b46e442fc41c2b86b821562f") ? URL(string: $0) : nil }
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack(alignment: .bottom, spacing: 48) {
                        Group {
                            if let image {
                                AsyncImage(url: image) { p in
                                    if let img = p.image { img.resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                                }
                            } else {
                                CoverImage(coverArt: artist.coverArt, size: 600, corner: 0, placeholder: "person.fill")
                            }
                        }
                        .frame(width: 360, height: 360)
                        .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 16) {
                            Text(artist.title).font(.system(size: 76, weight: .heavy)).lineLimit(2)
                            HStack(spacing: 24) {
                                Button { Player.shared.play(page.top) } label: { Label("Play", systemImage: "play.fill") }
                                    .disabled(page.top.isEmpty)
                                Button {
                                    Task {
                                        var all: [Song] = []
                                        for a in albums { all += ((try? await Subsonic.shared.album(a.id))?.songs ?? []) }
                                        Player.shared.play(all, shuffle: true)
                                    }
                                } label: { Label("Shuffle", systemImage: "shuffle") }
                                Button { Actions.artistRadio(artist) } label: { Label("Radio", systemImage: "dot.radiowaves.left.and.right") }
                                Button { Actions.toggleStar(artist.id, liked: liked, kind: .artist) } label: {
                                    Image(systemName: liked ? "heart.fill" : "heart")
                                }
                            }
                        }
                    }
                    .focusSection()
                    if !page.top.isEmpty {
                        Text("Popular").font(.title3).bold()
                        LazyVStack(spacing: 4) {
                            ForEach(Array(page.top.prefix(10).enumerated()), id: \.offset) { i, s in
                                SongRow(song: s, number: i + 1) { Player.shared.play(page.top, start: i) }
                            }
                        }
                    }
                    if !albums.isEmpty {
                        Shelf(title: "Discography") {
                            ForEach(albums) { AlbumCard(album: $0, subtitle: $0.year.map { "\($0)" } ?? "Album") }
                        }
                    }
                    if let similar = page.info?.similarArtist, !similar.isEmpty {
                        Shelf(title: "Fans also like") { ForEach(similar.filter { !$0.id.isEmpty }) { ArtistCard(artist: $0) } }
                    }
                    if let bio = page.info?.biography.map(stripHtml), !bio.isEmpty {
                        Text("About").font(.title3).bold()
                        Text(bio).font(.callout).foregroundStyle(.secondary).lineLimit(8)
                    }
                }
                .padding(40)
            }
        }
    }
}

// MARK: - Playlist

struct PlaylistView: View {
    let id: String
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var confirmDelete = false

    var body: some View {
        Loader(id: "\(id)-\(store.version)", load: { try await Subsonic.shared.playlist(id) }) { pl in
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    CollectionHeader(
                        title: pl.title,
                        subtitle: pl.comment ?? pl.owner.map { "by \($0)" } ?? "",
                        meta: "Playlist · \(pl.songs.count) songs · \(totalDuration(pl.duration ?? 0))",
                        songs: pl.songs,
                        art: { CoverImage(coverArt: pl.coverArt, size: 800, placeholder: "music.note.list") },
                        extra: { Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") } })
                    LazyVStack(spacing: 4) {
                        ForEach(Array(pl.songs.enumerated()), id: \.offset) { i, s in
                            SongRow(song: s) { Player.shared.play(pl.songs, start: i) }
                                .contextMenu {
                                    SongActions(song: s)
                                    Button(role: .destructive) {
                                        Task {
                                            try? await Subsonic.shared.removeFromPlaylist(pl.id, index: i)
                                            Store.shared.bump()
                                        }
                                    } label: { Label("Remove from this playlist", systemImage: "minus.circle") }
                                }
                        }
                    }
                }
                .padding(40)
            }
            .confirmationDialog("Delete \"\(pl.title)\"?", isPresented: $confirmDelete) {
                Button("Delete playlist", role: .destructive) {
                    Task {
                        do {
                            try await Subsonic.shared.deletePlaylist(pl.id)
                            toast("Playlist deleted")
                            Store.shared.bump()
                            dismiss()
                        } catch { toast("Couldn't delete: \(error.localizedDescription)") }
                    }
                }
            }
        }
    }
}

// MARK: - Mix

struct MixView: View {
    let id: String
    @EnvironmentObject var store: Store

    var body: some View {
        if let mix = store.mixes.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    CollectionHeader(
                        title: mix.title, subtitle: mix.description,
                        meta: "Made for you · \(mix.songs.count) songs · updated \(timeAgo(mix.createdAt))",
                        songs: mix.songs,
                        art: { MixArt(mix: mix) },
                        extra: {
                            Button {
                                Task {
                                    do {
                                        try await Subsonic.shared.savePlaylist(named: "Feynos · \(mix.title)", songs: mix.songs)
                                        toast("Saved to Navidrome")
                                    } catch { toast("Couldn't save: \(error.localizedDescription)") }
                                }
                            } label: { Image(systemName: "square.and.arrow.down") }
                        })
                    SongListView(songs: mix.songs)
                }
                .padding(40)
            }
        } else {
            ContentUnavailableView("This mix has been refreshed", systemImage: "sparkles", description: Text("Open it again from For You."))
        }
    }
}

// MARK: - ListenBrainz playlist

struct LbPlaylistView: View {
    let mbid: String
    let title: String
    @State var tracks: [LbTrack] = []
    @State var matched: [Int: Song] = [:]
    @State var checked = 0
    @State var loaded = false

    var body: some View {
        let songs = tracks.indices.compactMap { matched[$0] }
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                CollectionHeader(
                    title: title, subtitle: "ListenBrainz",
                    meta: !loaded ? "Loading…" : checked < tracks.count
                        ? "Finding songs in your library… \(checked)/\(tracks.count)"
                        : "\(songs.count) of \(tracks.count) songs are in your library",
                    songs: songs,
                    art: {
                        ZStack {
                            LinearGradient(colors: [color(for: title), .black], startPoint: .top, endPoint: .bottom)
                            Image(systemName: "safari").font(.system(size: 120)).foregroundStyle(.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    },
                    extra: {
                        Button {
                            Task {
                                let name = title.components(separatedBy: " for ").first ?? title
                                do {
                                    try await Subsonic.shared.savePlaylist(named: name, songs: songs)
                                    toast("Saved \"\(name)\" to Navidrome")
                                } catch { toast("Couldn't save: \(error.localizedDescription)") }
                            }
                        } label: { Image(systemName: "square.and.arrow.down") }
                        .disabled(songs.isEmpty)
                    })
                LazyVStack(spacing: 4) {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { i, t in
                        if let s = matched[i] {
                            SongRow(song: s) { Player.shared.play(songs, start: songs.firstIndex(of: s) ?? 0) }
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(t.title).font(.headline)
                                    Text(i < checked ? "\(t.artist) · not in your library" : t.artist).font(.caption)
                                }
                                .opacity(0.5)
                                Spacer()
                                if i >= checked { ProgressView() }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        }
                    }
                }
            }
            .padding(40)
        }
        .task(id: mbid) {
            guard let pl = try? await ListenBrainz.shared.playlist(mbid) else {
                loaded = true
                return
            }
            tracks = pl.1
            loaded = true
            for (i, t) in pl.1.enumerated() {
                if let s = await Matcher.match(t) { matched[i] = s }
                checked = i + 1
            }
        }
    }
}

// MARK: - Genre

struct GenreView: View {
    let name: String

    var body: some View {
        Loader(id: name, load: { try await Subsonic.shared.songsByGenre(name, count: 300) }) { songs in
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    CollectionHeader(
                        title: name, subtitle: "Genre", meta: "\(songs.count) songs", songs: songs,
                        art: {
                            ZStack {
                                LinearGradient(colors: [color(for: name), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: "guitars").font(.system(size: 120)).foregroundStyle(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        },
                        extra: { EmptyView() })
                    SongListView(songs: songs)
                }
                .padding(40)
            }
        }
    }
}

// MARK: - Liked

struct LikedView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Loader(id: store.version, load: { try await Subsonic.shared.starred() }) { st in
            let songs = st.song ?? []
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    CollectionHeader(
                        title: "Liked Songs", subtitle: "", meta: "\(songs.count) songs", songs: songs,
                        art: {
                            ZStack {
                                LinearGradient(colors: [.purple, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: "heart.fill").font(.system(size: 120)).foregroundStyle(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        },
                        extra: { EmptyView() })
                    if let albums = st.album, !albums.isEmpty {
                        Shelf(title: "Liked albums") { ForEach(albums) { AlbumCard(album: $0) } }
                    }
                    if let artists = st.artist, !artists.isEmpty {
                        Shelf(title: "Followed artists") { ForEach(artists) { ArtistCard(artist: $0) } }
                    }
                    SongListView(songs: songs)
                }
                .padding(40)
            }
        }
    }
}

// MARK: - History & stats

struct HistoryView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State var source = 0
    @State var lb: [LbTrack]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Listening history").font(.largeTitle).bold()
                if settings.lbConnected {
                    Picker("Source", selection: $source) {
                        Text("This Apple TV").tag(0)
                        Text("ListenBrainz").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                if source == 0 || !settings.lbConnected {
                    let recent = Array(store.plays.suffix(300).reversed())
                    if recent.isEmpty { Text("Nothing played yet.").foregroundStyle(.secondary) }
                    LazyVStack(spacing: 4) {
                        ForEach(Array(recent.enumerated()), id: \.offset) { i, p in
                            SongRow(song: p.song, subtitle: "\(p.song.artistName) · \(timeAgo(p.at))") {
                                Player.shared.play(recent.map(\.song), start: i)
                            }
                        }
                    }
                } else if let lb {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(lb.enumerated()), id: \.offset) { _, t in
                            Button {
                                Task {
                                    if let s = await Matcher.match(t) { Player.shared.play([s]) } else { toast("That song isn't in your library") }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(t.title).font(.headline)
                                        Text(t.artist).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let at = t.listenedAt { Text(timeAgo(at)).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                            .buttonStyle(RowStyle())
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .padding(40)
        }
        .task(id: source) {
            if source == 1 && lb == nil { lb = (try? await ListenBrainz.shared.recentListens(count: 100)) ?? [] }
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var store: Store
    @State var range = 0

    var body: some View {
        let days: Double = [7, 30, 365, 100_000][range]
        let since = Date().addingTimeInterval(-days * 86400)
        let st = store.stats(since: since)
        let artists = store.topArtists(since: since, limit: 10)
        let songs = store.topSongs(since: since, limit: 10)
        let chart = store.playCounts(lastDays: range == 0 ? 7 : 30)
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Your stats").font(.largeTitle).bold()
                Picker("Range", selection: $range) {
                    Text("7 days").tag(0)
                    Text("30 days").tag(1)
                    Text("1 year").tag(2)
                    Text("All time").tag(3)
                }
                .pickerStyle(.segmented)
                HStack(spacing: 30) {
                    StatTile(label: "Plays", value: "\(st.plays)")
                    StatTile(label: "Minutes", value: "\(st.minutes)")
                    StatTile(label: "Songs", value: "\(st.songs)")
                    StatTile(label: "Artists", value: "\(st.artists)")
                }
                Text("Plays per day").font(.title3).bold()
                let maxCount = Swift.max(chart.map(\.1).max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(chart.enumerated()), id: \.offset) { _, d in
                        VStack {
                            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
                                .frame(height: Swift.max(4, 200 * CGFloat(d.1) / CGFloat(maxCount)))
                            if chart.count <= 7 { Text(d.0).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 240, alignment: .bottom)
                if !artists.isEmpty {
                    Text("Top artists").font(.title3).bold()
                    let top = artists.first?.count ?? 1
                    ForEach(artists.map { NamedCount(name: $0.name, count: $0.count) }) { a in BarRow(label: a.name, value: a.count, max: top) }
                }
                if !songs.isEmpty {
                    Text("Top songs").font(.title3).bold()
                    LazyVStack(spacing: 4) {
                        ForEach(Array(songs.enumerated()), id: \.offset) { i, pair in
                            SongRow(song: pair.0, number: i + 1, subtitle: "\(pair.0.artistName) · \(pair.1) plays") {
                                Player.shared.play(songs.map(\.0), start: i)
                            }
                        }
                    }
                }
            }
            .padding(40)
        }
    }
}

struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.system(size: 60, weight: .heavy)).foregroundStyle(Color.accentColor)
            Text(label).foregroundStyle(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
    }
}
