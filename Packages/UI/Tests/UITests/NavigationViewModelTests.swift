//
//  NavigationViewModelTests.swift
//  IntentTodo
//

import Foundation
import Testing
import TodoAppIntents
@testable import UI

@MainActor
@Suite("NavigationViewModel Tests")
struct NavigationViewModelTests {
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
        let viewModel = NavigationViewModel()

        #expect(viewModel.path.isEmpty)
        #expect(!viewModel.showingAddTodo)
    }

    // MARK: - showDetail Tests

    @Test("showDetail appends destination to path")
    func showDetail() {
        let viewModel = NavigationViewModel()
        let entity = makeTodoEntity(title: "Detail Todo")

        viewModel.showDetail(for: entity)

        #expect(viewModel.path.count == 1)
        if case .todoDetail(let todo) = viewModel.path.first {
            #expect(todo.title == "Detail Todo")
        } else {
            Issue.record("Expected todoDetail destination")
        }
    }

    @Test("showDetail can push multiple destinations")
    func showDetailMultiple() {
        let viewModel = NavigationViewModel()

        viewModel.showDetail(for: makeTodoEntity(title: "First"))
        viewModel.showDetail(for: makeTodoEntity(title: "Second"))

        #expect(viewModel.path.count == 2)
    }

    // MARK: - popToRoot Tests

    @Test("popToRoot clears entire path")
    func popToRoot() {
        let viewModel = NavigationViewModel()
        viewModel.showDetail(for: makeTodoEntity(title: "First"))
        viewModel.showDetail(for: makeTodoEntity(title: "Second"))
        #expect(viewModel.path.count == 2)

        viewModel.popToRoot()

        #expect(viewModel.path.isEmpty)
    }

    @Test("popToRoot on empty path does nothing")
    func popToRootEmpty() {
        let viewModel = NavigationViewModel()

        viewModel.popToRoot()

        #expect(viewModel.path.isEmpty)
    }

    // MARK: - pop Tests

    @Test("pop removes last destination from path")
    func pop() {
        let viewModel = NavigationViewModel()
        viewModel.showDetail(for: makeTodoEntity(title: "First"))
        viewModel.showDetail(for: makeTodoEntity(title: "Second"))

        viewModel.pop()

        #expect(viewModel.path.count == 1)
        if case .todoDetail(let todo) = viewModel.path.first {
            #expect(todo.title == "First")
        } else {
            Issue.record("Expected first detail to remain")
        }
    }

    @Test("pop on empty path does nothing")
    func popEmpty() {
        let viewModel = NavigationViewModel()

        viewModel.pop()

        #expect(viewModel.path.isEmpty)
    }

    // MARK: - showAddTodo / dismissAddTodo Tests

    @Test("showAddTodo sets flag to true")
    func showAddTodo() {
        let viewModel = NavigationViewModel()

        viewModel.showAddTodo()

        #expect(viewModel.showingAddTodo)
    }

    @Test("dismissAddTodo sets flag to false")
    func dismissAddTodo() {
        let viewModel = NavigationViewModel()
        viewModel.showAddTodo()
        #expect(viewModel.showingAddTodo)

        viewModel.dismissAddTodo()

        #expect(!viewModel.showingAddTodo)
    }

    @Test("dismissAddTodo on already dismissed state is safe")
    func dismissAddTodoWhenAlreadyDismissed() {
        let viewModel = NavigationViewModel()

        viewModel.dismissAddTodo()

        #expect(!viewModel.showingAddTodo)
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
