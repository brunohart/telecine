//  ParityTests.swift — two implementations, one network.
//
//  scripts/parity-fixture.mjs runs the reference resolver (src/lib/broadcast.js) over the
//  real network and freezes its answers. This suite proves the Swift engine agrees with
//  every one of them: same block, same offset, same boundaries, same up-next, same airings.
//  Two receivers that disagree about what is on are not one network.

import Foundation
import Testing
@testable import Telecine

private struct Fixture: Decodable {
    struct Case: Decodable {
        var channel: String; var atMs: Double
        var index: Int; var offsetSec: Double
        var blockStartMs: Double; var blockEndMs: Double; var loopSec: Double
        var upNext: String?; var nextAiringOfFirstFilm: Double?
    }
    struct Window: Decodable {
        struct A: Decodable { var film: String; var index: Int; var startMs: Double; var endMs: Double }
        var channel: String; var fromMs: Double; var toMs: Double; var airings: [A]
    }
    var networkGeneratedAt: String?
    var cases: [Case]
    var windows: [Window]
}

@Suite("Parity with the reference resolver")
struct ParityTests {
    private func fixture() throws -> Fixture {
        let url = try #require(Bundle(for: Marker.self).url(forResource: "parity", withExtension: "json"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
    private final class Marker {}

    @Test func fixtureWasCutFromTheBundledNetwork() throws {
        let f = try fixture()
        let network = Bundled.network()
        #expect(f.networkGeneratedAt == network.generatedAt, "regenerate: node scripts/parity-fixture.mjs")
    }

    @Test func everyResolutionMatches() throws {
        let f = try fixture()
        let network = Bundled.network()
        #expect(f.cases.count > 300)
        for c in f.cases {
            let ch = try #require(network.channel(c.channel))
            let r = try Broadcast.resolve(ch, at: Date(timeIntervalSince1970: c.atMs / 1000))
            #expect(r.index == c.index, "\(c.channel) @\(c.atMs) index")
            #expect(abs(r.offsetSec - c.offsetSec) < 1e-6, "\(c.channel) @\(c.atMs) offset \(r.offsetSec) vs \(c.offsetSec)")
            #expect(Broadcast.ms(r.blockStart) == c.blockStartMs, "\(c.channel) @\(c.atMs) start")
            #expect(Broadcast.ms(r.blockEnd) == c.blockEndMs, "\(c.channel) @\(c.atMs) end")
            #expect(r.loopSec == c.loopSec)
            #expect(Broadcast.upNext(ch, at: Date(timeIntervalSince1970: c.atMs / 1000))?.filmSlug == c.upNext)
            let first = try #require(ch.blocks.first { $0.isFilm }).filmSlug
            let na = Broadcast.nextAiring(ch, film: first, at: Date(timeIntervalSince1970: c.atMs / 1000)).map { Broadcast.ms($0.start) }
            #expect(na == c.nextAiringOfFirstFilm, "\(c.channel) @\(c.atMs) nextAiring")
        }
    }

    @Test func everyWindowMatches() throws {
        let f = try fixture()
        let network = Bundled.network()
        for w in f.windows {
            let ch = try #require(network.channel(w.channel))
            let got = Broadcast.airingsBetween(ch, from: Date(timeIntervalSince1970: w.fromMs / 1000), to: Date(timeIntervalSince1970: w.toMs / 1000))
            #expect(got.count == w.airings.count, "\(w.channel) window count")
            for (g, e) in zip(got, w.airings) {
                #expect(g.filmSlug == e.film); #expect(g.index == e.index)
                #expect(Broadcast.ms(g.start) == e.startMs); #expect(Broadcast.ms(g.end) == e.endMs)
            }
        }
    }

    @Test func theBundledNetworkIsWhole() {
        let n = Bundled.network()
        #expect(n.channels.count == 4)
        #expect(n.films.count == 30)
        for ch in n.channels {
            #expect(ch.transmission == "0.1")
            #expect(Broadcast.loopDuration(ch) > 0)
            for b in ch.blocks { #expect(n.films[b.filmSlug] != nil, "\(ch.id) schedules unknown film \(b.filmSlug)") }
        }
        let g = Bundled.graph()
        #expect(g.people.count > 200)
        #expect(g.threads.count == 20)
    }
}
