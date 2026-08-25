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

            // 集中モードの絞り込みはウィジェットにも効かせる。アプリ側と同じ
            // `TodoFocusFilter.apply` を通すので、一覧とウィジェットで結果がずれない。
            // 設定は App Group の UserDefaults 経由で受け取る（Focus filter の
            // `perform()` はアプリプロセスで走るため、ここでは読むだけ）。
            let focusFilter = TodoFocusFilter.loadFromSharedDefaults()
            let visibleTodos = focusFilter.apply(to: sortedTodos.map { TodoAppEntity(from: $0) })

            let entities = visibleTodos.prefix(10)
            // 各 size view が独立して `todos.filter { !$0.isCompleted }.count` を
            // 走らせていた旧実装を、Provider 側で 1 回 precompute する形に集約。
            // 件数も絞り込み後の母数で数える（絞られた一覧に対して全体の件数を出すと
            // 「表示 0 件なのに未完了 5 件」という食い違った表示になる）。
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
        // `.systemExtraLargePortrait` は iOS/macOS 27 で追加された縦長ファミリー
        // （WWDC 2026 #277）。本ブランチはデプロイメントターゲットが 27 なので
        // `#available` での組み立ては不要。
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
