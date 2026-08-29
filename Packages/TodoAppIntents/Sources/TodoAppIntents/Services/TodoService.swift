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

import Domain
import Foundation
import os.log
import Repository
import SwiftData

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
//
// 以下の payload は `@MainActor` 隔離なので Sendable は暗黙に付く（グローバルアクター
// 隔離型は SE-0316 により public でも推論される）。明示すると重複になる。

/// Payload returned after toggling a todo's completion.
@MainActor
public struct TodoToggleResult {
    public let entity: TodoAppEntity
    public let isNowCompleted: Bool
}

/// Payload returned after snoozing a todo.
@MainActor
public struct TodoSnoozeResult {
    public let entity: TodoAppEntity
    public let newDueDate: Date
    public let title: String
}

/// Payload returned after toggling the most urgent todo.
@MainActor
public struct UrgentTodoToggleResult {
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

    /// Spotlight 反映（`TodoService+Spotlight.swift`）からも全件取得するため internal。
    let repository: any TodoRepositoryProtocol

    /// 進行中の Spotlight 操作 (id 単位)。連続トグルで前タスクをキャンセルし、
    /// 最新の reindex/deindex だけが Spotlight に反映されるようにする (race condition 対策)。
    ///
    /// 実体の操作は `TodoService+Spotlight.swift` にあるため internal。
    var inflightSpotlightTasks: [String: Task<Void, Never>] = [:]

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
        locationLongitude: Double? = nil,
        tags: [String] = [],
        urls: [URL] = [],
        recurrenceFrequency: TodoRecurrenceFrequency? = nil,
        recurrenceInterval: Int = TodoRecurrenceFrequency.minimumInterval,
        locationTriggerEvent: TodoLocationTriggerEvent? = nil
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
        // `.reminders.reminder` 由来の属性は `TodoItem.init` に載せず、既定値のあるプロパティ
        // として代入する。init の引数を増やすと復元用 init（`TodoItemSnapshot.makeTodoItem`）と
        // 2 箇所で同じ並びを保たなければならなくなるため。
        item.tags = TodoAttributes.normalized(tags: tags)
        item.urls = TodoAttributes.normalized(urls: urls)
        item.recurrenceFrequency = recurrenceFrequency?.rawValue
        item.recurrenceInterval = max(TodoRecurrence.minimumInterval, recurrenceInterval)
        item.locationTriggerEvent = locationTriggerEvent?.rawValue
        try repository.create(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return entity
    }

    public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
        defer { Self.dataDidChange() }
        let item = try resolve(todoId: todoId)
        item.isCompleted.toggle()
        syncCompletionDate(item)
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
            syncCompletionDate(item)
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

    /// 完了状態を変えたら `completionDate` を合わせる。
    ///
    /// `.reminders.reminder` スキーマは `isCompleted` と `completionDate` を別々に要求する。
    /// 2 つを独立に持つとずれるので、完了状態を触る経路（トグル / 絶対値セット / 最急トグル）は
    /// 必ずここを通す。復元（`restore(_:)`）は snapshot の値をそのまま戻すので通さない。
    private func syncCompletionDate(_ item: TodoItem) {
        item.completionDate = item.isCompleted ? Date() : nil
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
        assigneeName: FieldUpdate<String?> = .unchanged,
        tags: FieldUpdate<[String]> = .unchanged,
        urls: FieldUpdate<[URL]> = .unchanged,
        recurrenceFrequency: FieldUpdate<TodoRecurrenceFrequency?> = .unchanged,
        recurrenceInterval: FieldUpdate<Int> = .unchanged,
        locationTriggerEvent: FieldUpdate<TodoLocationTriggerEvent?> = .unchanged
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

        applySchemaAttributes(
            to: item,
            tags: tags,
            urls: urls,
            recurrenceFrequency: recurrenceFrequency,
            recurrenceInterval: recurrenceInterval,
            locationTriggerEvent: locationTriggerEvent
        )

        item.modifiedAt = Date()
        try repository.update(item)
        let entity = TodoAppEntity(from: item)
        reindexSpotlight(entity)
        return entity
    }

    /// `.reminders.reminder` 由来の属性の部分更新。
    ///
    /// `update(todoId:…)` から切り出しているのは分岐数を分けるためだけで、意味の境界も
    /// ここに一致する（スキーマが要求して #83 で足したフィールド群）。
    ///
    /// `tags` / `urls` は差分ではなく置き換え。「1 つ足す」は呼出側が現在値に足した配列を
    /// 渡す形で表現する（Shortcuts の編集画面が配列を丸ごと編集する形なので、Intent の
    /// 意味と UI の意味がずれない）。
    private func applySchemaAttributes(
        to item: TodoItem,
        tags: FieldUpdate<[String]>,
        urls: FieldUpdate<[URL]>,
        recurrenceFrequency: FieldUpdate<TodoRecurrenceFrequency?>,
        recurrenceInterval: FieldUpdate<Int>,
        locationTriggerEvent: FieldUpdate<TodoLocationTriggerEvent?>
    ) {
        if case .set(let value) = tags { item.tags = TodoAttributes.normalized(tags: value) }
        if case .set(let value) = urls { item.urls = TodoAttributes.normalized(urls: value) }
        if case .set(let value) = recurrenceFrequency { item.recurrenceFrequency = value?.rawValue }
        if case .set(let value) = recurrenceInterval {
            item.recurrenceInterval = max(TodoRecurrence.minimumInterval, value)
        }
        if case .set(let value) = locationTriggerEvent { item.locationTriggerEvent = value?.rawValue }
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
        syncCompletionDate(item)
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
            try repository.fetchAll().map { ($0.id.uuidString, $0) }
        ) { first, _ in first }
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

    /// 単一の Todo を id で引く。見つからなければ `nil`。
    ///
    /// ディープリンク（`TodoDeepLink.todo(id:)`）の解決用。古いリンクを開いたときに
    /// エラーを見せる意味がないので、`resolve(todoId:)` と違って throw せず `nil` を返す。
    public func todo(id: String) -> TodoAppEntity? {
        guard let uuid = UUID(uuidString: id),
              let item = try? repository.fetch(by: uuid) else {
            return nil
        }
        return TodoAppEntity(from: item)
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
}
