//
//  WatchTodoListView.swift
//  IntentTodoWatchApp
//
//  Main list view for watchOS showing incomplete todos.
//

import Domain
import SwiftData
import SwiftUI

/// Main list view showing incomplete todos on watchOS.
struct WatchTodoListView: View {
    @Query(
        filter: #Predicate<TodoItem> { !$0.isCompleted },
        sort: [
            SortDescriptor(\TodoItem.dueDate),
            SortDescriptor(\TodoItem.createdAt, order: .reverse)
        ]
    )
    private var incompleteTodos: [TodoItem]

    @State private var showingAllTodos = false

    var body: some View {
        NavigationStack {
            Group {
                if incompleteTodos.isEmpty {
                    emptyView
                } else {
                    todoList
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: WatchAddTodoView()) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTodoButton")
                }
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("All Done!")
                .font(.headline)

            Text("No incomplete todos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Todo List

    private var todoList: some View {
        List {
            // Due soon section
            let dueSoon = incompleteTodos.filter { isDueSoon($0) }
            if !dueSoon.isEmpty {
                Section("Due Soon") {
                    ForEach(dueSoon) { todo in
                        WatchTodoRow(todo: todo)
                    }
                }
            }

            // Other todos
            let others = incompleteTodos.filter { !isDueSoon($0) }
            if !others.isEmpty {
                Section("Upcoming") {
                    ForEach(others.prefix(10)) { todo in
                        WatchTodoRow(todo: todo)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func isDueSoon(_ todo: TodoItem) -> Bool {
        guard let dueDate = todo.dueDate else { return false }
        return dueDate.timeIntervalSinceNow <= 3600 && dueDate.timeIntervalSinceNow > 0
    }
}

// MARK: - Previews

#Preview {
    WatchTodoListView()
}
