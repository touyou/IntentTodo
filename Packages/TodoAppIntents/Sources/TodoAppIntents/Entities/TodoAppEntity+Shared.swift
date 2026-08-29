//
//  TodoAppEntity+Shared.swift
//  IntentTodo
//
//  `TodoAppEntity` のプラットフォーム共通実装。宣言は `TodoAppEntity.swift` で 2 系統に
//  分かれているが（理由はそちらのコメント）、差分はスキーマ適合とスキーマ要求プロパティ
//  だけなので、それ以外はここに 1 つだけ書いて `typealias` 経由で両方に効かせる。
//
//  **宣言側に書かざるを得ないのはプロパティだけ**（`@Property` / `@ComputedProperty` /
//  `@DeferredProperty` はメンバに付く attribute で、extension の格納/計算プロパティには
//  持ち出せないものがあるため）。それ以外をここに寄せることで、2 系統の重複を
//  プロパティ宣言と init に限定している。
//

import AppIntents
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Domain
import Foundation
import GeoToolbox
import Repository
import SwiftData

// MARK: - AppEntity Requirements

public extension TodoAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Todo", comment: "Todo item type name"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) todos", comment: "Number of todos")
        )
    }

    var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(
            title: title,
            isCompleted: isCompleted,
            isFavorite: isFavorite,
            dueDate: dueDateValue
        )
    }

    static var defaultQuery: TodoEntityQuery {
        TodoEntityQuery()
    }
}

// MARK: - Display

extension TodoAppEntity {
    /// Builds a todo's display representation from raw field values.
    ///
    /// Static so `TodoEntityQuery.displayRepresentations(for:)` can build the same
    /// representation straight from a `TodoItem`, without constructing the entity
    /// (and its `CategoryAppEntity` relation) only to discard it.
    ///
    /// The image is passed as a closure so the system can skip materializing it in
    /// text-only contexts (`DisplayRepresentation.Components.text`).
    static func makeDisplayRepresentation(
        title: String,
        isCompleted: Bool,
        isFavorite: Bool,
        dueDate: Date?
    ) -> DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle(isCompleted: isCompleted, dueDate: dueDate),
            synonyms: ["\(title) todo", "\(title) task"]
        ) {
            image(isCompleted: isCompleted, isFavorite: isFavorite)
        }
    }

    /// Siri はこの subtitle を読み上げるので、時刻は位置指定表記（"14:30"）ではなく
    /// 自然文表記で渡す。出す情報が無いときは空文字ではなく `nil`。
    /// 詳細: docs/insights/03-app-intents-core.md
    private static func subtitle(isCompleted: Bool, dueDate: Date?) -> LocalizedStringResource? {
        if isCompleted {
            return LocalizedStringResource("Completed", comment: "Todo completed status")
        }
        if let dueDate {
            return "Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return nil
    }

    private static func image(isCompleted: Bool, isFavorite: Bool) -> DisplayRepresentation.Image {
        if isCompleted {
            return .init(systemName: "checkmark.circle.fill")
        }
        if isFavorite {
            return .init(systemName: "star.fill")
        }
        return .init(systemName: "circle")
    }
}

// MARK: - Derived values

extension TodoAppEntity {
    /// 期限切れ判定。`@ComputedProperty` の本体は宣言側にあるので、中身だけ共有する。
    static func isOverdue(isCompleted: Bool, dueDate: Date?) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }
}

// MARK: - Deferred loaders

extension TodoAppEntity {
    /// Fetches subtask completion counts on the MainActor and formats a summary.
    ///
    /// Entities can't use `@Dependency` (that is intents-only), so the shared
    /// container is read from `TodoEntityStore`, which the app registers at launch.
    static func loadSubtaskProgress(forID id: String) async throws -> String {
        try await MainActor.run {
            guard let item = liveItem(forID: id) else {
                return String(localized: "No subtasks")
            }
            let subTasks = item.subTasks ?? []
            guard !subTasks.isEmpty else {
                return String(localized: "No subtasks")
            }
            let completed = subTasks.filter(\.isCompleted).count
            return "\(completed)/\(subTasks.count) completed"
        }
    }

    /// Looks a todo up in the shared container, or `nil` when it is gone.
    @MainActor
    static func liveItem(forID id: String) -> TodoItem? {
        guard let container = TodoEntityStore.container,
              let uuid = UUID(uuidString: id) else {
            return nil
        }
        let repository = SwiftDataTodoRepository(modelContext: container.mainContext)
        return try? repository.fetch(by: uuid)
    }
}

#if !os(watchOS)
extension TodoAppEntity {
    /// Re-fetches the tags by id. Same shape as `loadSubtaskProgress`.
    static func loadTags(forID id: String) async throws -> Set<String> {
        try await MainActor.run {
            guard let item = liveItem(forID: id) else { return [] }
            return Set(item.tags)
        }
    }

    /// Re-fetches the attached links by id.
    static func loadURLs(forID id: String) async throws -> [URL] {
        try await MainActor.run {
            guard let item = liveItem(forID: id) else { return [] }
            return item.urls
        }
    }
}
#endif

// MARK: - Hashable / Equatable

// The `@ComputedProperty` / `@DeferredProperty` macros add non-`Hashable`
// `EntityProperty` backing storage, so synthesis is unavailable. Equality
// compares the value snapshot fields; the hash uses the stable id.
// `location` (PlaceDescriptor) is excluded as it isn't guaranteed `Equatable`;
// the underlying stored name/coordinate are reflected via the model anyway.
//
// 比較に使うのは 2 系統の両方にあるフィールドだけ（`dueDate` ではなく `dueDateValue`）。
public extension TodoAppEntity {
    static func == (lhs: TodoAppEntity, rhs: TodoAppEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.todoDescription == rhs.todoDescription
            && lhs.isCompleted == rhs.isCompleted
            && lhs.isFavorite == rhs.isFavorite
            && lhs.dueDateValue == rhs.dueDateValue
            && lhs.createdAt == rhs.createdAt
            && lhs.sortIndex == rhs.sortIndex
            && lhs.category == rhs.category
            && lhs.estimatedDuration == rhs.estimatedDuration
            && lhs.assigneeName == rhs.assigneeName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - IndexedEntity (Spotlight Integration)

#if os(iOS) || os(macOS) || os(visionOS)
/// Spotlight integration for todo items.
/// Allows users to search for todos via Spotlight with enhanced attributes.
extension TodoAppEntity: IndexedEntity {
    /// `@Property(indexingKey:)` が使っているキーはここで埋めない（どちらが勝つかは
    /// 公式に未定義）。`contentDescription` は `todoDescription` のマップ先なので、
    /// 完了状態は `keywords` 側で表現する。`displayName` は `.title` とは別キーで衝突しない。
    /// 詳細: docs/insights/03-app-intents-core.md
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = title
        if let dueDateValue {
            attributes.dueDate = dueDateValue
        }
        attributes.keywords = buildKeywords()
        return attributes
    }

    /// Builds keyword list for Spotlight search.
    private func buildKeywords() -> [String] {
        var keywords = ["todo", title]
        if isFavorite {
            keywords.append(contentsOf: ["favorite", "starred", "important"])
        }
        if isCompleted {
            keywords.append("completed")
        } else {
            keywords.append(contentsOf: ["incomplete", "pending"])
        }
        return keywords
    }
}
#endif
