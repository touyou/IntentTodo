//
//  SubTaskEntityQuery.swift
//  IntentTodo
//

import AppIntents
import Domain
import Foundation
import SwiftData

/// A query for fetching sub-task entities in App Intents.
///
/// Mirrors `TodoEntityQuery` / `CategoryEntityQuery`: receives the process-scoped
/// `ModelContainer` via `@Dependency` and resolves sub-tasks from the store.
public struct SubTaskEntityQuery: EntityQuery {
    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    private func fetchAll() throws -> [SubTask] {
        let descriptor = FetchDescriptor<SubTask>(sortBy: [SortDescriptor(\.orderIndex)])
        return try modelContainer.mainContext.fetch(descriptor)
    }

    @MainActor
    public func entities(for identifiers: [SubTaskAppEntity.ID]) async throws -> [SubTaskAppEntity] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        return try fetchAll()
            .filter { ids.contains($0.id) }
            .map { SubTaskAppEntity(from: $0) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [SubTaskAppEntity] {
        try fetchAll()
            .filter { !$0.isCompleted }
            .map { SubTaskAppEntity(from: $0) }
    }

    /// Builds representations without walking back to the parent todo.
    @MainActor
    public func displayRepresentations(
        for identifiers: [SubTaskAppEntity.ID]
    ) async throws -> [SubTaskAppEntity.ID: DisplayRepresentation] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        return try fetchAll()
            .filter { ids.contains($0.id) }
            .reduce(into: [:]) { result, subTask in
                result[subTask.id.uuidString] = SubTaskAppEntity.makeDisplayRepresentation(
                    title: subTask.title,
                    isCompleted: subTask.isCompleted
                )
            }
    }
}

// MARK: - EntityStringQuery

extension SubTaskEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [SubTaskAppEntity] {
        try fetchAll()
            .filter { $0.title.localizedStandardContains(string) }
            .map { SubTaskAppEntity(from: $0) }
    }
}
