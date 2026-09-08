//  Motion.swift — one spring family, tuned by feel. Elements have mass; they overshoot once and settle.

import SwiftUI

enum Motion {
    /// The rubber stamp pressed too hard, bouncing back.
    static let spring = Animation.spring(response: 0.55, dampingFraction: 0.62)
    /// The brush stroke: directional, settles without much bounce.
    static let soft = Animation.spring(response: 0.6, dampingFraction: 0.82)
    /// A key with travel. High-frequency; must not linger.
    static let key = Animation.spring(response: 0.16, dampingFraction: 0.75)
    /// Objects placed on the table one by one.
    static func settle(_ index: Int, every: Double = 0.07) -> Animation {
        spring.delay(Double(index) * every)
    }
}

/// Settle choreography: appears by rising into place, staggered by index.
struct Settle: ViewModifier {
    var index: Int
    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(settled || reduceMotion ? 1 : 0)
            .offset(y: settled || reduceMotion ? 0 : 10)
            .onAppear {
                guard !settled else { return }
                withAnimation(Motion.settle(index)) { settled = true }
            }
    }
}
extension View {
    func settle(_ index: Int) -> some View { modifier(Settle(index: index)) }
}
