//
//  TodoCheckbox.swift
//  IntentTodo
//

import SwiftUI
import TodoAppIntents

/// A checkbox component that toggles todo completion via App Intent.
///
/// Usage:
/// ```swift
/// TodoCheckbox(todo: entity)
/// ```
public struct TodoCheckbox: View {
    // MARK: - Properties

    private let todo: TodoAppEntity

    // MARK: - Initialization

    /// Creates a checkbox for the given todo.
    /// - Parameter todo: The todo entity to display and toggle.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Body

    public var body: some View {
        Button(intent: ToggleTodoCompletionIntent(todo: todo)) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todo.isCompleted ? "Mark as incomplete" : "Mark as complete")
    }
}

// MARK: - Preview

#Preview("Incomplete") {
    TodoCheckbox(
        todo: TodoAppEntity(
            id: UUID().uuidString,
            title: "Test Todo",
            isCompleted: false
        )
    )
}

#Preview("Completed") {
    TodoCheckbox(
        todo: TodoAppEntity(
            id: UUID().uuidString,
            title: "Test Todo",
            isCompleted: true
        )
    )
}
