//
//  AppShortcutParameterUpdater.swift
//  IntentTodo
//
//  Bridges "the todo data changed" (package side) to
//  `TodoAppShortcuts.updateAppShortcutParameters()` (app target side).
//

import Foundation

/// Indirection that lets package code ask the system to refetch App Shortcut parameter
/// suggestions.
///
/// `updateAppShortcutParameters()` is a static method on the **concrete**
/// `AppShortcutsProvider`, and that type can only live in the app target, which package
/// code cannot reference — so the app registers a closure at launch instead.
///
/// Call it when entities are added or removed, when a `displayRepresentation` changes, and
/// **on first launch**: parameterised phrases do not work until the system has fetched
/// entities at least once.
///
@MainActor
public enum AppShortcutParameterUpdater {
    private static var updateHandler: (@MainActor () -> Void)?

    /// The app passes `{ TodoAppShortcuts.updateAppShortcutParameters() }` at launch.
    public static func register(_ handler: @escaping @MainActor () -> Void) {
        updateHandler = handler
    }

    /// Tells the system the entity set or its display changed.
    ///
    /// A no-op in processes that never registered a handler, such as the widget extension —
    /// correct, since the parameters belong to the app target's provider.
    public static func notifyEntitiesChanged() {
        updateHandler?()
    }
}
