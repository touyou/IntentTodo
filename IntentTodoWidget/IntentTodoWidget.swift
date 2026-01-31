//
//  IntentTodoWidget.swift
//  IntentTodoWidget
//
//  Home screen widget for displaying todos.
//

import AppIntents
import Domain
import Repository
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

// MARK: - Model Container for Widget

private let widgetModelContainer: ModelContainer = {
    let schema = Schema([TodoItem.self, SubTask.self, Category.self])
    let config = ModelConfiguration(schema: schema)
    // swiftlint:disable:next force_try
    return try! ModelContainer(for: schema, configurations: [config])
}()

// MARK: - Timeline Provider

struct TodoWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TodoWidgetEntry
    typealias Intent = TodoWidgetConfigurationIntent

    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            todos: [
                TodoAppEntity(id: "1", title: "Sample Todo", isCompleted: false),
                TodoAppEntity(id: "2", title: "Another Todo", isCompleted: true, dueDate: Date())
            ],
            configuration: TodoWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> TodoWidgetEntry {
        await fetchEntry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<TodoWidgetEntry> {
        let entry = await fetchEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    @MainActor
    private func fetchEntry(for configuration: Intent) async -> TodoWidgetEntry {
        do {
            let repository = SwiftDataTodoRepository(modelContext: widgetModelContainer.mainContext)
            let todos = try await repository.fetchAll()

            let filteredTodos: [TodoItem]
            switch configuration.filter {
            case .all:
                filteredTodos = todos
            case .incomplete:
                filteredTodos = todos.filter { !$0.isCompleted }
            case .favorites:
                filteredTodos = todos.filter { $0.isFavorite }
            case .dueToday:
                filteredTodos = todos.filter {
                    guard let dueDate = $0.dueDate else { return false }
                    return Calendar.current.isDateInToday(dueDate)
                }
            }

            let sortedTodos = filteredTodos.sorted { lhs, rhs in
                if let lhsDue = lhs.dueDate, let rhsDue = rhs.dueDate {
                    return lhsDue < rhsDue
                }
                if lhs.dueDate != nil { return true }
                if rhs.dueDate != nil { return false }
                return lhs.createdAt > rhs.createdAt
            }

            let entities = sortedTodos.prefix(10).map { TodoAppEntity(from: $0) }

            return TodoWidgetEntry(
                date: Date(),
                todos: Array(entities),
                configuration: configuration
            )
        } catch {
            return TodoWidgetEntry(
                date: Date(),
                todos: [],
                configuration: configuration
            )
        }
    }
}

// MARK: - Widget Entry

/// Entry for the todo widget timeline.
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [TodoAppEntity]
    let configuration: TodoWidgetConfigurationIntent
}

// MARK: - Widget Definition

struct IntentTodoWidget: Widget {
    let kind: String = "IntentTodoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TodoWidgetConfigurationIntent.self,
            provider: TodoWidgetProvider()
        ) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Todo List")
        .description("View your todos at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    IntentTodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now,
        todos: [
            TodoAppEntity(id: "1", title: "Buy groceries", isCompleted: false, dueDate: Date()),
            TodoAppEntity(id: "2", title: "Call mom", isCompleted: false),
            TodoAppEntity(id: "3", title: "Finish report", isCompleted: true)
        ],
        configuration: TodoWidgetConfigurationIntent()
    )
}

#Preview(as: .systemMedium) {
    IntentTodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now,
        todos: [
            TodoAppEntity(id: "1", title: "Buy groceries", isCompleted: false, dueDate: Date()),
            TodoAppEntity(id: "2", title: "Call mom", isCompleted: false),
            TodoAppEntity(
                id: "3",
                title: "Finish report",
                isCompleted: true,
                dueDate: Date().addingTimeInterval(-3600)
            )
        ],
        configuration: TodoWidgetConfigurationIntent()
    )
}
