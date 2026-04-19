//
//  TodoService.swift
//  TodoAppIntents
//
//  Unified access point for todo business logic. Registered via AppDependencyManager
//  and resolved by intents through @Dependency. The repository is injected at
//  construction time so intents do not need to instantiate it themselves.
//
//  Mutation-bearing methods automatically invoke WidgetReloader on exit via `defer`,
//  eliminating per-intent reload bookkeeping.
//

#if os(iOS) || os(macOS)
import CoreSpotlight
#endif
import Domain
import Foundation
import Repository
import SwiftData

// MARK: - Result Types

/// Payload returned after toggling a todo's completion.
@MainActor
public struct TodoToggleResult: Sendable {
    public let entity: TodoAppEntity
    public let isNowCompleted: Bool
}

/// Payload returned after snoozing a todo.
@MainActor
public struct TodoSnoozeResult: Sendable {
    public let entity: TodoAppEntity
    public let newDueDate: Date
    public let title: String
}

/// Payload returned after toggling the most urgent todo.
@MainActor
public struct UrgentTodoToggleResult: Sendable {
    public let title: String
    public let isNowCompleted: Bool
}

// MARK: - Service

/// Encapsulates all todo business logic used by App Intents and (future) Views.
///
/// Registration pattern:
/// ```swift
/// let repo = SwiftDataTodoRepository(modelContext: container.mainContext)
/// let service = TodoService(repository: repo)
/// AppDependencyManager.shared.add(dependency: service)
/// ```
@MainActor
public final class TodoService {
    // MARK: - Dependencies

    private let repository: any TodoRepositoryProtocol

    // MARK: - Initialization

    public init(repository: any TodoRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Mutation (with automatic widget reload)

    public func create(
        title: String,
        todoDescription: String?,
        dueDate: Date?,
        isFavorite: Bool
    ) throws -> TodoAppEntity {
        defer { WidgetReloader.reloadAllWidgets() }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }
        let item = TodoItem(
            title: trimmed,
            todoDescription: todoDescription,
            isFavorite: isFavorite,
            dueDate: dueDate
        )
        try repository.create(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return entity
    }

    public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try resolve(todoId: todoId)
        item.isCompleted.toggle()
        item.modifiedAt = Date()
        try repository.update(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return TodoToggleResult(entity: entity, isNowCompleted: item.isCompleted)
    }

    public func toggleFavorite(todoId: String) throws -> TodoAppEntity {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try resolve(todoId: todoId)
        item.isFavorite.toggle()
        item.modifiedAt = Date()
        try repository.update(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return entity
    }

    public func delete(todoId: String) throws {
        defer { WidgetReloader.reloadAllWidgets() }
        guard let uuid = UUID(uuidString: todoId) else {
            throw IntentError.validation("Invalid todo ID")
        }
        try repository.delete(by: uuid)
        deindexSpotlight(id: todoId)
    }

    public func snooze(
        todoId: String,
        by interval: TimeInterval = 30 * 60
    ) throws -> TodoSnoozeResult {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try resolve(todoId: todoId)
        guard let currentDueDate = item.dueDate else {
            throw IntentError.notFound("Todo has no due date")
        }
        let newDueDate = currentDueDate.addingTimeInterval(interval)
        item.dueDate = newDueDate
        item.modifiedAt = Date()
        try repository.update(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return TodoSnoozeResult(
            entity: entity,
            newDueDate: newDueDate,
            title: item.title
        )
    }

    /// Picks the earliest-due incomplete todo and toggles its completion.
    /// Returns `nil` when there is no matching todo.
    ///
    /// Used by `ToggleUrgentTodoIntent` (Control Center quick action).
    public func toggleMostUrgentTodo() throws -> UrgentTodoToggleResult? {
        defer { WidgetReloader.reloadAllWidgets() }
        guard let item = try repository.fetchMostUrgentIncomplete() else {
            return nil
        }
        let title = item.title
        item.isCompleted.toggle()
        item.modifiedAt = Date()
        try repository.update(item)
        reindexSpotlight(TodoAppEntity(from: item))
        return UrgentTodoToggleResult(title: title, isNowCompleted: item.isCompleted)
    }

    // MARK: - Read (no widget reload)

    public func listTodos(filter: TodoFilterType) throws -> [TodoAppEntity] {
        let items: [TodoItem]
        switch filter {
        case .all, .completed:
            items = try repository.fetchAll()
        case .incomplete:
            items = try repository.fetchIncomplete()
        case .favorites:
            items = try repository.fetchFavorites()
        }
        return items.map { TodoAppEntity(from: $0) }
    }

    public func incompleteCount() throws -> Int {
        try repository.fetchIncomplete().count
    }

    // MARK: - Spotlight

    /// Populate Spotlight with every todo currently in the store. Call once on
    /// app launch — `IndexedEntity` conformance alone is not enough for
    /// Spotlight to discover entities (it covers Apple Intelligence surfaces).
    public func indexAllForSpotlight() async {
        #if os(iOS) || os(macOS)
        do {
            let entities = try listTodos(filter: .all)
            try await CSSearchableIndex.default().indexAppEntities(entities)
        } catch {
            // Non-fatal: Spotlight just won't show entries that failed to index.
        }
        #endif
    }

    // MARK: - Private

    private func resolve(todoId: String) throws -> TodoItem {
        guard let uuid = UUID(uuidString: todoId) else {
            throw IntentError.validation("Invalid todo ID")
        }
        guard let item = try repository.fetch(by: uuid) else {
            throw IntentError.notFound("Todo not found")
        }
        return item
    }

    /// Add / update a single todo in Spotlight. Fire-and-forget; Spotlight
    /// failures must not surface to the Intent caller.
    private func reindexSpotlight(_ entity: TodoAppEntity) {
        #if os(iOS) || os(macOS)
        Task {
            try? await CSSearchableIndex.default().indexAppEntities([entity])
        }
        #endif
    }

    /// Remove a deleted todo from Spotlight.
    private func deindexSpotlight(id: String) {
        #if os(iOS) || os(macOS)
        Task {
            try? await CSSearchableIndex.default().deleteAppEntities(
                identifiedBy: [id],
                ofType: TodoAppEntity.self
            )
        }
        #endif
    }
}

// MARK: - Factory

public extension TodoService {
    /// Convenience factory for a SwiftData-backed service. Lets callers avoid
    /// importing `Repository` directly — handy for targets (watchOS app,
    /// Widget Extension) that don't link the Repository product.
    @MainActor
    static func swiftDataBacked(container: ModelContainer) -> TodoService {
        TodoService(repository: SwiftDataTodoRepository(modelContext: container.mainContext))
    }
}
