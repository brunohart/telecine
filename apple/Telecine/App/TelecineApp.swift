//  TelecineApp.swift — a public broadcast receiver.

import SwiftUI

@main
struct TelecineApp: App {
    @State private var stations: Stations
    @State private var receiver: Receiver
    @State private var licence = Licence()
    @State private var navigator = Navigator()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let s = Stations()
        _stations = State(initialValue: s)
        _receiver = State(initialValue: Receiver(stations: s))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(stations)
                .environment(receiver)
                .environment(licence)
                .environment(navigator)
                .task {
                    await stations.refresh()
                    receiver.reconcile()
                    await licence.load()
                }
                .onOpenURL { url in navigator.open(url, receiver: receiver, stations: stations) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { receiver.wake() }
                }
        }
    }
}

/// Where the viewer is, and the one cross-cutting verb: tune.
@MainActor @Observable
final class Navigator {
    enum Tab: Hashable { case set, guide, channels, licence, about }
    var tab: Tab = .set
    var guidePath = NavigationPath()
    var channelsPath = NavigationPath()

    func tune(to channelID: String, receiver: Receiver) {
        receiver.setChannel(channelID)
        tab = .set
    }

    /// telecine://ch/02  ·  telecine://film/detour-1945  ·  https://telecine.vercel.app/#02
    func open(_ url: URL, receiver: Receiver, stations: Stations) {
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == "telecine" {
            switch url.host() {
            case "ch":
                if let n = parts.first, let ch = stations.channels.first(where: { $0.number == n || $0.id == n }) { tune(to: ch.id, receiver: receiver) }
            case "film":
                if let slug = parts.first, stations.film(slug) != nil { tab = .guide; guidePath.append(Route.film(slug)) }
            default: break
            }
        } else if let frag = url.fragment(), let ch = stations.channels.first(where: { $0.number == frag }) {
            tune(to: ch.id, receiver: receiver)
        }
    }
}

enum Route: Hashable {
    case film(String)
    case person(String)
    case channel(String)
}
