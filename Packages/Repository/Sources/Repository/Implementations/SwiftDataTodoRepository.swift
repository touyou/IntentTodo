//
//  SwiftDataTodoRepository.swift
//  IntentTodo
//

import Domain
import Foundation
import SwiftData

/// A SwiftData implementation of TodoRepositoryProtocol.
///
/// This implementation persists todo items using SwiftData and supports
/// CloudKit synchronization when configured appropriately.
@MainActor
public final class SwiftDataTodoRepository: TodoRepositoryProtocol {
    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    /// Creates a new SwiftData repository with the given model context.
    /// - Parameter modelContext: The SwiftData model context to use for persistence.
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    public func create(_ todo: TodoItem) throws {
        modelContext.insert(todo)
        try modelContext.save()
    }

    // MARK: - Read

    public func fetchAll() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetch(by id: UUID) throws -> TodoItem? {
        let predicate = #Predicate<TodoItem> { todo in
            todo.id == id
        }
        let descriptor = FetchDescriptor<TodoItem>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    public func fetchMostUrgentIncomplete() throws -> TodoItem? {
        var descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
            sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func fetchCategory(by id: UUID) throws -> Domain.Category? {
        let predicate = #Predicate<Domain.Category> { category in
            category.id == id
        }
        var descriptor = FetchDescriptor<Domain.Category>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func incompleteCount() throws -> Int {
        // fetchCount counts at the store level without materializing TodoItem
        // instances into memory (Apple: "without the overhead of fetching the
        // models themselves").
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Update

    public func update(_ todo: TodoItem) throws {
        // SwiftData automatically tracks changes to managed objects.
        // We just need to ensure the object is in the context and save.
        guard modelContext.model(for: todo.persistentModelID) as? TodoItem != nil else {
            throw RepositoryError.notFound(id: todo.id)
        }
        try modelContext.save()
    }

    // MARK: - Delete

    public func delete(_ todo: TodoItem) throws {
        modelContext.delete(todo)
        try modelContext.save()
    }

    public func delete(by id: UUID) throws {
        guard let todo = try fetch(by: id) else {
            throw RepositoryError.notFound(id: id)
        }
        try delete(todo)
    }

    // MARK: - Optimized Convenience Methods

    public func fetchIncomplete() throws -> [TodoItem] {
        let predicate = #Predicate<TodoItem> { todo in
            !todo.isCompleted
        }
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchCompleted() throws -> [TodoItem] {
        let predicate = #Predicate<TodoItem> { todo in
            todo.isCompleted
        }
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchFavorites() throws -> [TodoItem] {
        let predicate = #Predicate<TodoItem> { todo in
            todo.isFavorite
        }
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
