//  Stations.swift — every Transmission this receiver can tune.
//
//  The house network ships inside the app, so the set always knows what is on. At launch it
//  re-reads the same file from telecine.vercel.app/network.json — new seasons arrive without an
//  app update, because the schedule is a file. Other people's stations (affiliates) are added by
//  URL and tuned exactly the same way. That is the whole federation model.

import Foundation
import Observation

@MainActor @Observable
final class Stations {
    enum Source: String { case bundled, cached, live }

    private(set) var network: Network
    private(set) var graph: Graph
    private(set) var source: Source = .bundled
    private(set) var refreshedAt: Date?
    private(set) var affiliates: [Affiliate] = []
    private(set) var lastError: String?

    struct Affiliate: Identifiable, Hashable, Codable {
        var url: URL
        var network: Network
        var addedAt: Date
        var id: URL { url }
    }

    static let headEnd = URL(string: "https://telecine.vercel.app/network.json")!
    private let defaults = UserDefaults.standard
    private let affiliateKey = "telecine.affiliates"

    init() {
        let bundled = Bundled.network()
        network = bundled
        graph = Bundled.graph()
        if let cached = Self.readCache(), Self.isSane(cached), (cached.generatedAt ?? "") >= (bundled.generatedAt ?? "") {
            network = cached
            source = .cached
        }
        affiliates = (try? JSONDecoder().decode([Affiliate].self, from: defaults.data(forKey: affiliateKey) ?? Data())) ?? []
    }

    // MARK: the dial

    var channels: [Transmission] { network.channels + affiliates.flatMap(\.network.channels) }

    func channel(_ id: String) -> Transmission? { channels.first { $0.id == id } }

    func film(_ slug: String) -> Film? {
        if let f = network.films[slug] { return f }
        for a in affiliates {
            if let f = a.network.films[slug] { return f }
            for ch in a.network.channels { if let f = ch.films?[slug] { return f } }
        }
        return nil
    }

    /// The film a block refers to — or a placeholder named after its slug, so a station with
    /// sparse metadata still tunes.
    func film(for block: Block) -> Film {
        film(block.filmSlug) ?? Film(slug: block.filmSlug, title: block.filmSlug.replacingOccurrences(of: "-", with: " ").capitalized,
                                     durationSec: block.durationSec, src: block.src)
    }

    func channel(for film: Film) -> Transmission? {
        channels.first { ch in ch.blocks.contains { $0.isFilm && $0.filmSlug == film.slug } }
    }

    func isAffiliate(_ channel: Transmission) -> Bool { !network.channels.contains { $0.id == channel.id } }

    // MARK: the head-end

    func refresh() async {
        do {
            var req = URLRequest(url: Self.headEnd)
            req.cachePolicy = .reloadRevalidatingCacheData
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { return }
            let fresh = try JSONDecoder().decode(Network.self, from: data)
            guard Self.isSane(fresh) else { lastError = "head-end published an unsound network"; return }
            network = fresh
            source = .live
            refreshedAt = .now
            lastError = nil
            Self.writeCache(data)
        } catch {
            lastError = error.localizedDescription
        }
        for i in affiliates.indices {
            if let n = try? await Self.fetchStation(affiliates[i].url) { affiliates[i].network = n }
        }
    }

    // MARK: affiliates

    func add(station url: URL) async throws {
        let n = try await Self.fetchStation(url)
        affiliates.removeAll { $0.url == url }
        affiliates.append(Affiliate(url: url, network: n, addedAt: .now))
        persistAffiliates()
    }

    func remove(_ affiliate: Affiliate) {
        affiliates.removeAll { $0.id == affiliate.id }
        persistAffiliates()
    }

    private func persistAffiliates() {
        defaults.set(try? JSONEncoder().encode(affiliates), forKey: affiliateKey)
    }

    enum StationError: LocalizedError {
        case notATransmission, unsound
        var errorDescription: String? {
            switch self {
            case .notATransmission: "That file is not a Transmission or a network of them."
            case .unsound: "That station's schedule does not add up — a block names a film it never describes."
            }
        }
    }

    /// A station file is either a network (channels + films) or a single Transmission,
    /// optionally carrying its own films inline.
    static func fetchStation(_ url: URL) async throws -> Network {
        let (data, _) = try await URLSession.shared.data(from: url)
        let dec = JSONDecoder()
        if let n = try? dec.decode(Network.self, from: data) {
            guard isSane(n) else { throw StationError.unsound }
            return n
        }
        if let t = try? dec.decode(Transmission.self, from: data) {
            let n = Network(generatedAt: nil, interstitialSec: nil, channels: [t], films: t.films ?? [:])
            guard Broadcast.loopDuration(t) > 0 else { throw StationError.unsound }
            return n
        }
        throw StationError.notATransmission
    }

    static func isSane(_ n: Network) -> Bool {
        guard !n.channels.isEmpty else { return false }
        for ch in n.channels {
            guard Broadcast.loopDuration(ch) > 0, ch.epochMs != 0 else { return false }
            for b in ch.blocks where b.isFilm {
                guard n.films[b.filmSlug] != nil || ch.films?[b.filmSlug] != nil else { return false }
            }
        }
        return true
    }

    // MARK: cache

    private static var cacheURL: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "network.json")
    }
    private static func readCache() -> Network? {
        guard let u = cacheURL, let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(Network.self, from: d)
    }
    private static func writeCache(_ data: Data) {
        guard let u = cacheURL else { return }
        try? data.write(to: u, options: .atomic)
    }
}
