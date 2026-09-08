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

// the cabinet is the tile: walnut edge to edge, iOS rounds the corners itself
let cab = CGRect(x: 0, y: 0, width: S, height: S)
linear(CGPath(rect: cab, transform: nil), [(0x2E241A, 0), (0x241C13, 0.5), (0x1B140D, 1)], from: CGPoint(x: 0, y: S), to: CGPoint(x: 0, y: 0))
var rng = SystemRandomNumberGenerator()
for _ in 0..<40000 {
    let x = CGFloat.random(in: 0..<S, using: &rng), y = CGFloat.random(in: 0..<S, using: &rng)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.03)); ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
}
// the fascia's own edge: a highlight along the top, a shadow along the bottom
linear(CGPath(rect: CGRect(x: 0, y: S - 40, width: S, height: 40), transform: nil), [(0x4A3D2D, 0), (0x2E241A, 1)], from: CGPoint(x: 0, y: S), to: CGPoint(x: 0, y: S - 40))
linear(CGPath(rect: CGRect(x: 0, y: 0, width: S, height: 60), transform: nil), [(0x110C08, 0), (0x1B140D, 1)], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 60))

// the bezel and the tube
let bezel = rect(x: 100, top: 100, w: 824, h: 590)
ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: c(0x000000, 0.7)); fill(rr(bezel, 52), c(0x0B0906)); ctx.restoreGState()
let glass = bezel.insetBy(dx: 24, dy: 24)
let tube = rr(glass, 34)
fill(tube, c(0x000000))
// the tube warming: deep blue glow with the test card on it
radial(tube, [(c(0x1B2D4F, 0.9), 0), (c(0x0A1224, 1), 0.6), (c(0x000000, 1), 1)], center: CGPoint(x: glass.midX, y: glass.midY + 20), radius: 640)
// the test card: six bars low on the tube, slightly misregistered
let bars: [UInt32] = [0x1B2D4F, 0xC24A1F, 0x2F4A3A, 0xA3762A, 0x9E3413, 0xEDE5D4]
ctx.saveGState(); ctx.addPath(tube); ctx.clip()
let bw = glass.width / CGFloat(bars.count)
for (i, h) in bars.enumerated() {
    ctx.setFillColor(c(h, 0.35)); ctx.fill(rect(x: glass.minX + CGFloat(i) * bw + 6, top: 528 - 6, w: bw + 1, h: 138))
    ctx.setFillColor(c(h)); ctx.fill(rect(x: glass.minX + CGFloat(i) * bw, top: 528, w: bw + 1, h: 138))
}
// the vignette of a curved screen, and one quiet reflection
radial(tube, [(c(0x000000, 0), 0), (c(0x000000, 0), 0.55), (c(0x000000, 0.55), 1)], center: CGPoint(x: glass.midX, y: glass.midY), radius: 560)
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(tube); ctx.clip()
let refl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(0xEDE5D4, 0.10), c(0xEDE5D4, 0.02), c(0xEDE5D4, 0)] as CFArray, locations: [0, 0.22, 0.4])!
ctx.drawLinearGradient(refl, start: CGPoint(x: glass.minX, y: glass.maxY), end: CGPoint(x: glass.maxX, y: glass.minY), options: [])
ctx.restoreGState()
stroke(rr(glass.insetBy(dx: 1, dy: 1), 33), c(0xEDE5D4, 0.06), 2)

// the display window: readouts behind dark glass, with the accent bar lit
let win = rect(x: 100, top: 728, w: 824, h: 70)
fill(rr(win, 12), c(0x0C0906))
stroke(rr(win, 12), c(0x060402), 2)
ctx.setFillColor(c(0x1B2D4F)); ctx.fill(rect(x: 112, top: 730, w: 800, h: 6))
// CH 01 · ● LIVE — as engraved marks, not text
ctx.setFillColor(c(0xE3B079)); ctx.fill(rect(x: 130, top: 757, w: 160, h: 13))
ctx.setFillColor(c(0xB98A54, 0.8)); ctx.fill(rect(x: 308, top: 757, w: 240, h: 13))
ctx.setFillColor(c(0xB23315)); ctx.fillEllipse(in: rect(x: 806, top: 753, w: 20, h: 20))
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 16, color: c(0xB23315, 0.9)); ctx.fillEllipse(in: rect(x: 806, top: 753, w: 20, h: 20)); ctx.restoreGState()
ctx.setFillColor(c(0xB98A54)); ctx.fill(rect(x: 840, top: 757, w: 56, h: 13))

// the power knob: ridged bakelite, indicator at twelve
let kc = CGPoint(x: 156, y: Y(872))
let kr: CGFloat = 48
ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: c(0x000000, 0.8))
fill(CGPath(ellipseIn: CGRect(x: kc.x - kr, y: kc.y - kr, width: kr * 2, height: kr * 2), transform: nil), c(0x171209)); ctx.restoreGState()
for i in 0..<36 {
    let a = CGFloat(i) / 36 * .pi * 2
    ctx.setFillColor(c(i % 2 == 0 ? 0x2E261D : 0x171209))
    ctx.move(to: kc)
    ctx.addArc(center: kc, radius: kr, startAngle: a, endAngle: a + .pi * 2 / 36, clockwise: false)
    ctx.closePath(); ctx.fillPath()
}
radial(CGPath(ellipseIn: CGRect(x: kc.x - 32, y: kc.y - 32, width: 64, height: 64), transform: nil), [(c(0x35291C), 0), (c(0x1A1410), 1)], center: CGPoint(x: kc.x - 8, y: kc.y + 10), radius: 36)
stroke(CGPath(ellipseIn: CGRect(x: kc.x - kr, y: kc.y - kr, width: kr * 2, height: kr * 2), transform: nil), c(0x0D0A06), 3)
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 8, color: c(0xC24A1F, 0.8))
fill(rr(CGRect(x: kc.x - 3.5, y: kc.y + 18, width: 7, height: 24), 3.5), c(0xC24A1F)); ctx.restoreGState()

// two keys with travel
for (i, x) in [244, 340].enumerated() {
    let k = rect(x: CGFloat(x), top: 846, w: 76, h: 52)
    fill(rr(k.offsetBy(dx: 0, dy: -4), 9), c(0x000000, 0.55))
    linear(rr(k, 9), [(0x2C251C, 0), (0x1E1913, 1)], from: CGPoint(x: 0, y: k.maxY), to: CGPoint(x: 0, y: k.minY))
    stroke(rr(k, 9), c(0x3C3327), 2)
    ctx.setFillColor(c(0xA39883, i == 0 ? 0.9 : 0.6)); ctx.fill(rect(x: CGFloat(x) + 18, top: 866, w: 40, h: 12))
}

// the speaker grille: whole punch tiles only
let grille = rect(x: 630, top: 840, w: 294, h: 64)
linear(rr(grille, 8), [(0x221C14, 0), (0x171209, 1)], from: CGPoint(x: 0, y: grille.maxY), to: CGPoint(x: 0, y: grille.minY))
ctx.setFillColor(c(0x000000, 0.85))
let pitch: CGFloat = 14
for row in 0..<Int(grille.height / pitch) { for col in 0..<Int(grille.width / pitch) {
    ctx.fillEllipse(in: CGRect(x: grille.minX + CGFloat(col) * pitch + 4, y: grille.minY + CGFloat(row) * pitch + 4, width: 6.5, height: 6.5))
} }
// the maker's plate: a small strip of bars
for (i, h) in bars.enumerated() { ctx.setFillColor(c(h)); ctx.fill(rect(x: 452 + CGFloat(i) * 22, top: 865, w: 23, h: 15)) }

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
