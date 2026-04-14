//
//  NavigationIntentsTests.swift
//  IntentTodo
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

// MARK: - NavigationModel Tests

@Suite("NavigationModel Tests")
@MainActor
struct NavigationModelTests {
    @Test("Initial state: showingAddTodo is false and path is empty")
    func initialState() {
        let navigation = NavigationModel()
        #expect(navigation.showingAddTodo == false)
        #expect(navigation.path.isEmpty)
    }

    @Test("showAddTodo flips the flag")
    func showAddTodoFlipsFlag() {
        let navigation = NavigationModel()
        navigation.showAddTodo()
        #expect(navigation.showingAddTodo == true)
    }

    @Test("dismissAddTodo resets the flag")
    func dismissAddTodoResetsFlag() {
        let navigation = NavigationModel()
        navigation.showAddTodo()
        navigation.dismissAddTodo()
        #expect(navigation.showingAddTodo == false)
    }

    @Test("navigateToRoot clears the navigation path")
    func navigateToRootClearsPath() {
        let navigation = NavigationModel()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "sample", isCompleted: false)
        navigation.showDetail(for: entity)
        #expect(navigation.path.isEmpty == false)
        navigation.navigateToRoot()
        #expect(navigation.path.isEmpty)
    }
}
