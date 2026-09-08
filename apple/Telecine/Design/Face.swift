//  Face.swift — the faces. Letterpress serif for display and body, mono for numerals and labels.
//  New York and SF Mono are the platform's own; the site sets Fraunces and IBM Plex Mono.
//  Every face scales with Dynamic Type.

import SwiftUI

enum Face {
    static func display(_ style: Font.TextStyle = .title, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }
    static func body(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .serif)
    }
    static func mono(_ style: Font.TextStyle = .caption, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
    /// Fixed-size faces for the set's fascia, where the readouts are engraved and do not scale.
    static func engraved(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func displayFixed(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// A mono label: uppercase, wide-tracked — a labelling system, not decoration.
struct MonoLabel: View {
    var text: String
    var style: Font.TextStyle = .caption2
    var color: Color = Ink.inkSoft
    init(_ text: String, style: Font.TextStyle = .caption2, color: Color = Ink.inkSoft) {
        self.text = text; self.style = style; self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(Face.mono(style))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

/// An archival stamp — thin border, not pressed quite level.
struct Stamp: View {
    var text: String
    var color: Color = Ink.inkSoft
    var border: Color = Ink.lineStrong
    var tilt: Double = -0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(_ text: String, color: Color = Ink.inkSoft, border: Color = Ink.lineStrong, tilt: Double = -0.8) {
        self.text = text; self.color = color; self.border = border; self.tilt = tilt
    }
    var body: some View {
        Text(text.uppercased())
            .font(Face.mono(.caption2))
            .tracking(1.8)
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(border, lineWidth: 1))
            .rotationEffect(.degrees(reduceMotion ? 0 : tilt))
            .accessibilityLabel(text)
    }
}
