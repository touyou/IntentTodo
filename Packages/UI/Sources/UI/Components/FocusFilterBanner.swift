//
//  FocusFilterBanner.swift
//  UI
//
//  Banner shown while a Focus filter is narrowing the list.
//

import SwiftUI
import TodoAppIntents

/// Reports that a Focus filter is active and offers to lift it in place, which is what
/// Calendar does [Apple: wwdc2022-10121 2:04]. Saying so without offering the escape hatch
/// would leave Settings as the only way out.
struct FocusFilterBanner: View {
    let store: TodoFocusFilterStore

    var body: some View {
        if store.filter.isActive {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.isSuspended ? .copy("Focus filter paused") : .copy("Filtered by Focus"))
                        .font(.footnote)
                    FocusFilterConditions(filter: store.filter)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.isSuspended ? .copy("Apply") : .copy("Show All")) {
                    store.isSuspended.toggle()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Chrome is left to the system material rather than painted here.
            .background(.bar)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Breakdown of the active conditions. Composed from separate `Text` views rather than a
/// concatenated `String` so each piece stays localizable; only the category name, being user
/// data, is verbatim.
private struct FocusFilterConditions: View {
    let filter: TodoFocusFilter

    var body: some View {
        HStack(spacing: 6) {
            if let categoryName = filter.categoryName {
                Text(verbatim: categoryName)
            }
            if filter.showsUrgentOnly {
                Text(.copy("Urgent only"))
            }
            if filter.hidesCompleted {
                Text(.copy("Hiding completed"))
            }
        }
    }
}
