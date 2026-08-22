//
//  TodoService.swift
//  TodoAppIntents
//
//  Unified access point for todo business logic. Registered via AppDependencyManager
//  and resolved by intents through @Dependency. The repository is injected at
//  construction time so intents do not need to instantiate it themselves.
//
//  Mutation-bearing methods automatically invoke `dataDidChange()` on exit via `defer`
//  (widget / control reload + App Shortcut パラメータ更新), eliminating per-intent
//  bookkeeping.
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
        defer { Self.dataDidChange() }
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
        defer { Self.dataDidChange() }
        let item = try resolve(todoId: todoId)
        item.isCompleted.toggle()
        item.modifiedAt = Date()
        try repository.update(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return TodoToggleResult(entity: entity, isNowCompleted: item.isCompleted)
    }

    /// Sets a todo's completion to an explicit value. Idempotent — writing the
    /// value it already holds is a no-op.
    ///
    /// Backs `SetTodoCompletionIntent`: a control toggle must converge on the state
    /// the system asked for, so this takes an absolute value rather than flipping
    /// (unlike `toggleCompletion`, whose result depends on the current state).
    @discardableResult
    public func setCompletion(todoId: String, isCompleted: Bool) throws -> TodoAppEntity {
        defer { Self.dataDidChange() }
        let item = try resolve(todoId: todoId)
        if item.isCompleted != isCompleted {
            item.isCompleted = isCompleted
            item.modifiedAt = Date()
            try repository.update(item)
            reindexSpotlight(TodoAppEntity(from: item))
        }
        return TodoAppEntity(from: item)
    }

    /// Marks a todo as completed. Idempotent (unlike `toggleCompletion`): calling
    /// it on an already-completed todo is a no-op. Used by bulk-completion intents
    /// that operate over a collection of ids.
    @discardableResult
    public func markCompleted(todoId: String) throws -> TodoAppEntity {
        try setCompletion(todoId: todoId, isCompleted: true)
    }

    public func toggleFavorite(todoId: String) throws -> TodoAppEntity {
        defer { Self.dataDidChange() }
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
            Self.dataDidChange()
        }
        try repository.delete(by: uuid)
    }

    // MARK: - Undo support

    /// Captures everything needed to bring a todo back under the same identity.
    ///
    /// Call this **before** deleting. Backs the `UndoableIntent` conformance on the
    /// delete intents — `TodoItem` is a SwiftData `@Model` and is neither valid nor
    /// `Sendable` after deletion, so the undo handler has to hold a value copy.
    public func snapshot(todoId: String) throws -> TodoItemSnapshot {
        TodoItemSnapshot(try resolve(todoId: todoId))
    }

    /// Recreates a previously deleted todo from its snapshot.
    ///
    /// Idempotent: if a todo with that id is already present (the person undid
    /// twice, or CloudKit brought it back first) the existing one wins and is
    /// returned untouched, rather than inserting a duplicate under the same id.
    @discardableResult
    public func restore(_ snapshot: TodoItemSnapshot) throws -> TodoAppEntity {
        defer { Self.dataDidChange() }
        if let existing = try repository.fetch(by: snapshot.id) {
            return TodoAppEntity(from: existing)
        }
        let category = try snapshot.categoryID.flatMap { try repository.fetchCategory(by: $0) }
        let item = snapshot.makeTodoItem(category: category)
        try repository.create(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return entity
    }

    public func snooze(
        todoId: String,
        by interval: TimeInterval = TodoService.defaultSnoozeInterval
    ) throws -> TodoSnoozeResult {
        defer { Self.dataDidChange() }
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
        defer { Self.dataDidChange() }
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
        defer { Self.dataDidChange() }
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

    /// Persists a manual ordering by assigning each todo's `sortIndex` to its
    /// position in `orderedIDs`. Only the todos whose index actually changes are
    /// written (cheap, avoids needless CloudKit churn). Ids not present are left
    /// untouched. Backs both `ReorderTodosIntent` and the drag-to-reorder UI
    /// (WWDC 2026 reorderable containers).
    public func reorderTodos(orderedIDs: [String]) throws {
        defer { Self.dataDidChange() }
        let byID = Dictionary(
            try repository.fetchAll().map { ($0.id.uuidString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let now = Date()
        for (index, id) in orderedIDs.enumerated() {
            guard let item = byID[id], item.sortIndex != index else { continue }
            item.sortIndex = index
            item.modifiedAt = now
            try repository.update(item)
        }
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
        try repository.incompleteCount()
    }

    /// Returns a `TodoListSummaryEntity` snapshot computed from a single `fetchAll()`.
    ///
    /// Uses `TransientAppEntity` (WWDC 2026 #344) — the result is not persisted.
    /// Exposed via `GetTodoSummaryIntent` for Shortcuts conditional branching.
    public func summarize() throws -> TodoListSummaryEntity {
        TodoListSummaryEntity(items: try repository.fetchAll())
    }

    // MARK: - Spotlight

    /// Populate Spotlight with every todo currently in the store. Call once on
    /// app launch — `IndexedEntity` conformance alone is not enough for
    /// Spotlight to discover entities (it covers Apple Intelligence surfaces).
    ///
    /// Spotlight 側からの再インデックス要求には `TodoEntityQuery`
    /// (`IndexedEntityQuery`) が応答する。こちらは起動時の初期投入専用。
    ///
    /// 前回コミットした client state と内容ダイジェストが一致していれば**丸ごと省く**。
    /// 逐次の変更は `reindexSpotlight` が拾っているので、ここが毎起動走る必要はない。
    /// ダイジェストの作り方と 250 バイト制約は `TodoSpotlightIndex.clientState(for:)`。
    public func indexAllForSpotlight() async {
        #if os(iOS) || os(macOS)
        await TodoSpotlightIndex.purgeLegacyDefaultIndexIfNeeded()
        do {
            let items = try repository.fetchAll()
            let state = TodoSpotlightIndex.clientState(
                for: items.map { "\($0.id.uuidString)@\($0.modifiedAt.timeIntervalSinceReferenceDate)" }
            )
            let index = TodoSpotlightIndex.index()
            if await TodoSpotlightIndex.lastClientState(of: index) == state {
                spotlightLogger.info("indexAllForSpotlight skipped (unchanged) count=\(items.count)")
                return
            }
            guard !items.isEmpty else {
                // 空のバッチを endIndexBatch しても state は永続化されない。開かずに抜ける。
                spotlightLogger.info("indexAllForSpotlight nothing to index")
                return
            }
            spotlightLogger.info("indexAllForSpotlight start count=\(items.count)")
            // batch は index 呼び出しの**前**に開く。
            index.beginBatch()
            try await index.indexAppEntities(items.map { TodoAppEntity(from: $0) })
            // 全件成功したときだけコミットする。途中で throw した起動は前回の state を
            // 残したままなので、次回起動でフル再インデックスをやり直す。
            try await index.endBatch(withClientState: state)
            spotlightLogger.info("indexAllForSpotlight done count=\(items.count)")
        } catch {
            spotlightLogger.error("indexAllForSpotlight failed: \(String(reflecting: error))")
        }
        #endif
    }

    // MARK: - Private

    /// データ変更後の共通後処理。
    ///
    /// 1. ウィジェット / コントロールのリロード（別 API なので `WidgetReloader` が両方叩く）
    /// 2. App Shortcut のパラメータ候補の再取得要求。パラメータ入りフレーズ
    ///    （"Complete \(todo) in IntentTodo"）は候補が古いと一致しなくなるため、
    ///    entity の追加 / 削除 / 表示名の変化ごとに通知する（wwdc2023-10102 9:24）
    ///
    /// 変更系メソッドはすべて `defer { Self.dataDidChange() }` でここを通る。
    private static func dataDidChange() {
        WidgetReloader.reloadAllWidgets()
        AppShortcutParameterUpdater.notifyEntitiesChanged()
    }

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
                try await TodoSpotlightIndex.index().indexAppEntities([entity])
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
                try await TodoSpotlightIndex.index().deleteAppEntities(
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
