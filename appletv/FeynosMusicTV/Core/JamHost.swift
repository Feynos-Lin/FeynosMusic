import Foundation
import Network
import UIKit

/// Lets phones running Feynos Music join a jam hosted by the Apple TV over Wi-Fi.
/// Uses the same messages as the Android app's jam (one JSON object per line over TCP),
/// advertised with Bonjour as "_feynosjam._tcp".
@MainActor
final class JamHost: ObservableObject {
    static let shared = JamHost()

    @Published private(set) var active = false
    @Published private(set) var guests: [String] = []
    @Published private(set) var addedBy: [String: String] = [:]
    @Published var error: String?

    private final class Peer {
        let conn: NWConnection
        var name = "Guest"
        var hello = false
        var buffer = Data()
        init(_ conn: NWConnection) { self.conn = conn }
    }

    private var listener: NWListener?
    private var peers: [Int: Peer] = [:]
    private var nextId = 1
    private var cursors: [Int: Int] = [:]
    /// songId -> (guest id, or nil for the TV itself; name)
    private var credits: [String: (Int?, String)] = [:]
    private var timer: Timer?
    private var lastSig = ""
    private var lastSent = Date.distantPast

    var hostName: String {
        let n = AppSettings.shared.username
        return n.isEmpty ? UIDevice.current.name : n
    }

    var people: [String] { [hostName] + guests }

    // ---------------- Start / stop ----------------

    func start() {
        guard !active else { return }
        do {
            let l = try NWListener(using: .tcp)
            l.service = NWListener.Service(name: "\(hostName)'s jam", type: "_feynosjam._tcp")
            l.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in self?.accept(conn) }
            }
            l.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    if case .failed(let e) = state {
                        self?.error = "Couldn't start the jam: \(e.localizedDescription)"
                        self?.stop()
                    }
                }
            }
            l.start(queue: .main)
            listener = l
            active = true
            error = nil
            credits = [:]
            addedBy = [:]
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            toast("Jam started. Phones on this Wi-Fi can join from their Jam screen.")
        } catch {
            self.error = "Couldn't start the jam: \(error.localizedDescription)"
        }
    }

    func stop() {
        for p in peers.values {
            send(p, ["t": "end"])
            p.conn.cancel()
        }
        peers = [:]
        listener?.cancel()
        listener = nil
        timer?.invalidate()
        timer = nil
        active = false
        guests = []
        credits = [:]
        addedBy = [:]
        cursors = [:]
    }

    // ---------------- Connections ----------------

    private func accept(_ conn: NWConnection) {
        let id = nextId
        nextId += 1
        let peer = Peer(conn)
        peers[id] = peer
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .failed, .cancelled: self?.drop(id)
                default: break
                }
            }
        }
        conn.start(queue: .main)
        receive(id)
    }

    private func receive(_ id: Int) {
        guard let peer = peers[id] else { return }
        peer.conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self, let peer = self.peers[id] else { return }
                if let data, !data.isEmpty {
                    peer.buffer.append(data)
                    while let nl = peer.buffer.firstIndex(of: 0x0A) {
                        let line = peer.buffer[peer.buffer.startIndex..<nl]
                        peer.buffer.removeSubrange(peer.buffer.startIndex...nl)
                        if let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] {
                            self.handle(id, obj)
                        }
                    }
                }
                if complete || error != nil { self.drop(id) } else { self.receive(id) }
            }
        }
    }

    private func drop(_ id: Int) {
        guard let peer = peers.removeValue(forKey: id) else { return }
        peer.conn.cancel()
        cursors[id] = nil
        if peer.hello {
            refreshGuests()
            toast("\(peer.name) left the jam")
        }
    }

    private func refreshGuests() {
        guests = peers.keys.sorted().compactMap { peers[$0]?.hello == true ? peers[$0]?.name : nil }
    }

    private func send(_ peer: Peer, _ obj: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        data.append(0x0A)
        peer.conn.send(content: data, completion: .contentProcessed { _ in })
    }

    private func send(_ id: Int, _ obj: [String: Any]) {
        if let p = peers[id] { send(p, obj) }
    }

    // ---------------- Messages from phones ----------------

    private func songs(_ any: Any?) -> [Song] {
        guard let arr = any as? [Any], let data = try? JSONSerialization.data(withJSONObject: arr) else { return [] }
        return (try? JSONDecoder().decode([Song].self, from: data)) ?? []
    }

    private func handle(_ id: Int, _ m: [String: Any]) {
        guard let peer = peers[id] else { return }
        let type = m["t"] as? String
        if type == "hello" {
            let isNew = !peer.hello
            peer.name = (m["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Guest"
            peer.hello = true
            refreshGuests()
            if isNew { toast("\(peer.name) joined the jam") }
            broadcast(force: true)
            return
        }
        guard type == "cmd", let op = m["op"] as? String else { return }
        let p = Player.shared
        let a = (m["a"] as? NSNumber)?.intValue ?? 0
        let b = (m["b"] as? NSNumber)?.intValue ?? 0
        let list = songs(m["songs"])
        switch op {
        case "toggle": p.toggle()
        case "next": p.next()
        case "previous": p.previous()
        case "seek": p.seek(to: ((m["ms"] as? NSNumber)?.doubleValue ?? 0) / 1000)
        case "skipTo": p.skipTo(a)
        case "remove": p.remove(at: a)
        case "move": p.move(from: a, to: b)
        case "shuffle": p.toggleShuffle()
        case "repeat": p.cycleRepeat()
        case "clear": p.clearUpNext()
        case "play":
            note(list, guest: id, name: peer.name)
            cursors[id] = p.insert(list, at: nil, jump: true)
        case "playNext":
            note(list, guest: id, name: peer.name)
            cursors[id] = p.insert(list, at: nil, jump: false)
        case "more":
            note(list, guest: id, name: peer.name)
            cursors[id] = p.insert(list, at: cursors[id], jump: false)
        case "add":
            note(list, guest: id, name: peer.name)
            p.insert(list, at: Int.max, jump: false)
        default: break
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.broadcast(force: true)
        }
    }

    /// Remembers who added songs so the queue can show it and listens go to the right person.
    func note(_ list: [Song], guest: Int?, name: String) {
        guard active else { return }
        for s in list {
            credits[s.id] = (guest, name)
            addedBy[s.id] = name
        }
    }

    func noteLocal(_ list: [Song]) { note(list, guest: nil, name: hostName) }

    // ---------------- Listen credit ----------------

    /// If a phone in the jam added this song, its owner gets the listen instead of the TV.
    func creditFor(_ songId: String) -> Int? {
        guard active, let g = credits[songId]?.0, peers[g]?.hello == true else { return nil }
        return g
    }

    private func songJSON(_ s: Song) -> Any {
        guard let data = try? JSONEncoder().encode(s) else { return [:] as [String: Any] }
        return (try? JSONSerialization.jsonObject(with: data)) ?? ([:] as [String: Any])
    }

    func sendListen(_ guest: Int, song: Song, at: Date) {
        send(guest, ["t": "listen", "song": songJSON(song), "at": Int(at.timeIntervalSince1970 * 1000)])
    }

    func sendNowPlaying(_ guest: Int, song: Song) {
        send(guest, ["t": "nowPlaying", "song": songJSON(song)])
    }

    // ---------------- Sharing what's playing ----------------

    private func tick() {
        broadcast(force: Date().timeIntervalSince(lastSent) > 4)
    }

    func broadcast(force: Bool) {
        guard active else { return }
        let ready = peers.values.filter(\.hello)
        guard !ready.isEmpty else { return }
        let p = Player.shared
        let next = Array(p.upNext.prefix(40))
        var sig = "\(p.current?.id ?? "")|\(p.isPlaying)|\(p.shuffle)|\(p.repeatMode.rawValue)|\(guests.count)|\(addedBy.count)"
        for (i, s) in next { sig += "|\(i)\(s.id)" }
        if !force && sig == lastSig { return }
        lastSig = sig
        lastSent = Date()
        // Same numbers the Android player uses: off = 0, one = 1, all = 2.
        let repeatCode: Int
        switch p.repeatMode {
        case .off: repeatCode = 0
        case .one: repeatCode = 1
        case .all: repeatCode = 2
        }
        var ids = Set(next.map(\.1.id))
        if let c = p.current { ids.insert(c.id) }
        var msg: [String: Any] = [
            "t": "state",
            "host": hostName,
            "playing": p.isPlaying,
            "pos": Int(p.position * 1000),
            "dur": Int(p.duration * 1000),
            "shuffle": p.shuffle,
            "repeat": repeatCode,
            "next": next.map { ["i": $0.0, "s": songJSON($0.1)] as [String: Any] },
            "members": people,
            "by": addedBy.filter { ids.contains($0.key) },
        ]
        if let c = p.current { msg["song"] = songJSON(c) }
        for peer in ready { send(peer, msg) }
    }
}
