//
//  TodoListViewModel.swift
//  IntentTodo
//

import Domain
import Foundation
import TodoAppIntents

/// View model for the todo list view.
///
/// This view model manages **UI state only** (filter, sort, search).
/// Business logic (CRUD operations) is handled by App Intents.
///
/// ## Responsibilities
/// - Filter state management
/// - Sort order management
/// - Search text management
/// - Filtering and sorting logic (UI-specific, not used by Siri/Shortcuts)
/// - Caching `TodoAppEntity` snapshots from `@Query` updates
@MainActor
@Observable
public final class TodoListViewModel {
    // MARK: - UI State

    /// Current filter for the todo list.
    public var filter: TodoFilter = .all

    /// Current sort order for the todo list.
    public var sortOrder: TodoSortOrder = .createdAtDescending

    /// Search text for filtering todos.
    public var searchText = ""

    // MARK: - Cached Entities

    /// `@Query` から渡される `TodoItem` を `TodoAppEntity` に変換したキャッシュ。
    /// View は `.onChange(of: todoItems, initial: true) { update(from:) }` で
    /// 更新する。これにより entity 化のコストを body 評価のたびではなく Query
    /// 更新時のみに限定できる (1,000 件規模でスクロール時のカクつきを抑える)。
    public private(set) var entities: [TodoAppEntity] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Cache Update

    /// Updates the cached entity snapshot from the latest `@Query` result.
    public func update(from todos: [TodoItem]) {
        entities = todos.map { TodoAppEntity(from: $0) }
    }

    // MARK: - Filtering & Sorting

    /// Filters and sorts todos based on current UI state.
    ///
    /// This logic is UI-specific and not exposed to Siri/Shortcuts.
    /// - Parameter todos: The source todos to filter and sort.
    /// - Returns: Filtered and sorted todos.
    public func filteredTodos(from todos: [TodoAppEntity]) -> [TodoAppEntity] {
        var result = todos

        // Apply filter
        switch filter {
        case .all:
            break
        case .incomplete:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.title.lowercased().contains(query) }
        }

        // Apply sort
        return sortTodos(result, by: sortOrder)
    }

    // MARK: - Statistics

    /// Number of incomplete todos.
    public func incompleteCount(from todos: [TodoAppEntity]) -> Int {
        todos.filter { !$0.isCompleted }.count
    }

    /// Number of favorite todos.
    public func favoriteCount(from todos: [TodoAppEntity]) -> Int {
        todos.filter { $0.isFavorite }.count
    }

    // MARK: - Private Helpers

    private func sortTodos(_ todos: [TodoAppEntity], by order: TodoSortOrder) -> [TodoAppEntity] {
        switch order {
        case .createdAtDescending:
            return todos.sorted { $0.createdAt > $1.createdAt }
        case .createdAtAscending:
            return todos.sorted { $0.createdAt < $1.createdAt }
        case .titleAscending:
            return todos.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return todos.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .dueDateAscending:
            return todos.sorted { compareDueDates($0.dueDate, $1.dueDate, ascending: true) }
        case .dueDateDescending:
            return todos.sorted { compareDueDates($0.dueDate, $1.dueDate, ascending: false) }
        }
    }

    private func compareDueDates(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case (nil, _):
            return !ascending
        case (_, nil):
            return ascending
        case let (date1?, date2?):
            return ascending ? date1 < date2 : date1 > date2
        }
    }
}

// MARK: - Supporting Types

/// Filter options for the todo list.
public enum TodoFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case incomplete
    case completed
    case favorites

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .incomplete: return "Incomplete"
        case .completed: return "Completed"
        case .favorites: return "Favorites"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .incomplete: return "circle"
        case .completed: return "checkmark.circle"
        case .favorites: return "star"
        }
    }
}

/// Sort options for the todo list.
public enum TodoSortOrder: String, CaseIterable, Identifiable, Sendable {
    case createdAtDescending
    case createdAtAscending
    case titleAscending
    case titleDescending
    case dueDateAscending
    case dueDateDescending

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .createdAtDescending: return "Newest First"
        case .createdAtAscending: return "Oldest First"
        case .titleAscending: return "Title A-Z"
        case .titleDescending: return "Title Z-A"
        case .dueDateAscending: return "Due Date (Earliest)"
        case .dueDateDescending: return "Due Date (Latest)"
        }
    }
}
