import AVFoundation
import Foundation
import MediaPlayer
import UIKit

/// Plays the queue, reports to the Siri Remote / Control Center, and scrobbles.
@MainActor
final class Player: ObservableObject {
    static let shared = Player()

    @Published private(set) var queue: [Song] = []
    @Published private(set) var index = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var shuffle = false
    @Published private(set) var repeatMode: RepeatMode = .off
    /// Changes whenever something starts playing, so the app can jump to Now Playing.
    @Published private(set) var startedCount = 0

    private let av = AVPlayer()
    private var unshuffled: [Song]?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    // scrobbling
    private var playedSeconds: Double = 0
    private var startedAt = Date()
    private var submitted = false
    private var nowPlayingSent = false

    var current: Song? { queue.indices.contains(index) ? queue[index] : nil }
    var upNext: [(Int, Song)] { queue.indices.contains(index) ? Array(queue.enumerated().dropFirst(index + 1)).map { ($0.offset, $0.element) } : [] }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        av.automaticallyWaitsToMinimizeStalling = true

        timeObserver = av.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            MainActor.assumeIsolated { self?.tick(t.seconds) }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] n in
            MainActor.assumeIsolated {
                guard let self, (n.object as? AVPlayerItem) === self.av.currentItem else { return }
                self.itemEnded()
            }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                toast("Couldn't play that song, skipping")
                self?.next()
            }
        }
        setupRemote()
    }

    // ---------------- Queue control ----------------

    func play(_ songs: [Song], start: Int = 0, shuffle: Bool = false) {
        guard !songs.isEmpty else { return }
        if JamHost.shared.active && !queue.isEmpty {
            // In a jam, playing something slots it in now without wiping everyone's queue.
            let picked = shuffle ? songs.shuffled() : Array(songs.dropFirst(min(max(start, 0), songs.count - 1)))
            JamHost.shared.noteLocal(picked)
            insert(picked, at: nil, jump: true)
            startedCount += 1
            return
        }
        if shuffle {
            unshuffled = songs
            queue = songs.shuffled()
            index = 0
        } else {
            unshuffled = nil
            queue = songs
            index = min(max(start, 0), songs.count - 1)
        }
        self.shuffle = shuffle
        load(autoplay: true)
        startedCount += 1
    }

    func playNext(_ songs: [Song]) {
        JamHost.shared.noteLocal(songs)
        insert(songs, at: nil, jump: false)
    }

    func addToQueue(_ songs: [Song]) {
        JamHost.shared.noteLocal(songs)
        insert(songs, at: Int.max, jump: false)
    }

    /// Inserts songs at `at` (nil = right after the current song, past the end = append),
    /// optionally jumping to the first. Returns the index just after the inserted block.
    @discardableResult
    func insert(_ songs: [Song], at: Int?, jump: Bool) -> Int {
        guard !songs.isEmpty else { return index + 1 }
        if queue.isEmpty {
            queue = songs
            index = 0
            unshuffled = nil
            load(autoplay: true)
            return songs.count
        }
        let pos = min(max(at ?? index + 1, 0), queue.count)
        queue.insert(contentsOf: songs, at: pos)
        unshuffled?.append(contentsOf: songs)
        if pos <= index && !jump { index += songs.count }
        if jump {
            index = pos
            load(autoplay: true)
        }
        return pos + songs.count
    }

    func toggle() {
        guard current != nil else { return }
        if isPlaying { av.pause() } else {
            if av.currentItem == nil { load(autoplay: true) } else { av.play() }
        }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        if index + 1 < queue.count {
            index += 1
        } else if repeatMode == .all {
            index = 0
        } else {
            return
        }
        load(autoplay: true)
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if position > 4 || index == 0 {
            seek(to: 0)
        } else {
            index -= 1
            load(autoplay: true)
        }
    }

    func seek(to seconds: Double) {
        av.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
        position = max(0, seconds)
        updateNowPlaying()
    }

    func skip(by seconds: Double) { seek(to: min(position + seconds, max(duration - 1, 0))) }

    func skipTo(_ i: Int) {
        guard queue.indices.contains(i) else { return }
        index = i
        load(autoplay: true)
    }

    func remove(at i: Int) {
        guard queue.indices.contains(i), i != index else { return }
        let removed = queue.remove(at: i)
        if i < index { index -= 1 }
        if let u = unshuffled, let j = u.firstIndex(of: removed) { unshuffled?.remove(at: j) }
    }

    func move(from: Int, to: Int) {
        guard queue.indices.contains(from), queue.indices.contains(to), from != index, to != index else { return }
        let s = queue.remove(at: from)
        queue.insert(s, at: to)
    }

    func clearUpNext() {
        guard let cur = current else { return }
        queue = [cur]
        index = 0
        unshuffled = nil
    }

    func toggleShuffle() {
        guard let cur = current else {
            shuffle.toggle()
            return
        }
        if shuffle {
            // Back to the original order, keeping the current song playing.
            if let u = unshuffled {
                queue = u
                index = u.firstIndex(of: cur) ?? 0
            }
            unshuffled = nil
            shuffle = false
        } else {
            unshuffled = queue
            let rest = queue.enumerated().filter { $0.offset != index }.map(\.element).shuffled()
            queue = [cur] + rest
            index = 0
            shuffle = true
        }
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func stop() {
        av.pause()
        av.replaceCurrentItem(with: nil)
        queue = []
        index = 0
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // ---------------- Playback ----------------

    private func load(autoplay: Bool) {
        guard let song = current, let url = Subsonic.shared.streamURL(song.id) else { return }
        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .readyToPlay {
                    let d = item.duration.seconds
                    if d.isFinite && d > 0 { self.duration = d }
                    self.isBuffering = false
                    self.updateNowPlaying()
                }
            }
        }
        AudioTap.shared.attach(to: item)
        av.replaceCurrentItem(with: item)
        position = 0
        duration = Double(song.seconds)
        isBuffering = true
        beginScrobble(song)
        if autoplay {
            av.play()
            isPlaying = true
        }
        updateNowPlaying(loadArtwork: true)
    }

    private func itemEnded() {
        if repeatMode == .one {
            seek(to: 0)
            beginScrobble(current)
            av.play()
            return
        }
        if index + 1 < queue.count {
            index += 1
            load(autoplay: true)
        } else if repeatMode == .all {
            index = 0
            load(autoplay: true)
        } else {
            isPlaying = false
            av.pause()
            updateNowPlaying()
        }
    }

    private func tick(_ seconds: Double) {
        guard seconds.isFinite else { return }
        position = seconds
        if av.timeControlStatus == .playing {
            isBuffering = false
            playedSeconds += 0.5
            if !nowPlayingSent, let s = current { sendNowPlaying(s) }
            checkScrobble()
        }
    }

    // ---------------- Scrobbling ----------------

    private func beginScrobble(_ song: Song?) {
        playedSeconds = 0
        startedAt = Date()
        submitted = false
        nowPlayingSent = false
    }

    private func checkScrobble() {
        guard !submitted, let song = current else { return }
        let total = duration > 0 ? duration : Double(song.seconds)
        let threshold = total > 0 ? min(total / 2, 240) : 240
        guard playedSeconds >= threshold, playedSeconds >= 10 else { return }
        submitted = true
        if let guest = JamHost.shared.creditFor(song.id) {
            JamHost.shared.sendListen(guest, song: song, at: startedAt)
        } else {
            recordListen(song, at: startedAt)
        }
    }

    private func sendNowPlaying(_ song: Song) {
        nowPlayingSent = true
        if let guest = JamHost.shared.creditFor(song.id) {
            JamHost.shared.sendNowPlaying(guest, song: song)
            return
        }
        let s = AppSettings.shared
        Task {
            if s.scrobbleNavidrome { try? await Subsonic.shared.scrobble(song.id, at: Date(), submission: false) }
            if s.scrobbleLb && !s.lbToken.isEmpty {
                _ = await ListenBrainz.shared.submit(ListenBrainz.shared.listenBody("playing_now", song: song, at: nil))
            }
        }
    }

    func recordListen(_ song: Song, at: Date) {
        Store.shared.addPlay(song, at: at)
        let s = AppSettings.shared
        Task {
            if s.scrobbleNavidrome { try? await Subsonic.shared.scrobble(song.id, at: at, submission: true) }
            if s.scrobbleLb && !s.lbToken.isEmpty {
                let body = ListenBrainz.shared.listenBody("single", song: song, at: at)
                if await ListenBrainz.shared.submit(body) {
                    await Store.shared.flushListens()
                } else {
                    Store.shared.queueListen(body)
                }
            }
        }
    }

    // ---------------- Siri Remote / Control Center ----------------

    private func setupRemote() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == false { self?.toggle() } }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.toggle() } }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            let t = (e as? MPChangePlaybackPositionCommandEvent)?.positionTime ?? 0
            Task { @MainActor in self?.seek(to: t) }
            return .success
        }
    }

    private func updateNowPlaying(loadArtwork: Bool = false) {
        guard let song = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.artistName,
            MPMediaItemPropertyAlbumTitle: song.album ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if !loadArtwork, let art = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = art
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        guard loadArtwork, let url = Covers.shared.artURL(song.coverArt, albumId: song.albumId, size: 600) else { return }
        let id = song.id
        Task {
            guard let result = try? await URLSession.shared.data(from: url), let image = UIImage(data: result.0) else { return }
            guard self.current?.id == id else { return }
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
            updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
    }
}
