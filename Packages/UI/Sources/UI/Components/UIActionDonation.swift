//
//  UIActionDonation.swift
//  UI
//
//  Donations for the few UI actions that do not run an intent. Everything that runs through
//  `Button(intent:)` is already recorded by the system; these are the gaps, so Siri learns
//  from them the same way it learns from the rest.
//

import AppIntents
import SwiftUI
import TodoAppIntents

enum UIActionDonation {
    /// Picking a filter in the list is what `ShowTodosIntent(filter:)` does from Siri.
    static func showList(_ filter: TodoFilter) {
        donate(ShowTodosIntent(filter: filter.filterType))
    }

    /// Selecting a row is what `OpenTodoIntent(target:)` does from Siri.
    static func openTodo(_ todo: TodoAppEntity) {
        donate(OpenTodoIntent(target: todo))
    }

    /// Never awaited by the caller: a failed donation must not hold up the interaction.
    private static func donate(_ intent: some AppIntent) {
        Task {
            _ = try? await intent.donate()
        }
    }
}

extension Binding {
    /// A binding that also reports values written through it.
    ///
    /// Only the control holding the binding writes through it; an intent that changes the
    /// same state writes `NavigationModel` directly. That is what keeps these donations to
    /// taps — the system already donates the intents it runs, so counting those would
    /// double them.
    ///
    /// Main-actor isolated, closures included: `Binding(get:set:)` takes `@Sendable`
    /// closures, and only actor-isolated ones may capture the non-`Sendable` binding.
    @MainActor
    func onUserSet(_ action: @escaping @MainActor (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { @MainActor in wrappedValue },
            set: { @MainActor newValue, transaction in
                self.transaction(transaction).wrappedValue = newValue
                action(newValue)
            }
        )
    }
}
