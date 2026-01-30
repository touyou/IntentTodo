//
//  IntentTodoWidget.swift
//  IntentTodoWidget
//
//  Widget extension for IntentTodo app.
//  Displays today's todos, incomplete count, and quick access.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import Domain
import TodoAppIntents

// MARK: - Widget Entry

/// Timeline entry for todo widgets.
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [TodoWidgetItem]
    let incompleteCount: Int
    let dueSoonCount: Int

    /// Empty entry for placeholder.
    static var placeholder: TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            todos: [
                TodoWidgetItem(id: "1", title: "Sample Todo 1", isCompleted: false, dueDate: nil),
                TodoWidgetItem(id: "2", title: "Sample Todo 2", isCompleted: false, dueDate: Date())
            ],
            incompleteCount: 5,
            dueSoonCount: 2
        )
    }
}

/// Lightweight todo representation for widgets.
struct TodoWidgetItem: Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?

    var isDueSoon: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate.timeIntervalSinceNow <= 3600 && dueDate.timeIntervalSinceNow > 0
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
}

// MARK: - Timeline Provider

struct TodoWidgetProvider: TimelineProvider {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([TodoItem.self, SubTask.self, Category.self])
        let config = ModelConfiguration(schema: schema)
        // swiftlint:disable:next force_try
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> TodoWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let entry = makeEntry()

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    @MainActor
    private func makeEntry() -> TodoWidgetEntry {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.createdAt, order: .reverse)]
        )

        let todos: [TodoItem]
        do {
            todos = try context.fetch(descriptor)
        } catch {
            todos = []
        }

        let widgetItems = todos.prefix(5).map { todo in
            TodoWidgetItem(
                id: todo.id.uuidString,
                title: todo.title,
                isCompleted: todo.isCompleted,
                dueDate: todo.dueDate
            )
        }

        let dueSoonCount = todos.filter { todo in
            guard let dueDate = todo.dueDate else { return false }
            return dueDate.timeIntervalSinceNow <= 3600 && dueDate.timeIntervalSinceNow > 0
        }.count

        return TodoWidgetEntry(
            date: Date(),
            todos: Array(widgetItems),
            incompleteCount: todos.count,
            dueSoonCount: dueSoonCount
        )
    }
}

// MARK: - Widget Views

/// Small widget showing incomplete count.
struct SmallTodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.incompleteCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Incomplete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.dueSoonCount > 0 {
                Label("\(entry.dueSoonCount) due soon", systemImage: "clock.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Medium widget showing todo list.
struct MediumTodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Today's Todos", systemImage: "checklist")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(entry.incompleteCount) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.todos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundStyle(.green)
                        Text("All done!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.todos.prefix(3)) { todo in
                    TodoWidgetRow(todo: todo)
                }

                if entry.todos.count > 3 {
                    Text("+ \(entry.todos.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Large widget showing extended todo list.
struct LargeTodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Todos", systemImage: "checklist")
                    .font(.title3.bold())

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(entry.incompleteCount) incomplete")
                        .font(.caption)

                    if entry.dueSoonCount > 0 {
                        Text("\(entry.dueSoonCount) due soon")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Divider()

            if entry.todos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All caught up!")
                            .font(.headline)
                        Text("No incomplete todos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.todos) { todo in
                    TodoWidgetRow(todo: todo)
                    if todo.id != entry.todos.last?.id {
                        Divider()
                    }
                }
            }

            Spacer(minLength: 0)

            // Quick add button
            Button(intent: AddTodoIntent()) {
                Label("Add Todo", systemImage: "plus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Row view for a todo item in widget.
struct TodoWidgetRow: View {
    let todo: TodoWidgetItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
                .font(.body)

            Text(todo.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            Spacer()

            if let dueDate = todo.dueDate {
                dueDateLabel(dueDate)
            }
        }
    }

    @ViewBuilder
    private func dueDateLabel(_ date: Date) -> some View {
        if todo.isOverdue {
            Label(date.formatted(.dateTime.hour().minute()), systemImage: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        } else if todo.isDueSoon {
            Label(date.formatted(.dateTime.hour().minute()), systemImage: "clock.badge.exclamationmark")
                .font(.caption2)
                .foregroundStyle(.orange)
        } else {
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Configuration

struct IntentTodoWidget: Widget {
    let kind: String = "IntentTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            IntentTodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Todos")
        .description("View your incomplete todos at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Entry view that adapts to widget family.
struct IntentTodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodoWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodoWidgetView(entry: entry)
        case .systemMedium:
            MediumTodoWidgetView(entry: entry)
        case .systemLarge:
            LargeTodoWidgetView(entry: entry)
        default:
            MediumTodoWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct IntentTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        IntentTodoWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    IntentTodoWidget()
} timeline: {
    TodoWidgetEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    IntentTodoWidget()
} timeline: {
    TodoWidgetEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    IntentTodoWidget()
} timeline: {
    TodoWidgetEntry.placeholder
}
