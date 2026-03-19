//
//  NavigationViewModel.swift
//  IntentTodo
//

import Foundation
import SwiftUI
import TodoAppIntents

/// Navigation destinations for the app.
public enum NavigationDestination: Hashable {
    /// Todo detail view.
    case todoDetail(TodoAppEntity)
}

/// View model managing app-wide navigation state.
///
/// Centralizes navigation logic for consistent navigation behavior
/// across the app and enables programmatic navigation from Intents.
@MainActor
@Observable
public final class NavigationViewModel {
    // MARK: - Navigation State

    /// The navigation path for NavigationStack.
    public var path: [NavigationDestination] = []

    /// Whether the add todo sheet is presented.
    public var showingAddTodo = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation Methods

    /// Navigates to the detail view for a todo.
    /// - Parameter todo: The todo to show details for.
    public func showDetail(for todo: TodoAppEntity) {
        path.append(.todoDetail(todo))
    }

    /// Pops to the root view.
    public func popToRoot() {
        path.removeAll()
    }

    /// Pops the last view from the navigation stack.
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Shows the add todo sheet.
    public func showAddTodo() {
        showingAddTodo = true
    }

    /// Dismisses the add todo sheet.
    public func dismissAddTodo() {
        showingAddTodo = false
    }
}
