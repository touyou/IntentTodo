//
//  TodoRepositoryProtocol.swift
//  IntentTodo
//

import Domain
import Foundation

/// Protocol defining the interface for todo item data access.
///
/// Implementations persist todo items using SwiftData, in-memory mocks, or other
/// backends. Every query method is expected to push filtering down to the
/// underlying store (e.g. `#Predicate` for SwiftData) so callers never need to
/// load the full table into memory.
///
/// - Important: All implementations should be used on the MainActor
///   as SwiftData models are not Sendable.
@MainActor
public protocol TodoRepositoryProtocol {
    // MARK: - Create

    /// Creates a new todo item.
    func create(_ todo: TodoItem) throws

    // MARK: - Read

    /// Fetches all todo items, sorted by creation time (descending).
    func fetchAll() throws -> [TodoItem]

    /// Fetches a todo item by its ID. Returns `nil` when not found.
    func fetch(by id: UUID) throws -> TodoItem?

    /// Fetches all incomplete todo items, sorted by creation time (descending).
    func fetchIncomplete() throws -> [TodoItem]

    /// Fetches all completed todo items, sorted by creation time (descending).
    func fetchCompleted() throws -> [TodoItem]

    /// Fetches all favorite todo items, sorted by creation time (descending).
    func fetchFavorites() throws -> [TodoItem]

    /// Fetches the earliest-due incomplete todo (limit 1). Returns `nil`
    /// when no incomplete todo has a due date.
    func fetchMostUrgentIncomplete() throws -> TodoItem?

    // MARK: - Update

    /// Updates an existing todo item.
    func update(_ todo: TodoItem) throws

    // MARK: - Delete

    /// Deletes a todo item.
    func delete(_ todo: TodoItem) throws

    /// Deletes a todo item by its ID.
    func delete(by id: UUID) throws
}
