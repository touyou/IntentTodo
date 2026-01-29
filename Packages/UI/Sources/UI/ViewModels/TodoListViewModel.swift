//
//  TodoListViewModel.swift
//  IntentTodo
//

import Foundation
import SwiftUI
import TodoAppIntents

/// View model for the todo list view.
///
/// This view model manages the display state of the todo list.
/// Business logic is delegated to App Intents.
@MainActor
@Observable
public final class TodoListViewModel {
    // MARK: - Published State

    /// All todo items to display.
    public private(set) var todos: [TodoAppEntity] = []

    /// Whether the view is currently loading.
    public private(set) var isLoading = false

    /// Error message to display, if any.
    public var errorMessage: String?

    /// Current filter for the todo list.
    public var filter: TodoFilter = .all

    /// Current sort order for the todo list.
    public var sortOrder: TodoSortOrder = .createdAtDescending

    /// Search text for filtering todos.
    public var searchText = ""

    // MARK: - Computed Properties

    /// Filtered and sorted todos based on current settings.
    public var filteredTodos: [TodoAppEntity] {
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
        result = sortTodos(result, by: sortOrder)

        return result
    }

    /// Number of incomplete todos.
    public var incompleteCount: Int {
        todos.filter { !$0.isCompleted }.count
    }

    /// Number of favorite todos.
    public var favoriteCount: Int {
        todos.filter { $0.isFavorite }.count
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Actions

    /// Loads all todos from the repository.
    public func loadTodos() async {
        isLoading = true
        errorMessage = nil

        do {
            let repository = try IntentDependencies.shared.createRepository()
            let todoItems = try repository.fetchAll()
            todos = todoItems.map { TodoAppEntity(from: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refreshes the todo at the specified index after an intent completes.
    /// - Parameter entity: The updated entity from the intent result.
    public func updateTodo(_ entity: TodoAppEntity) {
        if let index = todos.firstIndex(where: { $0.id == entity.id }) {
            todos[index] = entity
        }
    }

    /// Removes a todo from the local list.
    /// - Parameter entity: The entity to remove.
    public func removeTodo(_ entity: TodoAppEntity) {
        todos.removeAll { $0.id == entity.id }
    }

    /// Adds a new todo to the local list.
    /// - Parameter entity: The entity to add.
    public func addTodo(_ entity: TodoAppEntity) {
        todos.insert(entity, at: 0)
    }

    /// Clears the error message.
    public func clearError() {
        errorMessage = nil
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
public enum TodoFilter: String, CaseIterable, Identifiable {
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
public enum TodoSortOrder: String, CaseIterable, Identifiable {
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
