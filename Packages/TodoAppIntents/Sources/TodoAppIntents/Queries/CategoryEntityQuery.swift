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

    /// Name this query reports to `QueryCallLog`.
    static let logName = "CategoryEntityQuery"

    @MainActor
    private func fetchAll() throws -> [Domain.Category] {
        let descriptor = FetchDescriptor<Domain.Category>(sortBy: [SortDescriptor(\.name)])
        return try modelContainer.mainContext.fetch(descriptor)
    }

    @MainActor
    public func entities(for identifiers: [CategoryAppEntity.ID]) async throws -> [CategoryAppEntity] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        let entities = try fetchAll()
            .filter { ids.contains($0.id) }
            .map { CategoryAppEntity(from: $0) }
        QueryCallLog.record(
            query: Self.logName,
            caller: #function,
            requested: identifiers.count,
            returned: entities.count
        )
        return entities
    }

    @MainActor
    public func suggestedEntities() async throws -> [CategoryAppEntity] {
        let entities = try fetchAll().map { CategoryAppEntity(from: $0) }
        QueryCallLog.record(query: Self.logName, caller: #function, returned: entities.count)
        return entities
    }

    /// Builds representations straight from the model: the name is all they need, so no
    /// entity has to be constructed.
    @MainActor
    public func displayRepresentations(
        for identifiers: [CategoryAppEntity.ID]
    ) async throws -> [CategoryAppEntity.ID: DisplayRepresentation] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        let representations: [CategoryAppEntity.ID: DisplayRepresentation] = try fetchAll()
            .filter { ids.contains($0.id) }
            .reduce(into: [:]) { result, category in
                result[category.id.uuidString] = CategoryAppEntity.makeDisplayRepresentation(
                    name: category.name
                )
            }
        QueryCallLog.record(
            query: Self.logName,
            caller: #function,
            requested: identifiers.count,
            returned: representations.count
        )
        return representations
    }
}

// MARK: - EntityStringQuery

extension CategoryEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [CategoryAppEntity] {
        let entities = try fetchAll()
            .filter { $0.name.localizedStandardContains(string) }
            .map { CategoryAppEntity(from: $0) }
        QueryCallLog.record(query: Self.logName, caller: #function, returned: entities.count)
        return entities
    }
}

// MARK: - EnumerableEntityQuery

extension CategoryEntityQuery: EnumerableEntityQuery {
    /// Describes the "Find Categories" action that Shortcuts generates from this query.
    public static var findIntentDescription: IntentDescription? {
        IntentDescription(
            "Finds the lists (categories) todos are organized into.",
            categoryName: "Todos",
            searchKeywords: ["find", "search", "category", "list"],
            resultValueName: "Categories"
        )
    }

    @MainActor
    public func allEntities() async throws -> [CategoryAppEntity] {
        let entities = try fetchAll().map { CategoryAppEntity(from: $0) }
        QueryCallLog.record(query: Self.logName, caller: #function, returned: entities.count)
        return entities
    }
}
