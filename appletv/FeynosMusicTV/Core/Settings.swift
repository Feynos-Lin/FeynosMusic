import Foundation

/// One person's Navidrome login (plus their ListenBrainz account). Each profile has its own
/// history, mixes and cover fixes; playback options are shared by everyone on the TV.
struct Profile: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var serverUrl: String
    var username: String
    var token: String
    var salt: String
    var lbToken = ""
    var lbUser = ""
    var lastMixGen: Double = 0

    var host: String { URL(string: serverUrl)?.host ?? serverUrl }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var currentId: String = ""
    /// Whether someone picked a profile since the app opened (the picker shows when there are several).
    @Published var picked = false
    /// True while the "add a profile" sign-in screen is showing.
    @Published var addingProfile = false

    // Current profile's fields (writes go back into that profile).
    @Published var serverUrl: String = "" { didSet { update { $0.serverUrl = serverUrl } } }
    @Published var username: String = "" { didSet { update { $0.username = username } } }
    @Published var token: String = "" { didSet { update { $0.token = token } } }
    @Published var salt: String = "" { didSet { update { $0.salt = salt } } }
    @Published var lbToken: String = "" { didSet { update { $0.lbToken = lbToken } } }
    @Published var lbUser: String = "" { didSet { update { $0.lbUser = lbUser } } }
    @Published var lastMixGen: Double = 0 { didSet { update { $0.lastMixGen = lastMixGen } } }

    // Shared by all profiles.
    @Published var scrobbleNavidrome: Bool { didSet { d.set(scrobbleNavidrome, forKey: "scrobbleNd") } }
    @Published var scrobbleLb: Bool { didSet { d.set(scrobbleLb, forKey: "scrobbleLb") } }
    @Published var maxBitrate: Int { didSet { d.set(maxBitrate, forKey: "maxBitrate") } }
    @Published var format: String { didSet { d.set(format, forKey: "format") } }
    @Published var syncMixes: Bool { didSet { d.set(syncMixes, forKey: "syncMixes") } }
    @Published var autoCovers: Bool { didSet { d.set(autoCovers, forKey: "autoCovers") } }

    private var applying = false

    private init() {
        scrobbleNavidrome = d.object(forKey: "scrobbleNd") as? Bool ?? true
        scrobbleLb = d.object(forKey: "scrobbleLb") as? Bool ?? true
        maxBitrate = d.object(forKey: "maxBitrate") as? Int ?? 0
        format = d.string(forKey: "format") ?? "raw"
        syncMixes = d.object(forKey: "syncMixes") as? Bool ?? false
        autoCovers = d.object(forKey: "autoCovers") as? Bool ?? true

        if let data = d.data(forKey: "profiles"), let list = try? JSONDecoder().decode([Profile].self, from: data) {
            profiles = list
        } else if let server = d.string(forKey: "server"), !server.isEmpty {
            // Move the single login from the first version into a profile.
            let user = d.string(forKey: "user") ?? ""
            profiles = [Profile(
                id: "default", name: user.isEmpty ? "Me" : user, serverUrl: server, username: user,
                token: d.string(forKey: "token") ?? "", salt: d.string(forKey: "salt") ?? "",
                lbToken: d.string(forKey: "lbToken") ?? "", lbUser: d.string(forKey: "lbUser") ?? "",
                lastMixGen: d.object(forKey: "lastMixGen") as? Double ?? 0)]
            saveProfiles()
        }
        let saved = d.string(forKey: "currentProfile") ?? ""
        let start = profiles.first { $0.id == saved } ?? profiles.first
        if let start { apply(start) }
        picked = profiles.count <= 1
    }

    var loggedIn: Bool { !serverUrl.isEmpty && !username.isEmpty && !token.isEmpty }
    var lbConnected: Bool { !lbToken.isEmpty && !lbUser.isEmpty }
    var current: Profile? { profiles.first { $0.id == currentId } }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) { d.set(data, forKey: "profiles") }
    }

    private func update(_ change: (inout Profile) -> Void) {
        guard !applying, let i = profiles.firstIndex(where: { $0.id == currentId }) else { return }
        change(&profiles[i])
        saveProfiles()
    }

    private func apply(_ p: Profile) {
        applying = true
        currentId = p.id
        serverUrl = p.serverUrl
        username = p.username
        token = p.token
        salt = p.salt
        lbToken = p.lbToken
        lbUser = p.lbUser
        lastMixGen = p.lastMixGen
        applying = false
        d.set(p.id, forKey: "currentProfile")
    }

    private func clearCurrent() {
        applying = true
        currentId = ""
        serverUrl = ""; username = ""; token = ""; salt = ""; lbToken = ""; lbUser = ""; lastMixGen = 0
        applying = false
        d.removeObject(forKey: "currentProfile")
    }

    /// Switches everything (library, history, mixes) over to another profile.
    func switchTo(_ id: String) {
        guard let p = profiles.first(where: { $0.id == id }) else { return }
        let changed = p.id != currentId
        if changed {
            Player.shared.stop()
            JamHost.shared.stop()
        }
        apply(p)
        picked = true
        addingProfile = false
        if changed {
            Store.shared.reload()
            AppState.shared.tab = 0
        }
    }

    func addProfile(name: String, server: String, user: String, token: String, salt: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        let p = Profile(name: clean.isEmpty ? user : clean, serverUrl: server, username: user, token: token, salt: salt)
        profiles.append(p)
        saveProfiles()
        switchTo(p.id)
    }

    func rename(_ id: String, to name: String) {
        guard let i = profiles.firstIndex(where: { $0.id == id }), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        profiles[i].name = name.trimmingCharacters(in: .whitespaces)
        saveProfiles()
    }

    func remove(_ id: String) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
        Store.deleteFiles(for: id)
        guard id == currentId else { return }
        Player.shared.stop()
        JamHost.shared.stop()
        if let next = profiles.first {
            apply(next)
            Store.shared.reload()
            picked = profiles.count <= 1
            AppState.shared.tab = 0
        } else {
            clearCurrent()
            Store.shared.reload()
        }
    }

    /// Sign out = remove this profile from the TV.
    func signOut() { remove(currentId) }
}

/// Small on-screen messages ("Added to queue" and so on).
@MainActor
final class Toaster: ObservableObject {
    static let shared = Toaster()
    @Published var message: String?
    private var task: Task<Void, Never>?

    func show(_ text: String) {
        message = text
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self.message = nil }
        }
    }
}

@MainActor
func toast(_ text: String) { Toaster.shared.show(text) }
