//
//  ReorderTodosIntent.swift
//  TodoAppIntents
//
//  The canonical "reorder todos" action. The drag-to-reorder UI (WWDC 2026
//  reorderable containers) can't be a `Button(intent:)`, so it calls the shared
//  `TodoService.reorderTodos(orderedIDs:)` directly — the same logic this intent
//  runs. Keeping the action defined as an intent honors the App-Intents-centric
//  principle and makes manual reordering available to Shortcuts / AppIntentsTesting
//  without duplicating logic.
//

import AppIntents

/// Persists a manual ordering of todos from a full, ordered list of ids.
public struct ReorderTodosIntent: AppIntent {
    public static let title: LocalizedStringResource = "Reorder Todos"

    /// UI / Shortcuts drive this; it isn't a standalone discoverable phrase.
    public static let isDiscoverable = false

    /// Pure data mutation — never needs to open the app.
    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Ordered Todo IDs")
    public var orderedIds: [String]

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(orderedIds: [String]) {
        self.orderedIds = orderedIds
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.reorderTodos(orderedIDs: orderedIds)
        return .result()
    }
}
