// make-icon.swift — the app icon: the set itself. A walnut cabinet, a curved-glass tube warming up
// with the test card on it, the backlit display window, the ridged power knob, the speaker grille.
// Run: swift scripts/make-icon.swift <out.png> [dark]
import AppKit
import CoreGraphics

let out = CommandLine.arguments[1]
let dark = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "dark"
let S: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor { CGColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: a) }
func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil) }
func fill(_ p: CGPath, _ color: CGColor) { ctx.addPath(p); ctx.setFillColor(color); ctx.fillPath() }
func stroke(_ p: CGPath, _ color: CGColor, _ w: CGFloat) { ctx.addPath(p); ctx.setStrokeColor(color); ctx.setLineWidth(w); ctx.strokePath() }
func linear(_ p: CGPath, _ stops: [(UInt32, CGFloat)], from: CGPoint, to: CGPoint) {
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops.map { c($0.0) } as CFArray, locations: stops.map { $0.1 })!
    ctx.drawLinearGradient(g, start: from, end: to, options: []); ctx.restoreGState()
}
func radial(_ p: CGPath, _ stops: [(CGColor, CGFloat)], center: CGPoint, radius: CGFloat) {
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops.map { $0.0 } as CFArray, locations: stops.map { $0.1 })!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation]); ctx.restoreGState()
}
// CoreGraphics y is up; think in "top" coordinates and flip
func Y(_ top: CGFloat) -> CGFloat { S - top }
func rect(x: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat) -> CGRect { CGRect(x: x, y: Y(top + h), width: w, height: h) }

// the room
fill(CGPath(rect: CGRect(x: 0, y: 0, width: S, height: S), transform: nil), c(dark ? 0x0B0A08 : 0x12100D))
var rng = SystemRandomNumberGenerator()
for _ in 0..<50000 {
    let x = CGFloat.random(in: 0..<S, using: &rng), y = CGFloat.random(in: 0..<S, using: &rng)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.035)); ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
}
// the room glow behind the set when it is on
radial(CGPath(rect: CGRect(x: 0, y: 0, width: S, height: S), transform: nil), [(c(0xEDE5D4, 0.10), 0), (c(0xEDE5D4, 0), 1)], center: CGPoint(x: S / 2, y: Y(430)), radius: 600)

// the cabinet
let cab = rect(x: 92, top: 112, w: 840, h: 800)
ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -28), blur: 60, color: c(0x000000, 0.85))
fill(rr(cab, 56), c(0x221A12)); ctx.restoreGState()
linear(rr(cab, 56), [(0x2B2118, 0), (0x221A12, 0.55), (0x1B140D, 1)], from: CGPoint(x: 0, y: cab.maxY), to: CGPoint(x: 0, y: cab.minY))
stroke(rr(cab.insetBy(dx: 1.5, dy: 1.5), 55), c(0x3D3325), 3)
stroke(rr(cab.insetBy(dx: 6, dy: 6), 51), c(0xEDE5D4, 0.06), 2)

// the bezel and the tube
let bezel = rect(x: 140, top: 160, w: 744, h: 560)
fill(rr(bezel, 44), c(0x0B0906))
let glass = bezel.insetBy(dx: 22, dy: 22)
let tube = rr(glass, 30)
fill(tube, c(0x000000))
// the tube warming: deep blue glow with the test card on it
radial(tube, [(c(0x1B2D4F, 0.9), 0), (c(0x0A1224, 1), 0.6), (c(0x000000, 1), 1)], center: CGPoint(x: glass.midX, y: glass.midY + 20), radius: 520)
// the test card: six bars low on the tube, slightly misregistered
let bars: [UInt32] = [0x1B2D4F, 0xC24A1F, 0x2F4A3A, 0xA3762A, 0x9E3413, 0xEDE5D4]
ctx.saveGState(); ctx.addPath(tube); ctx.clip()
let bw = glass.width / CGFloat(bars.count)
for (i, h) in bars.enumerated() {
    ctx.setFillColor(c(h, 0.35)); ctx.fill(rect(x: glass.minX + CGFloat(i) * bw + 6, top: 560 - 6, w: bw + 1, h: 120))
    ctx.setFillColor(c(h)); ctx.fill(rect(x: glass.minX + CGFloat(i) * bw, top: 560, w: bw + 1, h: 120))
}
// the vignette of a curved screen, and one quiet reflection
radial(tube, [(c(0x000000, 0), 0), (c(0x000000, 0), 0.55), (c(0x000000, 0.55), 1)], center: CGPoint(x: glass.midX, y: glass.midY), radius: 460)
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(tube); ctx.clip()
let refl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(0xEDE5D4, 0.10), c(0xEDE5D4, 0.02), c(0xEDE5D4, 0)] as CFArray, locations: [0, 0.22, 0.4])!
ctx.drawLinearGradient(refl, start: CGPoint(x: glass.minX, y: glass.maxY), end: CGPoint(x: glass.maxX, y: glass.minY), options: [])
ctx.restoreGState()
stroke(rr(glass.insetBy(dx: 1, dy: 1), 29), c(0xEDE5D4, 0.06), 2)

// the display window: readouts behind dark glass, with the accent bar lit
let win = rect(x: 140, top: 748, w: 744, h: 64)
fill(rr(win, 12), c(0x0C0906))
stroke(rr(win, 12), c(0x060402), 2)
ctx.setFillColor(c(0x1B2D4F)); ctx.fill(rect(x: 152, top: 750, w: 720, h: 5))
// CH 01 · ● LIVE — as engraved marks, not text
ctx.setFillColor(c(0xE3B079)); ctx.fill(rect(x: 168, top: 774, w: 150, h: 12))
ctx.setFillColor(c(0xB98A54, 0.8)); ctx.fill(rect(x: 334, top: 774, w: 220, h: 12))
ctx.setFillColor(c(0xB23315)); ctx.fillEllipse(in: rect(x: 776, top: 771, w: 18, h: 18))
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 14, color: c(0xB23315, 0.9)); ctx.fillEllipse(in: rect(x: 776, top: 771, w: 18, h: 18)); ctx.restoreGState()
ctx.setFillColor(c(0xB98A54)); ctx.fill(rect(x: 808, top: 774, w: 56, h: 12))

// the power knob: ridged bakelite, indicator at twelve
let kc = CGPoint(x: 220, y: Y(868))
let kr: CGFloat = 44
ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: c(0x000000, 0.8))
fill(CGPath(ellipseIn: CGRect(x: kc.x - kr, y: kc.y - kr, width: kr * 2, height: kr * 2), transform: nil), c(0x171209)); ctx.restoreGState()
for i in 0..<36 {
    let a = CGFloat(i) / 36 * .pi * 2
    ctx.setFillColor(c(i % 2 == 0 ? 0x2E261D : 0x171209))
    ctx.move(to: kc)
    ctx.addArc(center: kc, radius: kr, startAngle: a, endAngle: a + .pi * 2 / 36, clockwise: false)
    ctx.closePath(); ctx.fillPath()
}
radial(CGPath(ellipseIn: CGRect(x: kc.x - 26, y: kc.y - 26, width: 52, height: 52), transform: nil), [(c(0x35291C), 0), (c(0x1A1410), 1)], center: CGPoint(x: kc.x - 6, y: kc.y + 8), radius: 30)
stroke(CGPath(ellipseIn: CGRect(x: kc.x - kr, y: kc.y - kr, width: kr * 2, height: kr * 2), transform: nil), c(0x0D0A06), 3)
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 8, color: c(0xC24A1F, 0.8))
fill(rr(CGRect(x: kc.x - 3, y: kc.y + 14, width: 6, height: 20), 3), c(0xC24A1F)); ctx.restoreGState()

// two keys with travel
for (i, x) in [292, 372].enumerated() {
    let k = rect(x: CGFloat(x), top: 846, w: 64, h: 44)
    fill(rr(k.offsetBy(dx: 0, dy: -4), 9), c(0x000000, 0.55))
    linear(rr(k, 9), [(0x2C251C, 0), (0x1E1913, 1)], from: CGPoint(x: 0, y: k.maxY), to: CGPoint(x: 0, y: k.minY))
    stroke(rr(k, 9), c(0x3C3327), 2)
    ctx.setFillColor(c(0xA39883, i == 0 ? 0.9 : 0.6)); ctx.fill(rect(x: CGFloat(x) + 14, top: 863, w: 36, h: 10))
}

// the speaker grille: whole punch tiles only
let grille = rect(x: 604, top: 840, w: 280, h: 56)
linear(rr(grille, 8), [(0x221C14, 0), (0x171209, 1)], from: CGPoint(x: 0, y: grille.maxY), to: CGPoint(x: 0, y: grille.minY))
ctx.setFillColor(c(0x000000, 0.85))
let pitch: CGFloat = 14
for row in 0..<Int(grille.height / pitch) { for col in 0..<Int(grille.width / pitch) {
    ctx.fillEllipse(in: CGRect(x: grille.minX + CGFloat(col) * pitch + 4, y: grille.minY + CGFloat(row) * pitch + 4, width: 6.5, height: 6.5))
} }
// the maker's plate: a small strip of bars
for (i, h) in bars.enumerated() { ctx.setFillColor(c(h)); ctx.fill(rect(x: 462 + CGFloat(i) * 16, top: 862, w: 17, h: 12)) }

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
