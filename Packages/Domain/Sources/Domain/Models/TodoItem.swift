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

    // 永続化スキーマの宣言なので、`= UUID()` / `= Date()` のように初期化子から型が
    // 読める場合でも型注釈を省かない。CloudKit と突き合わせる際に読む対象がここなので、
    // 一覧として全プロパティの型が揃って並んでいることに価値がある。
    // swiftlint:disable redundant_type_annotation

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

    /// Common name of the location associated with this todo, if any.
    ///
    /// Location is decomposed into CloudKit-safe primitives (name + coordinate) and
    /// bridged to / from the App Intents `PlaceDescriptor` (GeoToolbox) type.
    public var locationName: String?

    /// Latitude of the associated location, if any.
    public var locationLatitude: Double?

    /// Longitude of the associated location, if any.
    public var locationLongitude: Double?

    /// The date when the todo item was created.
    public var createdAt: Date = Date()

    /// The date when the todo item was last modified.
    ///
    /// `@Model` プロパティで `didSet` を使うと CloudKit マージ時や KVC 経由の
    /// 更新で発火しないため、更新側 (TodoService 等) で明示的に触る方針。
    public var modifiedAt: Date = Date()

    /// User-defined manual ordering index (drag-to-reorder).
    ///
    /// Default `0` keeps this CloudKit-safe and lets SwiftData perform a
    /// lightweight migration (no `VersionedSchema` needed). Only consulted when the
    /// list's sort order is `.manual`; `TodoService.reorderTodos(orderedIDs:)`
    /// assigns it by position.
    public var sortIndex: Int = 0

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

    // swiftlint:enable redundant_type_annotation

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
        assigneeName: String? = nil,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.assigneeName = assigneeName
        self.locationName = locationName
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.category = nil
        self.subTasks = []
    }

    /// Recreates a todo with an explicit identifier and timestamps.
    ///
    /// Used to bring a deleted todo back (`TodoItemSnapshot.makeTodoItem(category:)`).
    /// Restoring **under the original `id`** is what keeps the Spotlight index entry,
    /// donations, and any `TodoAppEntity` a widget / Live Activity still holds
    /// pointing at the same thing — a fresh UUID would silently orphan all of them.
    ///
    /// The ordinary `init(title:…)` deliberately doesn't take an id so normal
    /// creation can't accidentally collide with an existing todo.
    public init(
        id: UUID,
        title: String,
        todoDescription: String? = nil,
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        assigneeName: String? = nil,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        createdAt: Date,
        modifiedAt: Date,
        sortIndex: Int
    ) {
        self.id = id
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.assigneeName = assigneeName
        self.locationName = locationName
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sortIndex = sortIndex
        self.category = nil
        self.subTasks = []
    }
}
