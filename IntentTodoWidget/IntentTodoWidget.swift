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
        // Elapsed time, not a calendar unit: going through `Calendar` would only add an
        // optional that can fail.
        let nextUpdate = Date(timeIntervalSinceNow: 15 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    @MainActor
    private func fetchEntry(for configuration: Intent) async -> TodoWidgetEntry {
        do {
            let repository = SwiftDataTodoRepository(modelContext: sharedWidgetModelContainer.mainContext)
            let todos = try repository.fetchAll()

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

            // Focus filtering applies to widgets too, through the same
            // `TodoFocusFilter.apply` the list uses so the two cannot disagree. The setting
            // arrives via the App Group; `perform()` runs in the app process, so this side
            // only reads.
            let focusFilter = TodoFocusFilter.loadFromSharedDefaults()
            let visibleTodos = focusFilter.apply(to: sortedTodos.map { TodoAppEntity(from: $0) })

            let entities = visibleTodos.prefix(10)
            // Counted here once, over the *filtered* todos: reporting the unfiltered total
            // next to a filtered list produces "no rows shown, 5 open".
            let incompleteCount = visibleTodos.lazy.filter { !$0.isCompleted }.count

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
    /// Precomputed so no size-specific view has to filter and count again.
    let incompleteCount: Int
    let configuration: TodoWidgetConfigurationIntent
    /// When the fetch failed, views say so rather than showing the empty state — "All
    /// done!" would be a lie.
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
        // `.systemExtraLargePortrait` is new in the 27 releases [Apple: wwdc2026-277]; the
        // deployment target is 27, so the list needs no availability check.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait])
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

#Preview(as: .systemExtraLargePortrait) {
    IntentTodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now,
        todos: (1...8).map { index in
            TodoAppEntity(
                id: "\(index)",
                title: "Todo \(index)",
                isCompleted: index.isMultiple(of: 4),
                dueDate: Date().addingTimeInterval(Double(index) * 3600)
            )
        },
        incompleteCount: 6,
        configuration: TodoWidgetConfigurationIntent()
    )
}
