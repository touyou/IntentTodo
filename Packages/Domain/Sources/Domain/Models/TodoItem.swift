//
//  TodoItem.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A todo item representing a task to be completed.
@Model
public final class TodoItem {
    // MARK: - Properties

    /// Unique identifier for the todo item.
    public var id: UUID

    /// The title of the todo item.
    public var title: String

    /// Optional detailed description of the todo item.
    public var todoDescription: String?

    /// Whether the todo item has been completed.
    public var isCompleted: Bool

    /// Whether the todo item is marked as favorite.
    public var isFavorite: Bool

    /// Optional due date for the todo item.
    public var dueDate: Date?

    /// The date when the todo item was created.
    public var createdAt: Date

    /// The date when the todo item was last modified.
    ///
    /// `@Model` プロパティで `didSet` を使うと CloudKit マージ時や KVC 経由の
    /// 更新で発火しないため、更新側 (TodoActions 等) で明示的に触る方針。
    public var modifiedAt: Date

    /// The category this todo belongs to (optional for CloudKit compatibility).
    @Relationship(deleteRule: .nullify, inverse: \Category.todos)
    public var category: Category?

    /// Sub-tasks associated with this todo item.
    @Relationship(deleteRule: .cascade, inverse: \SubTask.parentTodo)
    public var subTasks: [SubTask]

    // MARK: - Initialization

    /// Creates a new todo item with the specified properties.
    /// - Parameters:
    ///   - title: The title of the todo item.
    ///   - todoDescription: Optional detailed description.
    ///   - isCompleted: Whether the item is completed. Defaults to `false`.
    ///   - isFavorite: Whether the item is marked as favorite. Defaults to `false`.
    ///   - dueDate: Optional due date for the item.
    public init(
        title: String,
        todoDescription: String? = nil,
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.category = nil
        self.subTasks = []
    }
}
