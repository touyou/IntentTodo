//
//  TodoItemSnapshot.swift
//  IntentTodo
//

import Foundation

/// A `Sendable` copy of everything needed to bring a deleted todo back.
///
/// A value-type copy of a todo, which is what makes "delete now, restore under the same id
/// later" possible: a `@Model` is meaningless once deleted and is not `Sendable`, so it
/// cannot be captured by an undo handler.
///
/// Taken **before** deleting, via `TodoService.snapshot(todoId:)`, and passed back to
/// `TodoService.restore(_:)` from the undo handler.
public struct TodoItemSnapshot: Sendable, Equatable {
    /// A `Sendable` copy of one sub-task.
    public struct SubTaskSnapshot: Sendable, Equatable {
        public let id: UUID
        public let title: String
        public let isCompleted: Bool
        public let orderIndex: Int

        public init(id: UUID, title: String, isCompleted: Bool, orderIndex: Int) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.orderIndex = orderIndex
        }
    }

    public let id: UUID
    public let title: String
    public let todoDescription: String?
    public let isCompleted: Bool
    public let isFavorite: Bool
    public let dueDate: Date?
    public let estimatedDuration: TimeInterval?
    public let assigneeName: String?
    public let locationName: String?
    public let locationLatitude: Double?
    public let locationLongitude: Double?
    public let createdAt: Date
    public let modifiedAt: Date
    public let sortIndex: Int
    public let completionDate: Date?
    public let tags: [String]
    public let recurrenceFrequency: String?
    public let recurrenceInterval: Int
    public let urls: [URL]
    public let locationTriggerEvent: String?

    /// Relationships cannot be carried by value, so the category is re-resolved on restore.
    public let categoryID: UUID?

    /// Sub-tasks are cascade-deleted with the parent, so they have to come back too.
    public let subTasks: [SubTaskSnapshot]

    // MARK: - Initialization

    @MainActor
    public init(_ item: TodoItem) {
        self.id = item.id
        self.title = item.title
        self.todoDescription = item.todoDescription
        self.isCompleted = item.isCompleted
        self.isFavorite = item.isFavorite
        self.dueDate = item.dueDate
        self.estimatedDuration = item.estimatedDuration
        self.assigneeName = item.assigneeName
        self.locationName = item.locationName
        self.locationLatitude = item.locationLatitude
        self.locationLongitude = item.locationLongitude
        self.createdAt = item.createdAt
        self.modifiedAt = item.modifiedAt
        self.sortIndex = item.sortIndex
        self.completionDate = item.completionDate
        self.tags = item.tags
        self.recurrenceFrequency = item.recurrenceFrequency
        self.recurrenceInterval = item.recurrenceInterval
        self.urls = item.urls
        self.locationTriggerEvent = item.locationTriggerEvent
        self.categoryID = item.category?.id
        self.subTasks = (item.subTasks ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                SubTaskSnapshot(
                    id: $0.id,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    orderIndex: $0.orderIndex
                )
            }
    }

    // MARK: - Restoration

    /// Rebuilds the todo (and its sub-tasks) under the original identifiers.
    ///
    /// - Parameter category: The category resolved from `categoryID`, or `nil` when
    ///   the category itself is gone. The relation is simply dropped in that case —
    ///   a missing category shouldn't block bringing the todo back.
    @MainActor
    public func makeTodoItem(category: Category?) -> TodoItem {
        let item = TodoItem(
            id: id,
            title: title,
            todoDescription: todoDescription,
            isCompleted: isCompleted,
            isFavorite: isFavorite,
            dueDate: dueDate,
            estimatedDuration: estimatedDuration,
            assigneeName: assigneeName,
            locationName: locationName,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            sortIndex: sortIndex
        )
        item.completionDate = completionDate
        item.tags = tags
        item.recurrenceFrequency = recurrenceFrequency
        item.recurrenceInterval = recurrenceInterval
        item.urls = urls
        item.locationTriggerEvent = locationTriggerEvent
        item.category = category
        item.subTasks = subTasks.map { snapshot in
            let subTask = SubTask(
                id: snapshot.id,
                title: snapshot.title,
                isCompleted: snapshot.isCompleted,
                orderIndex: snapshot.orderIndex
            )
            subTask.parentTodo = item
            return subTask
        }
        return item
    }
}
