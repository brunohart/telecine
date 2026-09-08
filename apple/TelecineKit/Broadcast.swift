//  Broadcast.swift — the Transmission resolver.
//
//  Given the real clock, answers the only question a broadcast needs to answer:
//  what is on, and how far into it are we. Pure functions, no state.
//  This is a second implementation of src/lib/broadcast.js; the two are held to
//  identical answers by TelecineTests/ParityTests against a frozen fixture.

import Foundation

public struct Resolution: Sendable, Hashable {
    public var block: Block
    public var index: Int
    public var offsetSec: Double
    public var blockStart: Date
    public var blockEnd: Date
    public var loopSec: Double

    public var progress: Double { min(1, max(0, offsetSec / Double(block.durationSec))) }
    public func remaining(at now: Date) -> TimeInterval { max(0, blockEnd.timeIntervalSince(now)) }
}

public struct Airing: Sendable, Hashable {
    public var block: Block
    public var index: Int
    public var start: Date
    public var end: Date
    public var filmSlug: String { block.filmSlug }
}

public enum BroadcastError: Error { case emptySchedule(String) }

public enum Broadcast {
    /// Milliseconds since 1970 as an integer-valued Double — the reference works in JS `Date` ms.
    @inline(__always) static func ms(_ d: Date) -> Double { (d.timeIntervalSince1970 * 1000).rounded() }
    @inline(__always) static func date(ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

    /// Total length of one loop of the schedule, in seconds.
    public static func loopDuration(_ channel: Transmission) -> Double {
        Double(channel.blocks.reduce(0) { $0 + $1.durationSec })
    }

    /// Resolve a channel against a moment in time.
    public static func resolve(_ channel: Transmission, at now: Date) throws -> Resolution {
        let t = ms(now)
        let epoch = channel.epochMs
        let loop = loopDuration(channel)
        guard loop > 0 else { throw BroadcastError.emptySchedule(channel.id) }
        // seconds into the current loop — well-defined before the epoch too
        var into = ((t - epoch) / 1000).truncatingRemainder(dividingBy: loop)
        into = (into + loop).truncatingRemainder(dividingBy: loop)
        var cum = 0.0
        for (i, b) in channel.blocks.enumerated() {
            let d = Double(b.durationSec)
            if into < cum + d {
                let loopStart = t - into * 1000
                return Resolution(block: b, index: i, offsetSec: into - cum,
                                  blockStart: date(ms: loopStart + cum * 1000),
                                  blockEnd: date(ms: loopStart + (cum + d) * 1000),
                                  loopSec: loop)
            }
            cum += d
        }
        // unreachable: `into` is always < loop
        throw BroadcastError.emptySchedule(channel.id)
    }

    /// All film airings on a channel that begin within [from, to).
    public static func airingsBetween(_ channel: Transmission, from: Date, to: Date) -> [Airing] {
        let fromMs = ms(from), toMs = ms(to)
        let epoch = channel.epochMs
        let loopMs = loopDuration(channel) * 1000
        guard loopMs > 0 else { return [] }
        var airings: [Airing] = []
        var k = floor((fromMs - epoch) / loopMs) - 1
        while true {
            let loopStart = epoch + k * loopMs
            if loopStart >= toMs { break }
            var cum = 0.0
            for (i, b) in channel.blocks.enumerated() {
                let start = loopStart + cum * 1000
                let d = Double(b.durationSec)
                cum += d
                guard b.isFilm else { continue }
                if start >= fromMs && start < toMs {
                    airings.append(Airing(block: b, index: i, start: date(ms: start), end: date(ms: start + d * 1000)))
                }
            }
            k += 1
        }
        return airings
    }

    /// The next airing of a given film on a channel, at or after `now`.
    public static func nextAiring(_ channel: Transmission, film slug: String, at now: Date) -> Airing? {
        let t = ms(now)
        let horizon = t + loopDuration(channel) * 1000 + 1000
        return airingsBetween(channel, from: date(ms: t), to: date(ms: horizon)).first { $0.filmSlug == slug }
    }

    /// What follows the current block — the first film after it, wrapping.
    public static func upNext(_ channel: Transmission, at now: Date) -> Block? {
        guard let r = try? resolve(channel, at: now) else { return nil }
        let n = channel.blocks.count
        for step in 1...max(1, n) {
            let b = channel.blocks[(r.index + step) % n]
            if b.isFilm { return b }
        }
        return nil
    }
}
