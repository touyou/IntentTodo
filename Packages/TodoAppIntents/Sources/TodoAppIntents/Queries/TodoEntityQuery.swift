//
//  TodoEntityQuery.swift
//  IntentTodo
//

import AppIntents
#if os(iOS) || os(macOS)
import CoreSpotlight
#endif
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

    /// 直近の未完了 todo（最大 `suggestedEntityLimit` 件）。
    ///
    /// **全件返してはいけない**。パラメータ入りの App Shortcut フレーズ
    /// （"Complete \(todo) in IntentTodo"）を使っている場合、システムはここで返した
    /// **値 1 つにつき App Shortcut を 1 つ生成する**（wwdc2025-244 9:46 "If provided,
    /// an App Shortcut for each value of that type will be created."）。未完了 todo が
    /// 数十件あると Shortcuts / Spotlight がそれで埋まる。
    ///
    /// `fetchIncomplete()` は `createdAt` の降順なので、先頭から取ると「最近作った未完了」
    /// になる。全件が必要な場面（Shortcuts の Find アクション等）は `allEntities()` が担う。
    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        try repository().fetchIncomplete()
            .prefix(Self.suggestedEntityLimit)
            .map { TodoAppEntity(from: $0) }
    }

    /// Siri / Spotlight に出す候補の上限。HIG の "not more than ten" に合わせている。
    static let suggestedEntityLimit = 10

    /// 候補一覧の描画用に、表示表現だけをまとめて返す。
    ///
    /// 既定実装は `entities(for:)` を呼んでから 1 件ずつ `displayRepresentation` を
    /// 読む。ここは `TodoItem` から直接組み立てて、表示に使わない `CategoryAppEntity`
    /// の生成を省く。公式: "Return full representations; the system materializes only
    /// the components it needs"（画像の遅延クロージャがここで効く）。
    @MainActor
    public func displayRepresentations(
        for identifiers: [TodoAppEntity.ID]
    ) async throws -> [TodoAppEntity.ID: DisplayRepresentation] {
        let repo = repository()
        var representations: [TodoAppEntity.ID: DisplayRepresentation] = [:]
        for identifier in identifiers {
            guard let uuid = UUID(uuidString: identifier),
                  let item = try repo.fetch(by: uuid) else {
                continue  // 既に削除済み。`entities(for:)` と同じく正常系。
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
    /// ユーザー入力との比較は `localizedStandardContains(_:)`（`CategoryEntityQuery` と同じ）。
    /// `lowercased().contains()` はロケール非依存で、かな/カナやダイアクリティカルマークを
    /// 別物として扱ってしまう。
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        try repository().fetchAll()
            .filter { $0.title.localizedStandardContains(string) }
            .map { TodoAppEntity(from: $0) }
    }
}

// MARK: - EnumerableEntityQuery

extension TodoEntityQuery: EnumerableEntityQuery {
    /// `EnumerableEntityQuery` 準拠だけで Shortcuts が "Find Todos" アクションを
    /// 自動生成する。未指定だと説明もカテゴリも無いアクションとして並ぶので、
    /// 何が返るか（`resultValueName`）まで含めてここで与える。
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

#if os(iOS) || os(macOS)
/// Spotlight からの**再インデックス要求**に応える口。
///
/// Apple 公式 (Making app entities available in Spotlight): "If you donate app entities
/// to a `CSSearchableIndex` using its `indexAppEntities(_:priority:)` method, implement
/// the `IndexedEntityQuery` protocol in your entity's query object to handle reindexing."
/// 本アプリは `TodoService` が donate 側なので、この準拠が対応する受け側になる。
///
/// これが無いと、Spotlight 側の index が壊れて再構築を要求してきたときに応答先が無く、
/// 次にアプリが起動して `indexAllForSpotlight()` が走るまで検索に出てこなくなる。
///
/// `indexDescription` は「どの index を更新するか」を判別するためのものだが、本アプリの
/// index は `TodoSpotlightIndex` の 1 本だけなので参照しない。
///
/// **このファイルの他のメソッドと違い `@MainActor` を付けられない**（`CSSearchableIndexDescription`
/// が non-Sendable のため）。nonisolated のまま、内側で `entities(for:)` などを await して
/// MainActor へホップする。詳細: docs/insights/03-app-intents-core.md
extension TodoEntityQuery: IndexedEntityQuery {
    public func reindexEntities(
        for identifiers: [TodoAppEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await entities(for: identifiers)
        if !entities.isEmpty {
            try await TodoSpotlightIndex.index().indexAppEntities(entities)
        }

        // 要求された id のうち既に消えているものは index からも落とす
        // (削除直後に要求が来た場合、放置すると Spotlight に幽霊が残る)。
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
