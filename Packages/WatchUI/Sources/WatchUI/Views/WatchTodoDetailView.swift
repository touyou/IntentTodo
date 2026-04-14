//
//  WatchTodoDetailView.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// Detail view for a todo item on watchOS.
public struct WatchTodoDetailView: View {
    private let todoId: UUID
    @Query private var todoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss

    private var todo: TodoItem? {
        todoItems.first { $0.id == todoId }
    }

    private var entity: TodoAppEntity? {
        todo.map { TodoAppEntity(from: $0) }
    }

    public init(todo: TodoItem) {
        self.todoId = todo.id
        _todoItems = Query()
    }

    public var body: some View {
        Group {
            if let todo, let entity {
                detailContent(todo: todo, entity: entity)
            } else {
                ContentUnavailableView(
                    "Todo Not Found",
                    systemImage: "questionmark.circle"
                )
            }
        }
        .onChange(of: todo) { _, newValue in
            if newValue == nil {
                dismiss()
            }
        }
    }

    private func detailContent(todo: TodoItem, entity: TodoAppEntity) -> some View {
        List {
            Section {
                HStack {
                    Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(todo.title)
                        .font(.headline)
                }
            }

            if let dueDate = todo.dueDate {
                Section("Due Date") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dueDate.formatted(date: .complete, time: .omitted))
                        Text(dueDate.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = todo.todoDescription, !description.isEmpty {
                Section("Description") {
                    Text(description)
                        .font(.caption)
                }
            }

            Section {
                Button(intent: ToggleFavoriteIntent(todo: entity)) {
                    Label(
                        todo.isFavorite ? "Remove Favorite" : "Add Favorite",
                        systemImage: todo.isFavorite ? "star.slash" : "star"
                    )
                }

                Button(role: .destructive, intent: DeleteTodoIntent(todo: entity)) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Details")
    }
}
