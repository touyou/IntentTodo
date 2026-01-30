//
//  TodoRowView.swift
//  IntentTodo
//

import SwiftUI
import TodoAppIntents

/// A row view displaying a single todo item.
///
/// This view uses App Intent buttons for all interactions.
/// Data updates are handled automatically by SwiftData's @Query in the parent view.
public struct TodoRowView: View {
    // MARK: - Properties

    private let todo: TodoAppEntity

    // MARK: - Initialization

    /// Creates a row view for the given todo.
    /// - Parameter todo: The todo entity to display.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            TodoCheckbox(todo: todo)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                if let dueDate = todo.dueDate {
                    DueDateLabel(date: dueDate, isCompleted: todo.isCompleted)
                }
            }

            Spacer()

            // Favorite button
            FavoriteButton(todo: todo)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private

    private var accessibilityLabel: String {
        var label = todo.title
        if todo.isCompleted {
            label += ", completed"
        }
        if todo.isFavorite {
            label += ", favorite"
        }
        if let dueDate = todo.dueDate {
            label += ", due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return label
    }
}

// MARK: - Due Date Label

private struct DueDateLabel: View {
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        !isCompleted && date < Date()
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
        }
        .foregroundStyle(isOverdue ? .red : .secondary)
    }
}

// MARK: - Preview

#Preview("Normal") {
    List {
        TodoRowView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Buy groceries",
                isCompleted: false,
                isFavorite: false
            )
        )
    }
}

#Preview("Completed & Favorite") {
    List {
        TodoRowView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Completed task",
                isCompleted: true,
                isFavorite: true
            )
        )
    }
}

#Preview("With Due Date") {
    List {
        TodoRowView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Task with due date",
                isCompleted: false,
                isFavorite: false,
                dueDate: Date().addingTimeInterval(86400)
            )
        )
    }
}
