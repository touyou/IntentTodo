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
    @Query private var todoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss

    private var todo: TodoItem? { todoItems.first }
    private var entity: TodoAppEntity? { todo.map { TodoAppEntity(from: $0) } }

    public init(todo: TodoItem) {
        let targetId = todo.id
        _todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
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
            Section { WatchTodoDetailHeaderSection(todo: todo, entity: entity) }

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

            Section { WatchTodoDetailActionsSection(todo: todo, entity: entity) }
        }
        .navigationTitle("Details")
    }
}

// MARK: - Header

private struct WatchTodoDetailHeaderSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    var body: some View {
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
}

// MARK: - Actions

private struct WatchTodoDetailActionsSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    todo.isFavorite ? "Remove Favorite" : "Add Favorite",
                    systemImage: todo.isFavorite ? "star.slash" : "star"
                )
            }

            // 確認はアプリ側で取る（`DeleteTodoIntent` の `requestConfirmation` は
            // アプリ内ボタンからだと提示する面が無く失敗する）。
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete “\(entity.title)”?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
                Text("Delete")
            }
        }
    }
}
