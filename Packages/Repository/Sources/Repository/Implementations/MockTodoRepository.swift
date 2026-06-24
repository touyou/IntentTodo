//
//  MockTodoRepository.swift
//  IntentTodo
//

import Domain
import Foundation

/// A mock implementation of TodoRepositoryProtocol for testing purposes.
///
/// This implementation stores todo items in memory and is useful for unit tests
/// where persistence is not required.
@MainActor
public final class MockTodoRepository: TodoRepositoryProtocol {
    // MARK: - Storage

    private var todos: [UUID: TodoItem] = [:]

    // MARK: - Initialization

    public init() {}

    /// Creates a mock repository pre-populated with todo items.
    /// - Parameter initialTodos: The initial todo items to populate.
    public init(initialTodos: [TodoItem]) {
        todos = Dictionary(uniqueKeysWithValues: initialTodos.map { ($0.id, $0) })
    }

    // MARK: - Create

    public func create(_ todo: TodoItem) throws {
        todos[todo.id] = todo
    }

    // MARK: - Read

    public func fetchAll() throws -> [TodoItem] {
        Array(todos.values)
    }

    public func fetch(by id: UUID) throws -> TodoItem? {
        todos[id]
    }

    public func fetchIncomplete() throws -> [TodoItem] {
        todos.values
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func fetchCompleted() throws -> [TodoItem] {
        todos.values
            .filter { $0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func fetchFavorites() throws -> [TodoItem] {
        todos.values
            .filter { $0.isFavorite }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func fetchMostUrgentIncomplete() throws -> TodoItem? {
        todos.values
            .filter { !$0.isCompleted && $0.dueDate != nil }
            .min { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    public func incompleteCount() throws -> Int {
        todos.values.lazy.filter { !$0.isCompleted }.count
    }

    // MARK: - Update

    public func update(_ todo: TodoItem) throws {
        guard todos[todo.id] != nil else {
            throw RepositoryError.notFound(id: todo.id)
        }
        todos[todo.id] = todo
    }

    // MARK: - Delete

    public func delete(_ todo: TodoItem) throws {
        guard todos.removeValue(forKey: todo.id) != nil else {
            throw RepositoryError.notFound(id: todo.id)
        }
    }

    public func delete(by id: UUID) throws {
        guard todos.removeValue(forKey: id) != nil else {
            throw RepositoryError.notFound(id: id)
        }
    }
}
