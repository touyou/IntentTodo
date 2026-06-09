//
//  CategoryEntityQuery.swift
//  IntentTodo
//

import AppIntents
import Domain
import Foundation
import SwiftData

/// A query for fetching category entities in App Intents.
///
/// Mirrors `TodoEntityQuery`: receives the process-scoped `ModelContainer` via
/// `@Dependency`. Categories are a small set, so queries fetch all and filter in
/// memory rather than pushing `Set.contains` predicates into SwiftData.
public struct CategoryEntityQuery: EntityQuery {
    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    private func fetchAll() throws -> [Domain.Category] {
        let descriptor = FetchDescriptor<Domain.Category>(sortBy: [SortDescriptor(\.name)])
        return try modelContainer.mainContext.fetch(descriptor)
    }

    @MainActor
    public func entities(for identifiers: [CategoryAppEntity.ID]) async throws -> [CategoryAppEntity] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        return try fetchAll()
            .filter { ids.contains($0.id) }
            .map { CategoryAppEntity(from: $0) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [CategoryAppEntity] {
        try fetchAll().map { CategoryAppEntity(from: $0) }
    }
}

// MARK: - EntityStringQuery

extension CategoryEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [CategoryAppEntity] {
        try fetchAll()
            .filter { $0.name.localizedStandardContains(string) }
            .map { CategoryAppEntity(from: $0) }
    }
}

// MARK: - EnumerableEntityQuery

extension CategoryEntityQuery: EnumerableEntityQuery {
    @MainActor
    public func allEntities() async throws -> [CategoryAppEntity] {
        try fetchAll().map { CategoryAppEntity(from: $0) }
    }
}
