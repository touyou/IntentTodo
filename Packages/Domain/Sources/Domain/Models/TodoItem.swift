//
//  TodoItem.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A todo item representing a task to be completed.
///
/// Shaped by Apple's "Define a CloudKit compatible schema" requirements: every attribute is
/// optional or has a default value, and so is every relationship.
@Model
public final class TodoItem {
    // MARK: - Properties

    // Type annotations are kept even where the initialiser makes them redundant: this list
    // is what gets read when checking the schema against CloudKit's requirements.
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

    /// The date the todo was completed, if it has been.
    ///
    /// Required by the `.reminders.reminder` schema and kept in step with `isCompleted` by
    /// `TodoService` — stored separately because "when" cannot be derived from "whether".
    public var completionDate: Date?

    /// Free-form tags.
    ///
    /// The schema asks for `Set<String>`; stored as `[String]` for SwiftData and CloudKit,
    /// and converted at the entity boundary.
    public var tags: [String] = []

    /// Links attached to the todo.
    public var urls: [URL] = []

    /// How often the todo repeats, if it does (`daily` / `weekly` / `monthly` / `yearly`).
    ///
    /// `Calendar.RecurrenceRule` **cannot be a `@Model` property**: it compiles, but
    /// SwiftData traps while initialising the schema. Stored as CloudKit-friendly primitives
    /// and reassembled at the entity boundary by `TodoRecurrence`.
    public var recurrenceFrequency: String?

    /// How many frequency units sit between occurrences (2 + `weekly` = every other week).
    public var recurrenceInterval: Int = 1

    /// Whether arriving at or leaving `locationName` should trigger the todo.
    ///
    /// Raw value of the `.reminders.locationTrigger` event, stored as a `String?` rather
    /// than an enum for CloudKit compatibility.
    public var locationTriggerEvent: String?

    /// The date when the todo item was created.
    public var createdAt: Date = Date()

    /// The date when the todo item was last modified.
    ///
    /// Updated explicitly by callers: `didSet` on a `@Model` property does not fire for
    /// CloudKit merges or KVC writes.
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
    /// Optional because Apple requires to-many relationships to be optional for CloudKit;
    /// readers use `subTasks ?? []`.
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
