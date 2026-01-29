//
//  DeleteButton.swift
//  IntentTodo
//

import SwiftUI
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
        Button(intent: DeleteTodoIntent(todo: todo)) {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
        .accessibilityLabel("Delete todo")
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
