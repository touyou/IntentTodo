//
//  TodoEntityQuery.swift
//  IntentTodo
//

import AppIntents
import Foundation
import os.log
import Repository
import SwiftData

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoEntityQuery")

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
            guard let uuid = UUID(uuidString: identifier) else {
                // 不正な UUID は呼び出し側 (Shortcuts / Live Activity) のバグの兆候。
                // 削除済 todo (fetch nil) は正常系なので、ここで区別してログを残す。
                logger.warning("entities(for:) received invalid UUID string: \(identifier, privacy: .public)")
                return nil
            }
            guard let todoItem = try repo.fetch(by: uuid) else {
                return nil  // 既に削除済み (CloudKit merge 等)。正常系なので無音。
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
