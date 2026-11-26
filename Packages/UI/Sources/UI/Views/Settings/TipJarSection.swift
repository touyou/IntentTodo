//
//  TipJarSection.swift
//  UI
//

#if os(iOS) || os(visionOS) || os(macOS)
import StoreKit
import SwiftUI

/// The "Support the Developer" section of About. Hidden until the products load, so a
/// build without them in App Store Connect shows nothing rather than dead rows.
struct TipJarSection: View {
    @State private var jar = TipJar.shared

    var body: some View {
        Group {
            if !jar.products.isEmpty {
                Section {
                    ForEach(TipJar.Tier.allCases) { tier in
                        if let product = jar.products[tier] {
                            TipRow(tier: tier, product: product, jar: jar)
                        }
                    }
                } header: {
                    Text(.copy("Support the Developer"))
                } footer: {
                    TipJarFooter(phase: jar.phase, tipCount: jar.tipCount)
                }
            }
        }
        .task { await jar.loadProducts() }
    }
}

private struct TipRow: View {
    let tier: TipJar.Tier
    let product: Product
    let jar: TipJar
    @Environment(\.purchase) private var purchase

    var body: some View {
        Button {
            Task { await jar.purchase(tier, using: purchase) }
        } label: {
            HStack {
                Text(verbatim: tier.emoji)
                    .accessibilityHidden(true)
                Text(tier.title)
                    .foregroundStyle(.primary)
                Spacer()
                if jar.phase == .purchasing(tier) {
                    ProgressView()
                } else {
                    Text(verbatim: product.displayPrice)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(jar.isPurchasing)
    }
}

private struct TipJarFooter: View {
    let phase: TipJar.Phase
    let tipCount: Int

    var body: some View {
        switch phase {
        case .thanked:
            Text(.copy("Thank you so much! It keeps Intento going."))
        case .failed:
            Text(.copy("The purchase didn't go through. You haven't been charged."))
        case .unverified:
            Text(.copy("We couldn't verify the purchase with the App Store."))
        case .idle, .purchasing:
            if tipCount > 0 {
                Text(.copy("You've supported Intento \(tipCount) times. Thank you!"))
            } else {
                Text(.copy("A tip unlocks nothing extra, but it helps keep Intento going."))
            }
        }
    }
}
#endif
