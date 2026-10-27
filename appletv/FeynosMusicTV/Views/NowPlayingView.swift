import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var store: Store
    @State var panel = 0

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

                    HStack(alignment: .top, spacing: 70) {
                        VStack(alignment: .leading, spacing: 22) {
                            CoverImage(coverArt: song.coverArt, albumId: song.albumId, size: 1000, corner: 16)
                                .frame(width: 560, height: 560)
                                .shadow(radius: 30)
                            Text(song.name).font(.title2).bold().lineLimit(2)
                            HStack(spacing: 20) {
                                if let artistId = song.artistId {
                                    NavigationLink(value: Route.artist(artistId)) { Text(song.artistName).lineLimit(1) }
                                } else {
                                    Text(song.artistName).foregroundStyle(.secondary)
                                }
                                if let albumId = song.albumId {
                                    NavigationLink(value: Route.album(albumId)) { Text(song.album ?? "Album").lineLimit(1) }
                                }
                            }
                            .font(.caption)
                            ProgressView(value: player.duration > 0 ? min(player.position / player.duration, 1) : 0)
                            HStack {
                                Text(formatTime(player.position))
                                Spacer()
                                Text(formatTime(player.duration))
                            }
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                            Controls(song: song)
                        }
                        .frame(width: 560)
                        .focusSection()

                        VStack(alignment: .leading, spacing: 20) {
                            Picker("Panel", selection: $panel) {
                                Text("Lyrics").tag(0)
                                Text("Up Next").tag(1)
                            }
                            .pickerStyle(.segmented)
                            if panel == 0 { LyricsPanel(song: song) } else { QueuePanel() }
                        }
                        .frame(maxWidth: .infinity)
                        .focusSection()
                    }
                    .padding(60)
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
        VStack(spacing: 20) {
            HStack(spacing: 18) {
                Button { player.previous() } label: { Image(systemName: "backward.fill") }
                Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 50)
                }
                Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
                Button { player.next() } label: { Image(systemName: "forward.fill") }
            }
            HStack(spacing: 18) {
                Button { player.toggleShuffle() } label: {
                    Image(systemName: "shuffle").foregroundStyle(player.shuffle ? Color.accentColor : Color.primary)
                }
                Button { player.cycleRepeat() } label: {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .foregroundStyle(player.repeatMode == .off ? Color.primary : Color.accentColor)
                }
                Button { Actions.toggleStar(song.id, liked: liked, kind: .song) } label: {
                    Image(systemName: liked ? "heart.fill" : "heart").foregroundStyle(liked ? Color.pink : Color.primary)
                }
                Button { Actions.startRadio(song) } label: { Image(systemName: "dot.radiowaves.left.and.right") }
                Button { Actions.addToPlaylistRequest = [song] } label: { Image(systemName: "text.badge.plus") }
            }
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
                        SongRow(song: item.song) { player.skipTo(i) }
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
