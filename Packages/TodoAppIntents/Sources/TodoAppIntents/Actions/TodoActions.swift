//
//  TodoActions.swift
//  TodoAppIntents
//
//  Shared business logic for todo actions, used by both the Primary (@Dependency-based)
//  and FromExtension (SharedModelContainer-based) Intent variants.
//
//  Each function is @MainActor and operates on a Repository abstraction so the
//  Intent variants only differ in how they construct the repository.
//

import Domain
import Foundation
import Repository

// MARK: - Result Types

/// Payload returned after toggling a todo's completion.
@MainActor
public struct TodoToggleResult: Sendable {
    public let entity: TodoAppEntity
    public let isNowCompleted: Bool
}

/// Payload returned after snoozing a todo.
@MainActor
public struct TodoSnoozeResult: Sendable {
    public let entity: TodoAppEntity
    public let newDueDate: Date
    public let title: String
}

// MARK: - Actions

public enum TodoActions {
    /// Toggle completion of a specific todo identified by its UUID string.
    @MainActor
    public static func toggleCompletion(
        todoId: String,
        using repository: any TodoRepositoryProtocol
    ) throws -> TodoToggleResult {
        guard let uuid = UUID(uuidString: todoId),
              let item = try repository.fetch(by: uuid) else {
            throw IntentError.notFound("Todo not found")
        }
        item.isCompleted.toggle()
        try repository.update(item)
        return TodoToggleResult(entity: TodoAppEntity(from: item), isNowCompleted: item.isCompleted)
    }

    /// Toggle favorite status of a specific todo.
    @MainActor
    public static func toggleFavorite(
        todoId: String,
        using repository: any TodoRepositoryProtocol
    ) throws -> TodoAppEntity {
        guard let uuid = UUID(uuidString: todoId),
              let item = try repository.fetch(by: uuid) else {
            throw IntentError.notFound("Todo not found")
        }
        item.isFavorite.toggle()
        try repository.update(item)
        return TodoAppEntity(from: item)
    }

    /// Delete a specific todo by UUID string.
    @MainActor
    public static func delete(
        todoId: String,
        using repository: any TodoRepositoryProtocol
    ) throws {
        guard let uuid = UUID(uuidString: todoId) else {
            throw IntentError.validation("Invalid todo ID")
        }
        try repository.delete(by: uuid)
    }

    /// Snooze a todo's due date by the given interval (default: 30 minutes).
    @MainActor
    public static func snooze(
        todoId: String,
        by interval: TimeInterval = 30 * 60,
        using repository: any TodoRepositoryProtocol
    ) throws -> TodoSnoozeResult {
        guard let uuid = UUID(uuidString: todoId),
              let item = try repository.fetch(by: uuid),
              let currentDueDate = item.dueDate else {
            throw IntentError.notFound("Todo or due date not found")
        }
        let newDueDate = currentDueDate.addingTimeInterval(interval)
        item.dueDate = newDueDate
        try repository.update(item)
        return TodoSnoozeResult(
            entity: TodoAppEntity(from: item),
            newDueDate: newDueDate,
            title: item.title
        )
    }

    /// Create a new todo.
    @MainActor
    public static func create(
        title: String,
        todoDescription: String?,
        dueDate: Date?,
        isFavorite: Bool,
        using repository: any TodoRepositoryProtocol
    ) throws -> TodoAppEntity {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }
        let item = TodoItem(
            title: trimmed,
            todoDescription: todoDescription,
            isFavorite: isFavorite,
            dueDate: dueDate
        )
        try repository.create(item)
        return TodoAppEntity(from: item)
    }
}
