import SwiftUI

@main
struct FeynosMusicTVApp: App {
    @Environment(\.scenePhase) var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppSettings.shared)
                .environmentObject(Player.shared)
                .environmentObject(Store.shared)
                .environmentObject(Mixes.shared)
                .environmentObject(Covers.shared)
                .environmentObject(AppState.shared)
                .environmentObject(Toaster.shared)
                .environmentObject(JamHost.shared)
                .tint(Color(red: 0.66, green: 0.44, blue: 1.0))
                .preferredColorScheme(.dark)
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await Store.shared.flushListens()
                    await Mixes.shared.maybeGenerate()
                }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            if settings.loggedIn { MainTabs() } else { LoginView() }
            if let m = toaster.message {
                Text(m)
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut, value: toaster.message)
        .sheet(item: Binding(
            get: { app.addToPlaylist.map { SongBatch(songs: $0) } },
            set: { app.addToPlaylist = $0?.songs }
        )) { batch in
            AddToPlaylistSheet(songs: batch.songs)
        }
    }
}

struct SongBatch: Identifiable {
    let songs: [Song]
    var id: String { songs.map(\.id).joined(separator: ",") }
}

struct MainTabs: View {
    @EnvironmentObject var player: Player
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.tab) {
            HomeView().tabItem { Label("Home", systemImage: "house") }.tag(0)
            SearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(1)
            ForYouView().tabItem { Label("For You", systemImage: "sparkles") }.tag(2)
            LibraryView().tabItem { Label("Library", systemImage: "music.note.house") }.tag(3)
            NowPlayingView().tabItem { Label("Now Playing", systemImage: "play.circle") }.tag(4)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(5)
        }
        .onChange(of: player.startedCount) { _, _ in app.tab = 4 }
        .onPlayPauseCommand { player.toggle() }
        .task { await Mixes.shared.maybeGenerate() }
    }
}

struct LoginView: View {
    @State var server = ""
    @State var user = ""
    @State var password = ""
    @State var busy = false
    @State var error: String?

    var body: some View {
        HStack(spacing: 80) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "music.note")
                    .font(.system(size: 90, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 180, height: 180)
                    .background(RoundedRectangle(cornerRadius: 40).fill(Color(red: 0.42, green: 0.24, blue: 0.88)))
                Text("Feynos Music").font(.largeTitle).bold()
                Text("Sign in to your Navidrome server").font(.title3).foregroundStyle(.secondary)
                Text("If you leave out http:// or https://, both are tried. Your password isn't stored, only a salted token.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 700)
            VStack(spacing: 24) {
                TextField("Server address (e.g. 192.168.1.10:4533)", text: $server)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                TextField("Username", text: $user)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
                Button {
                    Task {
                        busy = true
                        error = nil
                        do {
                            try await Subsonic.shared.login(server: server, user: user, password: password)
                        } catch {
                            self.error = error.localizedDescription
                        }
                        busy = false
                    }
                } label: {
                    if busy { ProgressView() } else { Text("Connect").frame(maxWidth: .infinity) }
                }
                .disabled(busy || server.isEmpty || user.isEmpty)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .frame(maxWidth: 800)
        }
        .padding(80)
    }
}

struct AddToPlaylistSheet: View {
    let songs: [Song]
    @Environment(\.dismiss) var dismiss
    @State var newName = ""

    var body: some View {
        NavigationStack {
            Loader(id: "playlists", load: { try await Subsonic.shared.playlists() }) { playlists in
                List {
                    Section("New playlist") {
                        TextField("Name", text: $newName)
                        Button("Create with \(songs.count) song\(songs.count == 1 ? "" : "s")") {
                            let name = newName.trimmingCharacters(in: .whitespaces)
                            Task {
                                do {
                                    try await Subsonic.shared.createPlaylist(name: name, songIds: songs.map(\.id))
                                    toast("Created \"\(name)\"")
                                    Store.shared.bump()
                                } catch { toast("Couldn't create playlist: \(error.localizedDescription)") }
                                dismiss()
                            }
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Section("Your playlists") {
                        ForEach(playlists) { p in
                            Button {
                                Task {
                                    do {
                                        try await Subsonic.shared.addToPlaylist(p.id, songIds: songs.map(\.id))
                                        toast("Added to \(p.title)")
                                        Store.shared.bump()
                                    } catch { toast("Couldn't add: \(error.localizedDescription)") }
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(p.title)
                                    Spacer()
                                    Text("\(p.songCount ?? 0) songs").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
        }
    }
}
