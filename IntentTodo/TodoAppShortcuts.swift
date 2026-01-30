//
//  TodoAppShortcuts.swift
//  IntentTodo
//
//  Re-exports TodoAppShortcuts from the TodoAppIntents package.
//  The actual implementation is in Packages/TodoAppIntents.
//

import AppIntents
@_exported import TodoAppIntents

// Note: TodoAppShortcuts is now defined in the TodoAppIntents package.
// This file exists for compatibility and to ensure the shortcuts
// are registered with the main app target.
//
// The package provides:
// - Add Todo shortcut
// - Show Todos shortcut
// - Show Incomplete Todos shortcut
// - Show Favorite Todos shortcut
