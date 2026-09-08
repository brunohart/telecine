//  Fascia.swift — the set's front panel: the display window, the tuning slit, the keys,
//  the preset dial, and the maker's plate. Everything you press has travel.

import SwiftUI

/// The display window: readouts backlit behind dark glass.
struct Chyron: View {
    @Environment(Receiver.self) private var receiver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false
    @State private var pulse = false
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                MonoLabel("CH \(receiver.channel.displayNumber) · \(receiver.channel.name)", style: .caption2, color: Ink.Room.displayDim)
                    .lineLimit(1)
                if !compact { onAirLine.frame(maxWidth: .infinity) }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFF8F6A), Ink.live, Color(hex: 0x6D1C0A)], center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 6))
                        .frame(width: 10, height: 10)
                        .shadow(color: Ink.live.opacity(0.6), radius: 4)
                        .opacity(pulse ? 0.45 : 1)
                    MonoLabel("Live", style: .caption2, color: Ink.Room.displayDim)
                }
                .accessibilityHidden(true)
            }
            if compact { onAirLine }
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 9)
        .background(LinearGradient(colors: [Ink.Room.displayGlass, Color(hex: 0x131009)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Ink.hue(receiver.channel.number, room: true))
                .frame(height: 2)
                .scaleEffect(x: sweep ? 1 : 0, y: 1, anchor: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: 0x060402)))
        .onChange(of: receiver.swap) { _, _ in
            sweep = false
            withAnimation(reduceMotion ? nil : Motion.soft) { sweep = true }
        }
        .onAppear {
            sweep = true
            if !reduceMotion { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } }
        }
        .accessibilityElement(children: .combine)
    }

    private var onAirLine: some View {
        Group {
            if !receiver.powered {
                Text("The set is off.")
            } else if receiver.isBreak {
                Text("Station break")
            } else if let f = receiver.onAirFilm {
                (Text(f.title).italic() + Text(" \(f.year.map { "(\($0))" } ?? "")\(f.director.map { " · \($0)" } ?? "")"))
            } else {
                Text("Tuning")
            }
        }
        .font(Face.body(.subheadline))
        .foregroundStyle(Ink.Room.displayLit)
        .shadow(color: Color(hex: 0xE0A35C).opacity(0.35), radius: 6)
        .lineLimit(2)
        .multilineTextAlignment(compact ? .leading : .center)
        .id(receiver.swap)
        .transition(.asymmetric(insertion: .offset(y: 8).combined(with: .opacity), removal: .opacity))
    }
}

/// The tuning slit: a groove in the fascia with a lit filament.
struct Strip: View {
    @Environment(Receiver.self) private var receiver
    var body: some View {
        HStack(spacing: 12) {
            readout(receiver.powered ? Clock.readout(receiver.elapsed) : "00:00")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x120E09))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color(hex: 0xE06A35), Ink.signal], startPoint: .top, endPoint: .bottom))
                        .frame(width: max(0, (geo.size.width - 2) * (receiver.powered ? receiver.progress : 0)))
                        .shadow(color: Ink.signal.opacity(0.55), radius: 3)
                        .padding(1)
                        .animation(.linear(duration: 0.5), value: receiver.progress)
                }
            }
            .frame(height: 5)
            readout(Clock.readout(receiver.total))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(receiver.powered ? "\(Clock.readout(receiver.elapsed)) of \(Clock.readout(receiver.total))" : "Off")
    }
    private func readout(_ s: String) -> some View {
        Text(s).font(Face.engraved(11)).tracking(1).foregroundStyle(Ink.Room.displayDim).monospacedDigit()
    }
}

/// A physical key with travel.
struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Face.engraved(11))
            .tracking(1.4)
            .textCase(.uppercase)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(configuration.isPressed ? Ink.Room.ink : Ink.Room.inkSoft)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(LinearGradient(colors: [Ink.Room.keyTop, Ink.Room.keyBottom], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Ink.Room.keyEdge))
            .shadow(color: .black.opacity(configuration.isPressed ? 0 : 0.55), radius: 0, y: configuration.isPressed ? 0 : 2)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(Motion.key, value: configuration.isPressed)
    }
}

/// Up next, sound, fullscreen.
struct Deck: View {
    @Environment(Receiver.self) private var receiver
    var onFullscreen: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            if let n = receiver.upNext, receiver.powered, !receiver.isBreak {
                MonoLabel("Up next: \(n.title)\(n.year.map { " (\($0))" } ?? "")", style: .caption2, color: Ink.Room.inkSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button(receiver.muted ? "Sound off" : "Sound on") { receiver.toggleSound() }
                    .accessibilityLabel(receiver.muted ? "Sound is off" : "Sound is on")
                    .accessibilityHint("Toggles sound")
                Button("Fullscreen", action: onFullscreen)
            }
            .buttonStyle(KeyStyle())
        }
        .frame(minHeight: 32)
    }
}

/// The maker's plate — the one place the ghost belongs on the product — and the grille.
struct PlateRow: View {
    @Environment(Licence.self) private var licence
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Wordmark(size: 12.5, color: Ink.Room.plate, ghostOpacity: 0.5)
                HStack(spacing: 0) {
                    ForEach(Array(Ink.roomBars.enumerated()), id: \.offset) { _, c in Rectangle().fill(c) }
                }
                .frame(width: 42, height: 7)
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .accessibilityHidden(true)
                ViewThatFits {
                    MonoLabel(licence.isHeld ? "Model 001 · Licensed receiver" : "Model 001 · Public broadcast receiver", style: .caption2, color: Ink.Room.plateModel)
                        .lineLimit(1)
                        .fixedSize()
                    MonoLabel("Model 001", style: .caption2, color: Ink.Room.plateModel)
                        .fixedSize()
                    EmptyView()
                }
            }
            Spacer(minLength: 0)
            Grille().frame(width: 130, height: 20)
        }
        .padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.55)).frame(height: 1) }
    }
}

/// A preset key on the set. Press one to feel the travel.
struct DialKey: View {
    let channel: Transmission
    let selected: Bool
    let nowLine: String
    let affiliate: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text(channel.displayNumber)
                    .font(Face.displayFixed(26))
                    .foregroundStyle(Ink.Room.ink)
                    .frame(minWidth: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(channel.name).font(Face.display(.headline, weight: .semibold)).foregroundStyle(Ink.Room.ink)
                        if affiliate { Stamp("Affiliate", color: Ink.Room.inkFaint, border: Ink.Room.line, tilt: 0) }
                    }
                    if let t = channel.tagline {
                        Text(t).font(Face.body(.footnote)).italic().foregroundStyle(Ink.Room.inkSoft)
                    }
                    MonoLabel(nowLine, style: .caption2, color: Ink.Room.inkFaint)
                        .lineLimit(2)
                        .padding(.top, 3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [selected ? Color(hex: 0x161209) : Color(hex: 0x241E16), selected ? Color(hex: 0x1D1710) : Color(hex: 0x1A1510)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .leading) {
                if selected { Rectangle().fill(Ink.hue(channel.number, room: true)).frame(width: 3) }
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(selected ? Ink.hue(channel.number, room: true) : Color(hex: 0x2C251C))
                    .frame(width: 7, height: 7)
                    .shadow(color: selected ? Ink.hue(channel.number, room: true).opacity(0.65) : .clear, radius: 4)
                    .padding(14)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: 0x362D22)))
            .shadow(color: .black.opacity(selected ? 0.2 : 0.5), radius: 0, y: selected ? 1 : 3)
            .offset(y: selected ? 2 : 0)
            .animation(Motion.key, value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Channel \(channel.displayNumber), \(channel.name). \(nowLine)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// The dial: every station this set can tune.
struct Dial: View {
    @Environment(Receiver.self) private var receiver
    @Environment(Stations.self) private var stations
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(receiver.channels.enumerated()), id: \.element.id) { i, ch in
                DialKey(channel: ch, selected: ch.id == receiver.channel.id, nowLine: receiver.nowOnLine(ch), affiliate: stations.isAffiliate(ch)) {
                    receiver.setChannel(ch.id)
                }
                .settle(i)
            }
            Text("There is no pause and no play-from-the-start. Whatever a channel is showing, that is what's on — for everyone, everywhere, at this same minute.")
                .font(Face.body(.footnote))
                .foregroundStyle(Ink.Room.inkSoft)
                .padding(.top, 6)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: receiver.channel.id)
    }
}
