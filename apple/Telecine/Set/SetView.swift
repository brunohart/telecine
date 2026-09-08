//  SetView.swift — The Set. On the phone and the tablet, a television in a walnut cabinet;
//  on Apple TV, the picture is the room.

import SwiftUI

struct SetView: View {
    @Environment(Receiver.self) private var receiver
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var theatre = false

    var body: some View {
        #if os(tvOS)
        TVSetView()
        #else
        ScrollView {
            Group {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 28) {
                        Cabinet(theatre: $theatre).frame(maxWidth: .infinity)
                        Dial().frame(width: 300)
                    }
                } else {
                    VStack(spacing: 22) {
                        Cabinet(theatre: $theatre)
                        Dial()
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 32)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .background(Ink.Room.paper.ignoresSafeArea())
        .overlay(Grain(opacity: 0.10).blendMode(.overlay))
        .safeAreaInset(edge: .top, spacing: 0) { Masthead(room: true) }
        .fullScreenCover(isPresented: $theatre) { TheatreView() }
        .onKeyPress(characters: .decimalDigits) { press in
            guard let n = Int(press.characters), n >= 1, n <= receiver.channels.count else { return .ignored }
            receiver.setChannel(receiver.channels[n - 1].id); return .handled
        }
        .onKeyPress("m") { receiver.toggleSound(); return .handled }
        .onKeyPress("f") { theatre = true; return .handled }
        #endif
    }
}

#if os(iOS)
/// The cabinet: a television, not a web player.
struct Cabinet: View {
    @Environment(Receiver.self) private var receiver
    @Binding var theatre: Bool

    var body: some View {
        VStack(spacing: 11) {
            ScreenFrame()
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(7)
                .background(Ink.Room.bezel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    Button { theatre = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xCBBB9D))
                            .frame(width: 42, height: 42)
                            .background(RadialGradient(colors: [Color(hex: 0x372C1F), Color(hex: 0x14100A)], center: .init(x: 0.36, y: 0.3), startRadius: 0, endRadius: 28), in: Circle())
                            .overlay(Circle().stroke(Color(hex: 0x060402)))
                            .shadow(color: .black.opacity(0.65), radius: 3, y: 2)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.85)
                    .padding(17)
                    .accessibilityLabel("Fullscreen")
                }
                .gesture(DragGesture(minimumDistance: 40).onEnded { g in
                    if g.translation.height < -40 { receiver.channelUp() } else if g.translation.height > 40 { receiver.channelDown() }
                })
            Chyron(compact: true)
            Strip()
            Deck { theatre = true }
            PlateRow()
        }
        .padding(.horizontal, 17).padding(.top, 17).padding(.bottom, 13)
        .background(LinearGradient(stops: [.init(color: Ink.Room.walnutTop, location: 0), .init(color: Ink.Room.walnutMid, location: 0.55), .init(color: Ink.Room.walnutBottom, location: 1)], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Ink.Room.walnutEdge))
        .shadow(color: .black.opacity(0.9), radius: 35, y: 24)
        .shadow(color: receiver.powered ? Ink.Room.ink.opacity(0.12) : .clear, radius: 55)
        .animation(.easeInOut(duration: 0.8), value: receiver.powered)
    }
}

/// Fullscreen: the picture and nothing else, until you tap.
struct TheatreView: View {
    @Environment(Receiver.self) private var receiver
    @Environment(\.dismiss) private var dismiss
    @State private var showChrome = true
    @State private var hide: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScreenFrame(theatre: true)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { reveal() }
                .gesture(DragGesture(minimumDistance: 40).onEnded { g in
                    if g.translation.height < -40 { receiver.channelUp(); reveal() } else if g.translation.height > 40 { receiver.channelDown(); reveal() }
                })
            if showChrome {
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Ink.Room.ink).frame(width: 44, height: 44)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Leave fullscreen")
                    }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 12) {
                        Chyron(compact: true).frame(maxWidth: 520)
                        Spacer(minLength: 0)
                        Button(receiver.muted ? "Sound off" : "Sound on") { receiver.toggleSound() }.buttonStyle(KeyStyle())
                    }
                }
                .padding(20)
                .transition(.opacity)
            }
        }
        .statusBarHidden(!showChrome)
        .onAppear(perform: reveal)
        .animation(Motion.soft, value: showChrome)
    }
    private func reveal() {
        showChrome = true
        hide?.cancel()
        hide = Task { try? await Task.sleep(for: .seconds(3.5)); if !Task.isCancelled { showChrome = false } }
    }
}
#endif

#if os(tvOS)
/// On Apple TV the set is the room. Swipe up or down on the remote to change channel;
/// press to bring up the dial; play/pause is answered honestly.
struct TVSetView: View {
    @Environment(Receiver.self) private var receiver
    @Environment(Stations.self) private var stations
    @State private var showChrome = true
    @State private var showDial = false
    @State private var hide: Task<Void, Never>?
    @FocusState private var screenFocused: Bool

    var body: some View {
        ZStack {
            ScreenFrame(theatre: true)
                .ignoresSafeArea()
            Color.clear
                .contentShape(Rectangle())
                .focusable(!showDial)
                .focused($screenFocused)
                .onMoveCommand { dir in
                    switch dir {
                    case .up: receiver.channelUp(); reveal()
                    case .down: receiver.channelDown(); reveal()
                    default: reveal()
                    }
                }
                .onPlayPauseCommand { receiver.playPausePressed(); reveal() }
                .onTapGesture {
                    if !receiver.powered { receiver.powerOn() } else { showDial.toggle() }
                    reveal()
                }
            if showChrome || showDial {
                VStack(spacing: 24) {
                    Spacer()
                    if showDial {
                        HStack(alignment: .top, spacing: 18) {
                            ForEach(receiver.channels) { ch in
                                Button {
                                    receiver.setChannel(ch.id); showDial = false; reveal()
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(ch.displayNumber).font(Face.displayFixed(40)).foregroundStyle(Ink.Room.ink)
                                        Text(ch.name).font(Face.display(.headline)).foregroundStyle(Ink.Room.ink)
                                        MonoLabel(receiver.nowOnLine(ch), style: .caption2, color: Ink.Room.inkSoft).lineLimit(2)
                                    }
                                    .padding(20).frame(width: 300, alignment: .leading)
                                }
                                .buttonStyle(.card)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Chyron().frame(maxWidth: 900)
                }
                .padding(60)
                .transition(.opacity)
            }
        }
        .background(.black)
        .onAppear { screenFocused = true; reveal() }
        .onChange(of: showDial) { _, v in if !v { screenFocused = true } }
        .onExitCommand { if showDial { showDial = false } }
        .animation(Motion.soft, value: showChrome)
        .animation(Motion.spring, value: showDial)
    }
    private func reveal() {
        showChrome = true
        hide?.cancel()
        hide = Task { try? await Task.sleep(for: .seconds(4)); if !Task.isCancelled { showChrome = false } }
    }
}
#endif
