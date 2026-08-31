//
//  TodoListSummaryEntity.swift
//  TodoAppIntents
//
//

import AppIntents
import Domain
import Foundation

/// A snapshot of the current todo list statistics, returned from `GetTodoSummaryIntent`.
///
/// Implemented as a `TransientAppEntity` — the entity is computed on demand,
/// not persisted or queryable. Shortcuts users can use the individual count
/// properties in conditional branches (e.g. "If Overdue Todos > 0, notify me").
public struct TodoListSummaryEntity: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo List Summary"

    // MARK: - Properties

    @Property(title: "Total Todos")
    public var totalCount: Int

    @Property(title: "Completed Todos")
    public var completedCount: Int

    @Property(title: "Pending Todos")
    public var pendingCount: Int

    @Property(title: "Overdue Todos")
    public var overdueCount: Int

    @Property(title: "Favorite Todos")
    public var favoriteCount: Int

    // MARK: - Display

    /// Siri reads this aloud, so the counts go through `^[...](inflect: true)` —
    /// the system then picks the right plural form per language instead of always
    /// saying "1 todos".
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "^[\(pendingCount) pending todo](inflect: true), \(overdueCount) overdue",
            subtitle: "^[\(totalCount) todo](inflect: true) total (\(completedCount) done, \(favoriteCount) starred)"
        )
    }

    // MARK: - Initialization

    public init() {}

    public init(
        totalCount: Int,
        completedCount: Int,
        pendingCount: Int,
        overdueCount: Int,
        favoriteCount: Int
    ) {
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.pendingCount = pendingCount
        self.overdueCount = overdueCount
        self.favoriteCount = favoriteCount
    }

    /// Computes the summary from a fetched set of todos.
    ///
    /// Kept here rather than inside `TodoService` so the same tally is shared by
    /// `GetTodoSummaryIntent` (service-backed) and `TodoSummarySnippetIntent`
    /// (store-backed, re-performed by the system after every snippet button tap).
    @MainActor
    public init(items: [TodoItem], now: Date = Date()) {
        let pending = items.filter { !$0.isCompleted }
        self.init(
            totalCount: items.count,
            completedCount: items.count - pending.count,
            pendingCount: pending.count,
            overdueCount: pending.filter { $0.dueDate.map { $0 < now } ?? false }.count,
            favoriteCount: items.filter(\.isFavorite).count
        )
    }
}
