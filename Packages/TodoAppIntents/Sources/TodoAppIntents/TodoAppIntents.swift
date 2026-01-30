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
///   - `ShowTodosIntent`: Shows all/filtered todos
///   - `OpenTodoListIntent`: Opens the todo list
///   - `OpenAddTodoIntent`: Opens the add todo screen (also used for Action Button)
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
