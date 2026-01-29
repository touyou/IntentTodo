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
/// TodoCheckbox(todo: entity) { updatedEntity in
///     viewModel.updateTodo(updatedEntity)
/// }
/// ```
public struct TodoCheckbox: View {
    // MARK: - Properties

    private let todo: TodoAppEntity
    private let onToggle: ((TodoAppEntity) -> Void)?

    @State private var isProcessing = false

    // MARK: - Initialization

    /// Creates a checkbox for the given todo.
    /// - Parameters:
    ///   - todo: The todo entity to display and toggle.
    ///   - onToggle: Optional callback when the todo is toggled.
    public init(
        todo: TodoAppEntity,
        onToggle: ((TodoAppEntity) -> Void)? = nil
    ) {
        self.todo = todo
        self.onToggle = onToggle
    }

    // MARK: - Body

    public var body: some View {
        Button {
            Task {
                await toggleCompletion()
            }
        } label: {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .accessibilityLabel(todo.isCompleted ? "Mark as incomplete" : "Mark as complete")
    }

    // MARK: - Actions

    @MainActor
    private func toggleCompletion() async {
        isProcessing = true
        defer { isProcessing = false }

        let intent = ToggleTodoCompletionIntent(todo: todo)
        do {
            let result = try await intent.perform()
            if let entity = result.value {
                onToggle?(entity)
            }
        } catch {
            // Error handling could be added here
        }
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
