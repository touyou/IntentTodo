//
//  WatchTodoListView.swift
//  WatchUI
//

import Domain
import SwiftData
import SwiftUI

/// Main list view showing incomplete todos on watchOS.
public struct WatchTodoListView: View {
    @Query(
        filter: #Predicate<TodoItem> { !$0.isCompleted },
        sort: [
            SortDescriptor(\TodoItem.dueDate),
            SortDescriptor(\TodoItem.createdAt, order: .reverse)
        ]
    )
    private var incompleteTodos: [TodoItem]

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if incompleteTodos.isEmpty {
                    emptyView
                } else {
                    todoList
                }
            }
            .navigationTitle(.copy("Todos"))
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

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text(.copy("All Done!"))
                .font(.headline)

            Text(.copy("No incomplete todos"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var todoList: some View {
        // 旧実装は `incompleteTodos.filter { isDueSoon($0) }` と
        // `incompleteTodos.filter { !isDueSoon($0) }` で同じ配列を 2 周し、
        // さらに `isDueSoon` の中で `Date()` を都度生成していた。watchOS は
        // CPU が弱いので 1 周の partition + Date() 1 回に圧縮する。
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        var dueSoon: [TodoItem] = []
        var others: [TodoItem] = []
        for todo in incompleteTodos {
            if let dueDate = todo.dueDate, dueDate > now, dueDate <= oneHourFromNow {
                dueSoon.append(todo)
            } else {
                others.append(todo)
            }
        }

        return List {
            if !dueSoon.isEmpty {
                Section(.copy("Due Soon")) {
                    ForEach(dueSoon) { todo in
                        WatchTodoRow(todo: todo)
                    }
                }
            }
            if !others.isEmpty {
                Section(.copy("Upcoming")) {
                    ForEach(others.prefix(10)) { todo in
                        WatchTodoRow(todo: todo)
                    }
                }
            }
        }
    }
}
