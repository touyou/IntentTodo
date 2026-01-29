//
//  TodoRepositoryProtocol.swift
//  IntentTodo
//

import Domain
import Foundation

/// Protocol defining the interface for todo item data access.
///
/// Implementations of this protocol handle persistence of todo items,
/// whether through SwiftData, mock storage for testing, or other backends.
///
/// - Important: All implementations should be used on the MainActor
///   as SwiftData models are not Sendable.
@MainActor
public protocol TodoRepositoryProtocol {
    // MARK: - Create

    /// Creates a new todo item.
    /// - Parameter todo: The todo item to create.
    /// - Throws: If the creation fails.
    func create(_ todo: TodoItem) throws

    // MARK: - Read

    /// Fetches all todo items.
    /// - Returns: An array of all todo items.
    /// - Throws: If the fetch fails.
    func fetchAll() throws -> [TodoItem]

    /// Fetches a todo item by its ID.
    /// - Parameter id: The unique identifier of the todo item.
    /// - Returns: The todo item if found, `nil` otherwise.
    /// - Throws: If the fetch fails.
    func fetch(by id: UUID) throws -> TodoItem?

    /// Fetches todo items matching the given predicate.
    /// - Parameter predicate: The predicate to filter todo items.
    /// - Returns: An array of matching todo items.
    /// - Throws: If the fetch fails.
    func fetch(where predicate: (TodoItem) -> Bool) throws -> [TodoItem]

    // MARK: - Update

    /// Updates an existing todo item.
    /// - Parameter todo: The todo item with updated values.
    /// - Throws: If the update fails.
    func update(_ todo: TodoItem) throws

    // MARK: - Delete

    /// Deletes a todo item.
    /// - Parameter todo: The todo item to delete.
    /// - Throws: If the deletion fails.
    func delete(_ todo: TodoItem) throws

    /// Deletes a todo item by its ID.
    /// - Parameter id: The unique identifier of the todo item to delete.
    /// - Throws: If the deletion fails.
    func delete(by id: UUID) throws

    // MARK: - Convenience Methods

    /// Fetches all incomplete todo items.
    /// - Returns: An array of incomplete todo items.
    /// - Throws: If the fetch fails.
    func fetchIncomplete() throws -> [TodoItem]

    /// Fetches all favorite todo items.
    /// - Returns: An array of favorite todo items.
    /// - Throws: If the fetch fails.
    func fetchFavorites() throws -> [TodoItem]
}

// MARK: - Default Implementations

public extension TodoRepositoryProtocol {
    func fetchIncomplete() throws -> [TodoItem] {
        try fetch { !$0.isCompleted }
    }

    func fetchFavorites() throws -> [TodoItem] {
        try fetch { $0.isFavorite }
    }
}
