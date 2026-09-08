//  BroadcastTests.swift — the reference suite (test/broadcast.test.mjs), ported clause for clause.

import Foundation
import Testing
@testable import Telecine

private let EPOCH = "2026-07-01T00:00:00Z"
private let epochMs: Double = 1_782_864_000_000 // Date.parse("2026-07-01T00:00:00Z")
private let channel = Transmission(
    id: "test", name: "Test", epoch: EPOCH,
    blocks: [
        .interstitial(next: "a", durationSec: 90),
        .film(slug: "a", durationSec: 3600, src: URL(string: "https://example.org/a.mp4")!),
        .interstitial(next: "b", durationSec: 90),
        .film(slug: "b", durationSec: 5400, src: URL(string: "https://example.org/b.mp4")!),
    ])
private let LOOP: Double = 90 + 3600 + 90 + 5400
private func at(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

@Suite("The Transmission resolver")
struct BroadcastTests {
    @Test func epochParsesToIntegerMilliseconds() {
        #expect(channel.epochMs == epochMs)
    }

    @Test func loopDurationSumsAllBlocks() {
        #expect(Broadcast.loopDuration(channel) == LOOP)
    }

    @Test func resolvesTheOpeningInterstitialAtTheEpoch() throws {
        let r = try Broadcast.resolve(channel, at: at(epochMs))
        #expect(r.index == 0)
        #expect(!r.block.isFilm)
        #expect(r.offsetSec == 0)
    }

    @Test func resolvesMidFilmWithTheCorrectOffset() throws {
        let r = try Broadcast.resolve(channel, at: at(epochMs + (90 + 1000) * 1000))
        #expect(r.block.filmSlug == "a")
        #expect(r.offsetSec == 1000)
        #expect(Broadcast.ms(r.blockStart) == epochMs + 90 * 1000)
        #expect(Broadcast.ms(r.blockEnd) == epochMs + (90 + 3600) * 1000)
    }

    @Test func blockBoundariesAreHalfOpen() throws {
        let r = try Broadcast.resolve(channel, at: at(epochMs + (90 + 3600) * 1000))
        #expect(r.index == 2)
        #expect(r.offsetSec == 0)
    }

    @Test func wrapsAroundTheLoop() throws {
        let r = try Broadcast.resolve(channel, at: at(epochMs + (LOOP + 90 + 5) * 1000))
        #expect(r.block.filmSlug == "a")
        #expect(r.offsetSec == 5)
    }

    @Test func isWellDefinedBeforeTheEpoch() throws {
        let r = try Broadcast.resolve(channel, at: at(epochMs - 10 * 1000))
        #expect(r.index == 3)
        #expect((Double(r.block.durationSec) - r.offsetSec).rounded() == 10)
    }

    @Test func twoClientsAtTheSameInstantSeeTheSameFrame() throws {
        let t = epochMs + 123456 * 1000 + 789
        let r1 = try Broadcast.resolve(channel, at: at(t))
        let r2 = try Broadcast.resolve(channel, at: Date(timeIntervalSince1970: t / 1000))
        #expect(r1.index == r2.index)
        #expect(r1.offsetSec == r2.offsetSec)
    }

    @Test func airingsBetweenListsFilmStartsInsideTheWindowOnly() {
        let airings = Broadcast.airingsBetween(channel, from: at(epochMs), to: at(epochMs + LOOP * 2 * 1000))
        #expect(airings.count == 4)
        #expect(airings.map(\.filmSlug) == ["a", "b", "a", "b"])
        #expect(Broadcast.ms(airings[0].start) == epochMs + 90 * 1000)
        #expect(Broadcast.ms(airings[2].start) == epochMs + (LOOP + 90) * 1000)
    }

    @Test func nextAiringFindsTheSoonestFutureStart() throws {
        let during = at(epochMs + (90 + 10) * 1000)
        let next = try #require(Broadcast.nextAiring(channel, film: "a", at: during))
        #expect(Broadcast.ms(next.start) == epochMs + (LOOP + 90) * 1000)
        let nb = try #require(Broadcast.nextAiring(channel, film: "b", at: during))
        #expect(Broadcast.ms(nb.start) == epochMs + (90 + 3600 + 90) * 1000)
    }

    @Test func upNextSkipsInterstitialsAndWraps() {
        let duringB = at(epochMs + (90 + 3600 + 90 + 10) * 1000)
        #expect(Broadcast.upNext(channel, at: duringB)?.filmSlug == "a")
    }

    @Test func channelsResolveIndependently() throws {
        var other = channel; other.epoch = "2026-07-01T00:30:00Z"
        let t = at(epochMs + 45 * 60 * 1000)
        let r1 = try Broadcast.resolve(channel, at: t)
        let r2 = try Broadcast.resolve(other, at: t)
        #expect(r1.offsetSec != r2.offsetSec)
    }

    @Test func emptyScheduleIsAnError() {
        let empty = Transmission(id: "x", name: "x", epoch: EPOCH, blocks: [])
        #expect(throws: BroadcastError.self) { try Broadcast.resolve(empty, at: .now) }
    }

    @Test func blocksRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(channel)
        let back = try JSONDecoder().decode(Transmission.self, from: data)
        #expect(back == channel)
    }
}
