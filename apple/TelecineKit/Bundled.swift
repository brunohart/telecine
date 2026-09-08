//  Bundled.swift — the Transmission that ships inside the receiver.
//  The app never needs the network to know what is on; the file is the broadcast.

import Foundation

public enum Bundled {
    private static func load<T: Decodable>(_ name: String, as: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    public static func network() -> Network {
        load("network", as: Network.self) ?? Network(channels: [], films: [:])
    }
    public static func graph() -> Graph {
        load("graph", as: Graph.self) ?? .empty
    }
}
