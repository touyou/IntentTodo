//
//  TodoItemTests.swift
//  IntentTodo
//

import Foundation
import SwiftData
import Testing
@testable import Domain

@Suite("TodoItem Tests")
struct TodoItemTests {
    // MARK: - Initialization Tests

    @Test("TodoItem initializes with required title")
    func initWithTitle() {
        let todo = TodoItem(title: "Buy groceries")

        #expect(todo.title == "Buy groceries")
        #expect(todo.isCompleted == false)
        #expect(todo.isFavorite == false)
        #expect(todo.todoDescription == nil)
        #expect(todo.dueDate == nil)
        #expect(todo.category == nil)
        #expect((todo.subTasks ?? []).isEmpty)
    }

    @Test("TodoItem initializes with all properties")
    func initWithAllProperties() {
        let dueDate = Date()
        let todo = TodoItem(
            title: "Complete project",
            todoDescription: "Finish the IntentTodo app",
            isCompleted: true,
            isFavorite: true,
            dueDate: dueDate
        )

        #expect(todo.title == "Complete project")
        #expect(todo.todoDescription == "Finish the IntentTodo app")
        #expect(todo.isCompleted == true)
        #expect(todo.isFavorite == true)
        #expect(todo.dueDate == dueDate)
    }

    @Test("TodoItem generates unique ID on creation")
    func uniqueIdGeneration() {
        let todo1 = TodoItem(title: "Task 1")
        let todo2 = TodoItem(title: "Task 2")

        #expect(todo1.id != todo2.id)
    }

    // MARK: - Property Modification Tests

    @Test("TodoItem can toggle completion status")
    func toggleCompletion() {
        let todo = TodoItem(title: "Test task")
        #expect(todo.isCompleted == false)

        todo.isCompleted = true
        #expect(todo.isCompleted == true)

        todo.isCompleted = false
        #expect(todo.isCompleted == false)
    }

    @Test("TodoItem can toggle favorite status")
    func toggleFavorite() {
        let todo = TodoItem(title: "Test task")
        #expect(todo.isFavorite == false)

        todo.isFavorite = true
        #expect(todo.isFavorite == true)
    }

    @Test("TodoItem can update title")
    func updateTitle() {
        let todo = TodoItem(title: "Original title")
        todo.title = "Updated title"

        #expect(todo.title == "Updated title")
    }

    // MARK: - Timestamp Tests

    @Test("TodoItem sets createdAt on initialization")
    func createdAtTimestamp() {
        let beforeCreation = Date()
        let todo = TodoItem(title: "Test task")
        let afterCreation = Date()

        #expect(todo.createdAt >= beforeCreation)
        #expect(todo.createdAt <= afterCreation)
    }

    // NOTE: didSet による自動 modifiedAt 更新は CloudKit マージで発火しない問題で
    // 撤去済 (`docs/insights/02-swiftdata-concurrency.md`)。modifiedAt の更新責務は
    // TodoService の各 mutation メソッドに移ったため、検証は TodoServiceTests 側で行う。
}

@Suite("SubTask Tests")
struct SubTaskTests {
    @Test("SubTask initializes with title")
    func initWithTitle() {
        let subTask = SubTask(title: "Sub task")

        #expect(subTask.title == "Sub task")
        #expect(subTask.isCompleted == false)
    }

    @Test("SubTask can toggle completion")
    func toggleCompletion() {
        let subTask = SubTask(title: "Sub task")
        #expect(subTask.isCompleted == false)

        subTask.isCompleted = true
        #expect(subTask.isCompleted == true)
    }
}

@Suite("Category Tests")
struct CategoryTests {
    @Test("Category initializes with name")
    func initWithName() {
        let category = Category(name: "Work")

        #expect(category.name == "Work")
        #expect(category.colorHex == nil)
        #expect((category.todos ?? []).isEmpty)
    }

    @Test("Category initializes with name and color")
    func initWithNameAndColor() {
        let category = Category(name: "Personal", colorHex: "#FF5733")

        #expect(category.name == "Personal")
        #expect(category.colorHex == "#FF5733")
    }
}
