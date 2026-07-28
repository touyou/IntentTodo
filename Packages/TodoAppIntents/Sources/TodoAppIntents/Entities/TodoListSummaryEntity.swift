//
//  TodoListSummaryEntity.swift
//  TodoAppIntents
//
//  `TransientAppEntity` (WWDC 2026 #344 / "Entity の作り分け") で実装した
//  Todo リスト集計エンティティ。通常の AppEntity と違い、
//  - defaultQuery / EntityQuery が不要
//  - 永続化されない（SwiftData に保存されない）
//  - 計算済み値のスナップショットとして Intent の戻り値に使う
//
//  Shortcuts で「未完了が N 件以上なら通知」など条件分岐が可能になる。
//

import AppIntents
import Foundation

/// A snapshot of the current todo list statistics, returned from `GetTodoSummaryIntent`.
///
/// Implemented as a `TransientAppEntity` — the entity is computed on demand,
/// not persisted or queryable. Shortcuts users can use the individual count
/// properties in conditional branches (e.g. "If Overdue Todos > 0, notify me").
public struct TodoListSummaryEntity: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo List Summary"

    // MARK: - Properties

    @Property(title: "Total Todos")
    public var totalCount: Int

    @Property(title: "Completed Todos")
    public var completedCount: Int

    @Property(title: "Pending Todos")
    public var pendingCount: Int

    @Property(title: "Overdue Todos")
    public var overdueCount: Int

    @Property(title: "Favorite Todos")
    public var favoriteCount: Int

    // MARK: - Display

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(pendingCount) pending, \(overdueCount) overdue",
            subtitle: "\(totalCount) total (\(completedCount) completed, \(favoriteCount) favorited)"
        )
    }

    // MARK: - Initialization

    public init() {}

    public init(
        totalCount: Int,
        completedCount: Int,
        pendingCount: Int,
        overdueCount: Int,
        favoriteCount: Int
    ) {
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.pendingCount = pendingCount
        self.overdueCount = overdueCount
        self.favoriteCount = favoriteCount
    }
}
