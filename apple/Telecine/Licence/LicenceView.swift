//  LicenceView.swift — the Receiving Licence, as a printed document.
//  Free to watch, permanently. The licence is how a viewer stands behind the projector.

import StoreKit
import SwiftUI

struct LicenceView: View {
    @Environment(Licence.self) private var licence
    @State private var busy: Licence.Kind?
    @State private var message: String?
    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var lic = licence
        Paper(title: "The Licence", lede: "The network is free to watch, and that is permanent. A Receiving Licence is how it grows.") {
            VStack(alignment: .leading, spacing: 28) {
                Text("Telecine costs almost nothing to run — that is the elegance of the design — but programming is labour: finding the best surviving print of each film, verifying it, writing the notes, composing seasons that mean something. A licence funds that labour, the way a licence fee funds a public broadcaster, except this one is voluntary and buys nothing you did not already have. Not a paywall in front of the films (they belong to you already), but a way to stand behind the projector.")
                    .font(Face.body(.body)).foregroundStyle(Ink.ink).lineSpacing(4).frame(maxWidth: 620, alignment: .leading)

                // the document
                VStack(alignment: .leading, spacing: 0) {
                    Bars(height: 10)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                MonoLabel("Telecine · Public broadcast network")
                                Text("Receiving Licence").font(Face.display(.title, weight: .black)).foregroundStyle(Ink.ink)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                MonoLabel("No.")
                                Text(licence.number ?? "———— ————").font(Face.engraved(18)).foregroundStyle(Ink.ink).monospacedDigit()
                            }
                        }
                        BrokenRule()
                        Text("This licence permits the holder to receive every Telecine transmission, on every channel, at every hour — which they could anyway. It records that they chose to pay for it.")
                            .font(Face.body(.subheadline)).italic().foregroundStyle(Ink.inkSoft).lineSpacing(3)
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel("Issued to")
                            TextField("Your name, for the credit roll (or leave it blank)", text: $lic.holderName)
                                .font(Face.display(.title3, weight: .semibold))
                                .foregroundStyle(Ink.ink)
                                .textFieldStyle(.plain)
                                .padding(.bottom, 6)
                                .overlay(alignment: .bottom) { Rectangle().fill(Ink.lineStrong).frame(height: 1) }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            MonoLabel("The holder receives")
                            ForEach(["A name in the network's end-of-night credit roll (or anonymity, kept)",
                                     "The printed seasonal programme — the guide as an object worth keeping",
                                     "One programming vote each season: one film on one channel is the licence-holders' pick",
                                     "First tune-in when new channels test their signal"], id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Rectangle().fill(Ink.signal).frame(width: 6, height: 6).offset(y: -3)
                                    Text(line).font(Face.body(.subheadline)).foregroundStyle(Ink.ink)
                                }
                            }
                        }
                    }
                    .padding(22)
                    .overlay(alignment: .bottomTrailing) {
                        if licence.isHeld {
                            Text(licence.isFounding ? "FOUNDING\nPATRON" : "LICENSED")
                                .font(Face.engraved(14, weight: .bold)).tracking(3)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Ink.live)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Ink.live, lineWidth: 2.5))
                                .rotationEffect(.degrees(-9))
                                .opacity(0.82)
                                .scaleEffect(stamped || reduceMotion ? 1 : 1.6)
                                .padding(28)
                                .onAppear { withAnimation(Motion.spring) { stamped = true } }
                                .accessibilityLabel(licence.isFounding ? "Stamped: Founding Patron" : "Stamped: Licensed")
                        }
                    }
                }
                .background(Ink.card)
                .overlay(Rectangle().stroke(Ink.lineStrong))
                .background(Rectangle().fill(Ink.tube.opacity(0.14)).offset(x: 7, y: 7))  // the second print pass, offset
                .rotationEffect(.degrees(reduceMotion ? 0 : 0.4))
                .frame(maxWidth: 680)
                .sensoryFeedback(.success, trigger: licence.isHeld)

                // the office
                VStack(alignment: .leading, spacing: 14) {
                    if licence.loading {
                        MonoLabel("The licence office is opening…", style: .caption2, color: Ink.inkFaint)
                    } else if licence.products.isEmpty {
                        MonoLabel("The licence office opens with Season Two.", style: .caption2, color: Ink.inkFaint)
                        Text("Until then the best ways to back the transmitter: tell exactly one person who would love CH 02, and give to the Internet Archive, whose shelves this network is built on.")
                            .font(Face.body(.subheadline)).foregroundStyle(Ink.inkSoft).frame(maxWidth: 620, alignment: .leading)
                    } else {
                        HStack(spacing: 14) {
                            ForEach(Licence.Kind.allCases, id: \.self) { kind in
                                if let p = licence.product(kind) {
                                    Button { Task { await buy(kind) } } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(kind.title).font(Face.display(.headline)).foregroundStyle(Ink.ink)
                                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                                Text(p.displayPrice).font(Face.engraved(15, weight: .semibold)).foregroundStyle(Ink.signalDeep)
                                                if kind == .annual { MonoLabel("per year", style: .caption2, color: Ink.inkFaint) } else { MonoLabel("once", style: .caption2, color: Ink.inkFaint) }
                                            }
                                            if licence.held[kind] != nil { Stamp("Held", color: Ink.live, border: Ink.live, tilt: 0) }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Ink.card, in: RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Ink.lineStrong))
                                        .opacity(busy == kind ? 0.6 : 1)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(busy != nil || licence.held[kind] != nil)
                                }
                            }
                        }
                        .frame(maxWidth: 680)
                        HStack(spacing: 18) {
                            Button("Restore a licence") { Task { await licence.restore() } }
                            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Link("Privacy", destination: URL(string: "https://telecine.vercel.app/about")!)
                        }
                        .buttonStyle(.plain)
                        .font(Face.mono(.caption2)).foregroundStyle(Ink.inkSoft)
                    }
                    if let message { Text(message).font(Face.body(.footnote)).italic().foregroundStyle(Ink.inkSoft) }
                    Text("The Viewer tier is every channel, every film, always on — no account, no tracking, no licence needed. Cinemas, festivals and film societies wanting a Transmission of their own are the Affiliate tier; that conversation happens by hand.")
                        .font(Face.body(.footnote)).foregroundStyle(Ink.inkFaint).frame(maxWidth: 620, alignment: .leading)
                }
            }
        }
    }

    private func buy(_ kind: Licence.Kind) async {
        busy = kind; message = nil
        do {
            switch try await licence.purchase(kind) {
            case .licensed: message = "Licensed. Thank you for standing behind the projector."
            case .pending: message = "The purchase is waiting for approval."
            case .cancelled: break
            }
        } catch { message = error.localizedDescription }
        busy = nil
    }
}
