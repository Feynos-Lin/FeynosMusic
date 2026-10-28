import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var store: Store
    @EnvironmentObject var jam: JamHost
    @State var panel = 0

    private var jamLine: String {
        let people = jam.people
        return people.count > 1 ? "Jam · \(people.count) people · \(people.joined(separator: ", "))" : "Jam · \(people.joined(separator: ", "))"
    }

    var body: some View {
        NavigationStack {
            if let song = player.current {
                ZStack {
                    CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 300, corner: 0)
                        .scaleEffect(2.2)
                        .blur(radius: 80)
                        .opacity(0.45)
                        .ignoresSafeArea()
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

                    GeometryReader { geo in
                        // Sized to the screen so nothing slides under the tab bar or off the bottom.
                        let art = min(500, max(280, geo.size.height - 380))
                        VStack(spacing: 26) {
                            HStack(alignment: .top, spacing: 60) {
                                VStack(alignment: .leading, spacing: 14) {
                                    CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 1000, corner: 16)
                                        .frame(width: art, height: art)
                                        .shadow(radius: 30)
                                    if jam.active {
                                        Label(jamLine, systemImage: "person.3.fill")
                                            .font(.caption).foregroundStyle(Color.accentColor).lineLimit(1)
                                    }
                                    Text(song.name).font(.title3).bold().lineLimit(1).minimumScaleFactor(0.7)
                                    HStack(spacing: 16) {
                                        if let artistId = song.artistId {
                                            NavigationLink(value: Route.artist(artistId)) { Text(song.artistName).lineLimit(1) }
                                                .frame(maxWidth: art * 0.55, alignment: .leading)
                                        } else {
                                            Text(song.artistName).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        if let albumId = song.albumId {
                                            NavigationLink(value: Route.album(albumId)) { Text(song.album ?? "Album").lineLimit(1) }
                                                .frame(maxWidth: art * 0.45, alignment: .leading)
                                        }
                                    }
                                    .font(.caption2)
                                }
                                .frame(width: art, alignment: .leading)
                                .focusSection()

                                VStack(alignment: .leading, spacing: 16) {
                                    Picker("Panel", selection: $panel) {
                                        Text("Lyrics").tag(0)
                                        Text("Up Next").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    Group {
                                        if panel == 0 { LyricsPanel(song: song) } else { QueuePanel() }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                    .clipped()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .focusSection()
                            }
                            .frame(maxHeight: .infinity, alignment: .top)

                            VStack(spacing: 14) {
                                HStack(spacing: 20) {
                                    Text(formatTime(player.position)).frame(width: 110, alignment: .trailing)
                                    ProgressView(value: player.duration > 0 ? min(player.position / player.duration, 1) : 0)
                                    Text(formatTime(player.duration)).frame(width: 110, alignment: .leading)
                                }
                                .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                                Controls(song: song)
                            }
                            .focusSection()
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 70) // room for the tab bar
                }
                .withRoutes()
            } else {
                ContentUnavailableView("Nothing playing", systemImage: "music.note", description: Text("Pick something from Home, Search or your Library."))
            }
        }
    }
}

private struct Controls: View {
    let song: Song
    @EnvironmentObject var player: Player
    @EnvironmentObject var store: Store

    var body: some View {
        let liked = store.isStarred(song.id, song.starred)
        HStack(spacing: 22) {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle").foregroundStyle(player.shuffle ? Color.accentColor : Color.primary)
            }
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
            Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 60)
            }
            Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
            Button { player.next() } label: { Image(systemName: "forward.fill") }
            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(player.repeatMode == .off ? Color.primary : Color.accentColor)
            }
            Spacer().frame(width: 30)
            Button { Actions.toggleStar(song.id, liked: liked, kind: .song) } label: {
                Image(systemName: liked ? "heart.fill" : "heart").foregroundStyle(liked ? Color.pink : Color.primary)
            }
            Button { Actions.startRadio(song) } label: { Image(systemName: "dot.radiowaves.left.and.right") }
            Button { Actions.addToPlaylistRequest = [song] } label: { Image(systemName: "text.badge.plus") }
        }
    }
}

private struct LyricsPanel: View {
    let song: Song
    @EnvironmentObject var player: Player
    @State var lyrics: Lyrics?
    @State var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let lyrics, !lyrics.lines.isEmpty {
                let current = lyrics.synced
                    ? (lyrics.lines.lastIndex { Double($0.start ?? 0) / 1000 <= player.position + 0.3 } ?? -1)
                    : -1
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { i, line in
                                Text((line.value ?? "").isEmpty ? "♪" : line.value ?? "")
                                    .font(.title3).bold()
                                    .foregroundStyle(.white.opacity(!lyrics.synced || i == current ? 1 : (i < current ? 0.55 : 0.3)))
                                    .id(i)
                            }
                        }
                        .padding(.vertical, 40)
                    }
                    .onChange(of: current) { _, c in
                        if c >= 0 { withAnimation(.easeInOut) { proxy.scrollTo(c, anchor: .center) } }
                    }
                }
            } else {
                ContentUnavailableView("No lyrics", systemImage: "quote.bubble", description: Text("No lyrics found for this song."))
            }
        }
        .task(id: song.id) {
            loaded = false
            lyrics = await Subsonic.shared.lyrics(song)
            loaded = true
        }
    }
}

private struct QueuePanel: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var jam: JamHost

    var body: some View {
        let next = player.upNext
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if next.isEmpty {
                    Text("Nothing queued").foregroundStyle(.secondary).padding()
                } else {
                    HStack {
                        Text(player.shuffle ? "Next up (shuffled)" : "Next up").font(.headline)
                        Spacer()
                        Button("Clear") { player.clearUpNext() }
                    }
                    ForEach(next.map { QueueItem(index: $0.0, song: $0.1) }) { item in
                        let i = item.index
                        SongRow(song: item.song, subtitle: jam.addedBy[item.song.id].map { "\(item.song.artistName) · added by \($0)" }) {
                            player.skipTo(i)
                        }
                            .contextMenu {
                                Button { player.move(from: i, to: i - 1) } label: { Label("Move Up", systemImage: "arrow.up") }
                                Button { player.move(from: i, to: i + 1) } label: { Label("Move Down", systemImage: "arrow.down") }
                                Button(role: .destructive) { player.remove(at: i) } label: { Label("Remove", systemImage: "minus.circle") }
                            }
                    }
                }
            }
        }
    }
}

private struct QueueItem: Identifiable {
    let index: Int
    let song: Song
    var id: Int { index }
}
