//
//  WatchTodoListView.swift
//  WatchUI
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

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

    /// The same `NavigationModel` the app uses, so `OpenTodoIntent` and
    /// `LaunchAppIntent(.addTodo)` work here without watch-specific handling.
    @Environment(NavigationModel.self) private var navigationModel

    public init() {}

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        // The path lives in `NavigationModel`, so navigation written by an intent arrives
        // here too.
        NavigationStack(path: $navigationModel.path) {
            Group {
                if incompleteTodos.isEmpty {
                    emptyView
                } else {
                    todoList
                }
            }
            .navigationTitle(.copy("Todos"))
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .todoDetail(let todo):
                    WatchTodoDetailView(todo: todo)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationModel.showAddTodo()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTodoButton")
                    .accessibilityLabel(.copy("Add todo"))
                }
            }
            // Closed by `AddTodoIntent` on success, as on iOS.
            .sheet(isPresented: $navigationModel.showingAddTodo) {
                WatchAddTodoView()
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
        // Partitioned in one pass with a single `Date()`: the watch has little CPU to spare.
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
