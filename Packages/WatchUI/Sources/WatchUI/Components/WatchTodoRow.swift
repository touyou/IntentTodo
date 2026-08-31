//
//  WatchTodoRow.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item on watchOS.
///
/// Two tap targets per row: the circle toggles completion, the body navigates to the detail
/// view. Making the whole row a toggle would leave no way to read the description or the due
/// time on the watch.
public struct WatchTodoRow: View {
    let todo: TodoItem
    private let entity: TodoAppEntity

    public init(todo: TodoItem) {
        self.todo = todo
        self.entity = TodoAppEntity(from: todo)
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? .copy("Mark as incomplete") : .copy("Mark as complete"))

            NavigationLink(value: NavigationDestination.todoDetail(entity)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(.body)
                        .lineLimit(2)

                    if let dueDate = todo.dueDate {
                        WatchDueDateLabel(date: dueDate, isCompleted: todo.isCompleted)
                    }
                }
            }
        }
        // Tells Siri which todo this row is. The collection form
        // `.appEntityIdentifier(forSelectionType:)` keys off the `List`'s selection type, and
        // this list has no selection (rows are a toggle plus a `NavigationLink`), so each row
        // carries its own annotation instead.
        .appEntityIdentifier(EntityIdentifier(for: entity))
    }
}
