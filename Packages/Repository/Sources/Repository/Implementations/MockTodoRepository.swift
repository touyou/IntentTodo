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

    /// Categories reachable by `fetchCategory(by:)`. Populated from whatever the
    /// stored todos reference, plus anything a test registers explicitly.
    private var categories: [UUID: Domain.Category] = [:]

    // MARK: - Initialization

    public init() {}

    /// Creates a mock repository pre-populated with todo items.
    /// - Parameter initialTodos: The initial todo items to populate.
    public init(initialTodos: [TodoItem]) {
        todos = Dictionary(uniqueKeysWithValues: initialTodos.map { ($0.id, $0) })
        for todo in initialTodos {
            register(todo.category)
        }
    }

    /// Makes a category resolvable by `fetchCategory(by:)` without going through a todo.
    public func register(_ category: Domain.Category?) {
        guard let category else { return }
        categories[category.id] = category
    }

    // MARK: - Create

    public func create(_ todo: TodoItem) throws {
        todos[todo.id] = todo
        register(todo.category)
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

    public func fetchCategory(by id: UUID) throws -> Domain.Category? {
        categories[id]
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
