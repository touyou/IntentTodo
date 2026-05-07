//
//  IntentTodoWidget.swift
//  IntentTodoWidget
//
//  Home screen widget for displaying todos.
//

import AppIntents
import Domain
import os.log
import Repository
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit
import WidgetUI

private let widgetLogger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoWidgetProvider")

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
            incompleteCount: 1,
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
            let repository = SwiftDataTodoRepository(modelContext: sharedWidgetModelContainer.mainContext)
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
            // 各 size view が独立して `todos.filter { !$0.isCompleted }.count` を
            // 走らせていた旧実装を、Provider 側で 1 回 precompute する形に集約。
            let incompleteCount = sortedTodos.lazy.filter { !$0.isCompleted }.count

            return TodoWidgetEntry(
                date: Date(),
                todos: Array(entities),
                incompleteCount: incompleteCount,
                configuration: configuration,
                loadFailed: false
            )
        } catch {
            widgetLogger.error("fetchEntry failed: \(String(reflecting: error))")
            return TodoWidgetEntry(
                date: Date(),
                todos: [],
                incompleteCount: 0,
                configuration: configuration,
                loadFailed: true
            )
        }
    }
}

// MARK: - Widget Entry

/// Entry for the todo widget timeline.
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todos: [TodoAppEntity]
    /// 全 todos のうち未完了件数。各 size view が個別に filter+count せず、Provider
    /// が 1 回計算した値をそのまま参照するために持つ。
    let incompleteCount: Int
    let configuration: TodoWidgetConfigurationIntent
    /// SwiftData fetch が失敗したかどうか。true のときは View 側で空表示ではなく
    /// 「読み込めません」表示にして、空 ("All done!") との誤認を防ぐ。
    var loadFailed: Bool = false
}

// MARK: - Widget Definition

struct IntentTodoWidget: Widget {
    let kind: String = "dev.touyou.IntentTodo.IntentTodoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TodoWidgetConfigurationIntent.self,
            provider: TodoWidgetProvider()
        ) { entry in
            TodoWidgetEntryView(
                todos: entry.todos,
                incompleteCount: entry.incompleteCount,
                loadFailed: entry.loadFailed
            )
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
        incompleteCount: 2,
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
        incompleteCount: 2,
        configuration: TodoWidgetConfigurationIntent()
    )
}
