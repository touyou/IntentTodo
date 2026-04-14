//
//  TodoEntityQuery.swift
//  IntentTodo
//

import AppIntents
import Foundation
import Repository
import SwiftData

/// A query for fetching todo entities in App Intents.
///
/// `@Dependency var modelContainer` で process-scoped に登録された ModelContainer を
/// 受け取り、そのたびに repository を組み立てる（legacy `IntentDependencies` singleton
/// 経由での dual-container 問題を回避）。
public struct TodoEntityQuery: EntityQuery {
    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    private func repository() -> any TodoRepositoryProtocol {
        SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
    }

    @MainActor
    public func entities(for identifiers: [TodoAppEntity.ID]) async throws -> [TodoAppEntity] {
        let repo = repository()
        return try identifiers.compactMap { identifier in
            guard let uuid = UUID(uuidString: identifier),
                  let todoItem = try repo.fetch(by: uuid) else {
                return nil
            }
            return TodoAppEntity(from: todoItem)
        }
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        try repository().fetchIncomplete().map { TodoAppEntity(from: $0) }
    }
}

// MARK: - EntityStringQuery

extension TodoEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        let lowercasedQuery = string.lowercased()
        return try repository().fetchAll()
            .filter { $0.title.lowercased().contains(lowercasedQuery) }
            .map { TodoAppEntity(from: $0) }
    }
}

// MARK: - EnumerableEntityQuery

extension TodoEntityQuery: EnumerableEntityQuery {
    @MainActor
    public func allEntities() async throws -> [TodoAppEntity] {
        try repository().fetchAll().map { TodoAppEntity(from: $0) }
    }
}
