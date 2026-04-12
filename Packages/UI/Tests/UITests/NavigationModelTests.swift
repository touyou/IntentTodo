//
//  NavigationModelTests.swift
//  IntentTodo
//

import Foundation
import Testing
import TodoAppIntents

@MainActor
@Suite("NavigationModel Tests")
struct NavigationModelTests {
    // MARK: - Helpers

    private func makeTodoEntity(
        id: String = UUID().uuidString,
        title: String = "Test Todo"
    ) -> TodoAppEntity {
        TodoAppEntity(id: id, title: title)
    }

    // MARK: - Initial State Tests

    @Test("Initial state has empty path and addTodo hidden")
    func initialState() {
        let model = NavigationModel()

        #expect(model.path.isEmpty)
        #expect(!model.showingAddTodo)
    }

    // MARK: - showDetail Tests

    @Test("showDetail appends destination to path")
    func showDetail() {
        let model = NavigationModel()
        let entity = makeTodoEntity(title: "Detail Todo")

        model.showDetail(for: entity)

        #expect(model.path.count == 1)
        if case .todoDetail(let todo) = model.path.first {
            #expect(todo.title == "Detail Todo")
        } else {
            Issue.record("Expected todoDetail destination")
        }
    }

    @Test("showDetail can push multiple destinations")
    func showDetailMultiple() {
        let model = NavigationModel()

        model.showDetail(for: makeTodoEntity(title: "First"))
        model.showDetail(for: makeTodoEntity(title: "Second"))

        #expect(model.path.count == 2)
    }

    // MARK: - popToRoot Tests

    @Test("popToRoot clears entire path")
    func popToRoot() {
        let model = NavigationModel()
        model.showDetail(for: makeTodoEntity(title: "First"))
        model.showDetail(for: makeTodoEntity(title: "Second"))
        #expect(model.path.count == 2)

        model.popToRoot()

        #expect(model.path.isEmpty)
    }

    @Test("popToRoot on empty path does nothing")
    func popToRootEmpty() {
        let model = NavigationModel()

        model.popToRoot()

        #expect(model.path.isEmpty)
    }

    // MARK: - navigateToRoot Tests

    @Test("navigateToRoot clears path and dismisses add todo")
    func navigateToRoot() {
        let model = NavigationModel()
        model.showDetail(for: makeTodoEntity(title: "Some Todo"))
        model.showAddTodo()
        #expect(model.path.count == 1)
        #expect(model.showingAddTodo)

        model.navigateToRoot()

        #expect(model.path.isEmpty)
        #expect(!model.showingAddTodo)
    }

    // MARK: - pop Tests

    @Test("pop removes last destination from path")
    func pop() {
        let model = NavigationModel()
        model.showDetail(for: makeTodoEntity(title: "First"))
        model.showDetail(for: makeTodoEntity(title: "Second"))

        model.pop()

        #expect(model.path.count == 1)
        if case .todoDetail(let todo) = model.path.first {
            #expect(todo.title == "First")
        } else {
            Issue.record("Expected first detail to remain")
        }
    }

    @Test("pop on empty path does nothing")
    func popEmpty() {
        let model = NavigationModel()

        model.pop()

        #expect(model.path.isEmpty)
    }

    // MARK: - showAddTodo / dismissAddTodo Tests

    @Test("showAddTodo sets flag to true")
    func showAddTodo() {
        let model = NavigationModel()

        model.showAddTodo()

        #expect(model.showingAddTodo)
    }

    @Test("dismissAddTodo sets flag to false")
    func dismissAddTodo() {
        let model = NavigationModel()
        model.showAddTodo()
        #expect(model.showingAddTodo)

        model.dismissAddTodo()

        #expect(!model.showingAddTodo)
    }

    @Test("dismissAddTodo on already dismissed state is safe")
    func dismissAddTodoWhenAlreadyDismissed() {
        let model = NavigationModel()

        model.dismissAddTodo()

        #expect(!model.showingAddTodo)
    }
}

// MARK: - NavigationDestination Tests

@Suite("NavigationDestination Tests")
struct NavigationDestinationTests {
    @Test("todoDetail is Hashable based on entity")
    func hashable() {
        let entity = TodoAppEntity(id: "same-id", title: "Test")
        let dest1 = NavigationDestination.todoDetail(entity)
        let dest2 = NavigationDestination.todoDetail(entity)

        #expect(dest1 == dest2)
    }

    @Test("Different entities produce different destinations")
    func differentEntities() {
        let entity1 = TodoAppEntity(id: "id-1", title: "First")
        let entity2 = TodoAppEntity(id: "id-2", title: "Second")

        let dest1 = NavigationDestination.todoDetail(entity1)
        let dest2 = NavigationDestination.todoDetail(entity2)

        #expect(dest1 != dest2)
    }
}
