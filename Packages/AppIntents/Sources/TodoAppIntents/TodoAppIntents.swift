//
//  TodoAppIntents.swift
//  IntentTodo
//

import AppIntents

@_exported import Repository

/// AppIntents module containing Intent definitions and business logic.
///
/// This module provides:
/// - `AddTodoIntent`: Creates a new todo item
/// - `ToggleTodoCompletionIntent`: Toggles completion status
/// - `DeleteTodoIntent`: Deletes a todo item
/// - `ToggleFavoriteIntent`: Toggles favorite status
/// - `TodoAppEntity`: App Intents entity for todos
/// - `TodoEntityQuery`: Query for finding todos
/// - `IntentDependencies`: DI configuration for Intents
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
