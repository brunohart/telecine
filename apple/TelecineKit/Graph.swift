//  Graph.swift — the editorial graph: posters, credits, people, and the editor's threads.
//  Facts come from Wikidata; the threads are hand-written. Every name is a door.

import Foundation

public struct Credit: Hashable, Sendable, Codable, Identifiable {
    public var slug: String
    public var name: String
    public var id: String { slug }
}

public struct FilmGraph: Hashable, Sendable, Codable {
    public var qid: String?
    public var poster: URL?
    public var posterSource: URL?
    public var directors: [Credit]?
    public var cinematography: [Credit]?
    public var cast: [Credit]?
}

public struct PersonCredit: Hashable, Sendable, Codable {
    public var film: String
    public var role: String
}

public struct Person: Hashable, Sendable, Codable, Identifiable {
    public var slug: String
    public var name: String
    public var qid: String?
    public var description: String?
    public var image: URL?
    public var imageSource: URL?
    public var credits: [PersonCredit]?
    public var id: String { slug }
}

public struct Thread: Hashable, Sendable, Codable, Identifiable {
    public var films: [String]
    public var note: String
    public var id: String { films.joined(separator: "+") }
}

public struct Graph: Sendable, Codable {
    public var films: [String: FilmGraph]
    public var people: [String: Person]
    public var threads: [Thread]

    public static let empty = Graph(films: [:], people: [:], threads: [])

    public func threads(for slug: String) -> [Thread] { threads.filter { $0.films.contains(slug) } }
}
