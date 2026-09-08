//  OnAirWidget.swift — what's on, on the Home Screen and the Lock Screen.
//  The resolver makes the timeline trivial: one entry per block boundary, computed from the
//  same file the set reads. No network, no server, and the widget is never wrong about the time.

import SwiftUI
import WidgetKit

struct OnAirEntry: TimelineEntry {
    struct Line: Identifiable {
        var number: String; var name: String; var title: String; var isBreak: Bool; var ends: Date
        var id: String { number }
    }
    var date: Date
    var lines: [Line]
}

struct OnAirProvider: TimelineProvider {
    let network = Bundled.network()

    func placeholder(in context: Context) -> OnAirEntry { entry(at: .now) }
    func getSnapshot(in context: Context, completion: @escaping (OnAirEntry) -> Void) { completion(entry(at: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<OnAirEntry>) -> Void) {
        // every boundary across every channel for the next six hours, in order
        var instants: Set<Date> = [.now]
        let horizon = Date.now.addingTimeInterval(6 * 3600)
        for ch in network.channels {
            var t = Date.now
            while t < horizon, let r = try? Broadcast.resolve(ch, at: t) {
                instants.insert(r.blockEnd.addingTimeInterval(0.5))
                t = r.blockEnd.addingTimeInterval(1)
            }
        }
        let entries = instants.sorted().map(entry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> OnAirEntry {
        OnAirEntry(date: date, lines: network.channels.compactMap { ch in
            guard let r = try? Broadcast.resolve(ch, at: date) else { return nil }
            let film = network.films[r.block.filmSlug]
            return .init(number: ch.displayNumber, name: ch.name, title: film?.title ?? r.block.filmSlug, isBreak: !r.block.isFilm, ends: r.blockEnd)
        })
    }
}

struct OnAirWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OnAirEntry

    private let paper = Color(red: 0.945, green: 0.922, blue: 0.875)
    private let ink = Color(red: 0.114, green: 0.094, blue: 0.071)
    private let soft = Color(red: 0.435, green: 0.396, blue: 0.333)
    private let signal = Color(red: 0.761, green: 0.290, blue: 0.122)
    private let bars: [Color] = [Color(red: 0.106, green: 0.176, blue: 0.310), Color(red: 0.761, green: 0.290, blue: 0.122), Color(red: 0.184, green: 0.290, blue: 0.227), Color(red: 0.639, green: 0.463, blue: 0.165), Color(red: 0.620, green: 0.204, blue: 0.075), Color(red: 0.114, green: 0.094, blue: 0.071)]

    var body: some View {
        switch family {
        case .accessoryRectangular:
            if let l = entry.lines.first {
                VStack(alignment: .leading, spacing: 1) {
                    Text("CH \(l.number) · \(l.isBreak ? "BREAK" : "ON AIR")").font(.system(.caption2, design: .monospaced, weight: .semibold))
                    Text(l.title).font(.system(.headline, design: .serif)).lineLimit(2)
                }
                .widgetURL(URL(string: "telecine://ch/\(l.number)"))
            }
        case .accessoryInline:
            if let l = entry.lines.first { Text("CH \(l.number): \(l.title)") }
        case .systemSmall:
            if let l = entry.lines.first {
                VStack(alignment: .leading, spacing: 6) {
                    barStrip
                    Text("CH \(l.number)").font(.system(size: 30, weight: .black, design: .serif)).foregroundStyle(ink)
                    Text((l.isBreak ? "Next: " : "") + l.title).font(.system(.subheadline, design: .serif, weight: .semibold)).italic().foregroundStyle(ink).lineLimit(3)
                    Spacer(minLength: 0)
                    Text(l.isBreak ? "STATION BREAK" : "ON AIR · ENDS \(l.ends.formatted(date: .omitted, time: .shortened))").font(.system(.caption2, design: .monospaced)).foregroundStyle(l.isBreak ? soft : signal)
                }
                .widgetURL(URL(string: "telecine://ch/\(l.number)"))
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                barStrip
                ForEach(entry.lines) { l in
                    Link(destination: URL(string: "telecine://ch/\(l.number)")!) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(l.number).font(.system(size: 18, weight: .black, design: .serif)).foregroundStyle(ink).frame(width: 26, alignment: .leading)
                            Text(l.title).font(.system(.subheadline, design: .serif, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                            Spacer(minLength: 0)
                            Text(l.isBreak ? "BREAK" : l.ends.formatted(date: .omitted, time: .shortened)).font(.system(.caption2, design: .monospaced)).foregroundStyle(l.isBreak ? signal : soft)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var barStrip: some View {
        HStack(spacing: 0) { ForEach(Array(bars.enumerated()), id: \.offset) { _, c in Rectangle().fill(c) } }.frame(height: 5)
    }
}

struct OnAirWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "net.telecine.onair", provider: OnAirProvider()) { entry in
            OnAirWidgetView(entry: entry)
                .containerBackground(Color(red: 0.945, green: 0.922, blue: 0.875), for: .widget)
        }
        .configurationDisplayName("On Air")
        .description("What every channel is showing right now — same for everyone, everywhere.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct TelecineWidgetBundle: WidgetBundle {
    var body: some Widget { OnAirWidget() }
}
