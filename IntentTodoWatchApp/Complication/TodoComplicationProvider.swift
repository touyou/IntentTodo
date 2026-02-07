//
//  TodoComplicationProvider.swift
//  IntentTodoWatchApp
//
//  Timeline provider for todo complications.
//

import Domain
import SwiftData
import WidgetKit

/// Timeline provider that fetches todo data for complications.
struct TodoComplicationProvider: TimelineProvider {
    private let modelContainer: ModelContainer

    init() {
        // swiftlint:disable:next force_try
        self.modelContainer = try! SharedModelContainer.createContainer()
    }

    func placeholder(in context: Context) -> TodoComplicationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoComplicationEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoComplicationEntry>) -> Void) {
        let entry = makeEntry()

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    @MainActor
    private func makeEntry() -> TodoComplicationEntry {
        let context = modelContainer.mainContext

        // Fetch incomplete todos
        let incompleteDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate)]
        )

        let incompleteTodos: [TodoItem]
        do {
            incompleteTodos = try context.fetch(incompleteDescriptor)
        } catch {
            incompleteTodos = []
        }

        // Find next due todo
        let nextDueTodo = incompleteTodos.first { $0.dueDate != nil }

        // Today's stats
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let todayDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { item in
                item.createdAt >= startOfDay && item.createdAt < endOfDay
            }
        )

        let todayTodos: [TodoItem]
        do {
            todayTodos = try context.fetch(todayDescriptor)
        } catch {
            todayTodos = []
        }

        let completedToday = todayTodos.filter { $0.isCompleted }.count

        return TodoComplicationEntry(
            date: Date(),
            incompleteCount: incompleteTodos.count,
            nextDueDate: nextDueTodo?.dueDate,
            nextDueTitle: nextDueTodo?.title,
            completedToday: completedToday,
            totalToday: todayTodos.count
        )
    }
}
