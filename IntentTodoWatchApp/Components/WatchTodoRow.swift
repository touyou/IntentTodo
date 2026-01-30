//
//  WatchTodoRow.swift
//  IntentTodoWatchApp
//
//  Row component for displaying a todo item on watchOS.
//

import Domain
import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item on watchOS.
struct WatchTodoRow: View {
    let todo: TodoItem

    private var entity: TodoAppEntity {
        TodoAppEntity(from: todo)
    }

    var body: some View {
        Button {
            Task {
                try? await ToggleTodoCompletionIntent(todo: entity).perform()
            }
        } label: {
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
