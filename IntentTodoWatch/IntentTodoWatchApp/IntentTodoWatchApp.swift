//
//  IntentTodoWatchApp.swift
//  IntentTodoWatch
//
//  watchOS app for IntentTodo.
//  Provides quick todo management from the wrist.
//

import SwiftUI
import SwiftData
import Domain
import TodoAppIntents

@main
struct IntentTodoWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([TodoItem.self, SubTask.self, Category.self])
        let config = ModelConfiguration(schema: schema)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [config])
        modelContainer = container

        Task { @MainActor in
            IntentDependencies.shared.configure(modelContainer: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchTodoListView()
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Watch Todo List View

struct WatchTodoListView: View {
    @Query(
        filter: #Predicate<TodoItem> { !$0.isCompleted },
        sort: [SortDescriptor(\TodoItem.dueDate), SortDescriptor(\TodoItem.createdAt, order: .reverse)]
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
                }
            }
        }
    }

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

    private func isDueSoon(_ todo: TodoItem) -> Bool {
        guard let dueDate = todo.dueDate else { return false }
        return dueDate.timeIntervalSinceNow <= 3600 && dueDate.timeIntervalSinceNow > 0
    }
}

// MARK: - Watch Todo Row

struct WatchTodoRow: View {
    let todo: TodoItem

    private var entity: TodoAppEntity {
        TodoAppEntity(from: todo)
    }

    var body: some View {
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

// MARK: - Watch Due Date Label

struct WatchDueDateLabel: View {
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        !isCompleted && date < Date()
    }

    private var isDueSoon: Bool {
        !isCompleted && date.timeIntervalSinceNow <= 3600 && date.timeIntervalSinceNow > 0
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(formattedDate)
                .font(.caption2)
        }
        .foregroundStyle(color)
    }

    private var iconName: String {
        if isOverdue { return "exclamationmark.circle.fill" }
        if isDueSoon { return "clock.badge.exclamationmark" }
        return "calendar"
    }

    private var color: Color {
        if isOverdue { return .red }
        if isDueSoon { return .orange }
        return .secondary
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Watch Add Todo View

struct WatchAddTodoView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""

    private var addIntent: AddTodoIntent {
        AddTodoIntent(title: title)
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Todo title", text: $title)
                .textContentType(.none)

            Button(intent: addIntent) {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("New Todo")
    }
}

// MARK: - Watch Todo Detail View

struct WatchTodoDetailView: View {
    let todo: TodoItem

    private var entity: TodoAppEntity {
        TodoAppEntity(from: todo)
    }

    var body: some View {
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

                Button(intent: DeleteTodoIntent(todo: entity), role: .destructive) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Details")
    }
}

// MARK: - Previews

#Preview {
    WatchTodoListView()
}
