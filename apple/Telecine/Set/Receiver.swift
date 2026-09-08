//  Receiver.swift — the reference Transmission receiver ("The Set").
//
//  Broadcast rules, enforced here:
//    · you join what is on, at the moment it is at — never from the top
//    · there is no pause and no scrubbing; the LIVE point is the only point
//    · drift is corrected quietly; two sets in two houses show the same frame
//
//  Playback discipline:
//    · the set warms up before you switch it on — the live source is loaded and seeked
//      while the TUNE IN lens is still showing, so power-on is fast
//    · during a station break the next film pre-buffers behind the test card
//    · if the print stalls the set says so ("TUNING"), and if the signal is lost it says
//      that too, and retries — it never pretends

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import Observation

@MainActor @Observable
final class Receiver {
    enum Status: Equatable { case off, tuning, onAir, stationBreak, signalLost }

    private(set) var channel: Transmission
    private(set) var powered = false
    private(set) var muted = false
    private(set) var status: Status = .off
    private(set) var resolution: Resolution?
    private(set) var now: Date = .now
    /// Increments on every channel change while powered — the view plays a burst of static.
    private(set) var burst = 0
    /// Increments when the on-air line changes — the chyron bar sweeps.
    private(set) var swap = 0
    /// A short, honest message from the set ("A broadcast does not pause.").
    private(set) var notice: String?

    let player = AVPlayer()
    private let stations: Stations
    private var srcKey: String?
    private var transitionTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var itemStatusTask: Task<Void, Never>?
    private var timeControlTask: Task<Void, Never>?
    private var endObserver: NSObjectProtocol?
    private var driftAt: Date = .distantPast
    private var remoteTargets: [Any] = []

    init(stations: Stations) {
        self.stations = stations
        let remembered = UserDefaults.standard.string(forKey: "telecine.channel")
        channel = stations.channels.first { $0.id == remembered } ?? stations.channels.first
            ?? Transmission(id: "off-air", name: "Off air", epoch: "2026-07-01T00:00:00Z", blocks: [.interstitial(next: "off-air", durationSec: 60)])
        player.automaticallyWaitsToMinimizeStalling = true
        player.preventsDisplaySleepDuringVideoPlayback = true
        observePlayer()
        installRemoteCommands()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        sync()
    }

    // MARK: what's on

    var onAirFilm: Film? {
        guard let r = resolution else { return nil }
        return stations.film(for: r.block)
    }
    var upNext: Film? {
        Broadcast.upNext(channel, at: now).map { stations.film(for: $0) }
    }
    var isBreak: Bool { resolution?.block.isFilm == false }
    var elapsed: Double { resolution?.offsetSec ?? 0 }
    var total: Double { Double(resolution?.block.durationSec ?? 0) }
    var progress: Double { resolution?.progress ?? 0 }
    var countdown: Double { resolution?.remaining(at: now) ?? 0 }
    var channels: [Transmission] { stations.channels }

    /// One line for the dial and the lens: what a channel is showing at this instant.
    func nowOnLine(_ ch: Transmission, at t: Date? = nil) -> String {
        guard let r = try? Broadcast.resolve(ch, at: t ?? now) else { return "Off air" }
        let film = stations.film(for: r.block)
        let year = film.year.map { " (\($0))" } ?? ""
        return r.block.isFilm ? "On air — \(film.title)\(year)" : "Station break — next: \(film.title)"
    }

    // MARK: the dial

    func setChannel(_ id: String) {
        guard let ch = stations.channel(id) else { return }
        let prev = channel.id
        channel = ch
        srcKey = nil
        UserDefaults.standard.set(ch.id, forKey: "telecine.channel")
        if prev != ch.id && powered { burst += 1 }
        sync()
    }

    func channelUp() { step(+1) }
    func channelDown() { step(-1) }
    private func step(_ d: Int) {
        let list = stations.channels
        guard let i = list.firstIndex(where: { $0.id == channel.id }), list.count > 1 else { return }
        setChannel(list[(i + d + list.count) % list.count].id)
    }

    /// If the network refreshed under us, keep the same channel by id.
    func reconcile() {
        if let fresh = stations.channel(channel.id), fresh != channel {
            channel = fresh
            srcKey = nil
            sync()
        }
    }

    // MARK: power

    func powerOn() {
        guard !powered else { return }
        powered = true
        muted = false
        player.isMuted = false
        activateAudio()
        sync()
        attemptPlay()
        say(nil)
    }

    func powerOff() {
        guard powered else { return }
        powered = false
        player.pause()
        status = .off
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func toggleSound() {
        muted.toggle()
        player.isMuted = muted
    }

    /// The remote's play/pause key on a broadcast: the set explains itself, then rejoins live.
    func playPausePressed() {
        if !powered { powerOn(); return }
        say("A broadcast does not pause. Rejoining live.")
        seekLive()
        attemptPlay()
    }

    func say(_ text: String?, for seconds: Double = 2.6) {
        noticeTask?.cancel()
        notice = text
        guard text != nil else { return }
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { self?.notice = nil }
        }
    }

    // MARK: the broadcast loop

    private func sync() {
        transitionTask?.cancel()
        now = .now
        guard let r = try? Broadcast.resolve(channel, at: now) else { status = .signalLost; return }
        resolution = r
        if r.block.isFilm { showFilm(r) } else { showBreak(r) }
        swap += 1
        updateNowPlaying()
        let wait = r.blockEnd.timeIntervalSince(now) + 0.3
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0.05, wait)))
            if !Task.isCancelled { self?.sync() }
        }
    }

    private func showFilm(_ r: Resolution) {
        guard let src = r.block.src else { return }
        let key = "\(channel.id):\(r.index)"
        if powered { status = .tuning }
        if srcKey == key {
            // pre-buffered during the break or the off state — just go
            if player.currentItem?.status == .readyToPlay { seekLive() }
            if powered { attemptPlay() }
        } else {
            load(key: key, src: src, seekOnReady: true)
        }
    }

    private func showBreak(_ r: Resolution) {
        player.pause()
        status = powered ? .stationBreak : .off
        // warm up the next reel behind the test card
        let n = channel.blocks.count
        let nextIndex = (r.index + 1) % n
        let next = channel.blocks[nextIndex]
        if let src = next.src { load(key: "\(channel.id):\(nextIndex)", src: src, seekOnReady: false) }
    }

    private func load(key: String, src: URL, seekOnReady: Bool) {
        guard srcKey != key else { return }
        srcKey = key
        let item = AVPlayerItem(url: src)
        player.replaceCurrentItem(with: item)
        itemStatusTask?.cancel()
        itemStatusTask = Task { [weak self] in
            for await s in item.publisher(for: \.status).values {
                guard let self, !Task.isCancelled else { return }
                switch s {
                case .readyToPlay:
                    if seekOnReady { seekLive() }
                    if powered, resolution?.block.isFilm == true { attemptPlay() }
                case .failed:
                    signalLost()
                default: break
                }
            }
        }
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
    }

    private func seekLive() {
        guard let r = try? Broadcast.resolve(channel, at: .now), r.block.isFilm else { return }
        let t = CMTime(seconds: r.offsetSec, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func attemptPlay() {
        guard powered, resolution?.block.isFilm == true else { return }
        player.play()
    }

    private func signalLost() {
        guard powered else { return }
        status = .signalLost
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, !Task.isCancelled else { return }
            srcKey = nil
            sync()
        }
    }

    private func tick() {
        now = .now
        guard let r = try? Broadcast.resolve(channel, at: now) else { return }
        resolution = r
        guard powered, r.block.isFilm, let item = player.currentItem, item.status == .readyToPlay else { return }
        // quiet drift correction, at most every 15s
        if now.timeIntervalSince(driftAt) > 15 {
            driftAt = now
            let actual = player.currentTime().seconds
            if actual.isFinite, abs(actual - r.offsetSec) > 2.5 { seekLive() }
        }
    }

    // MARK: the machine underneath

    private func observePlayer() {
        let player = self.player
        timeControlTask = Task { [weak self] in
            for await s in player.publisher(for: \.timeControlStatus).values {
                guard let self, !Task.isCancelled, self.powered, self.resolution?.block.isFilm == true else { continue }
                switch s {
                case .playing: if status != .signalLost { status = .onAir }
                case .waitingToPlayAtSpecifiedRate: if status == .onAir { status = .tuning }
                default: break
                }
            }
        }
    }

    private func activateAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    private func installRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        for cmd in [c.seekForwardCommand, c.seekBackwardCommand, c.skipForwardCommand, c.skipBackwardCommand,
                    c.changePlaybackPositionCommand, c.nextTrackCommand, c.previousTrackCommand] {
            cmd.isEnabled = false
        }
        remoteTargets.append(c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.powerOn() }
            return .success
        })
        remoteTargets.append(c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.powerOff() }
            return .success
        })
        remoteTargets.append(c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.powered { self.powerOff() } else { self.powerOn() }
            }
            return .success
        })
    }

    private func updateNowPlaying() {
        guard powered, let film = onAirFilm else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: film.title,
            MPMediaItemPropertyArtist: [film.director, film.year.map(String.init)].compactMap { $0 }.joined(separator: " · "),
            MPMediaItemPropertyAlbumTitle: "CH \(channel.displayNumber) · \(channel.name)",
            MPNowPlayingInfoPropertyIsLiveStream: true,
        ]
        if let r = resolution, r.block.isFilm {
            info[MPMediaItemPropertyPlaybackDuration] = Double(r.block.durationSec)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = r.offsetSec
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Foreground again: whatever was on has moved on. Rejoin live.
    func wake() {
        if powered { srcKey = nil }
        sync()
    }
}
