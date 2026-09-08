//  Licence.swift — the Receiving Licence.
//
//  The network is free to watch and that is permanent. A licence is how a viewer stands behind
//  the projector — the way a licence fee funds a public broadcaster, except this one is voluntary
//  and buys nothing the holder did not already have. It gates nothing. It never will.

import Foundation
import Observation
import StoreKit

@MainActor @Observable
final class Licence {
    enum Kind: String, CaseIterable {
        case annual = "com.designedbybruno.telecine.licence.annual"
        case founding = "com.designedbybruno.telecine.licence.founding"
        var title: String {
            switch self { case .annual: "Annual Receiving Licence"; case .founding: "Founding Patron" }
        }
    }

    private(set) var products: [Product] = []
    private(set) var held: [Kind: Transaction] = [:]
    private(set) var loading = true
    private(set) var lastError: String?
    var holderName: String {
        get { UserDefaults.standard.string(forKey: "telecine.licence.holder") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "telecine.licence.holder") }
    }
    private var updates: Task<Void, Never>?

    var isHeld: Bool { !held.isEmpty }
    var isFounding: Bool { held[.founding] != nil }

    /// A licence number, derived from the original transaction — printed on the document.
    var number: String? {
        guard let t = held[.founding] ?? held[.annual] else { return nil }
        let raw = String(t.originalID)
        let padded = String(repeating: "0", count: max(0, 8 - raw.count)) + raw
        let tail = String(padded.suffix(8))
        return "\(tail.prefix(4)) \(tail.suffix(4))"
    }

    func product(_ kind: Kind) -> Product? { products.first { $0.id == kind.rawValue } }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            products = try await Product.products(for: Kind.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refreshEntitlements()
            }
        }
    }

    func refreshEntitlements() async {
        var found: [Kind: Transaction] = [:]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, let kind = Kind(rawValue: t.productID) else { continue }
            if t.revocationDate == nil { found[kind] = t }
        }
        held = found
    }

    enum PurchaseOutcome { case licensed, pending, cancelled }

    func purchase(_ kind: Kind) async throws -> PurchaseOutcome {
        guard let product = product(kind) else { return .cancelled }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let t) = verification { await t.finish() }
            await refreshEntitlements()
            return .licensed
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: return .cancelled
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
