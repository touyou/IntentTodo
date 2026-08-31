//
//  SubTask.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A sub-task that belongs to a parent todo item.
///
/// Every attribute has a default value for CloudKit compatibility, as in `TodoItem`.
@Model
public final class SubTask {
    // MARK: - Properties

    // Type annotations are kept for the same reason as in `TodoItem`.
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
    /// ids as well. See `TodoItemSnapshot`.
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
