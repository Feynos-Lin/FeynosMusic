import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var mixes: Mixes
    @EnvironmentObject var covers: Covers
    @EnvironmentObject var store: Store
    @EnvironmentObject var jam: JamHost
    @State var lbToken = ""
    @State var lbBusy = false
    @State var confirmSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if jam.active {
                        LabeledContent("Jam is live", value: "\(jam.people.count) \(jam.people.count == 1 ? "person" : "people")")
                        ForEach(jam.guests, id: \.self) { Text($0) }
                        Button("End Jam", role: .destructive) { jam.stop() }
                    } else {
                        Button("Start a Jam") { jam.start() }
                    }
                    if let e = jam.error { Text(e).foregroundStyle(.red) }
                } header: {
                    Text("Jam")
                } footer: {
                    Text("Friends on the same Wi-Fi open Jam in Feynos Music on their phone, tap Join a jam and pick this Apple TV. Everyone can add songs, skip and control the music, and each person's listens go to their own history.")
                }

                Section {
                    LabeledContent("Profile", value: settings.current?.name ?? settings.username)
                    LabeledContent("Server", value: settings.serverUrl)
                    LabeledContent("User", value: settings.username)
                    Button("Switch Profile") { settings.picked = false }
                    Button("Add Profile") { settings.addingProfile = true }
                    Button("Remove This Profile", role: .destructive) { confirmSignOut = true }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Each profile has its own Navidrome login, ListenBrainz account, listening history, mixes and cover fixes. Playback settings below are shared.")
                }

                Section {
                    if settings.lbConnected {
                        LabeledContent("Connected as", value: settings.lbUser)
                        Toggle("Send listens to ListenBrainz", isOn: $settings.scrobbleLb)
                        if !store.lbQueue.isEmpty {
                            Button("Upload \(store.lbQueue.count) waiting listens") { Task { await store.flushListens() } }
                        }
                        Button("Disconnect ListenBrainz", role: .destructive) {
                            settings.lbToken = ""
                            settings.lbUser = ""
                        }
                    } else {
                        TextField("User token from listenbrainz.org/settings", text: $lbToken)
                            .autocorrectionDisabled()
                        Button(lbBusy ? "Checking…" : "Connect") {
                            Task {
                                lbBusy = true
                                defer { lbBusy = false }
                                do {
                                    if let user = try await ListenBrainz.shared.validate(lbToken) {
                                        settings.lbToken = lbToken.trimmingCharacters(in: .whitespaces)
                                        settings.lbUser = user
                                        lbToken = ""
                                        toast("Connected to ListenBrainz as \(user)")
                                        Task { await mixes.generate(quiet: true) }
                                    } else {
                                        toast("That token isn't valid")
                                    }
                                } catch {
                                    toast("Couldn't reach ListenBrainz: \(error.localizedDescription)")
                                }
                            }
                        }
                        .disabled(lbToken.isEmpty || lbBusy)
                    }
                } header: {
                    Text("ListenBrainz")
                } footer: {
                    Text("Keeps your listening history in your MusicBrainz account and unlocks weekly Jams and Exploration playlists. Tip: use the Apple TV Remote on your phone to paste the token.")
                }

                Section("Scrobbling") {
                    Toggle("Scrobble to Navidrome", isOn: $settings.scrobbleNavidrome)
                }

                Section("Streaming") {
                    Picker("Quality", selection: $settings.maxBitrate) {
                        Text("Original").tag(0)
                        Text("320 kbps").tag(320)
                        Text("256 kbps").tag(256)
                        Text("192 kbps").tag(192)
                        Text("128 kbps").tag(128)
                    }
                    Picker("Transcode format", selection: $settings.format) {
                        Text("Server default").tag("raw")
                        Text("AAC").tag("aac")
                        Text("MP3").tag("mp3")
                    }
                }

                Section {
                    Button(mixes.generating ? "Making your mixes…" : "Refresh mixes now") { Task { await mixes.generate() } }
                        .disabled(mixes.generating)
                    Toggle("Save mixes to Navidrome", isOn: $settings.syncMixes)
                } header: {
                    Text("Weekly mixes")
                } footer: {
                    Text(settings.lastMixGen > 0 ? "Last updated \(timeAgo(Date(timeIntervalSince1970: settings.lastMixGen))). Mixes refresh when you open the app once a week has passed." : "Mixes refresh weekly when you open the app.")
                }

                Section("Screen") {
                    Toggle("Keep the TV awake while Feynos Music is open", isOn: $settings.keepAwake)
                    Picker("Visualizer", selection: $settings.visualizer) {
                        ForEach(VisStyle.all, id: \.self) { Text(VisStyle.label($0)).tag($0) }
                    }
                }
                Section("Theme") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(TVTheme.all) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    HStack(spacing: 16) {
                        ForEach(TVTheme.all) { t in
                            Circle().fill(t.accent).frame(width: 34, height: 34)
                                .overlay(Circle().stroke(Color.white, lineWidth: t.id == settings.theme ? 4 : 0))
                        }
                    }
                    .padding(.vertical, 8)
                }
                Section("Cover art") {
                    NavigationLink(value: Route.covers) { Text(covers.running ? "Finding cover art… \(covers.done)/\(covers.total)" : "Find missing cover art") }
                    Toggle("Fix new albums automatically", isOn: $settings.autoCovers)
                }

                Section("About") {
                    LabeledContent("Feynos Music for Apple TV",
                                   value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .withRoutes()
            .confirmationDialog("Remove the profile \"\(settings.current?.name ?? settings.username)\" from this Apple TV?", isPresented: $confirmSignOut) {
                Button("Remove Profile", role: .destructive) {
                    Player.shared.stop()
                    settings.signOut()
                }
            }
        }
    }
}

struct CoverArtView: View {
    @EnvironmentObject var covers: Covers
    @EnvironmentObject var store: Store

    var body: some View {
        let entries = store.covers.values.filter { $0.missing || $0.url != nil }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let fixed = entries.filter { $0.url != nil }
        let missing = entries.filter { $0.url == nil && $0.missing }
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Cover art").font(.largeTitle).bold()
                Text("Finds albums that only show Navidrome's placeholder image and looks up the real cover on MusicBrainz (Cover Art Archive), Deezer and iTunes. To pick one by hand, open the album and press the photo button.")
                    .foregroundStyle(.secondary)
                if covers.running {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(covers.phase)… \(covers.done)/\(covers.total) · found \(covers.found)")
                        ProgressView(value: covers.total > 0 ? Double(covers.done) / Double(covers.total) : 0)
                        Button("Stop") { covers.stop() }
                    }
                } else {
                    HStack(spacing: 30) {
                        Button("Scan library") { Task { await covers.scan(full: false) } }
                        Button("Re-check everything") { Task { await covers.scan(full: true) } }
                    }
                }
                if !fixed.isEmpty {
                    Text("Fixed (\(fixed.count))").font(.title3).bold()
                    coverGrid(fixed)
                }
                if !missing.isEmpty {
                    Text("Still missing (\(missing.count))").font(.title3).bold()
                    coverGrid(missing)
                }
            }
            .padding(40)
        }
    }

    private func coverGrid(_ list: [CoverEntry]) -> some View {
        LazyVGrid(columns: cardColumns(220), spacing: 50) {
            ForEach(list, id: \.albumId) { e in
                NavigationLink(value: Route.album(e.albumId)) {
                    VStack(alignment: .leading, spacing: 6) {
                        CoverImage(coverArt: e.coverArt, albumId: e.albumId, size: 300)
                        Text(e.name).font(.caption2).bold().lineLimit(1)
                        Text(e.source.map { $0 == "manual" ? "picked by you" : $0 } ?? e.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(10)
                }
                .buttonStyle(.card)
            }
        }
    }
}

struct CoverPickerSheet: View {
    let album: Album
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var candidates: [CoverCandidate]?

    var body: some View {
        let current = store.coverOverride(album.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Cover art for \(album.title)").font(.title2).bold()
                if let candidates {
                    if candidates.isEmpty { Text("No artwork found online for this album.").foregroundStyle(.secondary) }
                    LazyVGrid(columns: cardColumns(260), spacing: 50) {
                        ForEach(candidates) { c in
                            Button {
                                Covers.shared.set(album, url: c.url, source: "manual")
                                toast("Cover updated")
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: URL(string: c.thumb)) { p in
                                        if let img = p.image { img.resizable().scaledToFill() } else { Color.white.opacity(0.08) }
                                    }
                                    .frame(width: 240, height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: c.url == current ? 6 : 0))
                                    Text(c.source).font(.caption2).foregroundStyle(Color.accentColor)
                                    Text([c.title, c.artist].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption2).lineLimit(2)
                                }
                                .frame(width: 240)
                                .padding(10)
                            }
                            .buttonStyle(.card)
                        }
                    }
                } else {
                    ProgressView("Searching MusicBrainz, Deezer and iTunes…")
                }
                if current != nil {
                    Button("Use the server's artwork") {
                        Covers.shared.set(album, url: nil, source: nil)
                        toast("Using the server's artwork")
                        dismiss()
                    }
                }
            }
            .padding(60)
        }
        .task { candidates = await Covers.shared.candidates(artist: album.artist ?? "", album: album.title) }
    }
}
