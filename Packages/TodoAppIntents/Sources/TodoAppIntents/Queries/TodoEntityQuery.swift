//
//  TodoEntityQuery.swift
//  IntentTodo
//

import AppIntents
#if os(iOS) || os(macOS) || os(visionOS)
import CoreSpotlight
#endif
import Foundation
import os.log
import Repository
import SwiftData

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoEntityQuery")

/// A query for fetching todo entities in App Intents.
///
/// Takes the `ModelContainer` registered in whichever process resolves the query and
/// builds a repository per call, so app and extension never share a stale container.
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
                // A malformed UUID means the caller is wrong; a missing todo does not.
                // Logged separately so the two are distinguishable.
                logger.warning("entities(for:) received invalid UUID string: \(identifier, privacy: .public)")
                return nil
            }
            guard let todoItem = try repo.fetch(by: uuid) else {
                return nil  // Already deleted (e.g. a CloudKit merge). Expected, so silent.
            }
            return TodoAppEntity(from: todoItem)
        }
    }

    /// The most recent incomplete todos, capped at `suggestedEntityLimit`.
    ///
    /// **Never return everything.** With a parameterised App Shortcut phrase the system
    /// creates one App Shortcut per suggested value — "If provided, an App Shortcut for
    /// each value of that type will be created" [Apple: wwdc2025-244 9:46] — so a few dozen
    /// open todos would fill Shortcuts and Spotlight. `allEntities()` is what serves the
    /// cases that genuinely need every row.
    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        try repository().fetchIncomplete()
            .prefix(Self.suggestedEntityLimit)
            .map { TodoAppEntity(from: $0) }
    }

    /// Matches the HIG guidance of "not more than ten" suggestions.
    static let suggestedEntityLimit = 10

    /// Returns display representations in bulk.
    ///
    /// The default implementation resolves full entities first; building straight from
    /// `TodoItem` skips constructing the `CategoryAppEntity` that never gets shown. Apple:
    /// "Return full representations; the system materializes only the components it needs"
    /// — which is what makes the deferred image closure pay off.
    @MainActor
    public func displayRepresentations(
        for identifiers: [TodoAppEntity.ID]
    ) async throws -> [TodoAppEntity.ID: DisplayRepresentation] {
        let repo = repository()
        var representations: [TodoAppEntity.ID: DisplayRepresentation] = [:]
        for identifier in identifiers {
            guard let uuid = UUID(uuidString: identifier),
                  let item = try repo.fetch(by: uuid) else {
                continue  // Already deleted, as in `entities(for:)`.
            }
            representations[identifier] = TodoAppEntity.makeDisplayRepresentation(
                title: item.title,
                isCompleted: item.isCompleted,
                isFavorite: item.isFavorite,
                dueDate: item.dueDate
            )
        }
        return representations
    }
}

// MARK: - EntityStringQuery

extension TodoEntityQuery: EntityStringQuery {
    /// The system does not filter for you. Comparison is `localizedStandardContains(_:)`:
    /// `lowercased().contains()` is locale-independent and treats kana forms and diacritics
    /// as different characters.
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        try repository().fetchAll()
            .filter { $0.title.localizedStandardContains(string) }
            .map { TodoAppEntity(from: $0) }
    }
}

// MARK: - EnumerableEntityQuery

extension TodoEntityQuery: EnumerableEntityQuery {
    /// Conforming to `EnumerableEntityQuery` is enough for Shortcuts to generate a
    /// "Find Todos" action; without this it appears with no description or category.
    public static var findIntentDescription: IntentDescription? {
        IntentDescription(
            "Finds todos and filters them by the conditions you specify.",
            categoryName: "Todos",
            searchKeywords: ["find", "search", "filter", "todo", "task"],
            resultValueName: "Todos"
        )
    }

    @MainActor
    public func allEntities() async throws -> [TodoAppEntity] {
        try repository().fetchAll().map { TodoAppEntity(from: $0) }
    }
}

// MARK: - IndexedEntityQuery (Spotlight reindexing)

#if os(iOS) || os(macOS) || os(visionOS)
/// Answers Spotlight's reindex requests — the receiving half of donating entities.
///
/// Apple: "If you donate app entities to a `CSSearchableIndex` using its
/// `indexAppEntities(_:priority:)` method, implement the `IndexedEntityQuery` protocol in
/// your entity's query object to handle reindexing." Without it, an index Spotlight decides
/// to rebuild stays empty until the app next launches and reindexes everything.
///
/// `indexDescription` is unused: there is only one index. These methods **cannot be
/// `@MainActor`** like the rest of the type, because `CSSearchableIndexDescription` is
/// non-Sendable; they stay nonisolated and hop inward instead.
extension TodoEntityQuery: IndexedEntityQuery {
    public func reindexEntities(
        for identifiers: [TodoAppEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await entities(for: identifiers)
        if !entities.isEmpty {
            try await TodoSpotlightIndex.index().indexAppEntities(entities)
        }

        // Requested ids that no longer resolve are dropped from the index too, otherwise
        // a request arriving right after a delete leaves a ghost in Spotlight.
        let resolved = Set(entities.map(\.id))
        let missing = identifiers.filter { !resolved.contains($0) }
        if !missing.isEmpty {
            try await TodoSpotlightIndex.index().deleteAppEntities(
                identifiedBy: missing,
                ofType: TodoAppEntity.self
            )
        }
        logger.info("reindexEntities indexed=\(entities.count) deleted=\(missing.count)")
    }

    public func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await allEntities()
        try await TodoSpotlightIndex.index().indexAppEntities(entities)
        logger.info("reindexAllEntities count=\(entities.count)")
    }
}
#endif
