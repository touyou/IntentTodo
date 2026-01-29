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

    public func fetch(where predicate: (TodoItem) -> Bool) throws -> [TodoItem] {
        todos.values.filter(predicate)
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
