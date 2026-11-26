//
//  TipJar.swift
//  IntentTodo
//

#if os(iOS) || os(visionOS) || os(macOS)
import Foundation
import Observation
import StoreKit
import SwiftUI

/// Consumable tips. A tip unlocks nothing (App Review rejects tips that gate features),
/// so the only state kept is how many times the person has tipped, on this device.
@MainActor
@Observable
public final class TipJar {
    public static let shared = TipJar()

    enum Tier: String, CaseIterable, Identifiable {
        case coffee, cake, lunch

        var id: String { productID }
        var productID: String { "dev.touyou.IntentTodo.tip.\(rawValue)" }

        var title: LocalizedStringResource {
            switch self {
            case .coffee: .copy("A Coffee")
            case .cake: .copy("Coffee and Cake")
            case .lunch: .copy("Lunch")
            }
        }

        var emoji: String {
            switch self {
            case .coffee: "☕️"
            case .cake: "🍰"
            case .lunch: "🍱"
            }
        }
    }

    enum Phase: Equatable {
        case idle
        case purchasing(Tier)
        case thanked
        case failed
        case unverified
    }

    private static let handledKey = "tipJarHandledTransactionIDs"

    private(set) var products: [Tier: Product] = [:]
    private(set) var phase: Phase = .idle
    private var handledIDs: Set<String>
    var tipCount: Int { handledIDs.count }
    private var observer: Task<Void, Never>?

    private init() {
        handledIDs = Set(UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? [])
    }

    /// Call at launch: an Ask to Buy approval or a purchase interrupted by a quit arrives
    /// through `Transaction.updates`, and a consumable left unfinished is redelivered forever.
    public func startObservingTransactions() {
        guard observer == nil else { return }
        Task { await loadProducts() }
        observer = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            for await result in StoreKit.Transaction.unfinished {
                await handle(result)
            }
        }
    }

    var isPurchasing: Bool {
        if case .purchasing = phase { true } else { false }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: Tier.allCases.map(\.productID))) ?? []
        products = Dictionary(uniqueKeysWithValues: loaded.compactMap { product in
            Tier.allCases.first { $0.productID == product.id }.map { ($0, product) }
        })
    }

    /// `Product.purchase()` is unavailable on visionOS, so the view passes in SwiftUI's `PurchaseAction`,
    /// which works on every platform and anchors the sheet to the right scene.
    func purchase(_ tier: Tier, using action: PurchaseAction) async {
        guard let product = products[tier], !isPurchasing else { return }
        phase = .purchasing(tier)
        do {
            switch try await action(product) {
            case .success(let result):
                phase = await handle(result)
            case .pending, .userCancelled:
                phase = .idle
            @unknown default:
                phase = .idle
            }
        } catch {
            phase = .failed
        }
    }

    /// Only a direct purchase result changes `phase`, so a background delivery never ends an in-flight purchase.
    @discardableResult
    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async -> Phase {
        let transaction: StoreKit.Transaction
        switch result {
        case .verified(let verified):
            transaction = verified
        case .unverified(let unverified, _):
            guard Self.isTip(unverified) else { return .unverified }
            // Not counted, but finished so it stops being redelivered on every launch.
            await unverified.finish()
            return .unverified
        }
        guard Self.isTip(transaction) else { return .idle }
        // `updates` and `unfinished` both deliver the same transaction at launch, and a quit
        // between counting and finish() redelivers it, so each id is counted once.
        let counted = transaction.revocationDate == nil && handledIDs.insert(String(transaction.id)).inserted
        if counted {
            UserDefaults.standard.set(Array(handledIDs), forKey: Self.handledKey)
        }
        await transaction.finish()
        return counted ? .thanked : .idle
    }

    private static func isTip(_ transaction: StoreKit.Transaction) -> Bool {
        Tier.allCases.contains { $0.productID == transaction.productID }
    }
}
#endif
