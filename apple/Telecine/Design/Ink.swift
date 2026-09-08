//  Ink.swift — the inks. A printed broadcast programme from a station that never existed.
//  Paper pages follow the system appearance (paper by day, the dark room by night);
//  the set itself is always the dark room.

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    /// A dynamic colour: one ink by day, another in the dark.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            let h = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        })
    }
}

enum Ink {
    // paper & ink — dynamic
    static let paper      = Color(light: 0xF1EBDF, dark: 0x12100D)
    static let paperDeep  = Color(light: 0xE6DDC9, dark: 0x0B0A08)
    static let card       = Color(light: 0xFAF6EC, dark: 0x1B1814)
    static let ink        = Color(light: 0x1D1812, dark: 0xEDE5D4)
    static let inkSoft    = Color(light: 0x6F6555, dark: 0xA39883)
    static let inkFaint   = Color(light: 0x9C917E, dark: 0x6F6555)
    static let line       = Color(light: 0xD5CBB6, dark: 0x322C23)
    static let lineStrong = Color(light: 0xB3A68A, dark: 0x453D2F)

    // the signal — fixed
    static let signal     = Color(hex: 0xC24A1F)
    static let signalDeep = Color(hex: 0x9E3413)
    static let tube       = Color(hex: 0x1B2D4F)
    static let live       = Color(hex: 0xB23315)
    static let bottle     = Color(hex: 0x2F4A3A)
    static let brass      = Color(hex: 0xA3762A)

    /// The dark room: the set page always drops the lights.
    enum Room {
        static let paper     = Color(hex: 0x12100D)
        static let paperDeep = Color(hex: 0x0B0A08)
        static let card      = Color(hex: 0x1B1814)
        static let ink       = Color(hex: 0xEDE5D4)
        static let inkSoft   = Color(hex: 0xA39883)
        static let inkFaint  = Color(hex: 0x6F6555)
        static let line      = Color(hex: 0x322C23)
        // the cabinet
        static let walnutTop    = Color(hex: 0x2B2118)
        static let walnutMid    = Color(hex: 0x221A12)
        static let walnutBottom = Color(hex: 0x1B140D)
        static let walnutEdge   = Color(hex: 0x3D3325)
        static let bezel        = Color(hex: 0x0B0906)
        static let keyTop       = Color(hex: 0x2C251C)
        static let keyBottom    = Color(hex: 0x1E1913)
        static let keyEdge      = Color(hex: 0x3C3327)
        // the display window: readouts backlit behind dark glass
        static let displayGlass = Color(hex: 0x0C0906)
        static let displayDim   = Color(hex: 0xB98A54)
        static let displayLit   = Color(hex: 0xE3B079)
        static let plate        = Color(hex: 0x8D7D63)
        static let plateModel   = Color(hex: 0x6F6046)
        // the paper of the station-break card, which is always paper
        static let cardPaper    = Color(hex: 0xF1EBDF)
        static let cardInk      = Color(hex: 0x1D1812)
        static let cardSoft     = Color(hex: 0x6F6555)
    }

    /// Each channel's hue. CH 02 is ink on paper; in the dark room it burns white.
    static func hue(_ number: String?, room: Bool = false) -> Color {
        switch number {
        case "01": tube
        case "02": room ? Color(hex: 0xECE3D0) : Color(hex: 0x26211A)
        case "03": bottle
        case "04": signal
        default: brass
        }
    }
    static let bars: [Color] = [tube, signal, bottle, brass, signalDeep, ink]
    static let roomBars: [Color] = [tube, signal, bottle, brass, signalDeep, Color(hex: 0xEDE5D4)]
}
