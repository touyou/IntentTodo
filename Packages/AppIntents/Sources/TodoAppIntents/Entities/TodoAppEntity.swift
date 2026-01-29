//
//  TodoAppEntity.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An App Intents entity representing a todo item.
///
/// This entity is used in Siri, Shortcuts, and Spotlight to reference todo items.
public struct TodoAppEntity: AppEntity {
    // MARK: - Properties

    /// The unique identifier for this entity.
    public var id: String

    /// The title of the todo item.
    public var title: String

    /// Whether the todo item is completed.
    public var isCompleted: Bool

    /// Whether the todo item is marked as favorite.
    public var isFavorite: Bool

    /// The due date of the todo item, if any.
    public var dueDate: Date?

    /// The creation date of the todo item.
    public var createdAt: Date

    // MARK: - AppEntity Requirements

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Todo", comment: "Todo item type name"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) todos", comment: "Number of todos")
        )
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: isCompleted
                ? LocalizedStringResource("Completed", comment: "Todo completed status")
                : (dueDate.map { LocalizedStringResource(stringLiteral: "Due: \($0.formatted(date: .abbreviated, time: .omitted))") }
                    ?? LocalizedStringResource("", comment: "Empty")),
            image: isCompleted
                ? .init(systemName: "checkmark.circle.fill")
                : (isFavorite ? .init(systemName: "star.fill") : .init(systemName: "circle"))
        )
    }

    public static var defaultQuery: TodoEntityQuery {
        TodoEntityQuery()
    }

    // MARK: - Initialization

    /// Creates a new TodoAppEntity from a TodoItem.
    /// - Parameter todoItem: The domain model to convert.
    @MainActor
    public init(from todoItem: TodoItem) {
        self.id = todoItem.id.uuidString
        self.title = todoItem.title
        self.isCompleted = todoItem.isCompleted
        self.isFavorite = todoItem.isFavorite
        self.dueDate = todoItem.dueDate
        self.createdAt = todoItem.createdAt
    }

    /// Creates a new TodoAppEntity with the given properties.
    public init(
        id: String,
        title: String,
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.createdAt = createdAt
    }
}
