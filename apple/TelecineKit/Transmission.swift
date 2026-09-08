//  Transmission.swift — the format, as Swift types.
//  A television station as a file: an epoch and a loop of blocks. See ../../SPEC.md.

import Foundation

/// One block of a Transmission's loop. Films play; interstitials are station breaks
/// rendered by the receiver. Additive fields the receiver does not understand are ignored.
public enum Block: Hashable, Sendable, Codable {
    case film(slug: String, durationSec: Int, src: URL)
    case interstitial(next: String, durationSec: Int)

    public var durationSec: Int {
        switch self {
        case .film(_, let d, _), .interstitial(_, let d): d
        }
    }
    /// The film this block is, or the film it precedes.
    public var filmSlug: String {
        switch self {
        case .film(let s, _, _): s
        case .interstitial(let n, _): n
        }
    }
    public var isFilm: Bool { if case .film = self { true } else { false } }
    public var src: URL? { if case .film(_, _, let u) = self { u } else { nil } }

    private enum Keys: String, CodingKey { case type, film, next, durationSec, src }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let type = try c.decode(String.self, forKey: .type)
        let duration = try c.decode(Int.self, forKey: .durationSec)
        switch type {
        case "film":
            let slug = try c.decode(String.self, forKey: .film)
            let src = try c.decode(String.self, forKey: .src)
            guard let url = URL(string: src) else {
                throw DecodingError.dataCorruptedError(forKey: .src, in: c, debugDescription: "film \(slug): src is not a URL")
            }
            self = .film(slug: slug, durationSec: duration, src: url)
        case "interstitial":
            self = .interstitial(next: try c.decode(String.self, forKey: .next), durationSec: duration)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown block type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .film(let slug, let d, let src):
            try c.encode("film", forKey: .type); try c.encode(slug, forKey: .film)
            try c.encode(d, forKey: .durationSec); try c.encode(src.absoluteString, forKey: .src)
        case .interstitial(let next, let d):
            try c.encode("interstitial", forKey: .type); try c.encode(next, forKey: .next)
            try c.encode(d, forKey: .durationSec)
        }
    }
}

/// A channel. `epoch` is the instant block 0 began; the loop is defined for all time.
public struct Transmission: Identifiable, Hashable, Sendable, Codable {
    public var transmission: String
    public var id: String
    public var number: String?
    public var name: String
    public var tagline: String?
    public var description: String?
    public var epoch: String
    public var blocks: [Block]
    /// Films described inline (an additive v0.1 extension used by single-file stations).
    public var films: [String: Film]?

    public init(transmission: String = "0.1", id: String, number: String? = nil, name: String, tagline: String? = nil,
                description: String? = nil, epoch: String, blocks: [Block], films: [String: Film]? = nil) {
        self.transmission = transmission; self.id = id; self.number = number; self.name = name
        self.tagline = tagline; self.description = description; self.epoch = epoch; self.blocks = blocks; self.films = films
    }

    /// The epoch as milliseconds since 1970 — integer, as `Date.parse` yields in the reference.
    public var epochMs: Double {
        guard let d = ISO8601.parse(epoch) else { return 0 }
        return (d.timeIntervalSince1970 * 1000).rounded()
    }
    public var epochDate: Date { Date(timeIntervalSince1970: epochMs / 1000) }
    /// A display number for stations that declare none.
    public var displayNumber: String { number ?? "—" }
}

/// A film, as the network describes it: the print, the facts, and the programme note.
public struct Film: Identifiable, Hashable, Sendable, Codable {
    public var slug: String
    public var title: String
    public var year: Int?
    public var director: String?
    public var durationSec: Int
    public var src: URL?
    public var identifier: String?
    public var itemUrl: URL?
    public var logline: String?
    public var note: String?
    public var channel: String?
    public var id: String { slug }

    public init(slug: String, title: String, year: Int? = nil, director: String? = nil, durationSec: Int,
                src: URL? = nil, identifier: String? = nil, itemUrl: URL? = nil, logline: String? = nil,
                note: String? = nil, channel: String? = nil) {
        self.slug = slug; self.title = title; self.year = year; self.director = director; self.durationSec = durationSec
        self.src = src; self.identifier = identifier; self.itemUrl = itemUrl; self.logline = logline; self.note = note; self.channel = channel
    }

    public var yearText: String { year.map(String.init) ?? "" }
    public var minutes: Int { Int((Double(durationSec) / 60).rounded()) }
}

/// A network: several Transmissions and the films they schedule.
/// This is the shape telecine.vercel.app/network.json publishes.
public struct Network: Hashable, Sendable, Codable {
    public var generatedAt: String?
    public var interstitialSec: Int?
    public var channels: [Transmission]
    public var films: [String: Film]

    public init(generatedAt: String? = nil, interstitialSec: Int? = nil, channels: [Transmission], films: [String: Film]) {
        self.generatedAt = generatedAt; self.interstitialSec = interstitialSec; self.channels = channels; self.films = films
    }

    public func film(_ slug: String) -> Film? { films[slug] }
    public func channel(_ id: String) -> Transmission? { channels.first { $0.id == id } }
    public func channel(for film: Film) -> Transmission? {
        channels.first { ch in ch.blocks.contains { $0.isFilm && $0.filmSlug == film.slug } }
    }
    public var totalHours: Double {
        channels.reduce(0) { $0 + Broadcast.loopDuration($1) } / 3600
    }
}

enum ISO8601 {
    nonisolated(unsafe) private static let strict: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    static func parse(_ s: String) -> Date? { strict.date(from: s) ?? fractional.date(from: s) }
}
