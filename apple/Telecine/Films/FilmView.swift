//  FilmView.swift — the programme notes. A one-sheet, the facts, the note, and every name a door.

import SwiftUI

struct FilmView: View {
    @Environment(Stations.self) private var stations
    @Environment(Receiver.self) private var receiver
    @Environment(Navigator.self) private var navigator
    let slug: String

    var body: some View {
        if let film = stations.film(slug) {
            let graph = stations.graph.films[slug]
            let channel = stations.channel(for: film)
            Paper(title: film.title, lede: film.logline) {
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    let next = channel.flatMap { Broadcast.nextAiring($0, film: slug, at: ctx.date) }
                    let onAir = channel.flatMap { try? Broadcast.resolve($0, at: ctx.date) }.map { $0.block.isFilm && $0.block.filmSlug == slug } ?? false
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 36) {
                            OneSheet(url: graph?.poster, title: film.title).frame(width: 300)
                            details(film, graph, channel, next, onAir).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 26) {
                            OneSheet(url: graph?.poster, title: film.title).frame(maxWidth: 320)
                            details(film, graph, channel, next, onAir)
                        }
                    }
                }
            }
        } else {
            Paper(title: "Not on the schedule", lede: "That film is not on any channel this set can tune.") { EmptyView() }
        }
    }

    @ViewBuilder
    private func details(_ film: Film, _ graph: FilmGraph?, _ channel: Transmission?, _ next: Airing?, _ onAir: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                if let y = film.year { Stamp(String(y)) }
                Stamp("\(film.minutes) min")
                if let ch = channel { Stamp("CH \(ch.displayNumber)", color: Ink.hue(ch.number), border: Ink.hue(ch.number)) }
            }
            if let d = film.director { Text("Directed by \(d)").font(Face.body(.body)).italic().foregroundStyle(Ink.inkSoft) }

            // next transmission — the appointment
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(onAir ? "On air now" : "Next transmission", color: onAir ? Ink.live : Ink.inkSoft)
                if let ch = channel {
                    Button { navigator.tune(to: ch.id, receiver: receiver) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(onAir ? "Tune in" : next.map { Clock.guideTime($0.start) } ?? "—")
                                .font(Face.display(.title2, weight: .semibold)).italic().foregroundStyle(Ink.ink)
                            MonoLabel("CH \(ch.displayNumber) · \(ch.name)", style: .caption2, color: Ink.inkFaint)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Ink.card, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.lineStrong))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(onAir ? "On air now on channel \(ch.displayNumber). Tune in." : "Next transmission \(next.map { Clock.guideTime($0.start) } ?? "") on channel \(ch.displayNumber). Tune in.")
                }
            }

            if let note = film.note {
                VStack(alignment: .leading, spacing: 8) {
                    MonoLabel("Programme note")
                    Text(note).font(Face.body(.body)).foregroundStyle(Ink.ink).lineSpacing(4).frame(maxWidth: 620, alignment: .leading)
                }
            }

            if let g = graph {
                Credits(title: "Directed by", people: g.directors ?? [])
                Credits(title: "Photographed by", people: g.cinematography ?? [])
                Credits(title: "With", people: g.cast ?? [])
            }

            let threads = stations.graph.threads(for: slug)
            if !threads.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    MonoLabel("Editor's threads")
                    ForEach(threads) { t in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t.note).font(Face.body(.subheadline)).italic().foregroundStyle(Ink.ink).lineSpacing(3)
                            HStack(spacing: 8) {
                                ForEach(t.films.filter { $0 != slug }, id: \.self) { other in
                                    if let f = stations.film(other) {
                                        NavigationLink(value: Route.film(other)) { Stamp(f.title, color: Ink.signalDeep, border: Ink.signalDeep, tilt: 0) }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Ink.card, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Ink.line))
                    }
                }
            }

            if let item = film.itemUrl {
                Link(destination: item) {
                    MonoLabel("The print, at the Internet Archive ↗", style: .caption2, color: Ink.inkSoft)
                }
            }
        }
    }
}

/// The one-sheet: a poster pinned slightly off level, silkscreened onto the paper.
struct OneSheet: View {
    var url: URL?
    var title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Ink.paperDeep
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill().saturation(0.85).contrast(1.06)
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .clipped()
        .overlay(Rectangle().stroke(Ink.lineStrong, lineWidth: 1))
        .padding(6)
        .background(Ink.card)
        .overlay(Rectangle().stroke(Ink.line, lineWidth: 1))
        .background(Rectangle().fill(Ink.tube.opacity(0.18)).offset(x: 6, y: 6))
        .rotationEffect(.degrees(reduceMotion ? 0 : -0.6))
        .accessibilityLabel("Poster for \(title)")
    }
    private var placeholder: some View {
        VStack(spacing: 10) {
            Bars(height: 10).frame(width: 120)
            Text(title).font(Face.display(.title3, weight: .semibold)).italic().foregroundStyle(Ink.inkSoft).multilineTextAlignment(.center).padding(.horizontal, 12)
        }
    }
}

struct Credits: View {
    var title: String
    var people: [Credit]
    var body: some View {
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(title)
                FlowLayout(spacing: 8) {
                    ForEach(people) { p in
                        NavigationLink(value: Route.person(p.slug)) {
                            Text(p.name).font(Face.body(.subheadline)).foregroundStyle(Ink.ink)
                                .underline(true, color: Ink.lineStrong)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// Names laid out like a credit block — wrapping, not columns.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing * 2; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing * 2; rowH = max(rowH, sz.height)
        }
    }
}

struct PersonView: View {
    @Environment(Stations.self) private var stations
    let slug: String
    var body: some View {
        if let p = stations.graph.people[slug] {
            Paper(title: p.name, lede: p.description) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 36) {
                        Portrait(url: p.image, name: p.name).frame(width: 220)
                        credits(p).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 24) {
                        Portrait(url: p.image, name: p.name).frame(maxWidth: 240)
                        credits(p)
                    }
                }
            }
        } else {
            Paper(title: "Uncredited", lede: "No page for that name.") { EmptyView() }
        }
    }
    private func credits(_ p: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel("On the network")
            ForEach(Array((p.credits ?? []).enumerated()), id: \.offset) { i, c in
                if let f = stations.film(c.film) {
                    NavigationLink(value: Route.film(f.slug)) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(f.title).font(Face.display(.callout, weight: .semibold)).foregroundStyle(Ink.ink)
                            Spacer()
                            MonoLabel("\(c.role) · \(f.yearText)", style: .caption2, color: Ink.inkFaint)
                        }
                        .padding(.vertical, 9)
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

struct Portrait: View {
    var url: URL?
    var name: String
    var body: some View {
        OneSheet(url: url, title: name)
    }
}
