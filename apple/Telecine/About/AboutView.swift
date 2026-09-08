//  AboutView.swift — why we broadcast this way.

import SwiftUI

struct AboutView: View {
    @Environment(Stations.self) private var stations
    var body: some View {
        Paper(title: "About the network", lede: "Telecine is a television network for films that belong to everyone.") {
            VStack(alignment: .leading, spacing: 18) {
                section("The idea", [
                    "Streaming solved access and, in the same motion, dissolved occasion. When everything is available always, nothing is on — and “what's on” was never a limitation. It was a shared clock. It meant that when you watched, you watched with people, even strangers, even alone in a dark room. The film started when it started. You arrived in the middle of things, or you planned your evening around it, and either way the watching was an event rather than a task from a queue.",
                    "Telecine brings that back, without asking anyone's permission, using the one catalogue that needs none: the public domain. Four channels run twenty-four hours a day. Every film is chosen by hand and played on a fixed rotation. There is no pause, no scrubbing, no autoplay of something an algorithm thinks resembles what you just saw. Whatever a channel is showing is what's on — for everyone on Earth, at the same frame, at the same moment.",
                ])
                section("How it works", [
                    "There is no broadcast server. Each channel is a Transmission: a small, open file that declares a starting instant and a loop of films and station breaks. This set reads the file, reads the clock, computes what is on and how far in, and seeks to that exact second of a public-domain print held by the Internet Archive. Two sets in two hemispheres perform the same arithmetic and land on the same frame. Synchrony without infrastructure — the schedule is the broadcast.",
                    "The format is documented and open. Publish a Transmission file and a player and you are a broadcaster; add its address under Channels and this set will tune it. We would genuinely like there to be more stations than ours.",
                ])
                section("The programming", [
                    "The public domain is often treated as a bargain bin. It is closer to a national gallery with the lights off: Sunrise is in there. His Girl Friday is in there. Night of the Living Dead is in there because of a clerical error, and Charade because of a defective copyright notice. What the catalogue lacks is not quality but curation — someone to turn the lights on, hang the pictures in an order that means something, and write the cards on the wall. That is the work here: four channels, each with a point of view, each film carrying programme notes on why it earned its slot.",
                    "No ratings, no thumbnails engineered for clicks, no infinite shelf. A rotation, not a library; an editor, not an engine.",
                ])
                section("The name", [
                    "A telecine is the machine that transfers motion-picture film to television — the bridge between the cinema and the living room. That is literally what this is: cinema's first century, carried across to the set in yours.",
                ])
                section("Colophon", [
                    "No accounts, no tracking, no analytics, no cookies. The set keeps one thing on this device: which channel you left it on. The films are served by the Internet Archive from public-domain prints; if this network gives you something, consider giving something to the Archive, which does the heavy lifting for the entire remembering-things industry.",
                ])
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel("This receiver")
                    MonoLabel("Schedule: \(stations.source.rawValue)\(stations.refreshedAt.map { " · refreshed \($0.formatted(date: .omitted, time: .shortened))" } ?? "")", style: .caption2, color: Ink.inkFaint)
                    MonoLabel("\(stations.network.channels.count) channels · \(stations.network.films.count) films · \(Int(stations.network.totalHours.rounded()))h of programming", style: .caption2, color: Ink.inkFaint)
                    if let e = stations.lastError { MonoLabel("Head-end: \(e)", style: .caption2, color: Ink.signalDeep) }
                }
                .padding(.top, 8)
                HStack(spacing: 16) {
                    Link("The Transmission format", destination: URL(string: "https://github.com/brunohart/telecine/blob/main/SPEC.md")!)
                    Link("Source", destination: URL(string: "https://github.com/brunohart/telecine")!)
                    Link("Give to the Archive", destination: URL(string: "https://archive.org/donate")!)
                }
                .font(Face.mono(.caption2)).foregroundStyle(Ink.inkSoft)
            }
            .frame(maxWidth: 620, alignment: .leading)
        }
    }
    private func section(_ title: String, _ paras: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Face.display(.title2, weight: .semibold)).foregroundStyle(Ink.ink).padding(.top, 10)
            ForEach(paras, id: \.self) { Text($0).font(Face.body(.body)).foregroundStyle(Ink.ink).lineSpacing(4) }
        }
    }
}
