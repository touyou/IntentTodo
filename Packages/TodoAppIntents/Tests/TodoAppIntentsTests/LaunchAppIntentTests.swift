//
//  LaunchAppIntentTests.swift
//  IntentTodo
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

// MARK: - AppScreenTarget Tests

@Suite("AppScreenTarget Tests")
struct AppScreenTargetTests {
    @Test("All cases have raw values")
    func rawValues() {
        #expect(AppScreenTarget.addTodo.rawValue == "addTodo")
        #expect(AppScreenTarget.todoList.rawValue == "todoList")
        #expect(AppScreenTarget.incompleteTodos.rawValue == "incompleteTodos")
        #expect(AppScreenTarget.favoriteTodos.rawValue == "favoriteTodos")
    }

    @Test("All cases have display representations")
    func displayRepresentations() {
        let representations = AppScreenTarget.caseDisplayRepresentations

        #expect(representations[.addTodo] != nil)
        #expect(representations[.todoList] != nil)
        #expect(representations[.incompleteTodos] != nil)
        #expect(representations[.favoriteTodos] != nil)
    }

    @Test("TypeDisplayRepresentation is configured")
    func typeDisplayRepresentation() {
        _ = AppScreenTarget.typeDisplayRepresentation
    }
}

// MARK: - LaunchAppIntent Tests
//
// `perform()` cannot run from SPM tests: resolving `@Dependency` needs the AppIntents
// dispatch flow.

@Suite("LaunchAppIntent Tests")
@MainActor
struct LaunchAppIntentTests {
    // MARK: - Initialization Tests

    @Test("Default initialization sets todoList target")
    func defaultInit() {
        let intent = LaunchAppIntent()

        #expect(intent.target == .todoList)
    }

    @Test("Initialization with specific target")
    func initWithTarget() {
        let intent = LaunchAppIntent(target: .addTodo)

        #expect(intent.target == .addTodo)
    }

    // MARK: - Factory Method Tests

    @Test("addTodo factory creates intent with addTodo target")
    func addTodoFactory() {
        let intent = LaunchAppIntent.addTodo()

        #expect(intent.target == .addTodo)
    }

    @Test("todoList factory creates intent with todoList target")
    func todoListFactory() {
        let intent = LaunchAppIntent.todoList()

        #expect(intent.target == .todoList)
    }

    @Test("incompleteTodos factory creates intent with incompleteTodos target")
    func incompleteTodosFactory() {
        let intent = LaunchAppIntent.incompleteTodos()

        #expect(intent.target == .incompleteTodos)
    }

    @Test("favoriteTodos factory creates intent with favoriteTodos target")
    func favoriteTodosFactory() {
        let intent = LaunchAppIntent.favoriteTodos()

        #expect(intent.target == .favoriteTodos)
    }

    // MARK: - Target → Filter Mapping

    // The mapping is a pure function so it can be tested, which is what stops the list
    // targets from silently regressing to "just opens the app".

    @Test("List targets map to the filter they promise")
    func listFilterMapping() {
        #expect(LaunchAppIntent.listFilter(for: .incompleteTodos) == .incomplete)
        #expect(LaunchAppIntent.listFilter(for: .favoriteTodos) == .favorites)
        #expect(LaunchAppIntent.listFilter(for: .todoList) == .all)
    }

    // MARK: - Metadata Tests

    @Test("LaunchAppIntent has foreground(.immediate) support mode")
    func supportedModes() {
        #expect(LaunchAppIntent.supportedModes == .foreground(.immediate))
    }
}
