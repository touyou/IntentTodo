//
//  NavigationIntentsTests.swift
//  IntentTodo
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("NavigationIntents Tests")
@MainActor
struct NavigationIntentsTests {
    // MARK: - OpenAddTodoIntent Tests

    @Test("OpenAddTodoIntent sets shouldShowAddTodo to true")
    func openAddTodoSetsState() async throws {
        // Reset state
        IntentAppState.shared.shouldShowAddTodo = false

        let intent = OpenAddTodoIntent()
        _ = try await intent.perform()

        #expect(IntentAppState.shared.shouldShowAddTodo == true)

        // Cleanup
        IntentAppState.shared.shouldShowAddTodo = false
    }

    @Test("OpenAddTodoIntent has foreground support mode")
    func openAddTodoSupportedModes() {
        #expect(OpenAddTodoIntent.supportedModes == .foreground)
    }

    @Test("OpenAddTodoIntent can be initialized")
    func openAddTodoInit() {
        let intent = OpenAddTodoIntent()
        #expect(intent != nil)
    }

    // MARK: - OpenTodoListIntent Tests

    @Test("OpenTodoListIntent performs without error")
    func openTodoListPerforms() async throws {
        let intent = OpenTodoListIntent()

        // Should not throw
        _ = try await intent.perform()
    }

    @Test("OpenTodoListIntent does not affect shouldShowAddTodo")
    func openTodoListDoesNotAffectState() async throws {
        IntentAppState.shared.shouldShowAddTodo = false

        let intent = OpenTodoListIntent()
        _ = try await intent.perform()

        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    @Test("OpenTodoListIntent has foreground support mode")
    func openTodoListSupportedModes() {
        #expect(OpenTodoListIntent.supportedModes == .foreground)
    }

    @Test("OpenTodoListIntent can be initialized")
    func openTodoListInit() {
        let intent = OpenTodoListIntent()
        #expect(intent != nil)
    }
}

// MARK: - IntentAppState Tests

@Suite("IntentAppState Tests")
@MainActor
struct IntentAppStateTests {
    init() {
        // Reset state before each test
        IntentAppState.shared.shouldShowAddTodo = false
    }

    @Test("Initial shouldShowAddTodo is false after reset")
    func initialState() {
        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    @Test("requestShowAddTodo sets shouldShowAddTodo to true")
    func requestShowAddTodo() {
        IntentAppState.shared.requestShowAddTodo()

        #expect(IntentAppState.shared.shouldShowAddTodo == true)

        // Cleanup
        IntentAppState.shared.shouldShowAddTodo = false
    }

    @Test("consumeShowAddTodoRequest returns true and resets when pending")
    func consumeWhenPending() {
        IntentAppState.shared.requestShowAddTodo()

        let wasPending = IntentAppState.shared.consumeShowAddTodoRequest()

        #expect(wasPending == true)
        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    @Test("consumeShowAddTodoRequest returns false when not pending")
    func consumeWhenNotPending() {
        let wasPending = IntentAppState.shared.consumeShowAddTodoRequest()

        #expect(wasPending == false)
        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }

    @Test("Multiple requests, single consume")
    func multipleRequestsSingleConsume() {
        IntentAppState.shared.requestShowAddTodo()
        IntentAppState.shared.requestShowAddTodo()

        let firstConsume = IntentAppState.shared.consumeShowAddTodoRequest()
        let secondConsume = IntentAppState.shared.consumeShowAddTodoRequest()

        #expect(firstConsume == true)
        #expect(secondConsume == false)
    }

    @Test("shouldShowAddTodo can be directly set and read")
    func directSetAndRead() {
        IntentAppState.shared.shouldShowAddTodo = true
        #expect(IntentAppState.shared.shouldShowAddTodo == true)

        IntentAppState.shared.shouldShowAddTodo = false
        #expect(IntentAppState.shared.shouldShowAddTodo == false)
    }
}
