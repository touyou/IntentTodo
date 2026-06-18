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
import os.log
import Repository
import SwiftData

private let spotlightLogger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoService.Spotlight")

// MARK: - Partial Update

/// Describes a single field's intent in a partial update.
///
/// Mirrors `IntentParameter.ValueState` (WWDC 2026 #344): `.unchanged` leaves the
/// stored value alone, while `.set` writes a new value. For optional fields the
/// `Value` is itself optional, so `.set(nil)` means "explicitly clear" — distinct
/// from `.unchanged` ("don't touch"). A plain `nil` check can't express that
/// difference; `FieldUpdate` makes it explicit end-to-end.
public enum FieldUpdate<Value>: Sendable where Value: Sendable {
    case unchanged
    case set(Value)
}

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
    public let id: String
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
    // MARK: - Constants

    /// `snooze` のデフォルト延長時間 (30 分)。SnoozeTodoIntent の description とも一致。
    public static let defaultSnoozeInterval: TimeInterval = 30 * 60

    // MARK: - Dependencies

    private let repository: any TodoRepositoryProtocol

    /// 進行中の Spotlight 操作 (id 単位)。連続トグルで前タスクをキャンセルし、
    /// 最新の reindex/deindex だけが Spotlight に反映されるようにする (race condition 対策)。
    private var inflightSpotlightTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Initialization

    public init(repository: any TodoRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Mutation (with automatic widget reload)

    public func create(
        title: String,
        todoDescription: String?,
        dueDate: Date?,
        isFavorite: Bool,
        estimatedDuration: TimeInterval? = nil,
        assigneeName: String? = nil,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil
    ) throws -> TodoAppEntity {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }
        defer { WidgetReloader.reloadAllWidgets() }
        let item = TodoItem(
            title: trimmed,
            todoDescription: todoDescription,
            isFavorite: isFavorite,
            dueDate: dueDate,
            estimatedDuration: estimatedDuration,
            assigneeName: assigneeName,
            locationName: locationName,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude
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

    /// Marks a todo as completed. Idempotent (unlike `toggleCompletion`): calling
    /// it on an already-completed todo is a no-op. Used by bulk-completion intents
    /// that operate over a collection of ids.
    @discardableResult
    public func markCompleted(todoId: String) throws -> TodoAppEntity {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try resolve(todoId: todoId)
        if !item.isCompleted {
            item.isCompleted = true
            item.modifiedAt = Date()
            try repository.update(item)
            reindexSpotlight(TodoAppEntity(from: item))
        }
        return TodoAppEntity(from: item)
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
        guard let uuid = UUID(uuidString: todoId) else {
            throw IntentError.validation("Invalid todo ID")
        }
        // Spotlight は idempotent。CloudKit merge で既に消えていて
        // repository.delete が throw した場合でも、ローカル index は消しておく方が
        // 整合性が取れるので defer で unconditional に呼ぶ。
        defer {
            deindexSpotlight(id: todoId)
            WidgetReloader.reloadAllWidgets()
        }
        try repository.delete(by: uuid)
    }

    public func snooze(
        todoId: String,
        by interval: TimeInterval = TodoService.defaultSnoozeInterval
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

    /// Applies a partial update to a todo. Each field is a `FieldUpdate`, so the
    /// caller can leave a field untouched (`.unchanged`), set a new value
    /// (`.set(value)`), or — for optional fields — explicitly clear it (`.set(nil)`).
    /// Used by `UpdateTodoIntent`, which derives each `FieldUpdate` from the
    /// corresponding parameter's `valueState` (WWDC 2026 #344).
    @discardableResult
    public func update(
        todoId: String,
        title: FieldUpdate<String> = .unchanged,
        todoDescription: FieldUpdate<String?> = .unchanged,
        dueDate: FieldUpdate<Date?> = .unchanged,
        isFavorite: FieldUpdate<Bool> = .unchanged,
        estimatedDuration: FieldUpdate<TimeInterval?> = .unchanged,
        assigneeName: FieldUpdate<String?> = .unchanged
    ) throws -> TodoAppEntity {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try resolve(todoId: todoId)

        if case .set(let value) = title {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw IntentError.validation("Todo title cannot be empty")
            }
            item.title = trimmed
        }
        if case .set(let value) = todoDescription { item.todoDescription = value }
        if case .set(let value) = dueDate { item.dueDate = value }
        if case .set(let value) = isFavorite { item.isFavorite = value }
        if case .set(let value) = estimatedDuration { item.estimatedDuration = value }
        if case .set(let value) = assigneeName { item.assigneeName = value }

        item.modifiedAt = Date()
        try repository.update(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return entity
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
        let id = item.id.uuidString
        item.isCompleted.toggle()
        item.modifiedAt = Date()
        try repository.update(item)
        reindexSpotlight(TodoAppEntity(from: item))
        return UrgentTodoToggleResult(id: id, title: title, isNowCompleted: item.isCompleted)
    }

    // MARK: - Read (no widget reload)

    public func listTodos(filter: TodoFilterType) throws -> [TodoAppEntity] {
        let items: [TodoItem]
        switch filter {
        case .all:
            items = try repository.fetchAll()
        case .completed:
            items = try repository.fetchCompleted()
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
            spotlightLogger.info("indexAllForSpotlight start count=\(entities.count)")
            try await CSSearchableIndex.default().indexAppEntities(entities)
            spotlightLogger.info("indexAllForSpotlight done count=\(entities.count)")
        } catch {
            spotlightLogger.error("indexAllForSpotlight failed: \(String(reflecting: error))")
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
    ///
    /// 同じ id に対して前回の reindex/deindex Task が残っていればキャンセルしてから
    /// 新しい Task を走らせる。これで連続トグル時に古い状態が後から上書きする
    /// race condition を避ける。
    private func reindexSpotlight(_ entity: TodoAppEntity) {
        #if os(iOS) || os(macOS)
        let id = entity.id
        inflightSpotlightTasks[id]?.cancel()
        inflightSpotlightTasks[id] = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in self?.inflightSpotlightTasks.removeValue(forKey: id) }
            }
            do {
                try await CSSearchableIndex.default().indexAppEntities([entity])
                if Task.isCancelled { return }
                spotlightLogger.debug("reindex ok id=\(id)")
            } catch is CancellationError {
                return
            } catch {
                Self.logSpotlight(error, action: "reindex", id: id)
            }
        }
        #endif
    }

    /// Remove a deleted todo from Spotlight. race 対策は `reindexSpotlight` と同じ。
    private func deindexSpotlight(id: String) {
        #if os(iOS) || os(macOS)
        inflightSpotlightTasks[id]?.cancel()
        inflightSpotlightTasks[id] = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in self?.inflightSpotlightTasks.removeValue(forKey: id) }
            }
            do {
                try await CSSearchableIndex.default().deleteAppEntities(
                    identifiedBy: [id],
                    ofType: TodoAppEntity.self
                )
                if Task.isCancelled { return }
                spotlightLogger.debug("deindex ok id=\(id)")
            } catch is CancellationError {
                return
            } catch {
                Self.logSpotlight(error, action: "deindex", id: id)
            }
        }
        #endif
    }

    #if os(iOS) || os(macOS)
    /// CSSearchableIndex のエラーは `NSError(domain: CSSearchableIndexErrorDomain)`
    /// で `code` を見れば quotaExceeded(1) / invalidIndexState(2) /
    /// userInteractionRequired(3) / indexUnavailable(4) を区別できる。
    /// 一律 `error` で潰さず、判別できるようにログに出しておくと運用で原因切り分けがしやすい。
    private static func logSpotlight(_ error: Error, action: String, id: String) {
        let nsError = error as NSError
        spotlightLogger.error(
            "spotlight \(action) failed id=\(id, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code): \(String(reflecting: error))"
        )
    }
    #endif
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
