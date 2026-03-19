//
//  LaunchAppIntentTests.swift
//  IntentTodo
//

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
        let typeRep = AppScreenTarget.typeDisplayRepresentation

        #expect(typeRep != nil)
    }
}

// MARK: - LaunchAppIntent Tests

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

    // MARK: - Perform Tests

    @Test("Perform with addTodo target sets IntentAppState")
    func performAddTodo() async throws {
        // Reset state before test
        IntentAppState.shared.shouldShowAddTodo = false

        let intent = LaunchAppIntent(target: .addTodo)
        _ = try await intent.perform()

        #expect(IntentAppState.shared.shouldShowAddTodo == true)

        // Cleanup
        IntentAppState.shared.shouldShowAddTodo = false
    }

    @Test("Perform with todoList target does not set shouldShowAddTodo")
    func performTodoList() async throws {
        IntentAppState.shared.shouldShowAddTodo = false

        let intent = LaunchAppIntent(target: .todoList)
        _ = try await intent.perform()

        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    @Test("Perform with incompleteTodos target does not set shouldShowAddTodo")
    func performIncompleteTodos() async throws {
        IntentAppState.shared.shouldShowAddTodo = false

        let intent = LaunchAppIntent(target: .incompleteTodos)
        _ = try await intent.perform()

        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    @Test("Perform with favoriteTodos target does not set shouldShowAddTodo")
    func performFavoriteTodos() async throws {
        IntentAppState.shared.shouldShowAddTodo = false

        let intent = LaunchAppIntent(target: .favoriteTodos)
        _ = try await intent.perform()

        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    // MARK: - Metadata Tests

    @Test("LaunchAppIntent has foreground support mode")
    func supportedModes() {
        #expect(LaunchAppIntent.supportedModes == .foreground)
    }
}
