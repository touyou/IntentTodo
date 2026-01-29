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
/// DeleteButton(todo: entity) {
///     viewModel.removeTodo(entity)
/// }
/// ```
public struct DeleteButton: View {
    // MARK: - Properties

    private let todo: TodoAppEntity
    private let onDelete: (() -> Void)?

    @State private var isProcessing = false

    // MARK: - Initialization

    /// Creates a delete button for the given todo.
    /// - Parameters:
    ///   - todo: The todo entity to delete.
    ///   - onDelete: Optional callback when the todo is deleted.
    public init(
        todo: TodoAppEntity,
        onDelete: (() -> Void)? = nil
    ) {
        self.todo = todo
        self.onDelete = onDelete
    }

    // MARK: - Body

    public var body: some View {
        Button(role: .destructive) {
            Task {
                await deleteTodo()
            }
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
        .disabled(isProcessing)
        .accessibilityLabel("Delete todo")
    }

    // MARK: - Actions

    @MainActor
    private func deleteTodo() async {
        isProcessing = true
        defer { isProcessing = false }

        let intent = DeleteTodoIntent(todo: todo)
        do {
            _ = try await intent.perform()
            onDelete?()
        } catch {
            // Error handling could be added here
        }
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
