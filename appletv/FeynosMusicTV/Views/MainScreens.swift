import SwiftUI

// MARK: - Home

struct HomeData {
    var recentAlbums: [Album] = []
    var newest: [Album] = []
    var frequent: [Album] = []
    var starred: [Album] = []
    var random: [Album] = []
}

struct HomeView: View {
    @EnvironmentObject var store: Store

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            Loader(id: store.version, load: {
                let api = Subsonic.shared
                async let a = api.albumList("recent", size: 20)
                async let b = api.albumList("newest", size: 20)
                async let c = api.albumList("frequent", size: 20)
                async let d = api.albumList("starred", size: 20)
                async let e = api.albumList("random", size: 20)
                return HomeData(
                    recentAlbums: (try? await a) ?? [], newest: try await b, frequent: (try? await c) ?? [],
                    starred: (try? await d) ?? [], random: (try? await e) ?? [])
            }) { data in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        Text(greeting).font(.largeTitle).bold().padding(.leading, 8)
                        if !store.mixes.isEmpty {
                            Shelf(title: "Made for you") { ForEach(store.mixes) { MixCard(mix: $0) } }
                        }
                        let recent = store.recentSongs(20)
                        if !recent.isEmpty {
                            Shelf(title: "Jump back in") {
                                ForEach(Array(recent.enumerated()), id: \.element.id) { i, s in
                                    Button { Player.shared.play(recent, start: i) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            CoverImage(coverArt: s.coverArt, albumId: s.albumId, size: 500).frame(width: 240, height: 240)
                                            Text(s.name).font(.caption).bold().lineLimit(1)
                                            Text(s.artistName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        .frame(width: 240)
                                        .padding(12)
                                    }
                                    .buttonStyle(.card)
                                    .contextMenu { SongActions(song: s) }
                                }
                            }
                        }
                        albumShelf("Recently played", data.recentAlbums, "recent")
                        albumShelf("Recently added", data.newest, "newest")
                        albumShelf("Your most played", data.frequent, "frequent")
                        albumShelf("Liked albums", data.starred, "starred")
                        albumShelf("Something different", data.random, "random")
                    }
                    .padding(.horizontal, 40)
                }
            }
            .withRoutes()
        }
    }

    @ViewBuilder
    private func albumShelf(_ title: String, _ albums: [Album], _ type: String) -> some View {
        if !albums.isEmpty {
            Shelf(title: title) {
                ForEach(albums) { AlbumCard(album: $0) }
                NavigationLink(value: Route.albums(type, title)) {
                    VStack {
                        Image(systemName: "ellipsis").font(.largeTitle)
                        Text("See all").font(.caption)
                    }
                    .frame(width: 200, height: 280)
                }
                .buttonStyle(.card)
            }
        }
    }
}

// MARK: - Search

struct SearchView: View {
    @State var query = ""
    @State var result: SearchResult?
    @State var genres: [Genre] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        if !genres.isEmpty {
                            Text("Browse genres").font(.title3).bold()
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 4), spacing: 40) {
                                ForEach(genres, id: \.self) { g in
                                    let name = g.value ?? ""
                                    NavigationLink(value: Route.genre(name)) {
                                        ZStack(alignment: .bottomLeading) {
                                            LinearGradient(colors: [color(for: name), color(for: name).opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            VStack(alignment: .leading) {
                                                Text(name).font(.headline).foregroundStyle(.white).lineLimit(2)
                                                Text("\(g.songCount ?? 0) songs").font(.caption2).foregroundStyle(.white.opacity(0.8))
                                            }
                                            .padding(20)
                                        }
                                        .frame(height: 160)
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                    } else if let r = result {
                        if (r.artist ?? []).isEmpty && (r.album ?? []).isEmpty && (r.song ?? []).isEmpty {
                            ContentUnavailableView.search(text: query)
                        }
                        if let artists = r.artist, !artists.isEmpty {
                            Shelf(title: "Artists") { ForEach(artists) { ArtistCard(artist: $0) } }
                        }
                        if let albums = r.album, !albums.isEmpty {
                            Shelf(title: "Albums") { ForEach(albums) { AlbumCard(album: $0) } }
                        }
                        if let songs = r.song, !songs.isEmpty {
                            Text("Songs").font(.title3).bold()
                            LazyVStack(spacing: 4) {
                                ForEach(Array(songs.enumerated()), id: \.element.id) { i, s in
                                    SongRow(song: s) { Player.shared.play(songs, start: i) }
                                }
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 40)
            }
            .searchable(text: $query, prompt: "Artists, albums, songs")
            .task {
                genres = ((try? await Subsonic.shared.genres()) ?? []).sorted { ($0.songCount ?? 0) > ($1.songCount ?? 0) }
            }
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard !q.isEmpty else {
                    result = nil
                    return
                }
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
                result = (try? await Subsonic.shared.search(q)) ?? SearchResult()
            }
            .withRoutes()
        }
    }
}

// MARK: - For You

struct ForYouView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var mixes: Mixes
    @EnvironmentObject var settings: AppSettings
    @State var lbPlaylists: [LbPlaylistRef] = []
    @State var lbTop: [LbTrack] = []
    @State var lbArtists: [NamedCount] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Made for you").font(.largeTitle).bold()
                            Text(settings.lastMixGen > 0
                                 ? "Refreshed weekly · last updated \(timeAgo(Date(timeIntervalSince1970: settings.lastMixGen)))"
                                 : "Your mixes refresh every week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await mixes.generate() }
                        } label: {
                            if mixes.generating { ProgressView() } else { Label("Refresh", systemImage: "arrow.clockwise") }
                        }
                        .disabled(mixes.generating)
                    }
                    if store.mixes.isEmpty {
                        ContentUnavailableView(
                            mixes.generating ? "Making your mixes…" : "No mixes yet", systemImage: "sparkles",
                            description: Text("Mixes are built from what you play, your Navidrome library and ListenBrainz. Play some music, then press Refresh."))
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5), spacing: 40) {
                            ForEach(store.mixes) { MixCard(mix: $0) }
                        }
                    }

                    Text("ListenBrainz").font(.title2).bold().padding(.top, 20)
                    if !settings.lbConnected {
                        Text("Connect ListenBrainz in Settings to keep your history in your MusicBrainz account and get weekly Jams and Exploration playlists.")
                            .foregroundStyle(.secondary)
                    } else {
                        if !lbPlaylists.isEmpty {
                            Shelf(title: "Created for you") {
                                ForEach(lbPlaylists) { p in
                                    NavigationLink(value: Route.lbPlaylist(p.mbid, p.title)) {
                                        VStack(alignment: .leading) {
                                            ZStack {
                                                LinearGradient(colors: [color(for: p.title), .black], startPoint: .top, endPoint: .bottom)
                                                Image(systemName: "safari").font(.system(size: 60)).foregroundStyle(.white)
                                            }
                                            .frame(width: 280, height: 280)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            Text(p.title).font(.caption).lineLimit(2)
                                        }
                                        .frame(width: 280)
                                        .padding(12)
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                        if !lbTop.isEmpty {
                            Text("Your top tracks this week").font(.title3).bold()
                            ForEach(lbTop, id: \.self) { t in
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
                                        Text("\(t.count) plays").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(RowStyle())
                            }
                        }
                        if !lbArtists.isEmpty {
                            Text("Your top artists this week").font(.title3).bold()
                            let maxCount = Swift.max(lbArtists.map(\.count).max() ?? 1, 1)
                            ForEach(lbArtists) { a in BarRow(label: a.name, value: a.count, max: maxCount) }
                        }
                    }
                    HStack(spacing: 30) {
                        NavigationLink(value: Route.history) { Label("Listening history", systemImage: "clock.arrow.circlepath") }
                        NavigationLink(value: Route.stats) { Label("Your stats", systemImage: "chart.bar") }
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 40)
            }
            .task(id: settings.lbUser) {
                guard settings.lbConnected else { return }
                let lb = ListenBrainz.shared
                lbPlaylists = (try? await lb.createdFor()) ?? []
                lbTop = (try? await lb.topRecordings(range: "week", count: 10)) ?? []
                lbArtists = ((try? await lb.topArtists(range: "week", count: 10)) ?? []).map { NamedCount(name: $0.0, count: $0.1) }
            }
            .withRoutes()
        }
    }
}

struct NamedCount: Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

struct BarRow: View {
    let label: String
    let value: Int
    let max: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).lineLimit(1)
                Spacer()
                Text("\(value)").foregroundStyle(.secondary)
            }
            .font(.caption)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Color.accentColor).frame(width: g.size.width * CGFloat(value) / CGFloat(Swift.max(max, 1)))
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Library

struct LibraryView: View {
    @State var section = 0
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Show", selection: $section) {
                    Text("Playlists").tag(0)
                    Text("Albums").tag(1)
                    Text("Artists").tag(2)
                    Text("Liked").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                switch section {
                case 0: PlaylistsGrid()
                case 1: AlbumGridView(type: "alphabeticalByName", title: nil)
                case 2: ArtistsGrid()
                default: LikedView()
                }
            }
            .withRoutes()
        }
    }
}

struct PlaylistsGrid: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Loader(id: store.version, load: { try await Subsonic.shared.playlists() }) { list in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 5), spacing: 40) {
                    NavigationLink(value: Route.liked) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                LinearGradient(colors: [.purple, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: "heart.fill").font(.system(size: 80)).foregroundStyle(.white)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("Liked Songs").font(.caption).bold()
                        }
                        .padding(12)
                    }
                    .buttonStyle(.card)
                    ForEach(list) { p in
                        NavigationLink(value: Route.playlist(p.id)) {
                            VStack(alignment: .leading, spacing: 8) {
                                CoverImage(coverArt: p.coverArt, size: 400, placeholder: "music.note.list")
                                Text(p.title).font(.caption).bold().lineLimit(1)
                                Text("\(p.songCount ?? 0) songs").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(12)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(40)
            }
        }
    }
}

struct ArtistsGrid: View {
    var body: some View {
        Loader(id: "artists", load: { try await Subsonic.shared.artists().sorted { $0.title.lowercased() < $1.title.lowercased() } }) { list in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 6), spacing: 40) {
                    ForEach(list) { ArtistCard(artist: $0) }
                }
                .padding(40)
            }
        }
    }
}

/// Paged album grid (loads more as you scroll).
struct AlbumGridView: View {
    let type: String
    let title: String?
    @State var albums: [Album] = []
    @State var end = false
    @State var loading = false

    var body: some View {
        ScrollView {
            if let title { Text(title).font(.largeTitle).bold().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 40) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 5), spacing: 40) {
                ForEach(albums) { a in
                    AlbumCard(album: a, width: 260)
                        .onAppear { if a.id == albums.last?.id { Task { await loadMore() } } }
                }
            }
            .padding(40)
            if loading { ProgressView().padding() }
        }
        .task { if albums.isEmpty { await loadMore() } }
    }

    private func loadMore() async {
        guard !loading, !end else { return }
        loading = true
        defer { loading = false }
        guard let page = try? await Subsonic.shared.albumList(type, size: 60, offset: albums.count) else {
            end = true
            return
        }
        albums += page
        if page.count < 60 || type == "random" { end = true }
    }
}
