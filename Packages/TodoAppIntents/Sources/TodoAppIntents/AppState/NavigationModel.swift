//
//  NavigationModel.swift
//  TodoAppIntents
//
//  Single source of truth for app navigation state.
//  Replaces NavigationViewModel — lives here so Intents can access it via @Dependency.
//
//  Register in App.init():
//    let nav = NavigationModel()
//    self.navigationModel = nav
//    AppDependencyManager.shared.add(dependency: nav)
//

import AppIntents
import Observation

/// Shared navigation state for the entire app.
///
/// Registered via `AppDependencyManager` so intents can write to it from `perform()`.
/// Passed to views via `.environment(navigationModel)` so they can observe and bind to it.
@MainActor
@Observable
public final class NavigationModel {
    // MARK: - State

    /// Navigation stack path for detail views.
    public var path: [NavigationDestination] = []

    /// Whether the add todo sheet is presented.
    public var showingAddTodo: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation Methods

    /// Navigates to the detail view for a todo.
    public func showDetail(for todo: TodoAppEntity) {
        path.append(.todoDetail(todo))
    }

    /// Pops to the root view.
    public func popToRoot() {
        path.removeAll()
    }

    /// Pops the last view from the stack.
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Resets all navigation state to root — call this before programmatic navigation
    /// from intents to ensure a clean slate regardless of current app state.
    public func navigateToRoot() {
        path.removeAll()
        showingAddTodo = false
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
