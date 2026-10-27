import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var serverUrl: String { didSet { d.set(serverUrl, forKey: "server") } }
    @Published var username: String { didSet { d.set(username, forKey: "user") } }
    @Published var token: String { didSet { d.set(token, forKey: "token") } }
    @Published var salt: String { didSet { d.set(salt, forKey: "salt") } }
    @Published var lbToken: String { didSet { d.set(lbToken, forKey: "lbToken") } }
    @Published var lbUser: String { didSet { d.set(lbUser, forKey: "lbUser") } }
    @Published var scrobbleNavidrome: Bool { didSet { d.set(scrobbleNavidrome, forKey: "scrobbleNd") } }
    @Published var scrobbleLb: Bool { didSet { d.set(scrobbleLb, forKey: "scrobbleLb") } }
    @Published var maxBitrate: Int { didSet { d.set(maxBitrate, forKey: "maxBitrate") } }
    @Published var format: String { didSet { d.set(format, forKey: "format") } }
    @Published var syncMixes: Bool { didSet { d.set(syncMixes, forKey: "syncMixes") } }
    @Published var autoCovers: Bool { didSet { d.set(autoCovers, forKey: "autoCovers") } }
    @Published var lastMixGen: Double { didSet { d.set(lastMixGen, forKey: "lastMixGen") } }

    private init() {
        serverUrl = d.string(forKey: "server") ?? ""
        username = d.string(forKey: "user") ?? ""
        token = d.string(forKey: "token") ?? ""
        salt = d.string(forKey: "salt") ?? ""
        lbToken = d.string(forKey: "lbToken") ?? ""
        lbUser = d.string(forKey: "lbUser") ?? ""
        scrobbleNavidrome = d.object(forKey: "scrobbleNd") as? Bool ?? true
        scrobbleLb = d.object(forKey: "scrobbleLb") as? Bool ?? true
        maxBitrate = d.object(forKey: "maxBitrate") as? Int ?? 0
        format = d.string(forKey: "format") ?? "raw"
        syncMixes = d.object(forKey: "syncMixes") as? Bool ?? false
        autoCovers = d.object(forKey: "autoCovers") as? Bool ?? true
        lastMixGen = d.object(forKey: "lastMixGen") as? Double ?? 0
    }

    var loggedIn: Bool { !serverUrl.isEmpty && !username.isEmpty && !token.isEmpty }
    var lbConnected: Bool { !lbToken.isEmpty && !lbUser.isEmpty }

    func signOut() {
        serverUrl = ""
        username = ""
        token = ""
        salt = ""
    }
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
