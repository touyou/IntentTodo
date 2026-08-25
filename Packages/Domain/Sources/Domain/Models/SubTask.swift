//
//  SubTask.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A sub-task that belongs to a parent todo item.
///
/// CloudKit 互換のため、すべての属性は宣言時にデフォルト値を持つ。
/// 詳細は `TodoItem` のコメント参照。
@Model
public final class SubTask {
    // MARK: - Properties

    // 型注釈を省かない理由は `TodoItem` と同じ（永続化スキーマの一覧として読む）。
    // swiftlint:disable redundant_type_annotation

    /// Unique identifier for the sub-task.
    public var id: UUID = UUID()

    /// The title of the sub-task.
    public var title: String = ""

    /// Whether the sub-task has been completed.
    public var isCompleted: Bool = false

    /// The order index for sorting sub-tasks.
    public var orderIndex: Int = 0

    /// The parent todo item this sub-task belongs to.
    public var parentTodo: TodoItem?

    // swiftlint:enable redundant_type_annotation

    // MARK: - Initialization

    /// Creates a new sub-task with the specified title.
    /// - Parameters:
    ///   - title: The title of the sub-task.
    ///   - isCompleted: Whether the sub-task is completed. Defaults to `false`.
    ///   - orderIndex: The order index for sorting. Defaults to `0`.
    public init(
        title: String,
        isCompleted: Bool = false,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.orderIndex = orderIndex
        self.parentTodo = nil
    }

    /// Recreates a sub-task with an explicit identifier.
    ///
    /// Counterpart to `TodoItem.init(id:…)` — sub-tasks are cascade-deleted with
    /// their parent, so undoing a deletion has to bring them back under the same
    /// ids as well. 詳細: `TodoItemSnapshot`
    public init(
        id: UUID,
        title: String,
        isCompleted: Bool,
        orderIndex: Int
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.orderIndex = orderIndex
        self.parentTodo = nil
    }
}
