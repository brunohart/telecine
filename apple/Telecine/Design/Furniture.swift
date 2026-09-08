//  Furniture.swift — the network's ornaments: test-card bars, the broken rule,
//  the misregistered wordmark, paper grain.

import SwiftUI
import CoreGraphics

/// The test-card bar strip — the network's signature ornament.
struct Bars: View {
    var height: CGFloat = 8
    var room = false
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array((room ? Ink.roomBars : Ink.bars).enumerated()), id: \.offset) { _, c in
                Rectangle().fill(c)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The stroke that ran out of ink.
struct BrokenRule: View {
    var color: Color = Ink.ink
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let runs: [(Double, Double)] = [(0, 0.31), (0.36, 0.63), (0.655, 0.86), (0.88, 1)]
            ZStack(alignment: .leading) {
                ForEach(Array(runs.enumerated()), id: \.offset) { _, r in
                    Rectangle().fill(color).frame(width: w * (r.1 - r.0), height: 2).offset(x: w * r.0)
                }
            }
        }
        .frame(height: 2)
        .opacity(0.85)
        .accessibilityHidden(true)
    }
}

/// The wordmark, with the ghost of a misregistered print pass behind it.
struct Wordmark: View {
    var size: CGFloat = 30
    var color: Color = Ink.ink
    var ghostOpacity: Double = 0.16
    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("TELECINE.")
                .font(Face.displayFixed(size))
                .foregroundStyle(Ink.signal.opacity(ghostOpacity))
                .offset(x: size * 0.045, y: size * 0.06)
                .accessibilityHidden(true)
            (Text("TELECINE").foregroundStyle(color) + Text(".").foregroundStyle(Ink.signal))
                .font(Face.displayFixed(size))
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityLabel("Telecine")
    }
}

/// Film grain, over everything, touching nothing.
struct Grain: View {
    var opacity: Double = 0.09
    var body: some View {
        Image(uiImage: Grain.tile)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.multiply)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea()
    }
    /// One tile of noise, drawn once. Deterministic, so every set has the same grain.
    static let tile: UIImage = {
        let n = 128
        var seed: UInt32 = 0x5EED_1234
        var bytes = [UInt8](repeating: 0, count: n * n)
        for i in 0..<(n * n) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            bytes[i] = UInt8(truncatingIfNeeded: seed >> 24)
        }
        let cs = CGColorSpaceCreateDeviceGray()
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let img = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: n, space: cs,
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                          decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return UIImage(cgImage: img)
    }()
}

/// Television static: the grain tile rolling in steps.
struct Static: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                let step = Int(ctx.date.timeIntervalSinceReferenceDate * 10) % 4
                Image(uiImage: Grain.tile)
                    .resizable(resizingMode: .tile)
                    .frame(width: geo.size.width + 320, height: geo.size.height + 320)
                    .offset(x: CGFloat(step * 37) - 60, y: CGFloat(-step * 53) + 80)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

/// A punched speaker grille.
struct Grille: View {
    var body: some View {
        Canvas { ctx, size in
            let pitch: CGFloat = 5
            let cols = Int(size.width / pitch), rows = Int(size.height / pitch)
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * pitch + 1.3, y: CGFloat(r) * pitch + 1.3, width: 2.4, height: 2.4)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.85)))
                }
            }
        }
        .background(LinearGradient(colors: [Color(hex: 0x221C14), Color(hex: 0x171209)], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityHidden(true)
    }
}
