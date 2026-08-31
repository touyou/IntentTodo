//
//  WatchAddTodoView.swift
//  WatchUI
//

import SwiftUI
import TodoAppIntents

/// View for adding a new todo on watchOS.
public struct WatchAddTodoView: View {
    @State private var title = ""

    public init() {}

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField(.copy("Todo title"), text: $title)
                .textContentType(.none)
                .accessibilityIdentifier("todoTitleField")

            // `Button(intent:)`, not a manual `perform()`: `@Dependency` is only injected
            // when the system dispatches the intent.
            Button(intent: AddTodoIntent(title: trimmedTitle)) {
                Label(.copy("Add"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedTitle.isEmpty)
            .accessibilityIdentifier("addButton")
        }
        .navigationTitle(.copy("New Todo"))
        // The sheet is closed by `AddTodoIntent` on success, not by a row-count change that
        // another device or a widget could also cause.
    }
}
