//
//  TodoComplicationProvider.swift
//  WatchUI
//

import Domain
import SwiftData
import WidgetKit

/// Timeline provider that fetches todo data for complications.
public struct TodoComplicationProvider: TimelineProvider {
    private let modelContainer: ModelContainer

    public init() {
        // swiftlint:disable:next force_try
        self.modelContainer = try! SharedModelContainer.createContainer()
    }

    public func placeholder(in context: Context) -> TodoComplicationEntry {
        .placeholder
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (TodoComplicationEntry) -> Void) {
        let container = modelContainer
        Task { @MainActor in
            completion(Self.makeEntry(using: container))
        }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodoComplicationEntry>) -> Void) {
        let container = modelContainer
        Task { @MainActor in
            let entry = Self.makeEntry(using: container)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private static func makeEntry(using modelContainer: ModelContainer) -> TodoComplicationEntry {
        let context = modelContainer.mainContext

        let incompleteDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        let incompleteTodos = (try? context.fetch(incompleteDescriptor)) ?? []
        let nextDueTodo = incompleteTodos.first { $0.dueDate != nil }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let todayDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { item in
                item.createdAt >= startOfDay && item.createdAt < endOfDay
            }
        )
        let todayTodos = (try? context.fetch(todayDescriptor)) ?? []
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
