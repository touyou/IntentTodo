//
//  SubTask.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A sub-task that belongs to a parent todo item.
@Model
public final class SubTask {
    // MARK: - Properties

    /// Unique identifier for the sub-task.
    public var id: UUID

    /// The title of the sub-task.
    public var title: String

    /// Whether the sub-task has been completed.
    public var isCompleted: Bool

    /// The order index for sorting sub-tasks.
    public var orderIndex: Int

    /// The parent todo item this sub-task belongs to.
    public var parentTodo: TodoItem?

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
}
