//
//  IntentAppState.swift
//  TodoAppIntents
//
//  Shared app state for Intent-to-UI communication.
//  Intents can set this state, and Views can observe it.
//

import Foundation
import os.log
import Repository

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "IntentAppState")

/// Shared app state for communication between Intents and UI.
///
/// This is a simple mechanism for Intents to trigger UI actions when the app opens.
/// Uses App Group UserDefaults for cross-process communication (Extension -> App).
@MainActor
public final class IntentAppState {
    // MARK: - Singleton

    public static let shared = IntentAppState()

    private init() {}

    // MARK: - Keys

    private enum Keys {
        static let shouldShowAddTodo = "IntentAppState.shouldShowAddTodo"
    }

    // MARK: - Shared UserDefaults

    /// UserDefaults shared via App Group for cross-process communication.
    /// Falls back to standard UserDefaults if App Group is not configured.
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
    }

    // MARK: - State Properties

    /// Flag indicating the add todo screen should be shown.
    /// Set by `OpenAddTodoIntent`, consumed by the main app.
    public var shouldShowAddTodo: Bool {
        get {
            sharedDefaults.bool(forKey: Keys.shouldShowAddTodo)
        }
        set {
            sharedDefaults.set(newValue, forKey: Keys.shouldShowAddTodo)
        }
    }

    // MARK: - Convenience Methods

    /// Requests the app to show the add todo screen.
    /// Call this from Intents that need to open the add screen.
    public func requestShowAddTodo() {
        logger.info("requestShowAddTodo() called, setting shouldShowAddTodo = true")
        shouldShowAddTodo = true
    }

    /// Consumes the add todo request and returns whether it was pending.
    /// Call this from the View to check and clear the pending request.
    /// - Returns: `true` if an add todo request was pending.
    public func consumeShowAddTodoRequest() -> Bool {
        let wasPending = shouldShowAddTodo
        logger.info("consumeShowAddTodoRequest() called, wasPending = \(wasPending)")
        guard shouldShowAddTodo else { return false }
        shouldShowAddTodo = false
        return true
    }
}
