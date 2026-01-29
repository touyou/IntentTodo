//
//  TodoEntityQuery.swift
//  IntentTodo
//

import AppIntents
import Foundation
import Repository

/// A query for fetching todo entities in App Intents.
///
/// This query is used by Siri and Shortcuts to find and display todo items.
public struct TodoEntityQuery: EntityQuery {
    // MARK: - Initialization

    public init() {}

    // MARK: - EntityQuery Requirements

    @MainActor
    public func entities(for identifiers: [TodoAppEntity.ID]) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        var results: [TodoAppEntity] = []

        for identifier in identifiers {
            guard let uuid = UUID(uuidString: identifier),
                  let todoItem = try repository.fetch(by: uuid) else {
                continue
            }
            results.append(TodoAppEntity(from: todoItem))
        }

        return results
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchIncomplete()
        return todos.map { TodoAppEntity(from: $0) }
    }
}

// MARK: - EntityStringQuery

extension TodoEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        let allTodos = try repository.fetchAll()
        let lowercasedQuery = string.lowercased()

        return allTodos
            .filter { $0.title.lowercased().contains(lowercasedQuery) }
            .map { TodoAppEntity(from: $0) }
    }
}

// MARK: - EnumerableEntityQuery

extension TodoEntityQuery: EnumerableEntityQuery {
    @MainActor
    public func allEntities() async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchAll()
        return todos.map { TodoAppEntity(from: $0) }
    }
}
