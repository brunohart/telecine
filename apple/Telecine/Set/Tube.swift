//  Tube.swift — the picture tube: an AVPlayerLayer with no controls, because a broadcast has none.

import AVFoundation
import SwiftUI
import UIKit

struct Tube: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        v.isAccessibilityElement = false
        return v
    }
    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player { uiView.playerLayer.player = player }
    }
    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// The glass and everything that can appear on it: static, the station-break card, the lens.
struct ScreenFrame: View {
    @Environment(Receiver.self) private var receiver
    var theatre = false
    @State private var burstVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Tube(player: receiver.player)

            if receiver.powered, receiver.status == .tuning || receiver.status == .signalLost {
                NoiseOverlay(label: receiver.status == .signalLost ? "Signal lost · retrying" : "Tuning")
                    .transition(.opacity)
            }

            if receiver.powered, receiver.isBreak {
                StationBreakCard()
                    .transition(.opacity)
            }

            if !receiver.powered {
                Lens()
                    .transition(.opacity.animation(Motion.soft))
            }

            if burstVisible {
                Static().opacity(0.9).transition(.opacity)
            }

            if let notice = receiver.notice {
                VStack {
                    Spacer()
                    Text(notice)
                        .font(Face.body(.footnote)).italic()
                        .foregroundStyle(Ink.Room.ink)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(.bottom, 18)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // glass: one quiet reflection across the tube, and the vignette of a curved screen
            LinearGradient(stops: [.init(color: Ink.Room.ink.opacity(0.05), location: 0), .init(color: Ink.Room.ink.opacity(0.015), location: 0.22), .init(color: .clear, location: 0.38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: theatre ? 0 : 10)
                .strokeBorder(.black.opacity(0.0), lineWidth: 0)
                .background(RadialGradient(colors: [.clear, .black.opacity(theatre ? 0.25 : 0.55)], center: .center, startRadius: 0, endRadius: 600))
                .allowsHitTesting(false)
        }
        .background(.black)
        .animation(reduceMotion ? nil : Motion.soft, value: receiver.status)
        .animation(reduceMotion ? nil : Motion.soft, value: receiver.notice)
        .onChange(of: receiver.burst) { _, _ in
            guard !reduceMotion else { return }
            burstVisible = true
            Task { try? await Task.sleep(for: .milliseconds(340)); burstVisible = false }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLine)
    }

    private var accessibilityLine: String {
        guard receiver.powered else { return "The set is off. \(receiver.nowOnLine(receiver.channel))" }
        if let f = receiver.onAirFilm {
            return receiver.isBreak ? "Station break. Next: \(f.title)." : "On air: \(f.title), \(f.yearText), \(f.director ?? "")."
        }
        return "Tuning"
    }
}

struct NoiseOverlay: View {
    var label: String
    var body: some View {
        ZStack {
            Static()
            MonoLabel(label, style: .caption, color: Ink.Room.ink)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(.black.opacity(0.72))
        }
        .accessibilityLabel(label)
    }
}

/// The power knob and the invitation. The first play must live inside this press.
struct Lens: View {
    @Environment(Receiver.self) private var receiver
    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button { receiver.powerOn() } label: {
            VStack(spacing: 14) {
                Knob(turned: pressed)
                Text("Tune in")
                    .font(Face.display(.title2, weight: .semibold)).italic()
                    .foregroundStyle(Ink.Room.ink)
                MonoLabel(receiver.nowOnLine(receiver.channel), style: .caption2, color: Color(hex: 0xA39883))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RadialGradient(colors: [Color(hex: 0x1B2D4F).opacity(0.35), .black.opacity(0.88)], center: .center, startRadius: 0, endRadius: 520))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tune in. \(receiver.nowOnLine(receiver.channel))")
        .accessibilityHint("Switches the set on and joins the broadcast live.")
        #if os(iOS)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in if !reduceMotion { pressed = true } }.onEnded { _ in pressed = false })
        #endif
    }
}

/// Ridged bakelite, indicator at twelve.
struct Knob: View {
    var turned = false
    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(stops: Knob.ridges, center: .center))
                .overlay(Circle().stroke(Color(hex: 0x0D0A06), lineWidth: 3))
                .shadow(color: .black.opacity(0.7), radius: 6, y: 4)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x35291C), Color(hex: 0x1A1410)], center: .init(x: 0.38, y: 0.3), startRadius: 0, endRadius: 40))
                .padding(16)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
            RoundedRectangle(cornerRadius: 2)
                .fill(Ink.signal)
                .frame(width: 4, height: 16)
                .shadow(color: Ink.signal.opacity(0.7), radius: 4)
                .offset(y: -26)
        }
        .frame(width: 92, height: 92)
        .rotationEffect(.degrees(turned ? 38 : 0))
        .scaleEffect(turned ? 0.96 : 1)
        .animation(Motion.spring, value: turned)
        .accessibilityHidden(true)
    }
    static let ridges: [Gradient.Stop] = {
        var s: [Gradient.Stop] = []
        let n = 36
        for i in 0..<n {
            let a = Double(i) / Double(n), b = Double(i + 1) / Double(n)
            s.append(.init(color: Color(hex: 0x2E261D), location: a))
            s.append(.init(color: Color(hex: 0x2E261D), location: a + (b - a) * 0.4))
            s.append(.init(color: Color(hex: 0x171209), location: a + (b - a) * 0.6))
            s.append(.init(color: Color(hex: 0x171209), location: b))
        }
        return s
    }()
}

/// The station break: paper on the glass, the next transmission, a countdown that breathes.
struct StationBreakCard: View {
    @Environment(Receiver.self) private var receiver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    var body: some View {
        let film = receiver.onAirFilm
        VStack(spacing: 0) {
            ZStack {
                Bars(height: 14)
                Bars(height: 14).offset(x: 4, y: 3).opacity(0.3).blendMode(.multiply)
            }
            VStack(spacing: 8) {
                VStack(spacing: 8) {
                    Text(receiver.channel.displayNumber)
                        .font(Face.displayFixed(56))
                        .foregroundStyle(Ink.Room.cardInk)
                    Stamp(receiver.channel.name, color: Ink.Room.cardSoft, border: Color(hex: 0xB3A68A))
                }
                .padding(.bottom, 18)
                MonoLabel("Next transmission", color: Ink.Room.cardSoft)
                Text(film?.title ?? "—")
                    .font(Face.display(.title, weight: .semibold)).italic()
                    .foregroundStyle(Ink.Room.cardInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text([film?.yearText, film?.director].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Face.body(.subheadline))
                    .foregroundStyle(Ink.Room.cardSoft)
                Text(Clock.readout(receiver.countdown))
                    .font(Face.engraved(24))
                    .tracking(2)
                    .foregroundStyle(Ink.Room.cardInk)
                    .padding(.top, 14)
                    .opacity(breathe ? 0.55 : 1)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            Bars(height: 14)
        }
        .background(Ink.Room.cardPaper)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Station break on channel \(receiver.channel.displayNumber). Next transmission: \(film?.title ?? ""), in \(Clock.readout(receiver.countdown)).")
    }
}
