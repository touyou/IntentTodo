//
//  TodoAppIntents.swift
//  IntentTodo
//

import AppIntents

@_exported import Repository

/// AppIntents module containing Intent definitions and business logic.
///
/// This module provides:
/// - **Intents**:
///   - `AddTodoIntent`: Creates a new todo item
///   - `ToggleTodoCompletionIntent`: Toggles completion status
///   - `DeleteTodoIntent`: Deletes a todo item
///   - `ToggleFavoriteIntent`: Toggles favorite status
///   - `ShowTodosIntent`: Shows todos with optional filter (all/incomplete/favorites)
///   - `LaunchAppIntent`: Opens the app to a specific screen (addTodo/todoList/etc.)
/// - **Entity**:
///   - `TodoAppEntity`: App Intents entity for todos
/// - **Query**:
///   - `TodoEntityQuery`: Query for finding todos
/// - **Shortcuts**:
///   - `TodoAppShortcuts`: App Shortcuts provider
/// - **Dependencies**:
///   - `IntentDependencies`: DI configuration for Intents
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
