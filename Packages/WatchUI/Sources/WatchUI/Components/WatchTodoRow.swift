//
//  WatchTodoRow.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item on watchOS.
public struct WatchTodoRow: View {
    let todo: TodoItem

    public init(todo: TodoItem) {
        self.todo = todo
    }

    private var entity: TodoAppEntity {
        TodoAppEntity(from: todo)
    }

    public var body: some View {
        Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
            HStack {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)

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
        .buttonStyle(.plain)
    }
}
