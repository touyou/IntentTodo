//
//  TodoComplicationProvider.swift
//  WatchUI
//

import Domain
import os.log
import SwiftData
import WidgetKit

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoComplication")

/// Timeline provider that fetches todo data for complications.
public struct TodoComplicationProvider: TimelineProvider {
    /// `nil` when the store could not be opened.
    ///
    /// A complication provider is the one place where `fatalError` is the wrong
    /// answer: crashing the extension leaves the complication blank, which reads
    /// exactly like "nothing due". `loadFailed` already exists to say "unknown"
    /// on the watch face, so an unopenable store takes the same path as a failed
    /// fetch — visibly unavailable, retried on the short 5-minute policy.
    private let modelContainer: ModelContainer?

    public init() {
        do {
            self.modelContainer = try SharedModelContainer.createContainer()
        } catch {
            logger.critical("complication ModelContainer init failed: \(String(reflecting: error))")
            let nsError = error as NSError
            logger.critical("NSError domain=\(nsError.domain) code=\(nsError.code)")
            self.modelContainer = nil
        }
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
            // Retried sooner after a failure. Elapsed time, not a calendar unit.
            let nextUpdateMinutes = entry.loadFailed ? 5.0 : 15.0
            let nextUpdate = Date(timeIntervalSinceNow: nextUpdateMinutes * 60)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private static func makeEntry(using modelContainer: ModelContainer?) -> TodoComplicationEntry {
        guard let modelContainer else { return .unavailable() }
        // One fetch, aggregated in memory: cheaper than two queries at watch-sized counts,
        // and it keeps the aggregation in one place.
        let context = modelContainer.mainContext
        let allTodos: [TodoItem]
        do {
            allTodos = try context.fetch(FetchDescriptor<TodoItem>())
        } catch {
            // Reported as unavailable rather than empty, and retried sooner by the timeline
            // policy above.
            logger.error("complication fetch failed: \(String(reflecting: error))")
            return .unavailable()
        }

        let incompleteTodos = allTodos
            .filter { !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let nextDueTodo = incompleteTodos.first { $0.dueDate != nil }

        // `isDateInToday` answers this directly; computing day boundaries by hand would have
        // to deal with DST and could fail.
        let calendar = Calendar.current
        let todayTodos = allTodos.filter { calendar.isDateInToday($0.createdAt) }
        let completedToday = todayTodos.filter(\.isCompleted).count

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
