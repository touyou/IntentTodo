//
//  DeleteButton.swift
//  IntentTodo
//

import SwiftUI
import AppIntents
import TodoAppIntents

/// A button component that deletes a todo via App Intent.
///
/// Usage:
/// ```swift
/// DeleteButton(todo: entity)
/// ```
public struct DeleteButton: View {
    // MARK: - Properties

    private let todo: TodoAppEntity

    // MARK: - Initialization

    /// Creates a delete button for the given todo.
    /// - Parameter todo: The todo entity to delete.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Body

    public var body: some View {
        // Swiping to reveal Delete and pressing it is the confirmation, so this uses the
        // non-confirming intent — `requestConfirmation` has no surface to present on when
        // the caller is an in-app button, and the run fails silently.
        Button(intent: DeleteTodoImmediatelyIntent(todo: todo)) {
            Label(.copy("Delete"), systemImage: "trash")
        }
        .tint(.red)
        .accessibilityLabel(.copy("Delete todo"))
    }
}

// MARK: - Preview

#Preview {
    DeleteButton(
        todo: TodoAppEntity(
            id: UUID().uuidString,
            title: "Test Todo"
        )
    )
}
