import SwiftUI

enum Route: Hashable {
    case album(String)
    case artist(String)
    case playlist(String)
    case mix(String)
    case lbPlaylist(String, String)
    case genre(String)
    case albums(String, String)
    case liked
    case history
    case stats
    case covers
}

struct RouteView: View {
    let route: Route
    var body: some View {
        switch route {
        case .album(let id): AlbumView(id: id)
        case .artist(let id): ArtistView(id: id)
        case .playlist(let id): PlaylistView(id: id)
        case .mix(let id): MixView(id: id)
        case .lbPlaylist(let id, let title): LbPlaylistView(mbid: id, title: title)
        case .genre(let name): GenreView(name: name)
        case .albums(let type, let title): AlbumGridView(type: type, title: title)
        case .liked: LikedView()
        case .history: HistoryView()
        case .stats: StatsView()
        case .covers: CoverArtView()
        }
    }
}

extension View {
    func withRoutes() -> some View { navigationDestination(for: Route.self) { RouteView(route: $0) } }
}

/// Loads something, shows a spinner meanwhile and an error with Retry if it fails.
struct Loader<T, Content: View>: View {
    let id: AnyHashable
    let load: @MainActor () async throws -> T
    @ViewBuilder let content: (T) -> Content
    @State var value: T?
    @State var error: String?

    init(id: AnyHashable, load: @escaping @MainActor () async throws -> T, @ViewBuilder content: @escaping (T) -> Content) {
        self.id = id
        self.load = load
        self.content = content
    }

    var body: some View {
        Group {
            if let value {
                content(value)
            } else if let error {
                VStack(spacing: 24) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 60)).foregroundStyle(.secondary)
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await run() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: id) { await run() }
    }

    private func run() async {
        error = nil
        do {
            value = try await load()
        } catch {
            if !(error is CancellationError) { self.error = error.localizedDescription }
        }
    }
}

struct CoverImage: View {
    let coverArt: String?
    var albumId: String? = nil
    var size: Int = 400
    var corner: CGFloat = 12
    var placeholder = "music.note"
    @EnvironmentObject var store: Store

    var body: some View {
        let url = Covers.shared.artURL(coverArt, albumId: albumId, size: size)
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if case .failure = phase {
                            blank.onAppear { lookupIfMissing() }
                        } else {
                            blank
                        }
                    }
                    .id(url)
                } else {
                    blank.onAppear { lookupIfMissing() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner))
    }

    private var blank: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: placeholder).font(.system(size: 50)).foregroundStyle(.secondary)
        }
    }

    /// The server image is missing or broken: look the album up online.
    private func lookupIfMissing() {
        let id = albumId ?? albumIdFromCover(coverArt)
        if Store.shared.coverOverride(id) == nil { Covers.shared.requestLookup(id) }
    }
}

/// Grid columns sized for fixed-width cards, with enough gap that a focused (enlarged) card
/// never overlaps its neighbours, however wide the screen is.
func cardColumns(_ width: CGFloat) -> [GridItem] {
    [GridItem(.adaptive(minimum: width, maximum: width + 60), spacing: 50, alignment: .top)]
}

/// A row of focusable items that scrolls sideways (like the Apple TV app shelves).
struct Shelf<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.title3).bold().padding(.leading, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 48) { content() }
                    .padding(.vertical, 36)
                    .padding(.horizontal, 8)
            }
            .scrollClipDisabled()
        }
    }
}

struct AlbumCard: View {
    let album: Album
    var subtitle: String? = nil
    var width: CGFloat = 280

    var body: some View {
        NavigationLink(value: Route.album(album.id)) {
            VStack(alignment: .leading, spacing: 8) {
                CoverImage(coverArt: album.coverArt, albumId: album.id, size: 500, placeholder: "square.stack")
                    .frame(width: width, height: width)
                Text(album.title).font(.caption).bold().lineLimit(1)
                Text(subtitle ?? album.artist ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: width)
            .padding(12)
        }
        .buttonStyle(.card)
    }
}

struct ArtistCard: View {
    let artist: Artist

    var body: some View {
        NavigationLink(value: Route.artist(artist.id)) {
            VStack(spacing: 8) {
                CoverImage(coverArt: artist.coverArt, size: 400, corner: 120, placeholder: "person.fill")
                    .frame(width: 220, height: 220)
                Text(artist.title).font(.caption).bold().lineLimit(1)
            }
            .frame(width: 240)
            .padding(12)
        }
        .buttonStyle(.card)
        .disabled(artist.id.isEmpty)
    }
}

struct MixArt: View {
    let mix: Mix

    var body: some View {
        let c = color(for: mix.id + mix.title)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [c, c.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if mix.coverArt != nil {
                CoverImage(coverArt: mix.coverArt, size: 300, corner: 8)
                    .frame(width: 130, height: 130)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)
            }
            Text(mix.title).font(.title3).fontWeight(.heavy).foregroundStyle(.white).lineLimit(3).padding(18)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MixCard: View {
    let mix: Mix

    var body: some View {
        NavigationLink(value: Route.mix(mix.id)) {
            VStack(alignment: .leading, spacing: 8) {
                MixArt(mix: mix).frame(width: 280, height: 280)
                Text(mix.description).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(width: 280)
            .padding(12)
        }
        .buttonStyle(.card)
    }
}

func color(for seed: String) -> Color {
    let palette: [Color] = [
        Color(red: 0.42, green: 0.24, blue: 0.88), Color(red: 0.12, green: 0.53, blue: 0.90), Color(red: 0.0, green: 0.54, blue: 0.48),
        Color(red: 0.90, green: 0.22, blue: 0.21), Color(red: 0.96, green: 0.32, blue: 0.12), Color(red: 0.56, green: 0.14, blue: 0.67),
        Color(red: 0.22, green: 0.29, blue: 0.67), Color(red: 0.26, green: 0.63, blue: 0.28), Color(red: 0.85, green: 0.11, blue: 0.38),
    ]
    var h: UInt64 = 5381
    for b in seed.utf8 { h = (h &* 33) &+ UInt64(b) }
    return palette[Int(h % UInt64(palette.count))]
}

/// List row with a soft highlight when focused.
struct RowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { RowBody(configuration: configuration) }

    struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) var focused

        var body: some View {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(focused ? Color.white.opacity(0.2) : Color.clear))
                .scaleEffect(focused ? 1.015 : 1)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

struct SongRow: View {
    let song: Song
    var number: Int? = nil
    var showCover = true
    var subtitle: String? = nil
    let action: () -> Void
    @EnvironmentObject var player: Player
    @EnvironmentObject var store: Store

    var body: some View {
        let current = player.current?.id == song.id
        Button(action: action) {
            HStack(spacing: 24) {
                if let number {
                    Group {
                        if current && player.isPlaying { Image(systemName: "waveform") } else { Text("\(number)") }
                    }
                    .frame(width: 50)
                    .foregroundStyle(current ? Color.accentColor : .secondary)
                }
                if showCover {
                    CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 150, corner: 8).frame(width: 80, height: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name).font(.headline).lineLimit(1).foregroundStyle(current ? Color.accentColor : .primary)
                    Text(subtitle ?? song.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if store.isStarred(song.id, song.starred) { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                Text(formatTime(Double(song.seconds))).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .buttonStyle(RowStyle())
        .contextMenu { SongActions(song: song) }
    }
}

/// Long-press menu for a song.
struct SongActions: View {
    let song: Song
    @EnvironmentObject var store: Store

    var body: some View {
        Button { Player.shared.playNext([song]); toast("Playing next") } label: { Label("Play Next", systemImage: "text.insert") }
        Button { Player.shared.addToQueue([song]); toast("Added to queue") } label: { Label("Add to Queue", systemImage: "text.append") }
        Button { Actions.startRadio(song) } label: { Label("Start Radio", systemImage: "dot.radiowaves.left.and.right") }
        let liked = store.isStarred(song.id, song.starred)
        Button { Actions.toggleStar(song.id, liked: liked, kind: .song) } label: {
            Label(liked ? "Remove from Liked" : "Like", systemImage: liked ? "heart.slash" : "heart")
        }
        Button { Actions.addToPlaylistRequest = [song] } label: { Label("Add to Playlist", systemImage: "music.note.list") }
    }
}

/// Play / Shuffle / Like buttons shown on albums, playlists and mixes.
struct CollectionHeader<Art: View, Extra: View>: View {
    let title: String
    let subtitle: String
    let meta: String
    let songs: [Song]
    @ViewBuilder let art: () -> Art
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        HStack(alignment: .bottom, spacing: 48) {
            art().frame(width: 420, height: 420).shadow(radius: 20)
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.title).bold().lineLimit(2)
                if !subtitle.isEmpty { Text(subtitle).font(.title3).foregroundStyle(.secondary).lineLimit(2) }
                Text(meta).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    Button { Player.shared.play(songs) } label: { Label("Play", systemImage: "play.fill") }
                        .disabled(songs.isEmpty)
                    Button { Player.shared.play(songs, shuffle: true) } label: { Label("Shuffle", systemImage: "shuffle") }
                        .disabled(songs.isEmpty)
                    extra()
                }
                .padding(.top, 20)
            }
            Spacer()
        }
        .focusSection()
    }
}

/// Things several screens do.
@MainActor
enum Actions {
    enum StarKind { case song, album, artist }

    static var addToPlaylistRequest: [Song]? {
        get { AppState.shared.addToPlaylist }
        set { AppState.shared.addToPlaylist = newValue }
    }

    static func toggleStar(_ id: String, liked: Bool, kind: StarKind) {
        let store = Store.shared
        store.starOverrides[id] = !liked
        Task {
            do {
                switch kind {
                case .song: try await Subsonic.shared.setStar(!liked, id: id)
                case .album: try await Subsonic.shared.setStar(!liked, albumId: id)
                case .artist: try await Subsonic.shared.setStar(!liked, artistId: id)
                }
                toast(liked ? "Removed from Liked" : "Added to Liked")
            } catch {
                store.starOverrides[id] = liked
                toast("Couldn't update: \(error.localizedDescription)")
            }
        }
    }

    static func startRadio(_ song: Song) {
        toast("Starting radio…")
        Task {
            let api = Subsonic.shared
            var list = [song]
            var seen: Set<String> = [song.id]
            func add(_ songs: [Song]) { for s in songs where seen.insert(s.id).inserted { list.append(s) } }
            add((try? await api.similarSongs(song.id, count: 50)) ?? [])
            if list.count < 15, let a = song.artist { add((try? await api.topSongs(a, count: 15)) ?? []) }
            if list.count < 25 { add((try? await api.randomSongs(30, genre: song.genre)) ?? []) }
            Player.shared.play([song] + list.dropFirst().shuffled())
        }
    }

    static func artistRadio(_ artist: Artist) {
        toast("Starting radio…")
        Task {
            var list = (try? await Subsonic.shared.topSongs(artist.title, count: 10)) ?? []
            list += (try? await Subsonic.shared.similarSongsForArtist(artist.id, count: 50)) ?? []
            if list.isEmpty { toast("Nothing to play") } else { Player.shared.play(list.shuffled()) }
        }
    }
}

/// App-wide UI state.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var tab = 0
    @Published var addToPlaylist: [Song]?
}
