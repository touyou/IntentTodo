//
//  TodoItem.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A todo item representing a task to be completed.
///
/// CloudKit 互換のため、すべての属性は宣言時にデフォルト値を持ち、
/// to-many リレーションは空配列デフォルト。Apple 公式 "Define a CloudKit
/// compatible schema" の要件:
/// - 全 attribute は optional または default value 付き
/// - 全 relationship は optional または default value 付き
@Model
public final class TodoItem {
    // MARK: - Properties

    /// Unique identifier for the todo item.
    public var id: UUID = UUID()

    /// The title of the todo item.
    public var title: String = ""

    /// Optional detailed description of the todo item.
    public var todoDescription: String?

    /// Whether the todo item has been completed.
    public var isCompleted: Bool = false

    /// Whether the todo item is marked as favorite.
    public var isFavorite: Bool = false

    /// Optional due date for the todo item.
    public var dueDate: Date?

    /// Estimated time to complete, in seconds.
    ///
    /// Stored as `TimeInterval` for SwiftData/CloudKit compatibility (optional, so
    /// no migration concerns) and bridged to the App Intents `Duration` type at the
    /// entity boundary.
    public var estimatedDuration: TimeInterval?

    /// Display name of the person this todo is assigned to, if any.
    ///
    /// Stored as a formatted `String` (CloudKit-safe); the App Intents layer accepts
    /// it as a native `PersonNameComponents` parameter and formats it here.
    public var assigneeName: String?

    /// The date when the todo item was created.
    public var createdAt: Date = Date()

    /// The date when the todo item was last modified.
    ///
    /// `@Model` プロパティで `didSet` を使うと CloudKit マージ時や KVC 経由の
    /// 更新で発火しないため、更新側 (TodoService 等) で明示的に触る方針。
    public var modifiedAt: Date = Date()

    /// The category this todo belongs to (optional for CloudKit compatibility).
    @Relationship(deleteRule: .nullify, inverse: \Category.todos)
    public var category: Category?

    /// Sub-tasks associated with this todo item.
    ///
    /// CloudKit 互換のため optional `[SubTask]?`。読み取りは `subTasks ?? []` で
    /// nil 安全に扱う (View / Service 側で). Apple "Define a CloudKit compatible
    /// schema" が `to-many relationships must be optional` を要求する。
    @Relationship(deleteRule: .cascade, inverse: \SubTask.parentTodo)
    public var subTasks: [SubTask]? = []

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
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        assigneeName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.assigneeName = assigneeName
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.category = nil
        self.subTasks = []
    }
}
