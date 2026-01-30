//
//  WatchTodoDetailView.swift
//  IntentTodoWatchApp
//
//  Detail view for a todo item on watchOS.
//

import Domain
import SwiftUI
import TodoAppIntents

/// Detail view for a todo item on watchOS.
struct WatchTodoDetailView: View {
    let todo: TodoItem

    private var entity: TodoAppEntity {
        TodoAppEntity(from: todo)
    }

    var body: some View {
        List {
            // Title section
            Section {
                HStack {
                    Button {
                        Task {
                            try? await ToggleTodoCompletionIntent(todo: entity).perform()
                        }
                    } label: {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(todo.title)
                        .font(.headline)
                }
            }

            // Due date section
            if let dueDate = todo.dueDate {
                Section("Due Date") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dueDate.formatted(date: .complete, time: .omitted))
                        Text(dueDate.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Description section
            if let description = todo.todoDescription, !description.isEmpty {
                Section("Description") {
                    Text(description)
                        .font(.caption)
                }
            }

            // Actions section
            Section {
                Button {
                    Task {
                        try? await ToggleFavoriteIntent(todo: entity).perform()
                    }
                } label: {
                    Label(
                        todo.isFavorite ? "Remove Favorite" : "Add Favorite",
                        systemImage: todo.isFavorite ? "star.slash" : "star"
                    )
                }

                Button(role: .destructive) {
                    Task {
                        try? await DeleteTodoIntent(todo: entity).perform()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Details")
    }
}
