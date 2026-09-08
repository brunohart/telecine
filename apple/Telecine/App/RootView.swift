//  RootView.swift — the set, the guide, the channels, the licence, the about page.

import SwiftUI

struct RootView: View {
    @Environment(Navigator.self) private var navigator
    var body: some View {
        @Bindable var nav = navigator
        TabView(selection: $nav.tab) {
            Tab("The Set", systemImage: "tv", value: .set) {
                SetView().toolbarColorScheme(.dark, for: .tabBar)
            }
            Tab("The Guide", systemImage: "list.bullet.rectangle", value: .guide) {
                NavigationStack(path: $nav.guidePath) { GuideView().destinations() }
            }
            Tab("Channels", systemImage: "dial.medium", value: .channels) {
                NavigationStack(path: $nav.channelsPath) { ChannelsView().destinations() }
            }
            Tab("Licence", systemImage: "seal", value: .licence) {
                NavigationStack { LicenceView() }
            }
            Tab("About", systemImage: "info.circle", value: .about) {
                NavigationStack { AboutView() }
            }
        }
        .tint(Ink.signal)
    }
}

extension View {
    /// Every film page is a hub: credits open people, people open films, threads cross channels.
    func destinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .film(let slug): FilmView(slug: slug)
            case .person(let slug): PersonView(slug: slug)
            case .channel(let id): ChannelView(id: id)
            }
        }
    }
}

/// The masthead: wordmark, tagline, bars. On paper pages it is the page header;
/// in the dark room it sits above the cabinet.
struct Masthead: View {
    var room = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Wordmark(size: 26, color: room ? Ink.Room.ink : Ink.ink, ghostOpacity: room ? 0.34 : 0.16)
                Spacer()
                ViewThatFits {
                    MonoLabel("A public broadcast network", style: .caption2, color: room ? Ink.Room.inkSoft : Ink.inkSoft)
                    EmptyView()
                }
            }
            Bars(height: 8, room: room)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        .frame(maxWidth: 1080)
        .frame(maxWidth: .infinity)
        .background((room ? Ink.Room.paper : Ink.paper).opacity(0.001))
    }
}

/// Paper: the page background and grain shared by every non-set surface.
struct Paper<Content: View>: View {
    var title: String
    var lede: String?
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Masthead()
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(Face.display(.largeTitle, weight: .black))
                        .foregroundStyle(Ink.ink)
                        .padding(.top, 14)
                    if let lede {
                        Text(lede)
                            .font(Face.body(.title3)).italic()
                            .foregroundStyle(Ink.inkSoft)
                            .frame(maxWidth: 620, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                Colophon()
            }
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .background(Ink.paper.ignoresSafeArea())
        .overlay(Grain())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

struct Colophon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BrokenRule()
            Text("Every film transmitted here is in the public domain, served from prints held by the Internet Archive. The schedule is the broadcast: no server, no algorithm, no account.")
                .font(Face.body(.footnote))
                .foregroundStyle(Ink.inkSoft)
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.top, 14)
            MonoLabel("Telecine is made by designedbybruno", style: .caption2)
        }
        .padding(.horizontal, 16).padding(.top, 56).padding(.bottom, 36)
    }
}
