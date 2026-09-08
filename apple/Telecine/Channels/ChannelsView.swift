//  ChannelsView.swift — the four channels, and any station you have added.

import SwiftUI

struct ChannelsView: View {
    @Environment(Stations.self) private var stations
    @Environment(Receiver.self) private var receiver
    @Environment(Navigator.self) private var navigator
    @State private var adding = false

    var body: some View {
        Paper(title: "Channels", lede: "Four channels, each with a point of view. Every film chosen by hand, every rotation written to mean something.") {
            VStack(alignment: .leading, spacing: 28) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 520), spacing: 20, alignment: .top)], spacing: 20) {
                    ForEach(Array(stations.network.channels.enumerated()), id: \.element.id) { i, ch in
                        ChannelCard(channel: ch).settle(i)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Other stations").font(Face.display(.title2, weight: .semibold)).foregroundStyle(Ink.ink)
                        Spacer()
                        Button { adding = true } label: { Stamp("Add a station", color: Ink.signalDeep, border: Ink.signalDeep, tilt: 0) }
                            .buttonStyle(.plain)
                    }
                    Text("A Transmission is an open file. Anyone who publishes one — a cinema, a festival, a film society, a person with a point of view — is a broadcaster, and this set can tune them.")
                        .font(Face.body(.subheadline)).foregroundStyle(Ink.inkSoft).frame(maxWidth: 620, alignment: .leading)
                    if stations.affiliates.isEmpty {
                        MonoLabel("No stations added yet", style: .caption2, color: Ink.inkFaint).padding(.top, 4)
                    } else {
                        ForEach(stations.affiliates) { a in
                            ForEach(a.network.channels) { ch in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(ch.displayNumber).font(Face.displayFixed(22)).foregroundStyle(Ink.brass)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ch.name).font(Face.display(.headline)).foregroundStyle(Ink.ink)
                                        MonoLabel(a.url.host() ?? a.url.absoluteString, style: .caption2, color: Ink.inkFaint)
                                    }
                                    Spacer()
                                    Button { navigator.tune(to: ch.id, receiver: receiver) } label: { Stamp("Tune in", color: Ink.signalDeep, border: Ink.signalDeep, tilt: 0) }.buttonStyle(.plain)
                                    Button(role: .destructive) { stations.remove(a) } label: { Image(systemName: "minus.circle").foregroundStyle(Ink.inkFaint) }
                                        .buttonStyle(.plain).accessibilityLabel("Remove station \(ch.name)")
                                }
                                .padding(.vertical, 8)
                                .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $adding) { AddStationView() }
    }
}

struct ChannelCard: View {
    @Environment(Stations.self) private var stations
    @Environment(Receiver.self) private var receiver
    let channel: Transmission
    var body: some View {
        NavigationLink(value: Route.channel(channel.id)) {
            VStack(alignment: .leading, spacing: 10) {
                Rectangle().fill(Ink.hue(channel.number)).frame(height: 6)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(channel.displayNumber).font(Face.displayFixed(36)).foregroundStyle(Ink.hue(channel.number))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.name).font(Face.display(.title3, weight: .semibold)).foregroundStyle(Ink.ink)
                        if let t = channel.tagline { Text(t).font(Face.body(.footnote)).italic().foregroundStyle(Ink.inkSoft) }
                    }
                }
                if let d = channel.description {
                    Text(d).font(Face.body(.subheadline)).foregroundStyle(Ink.inkSoft).lineLimit(4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    MonoLabel("\(channel.blocks.filter(\.isFilm).count) films · \(Int((Broadcast.loopDuration(channel) / 3600).rounded()))h rotation", style: .caption2, color: Ink.inkFaint)
                    MonoLabel(receiver.nowOnLine(channel), style: .caption2, color: Ink.inkFaint).lineLimit(1)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.card)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChannelView: View {
    @Environment(Stations.self) private var stations
    @Environment(Receiver.self) private var receiver
    @Environment(Navigator.self) private var navigator
    let id: String

    var body: some View {
        if let ch = stations.channel(id) {
            Paper(title: "CH \(ch.displayNumber) · \(ch.name)", lede: ch.tagline) {
                VStack(alignment: .leading, spacing: 24) {
                    if let d = ch.description {
                        Text(d).font(Face.body(.body)).foregroundStyle(Ink.ink).frame(maxWidth: 620, alignment: .leading)
                    }
                    Button { navigator.tune(to: ch.id, receiver: receiver) } label: {
                        HStack(spacing: 10) {
                            Circle().fill(Ink.live).frame(width: 8, height: 8)
                            Text("Tune in now").font(Face.display(.headline)).italic()
                            MonoLabel(receiver.nowOnLine(ch), style: .caption2, color: Ink.inkSoft).lineLimit(1)
                        }
                        .foregroundStyle(Ink.ink)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Ink.card, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.lineStrong))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack { MonoLabel("The rotation"); Spacer(); MonoLabel("Next transmission") }
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }
                        TimelineView(.periodic(from: .now, by: 30)) { ctx in
                            ForEach(Array(ch.blocks.filter(\.isFilm).enumerated()), id: \.offset) { i, b in
                                let film = stations.film(for: b)
                                let next = Broadcast.nextAiring(ch, film: b.filmSlug, at: ctx.date)
                                let onAir = (try? Broadcast.resolve(ch, at: ctx.date)).map { $0.block == b } ?? false
                                NavigationLink(value: Route.film(film.slug)) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(film.title).font(Face.display(.callout, weight: .semibold)).foregroundStyle(Ink.ink)
                                            MonoLabel("\(film.yearText) · \(film.director ?? "") · \(film.minutes) min", style: .caption2, color: Ink.inkFaint)
                                        }
                                        Spacer()
                                        Text(onAir ? "ON AIR" : next.map { Clock.guideTime($0.start, relativeTo: ctx.date) } ?? "—")
                                            .font(Face.mono(.caption2)).tracking(0.6)
                                            .foregroundStyle(onAir ? Ink.live : Ink.inkSoft)
                                    }
                                    .padding(.vertical, 10)
                                    .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .settle(i)
                            }
                        }
                    }
                }
            }
        } else {
            Paper(title: "Off air", lede: "That channel is not on this set.") { EmptyView() }
        }
    }
}
