//  GuideView.swift — the next twenty-four hours, in your local time. Times are the same for
//  everyone; the clock is the schedule. Listings are typeset one by one.

import SwiftUI

struct GuideView: View {
    @Environment(Stations.self) private var stations
    @Environment(Receiver.self) private var receiver
    @Environment(Navigator.self) private var navigator

    var body: some View {
        Paper(title: "The Guide", lede: "The next twenty-four hours, in your local time. Times are the same for everyone; the clock is the schedule.") {
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 520), spacing: 36, alignment: .top)], alignment: .leading, spacing: 36) {
                    ForEach(Array(stations.channels.enumerated()), id: \.element.id) { i, ch in
                        GuideChannel(channel: ch, now: ctx.date).settle(i)
                    }
                }
            }
        }
    }
}

struct GuideChannel: View {
    @Environment(Stations.self) private var stations
    @Environment(Receiver.self) private var receiver
    @Environment(Navigator.self) private var navigator
    let channel: Transmission
    let now: Date

    struct Row: Identifiable {
        var start: Date; var film: Film; var onAir: Bool
        var id: String { "\(film.slug)-\(start.timeIntervalSince1970)" }
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if let r = try? Broadcast.resolve(channel, at: now), r.block.isFilm {
            rows.append(Row(start: r.blockStart, film: stations.film(for: r.block), onAir: true))
        }
        for a in Broadcast.airingsBetween(channel, from: now, to: now.addingTimeInterval(24 * 3600)) {
            rows.append(Row(start: a.start, film: stations.film(for: a.block), onAir: false))
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(channel.displayNumber).font(Face.displayFixed(32)).foregroundStyle(Ink.hue(channel.number))
                VStack(alignment: .leading, spacing: 2) {
                    NavigationLink(value: Route.channel(channel.id)) {
                        Text(channel.name).font(Face.display(.title3, weight: .semibold)).foregroundStyle(Ink.ink)
                    }
                    .buttonStyle(.plain)
                    if let t = channel.tagline { Text(t).font(Face.body(.footnote)).italic().foregroundStyle(Ink.inkSoft) }
                }
                Spacer(minLength: 0)
                Button { navigator.tune(to: channel.id, receiver: receiver) } label: {
                    Stamp("Tune in", color: Ink.signalDeep, border: Ink.signalDeep, tilt: 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tune in to channel \(channel.displayNumber)")
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2) }

            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                NavigationLink(value: Route.film(row.film.slug)) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.onAir ? "ON AIR" : Clock.guideTime(row.start, relativeTo: now))
                            .font(Face.mono(.caption2, weight: row.onAir ? .semibold : .medium))
                            .tracking(0.6)
                            .foregroundStyle(row.onAir ? Ink.live : Ink.inkSoft)
                            .frame(width: 84, alignment: .leading)
                            .monospacedDigit()
                        Text(row.film.title)
                            .font(Face.display(.callout, weight: .semibold))
                            .foregroundStyle(Ink.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        MonoLabel("\(row.film.yearText) · \(row.film.minutes) min", style: .caption2, color: Ink.inkFaint)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.vertical, 9)
                    .background(row.onAir ? LinearGradient(colors: [Ink.signal.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
                    .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .settle(i)
                .accessibilityLabel("\(row.onAir ? "On air now" : Clock.guideTime(row.start, relativeTo: now)): \(row.film.title), \(row.film.yearText), \(row.film.minutes) minutes")
            }
        }
    }
}
