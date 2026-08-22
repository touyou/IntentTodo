//
//  SubTaskAppEntity.swift
//  IntentTodo
//

import AppIntents
import Domain

/// An App Intents entity representing a sub-task of a todo item.
///
/// Exposes sub-tasks as first-class "nouns" so Siri / Shortcuts can reference and
/// (in later phases) act on individual sub-tasks.
public struct SubTaskAppEntity: AppEntity, Hashable {
    // MARK: - Properties

    /// The unique identifier for this entity (the sub-task UUID as a string).
    public var id: String

    /// Sort order within the parent todo. Not exposed as a queryable property.
    public var orderIndex: Int

    /// Identifier of the parent todo, if known. Not exposed as a queryable property.
    public var parentTodoId: String?

    /// The title of the sub-task.
    @Property(title: "Title")
    public var title: String

    /// Whether the sub-task is completed.
    @Property(title: "Completed")
    public var isCompleted: Bool

    // MARK: - AppEntity Requirements

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Subtask", comment: "Subtask type name"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) subtasks", comment: "Number of subtasks")
        )
    }

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(title: title, isCompleted: isCompleted)
    }

    /// Builds a sub-task's display representation from raw field values.
    ///
    /// Static so `SubTaskEntityQuery.displayRepresentations(for:)` can build it
    /// straight from the model without constructing the entity. `synonyms:` widens
    /// Siri's matching; the image is a closure so text-only contexts can skip it.
    static func makeDisplayRepresentation(title: String, isCompleted: Bool) -> DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            synonyms: ["\(title) subtask", "\(title) step"]
        ) {
            DisplayRepresentation.Image(
                systemName: isCompleted ? "checkmark.circle.fill" : "circle"
            )
        }
    }

    public static var defaultQuery: SubTaskEntityQuery {
        SubTaskEntityQuery()
    }

    // MARK: - Initialization

    /// Creates a new SubTaskAppEntity from a SubTask model.
    @MainActor
    public init(from subTask: SubTask) {
        // Assign plain stored properties before @Property-wrapped ones to satisfy
        // definite-initialization (the wrapper changes init ordering).
        self.id = subTask.id.uuidString
        self.orderIndex = subTask.orderIndex
        self.parentTodoId = subTask.parentTodo?.id.uuidString
        self.title = subTask.title
        self.isCompleted = subTask.isCompleted
    }

    /// Creates a new SubTaskAppEntity with the given properties.
    public init(
        id: String,
        title: String,
        isCompleted: Bool = false,
        orderIndex: Int = 0,
        parentTodoId: String? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.parentTodoId = parentTodoId
        self.title = title
        self.isCompleted = isCompleted
    }

    // MARK: - Hashable / Equatable

    public static func == (lhs: SubTaskAppEntity, rhs: SubTaskAppEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isCompleted == rhs.isCompleted
            && lhs.orderIndex == rhs.orderIndex
            && lhs.parentTodoId == rhs.parentTodoId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
