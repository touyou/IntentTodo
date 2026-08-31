//
//  TodoUndoRegistrar.swift
//  TodoAppIntents
//
//  Undo registration for every `UndoableIntent`, in one place: there are three delete
//  intents (confirming, non-confirming, bulk) and duplicating the registration invites
//  fixing only one of them.
//

import AppIntents
import Domain
import Foundation

/// Registers undo handlers for todo mutations performed by `UndoableIntent`s.
///
/// `undoManager` is provided by the surface that ran the intent; callers that do not have
/// one (a widget `Button(intent:)`, for instance) leave it `nil` and every registration
/// becomes a no-op. That is expected, not a failure.
enum TodoUndoRegistrar {
    /// Registers undo for a delete. `snapshots` must have been taken *before* deleting.
    ///
    /// `UndoManager.registerUndo(withTarget:handler:)` isolates the handler to the main
    /// actor, so `TodoService` can be called directly without hopping through a task.
    @MainActor
    static func registerRestore(
        _ snapshots: [TodoItemSnapshot],
        undoManager: UndoManager?,
        service: TodoService
    ) {
        guard let undoManager, !snapshots.isEmpty else { return }
        undoManager.registerUndo(withTarget: service) { service in
            for snapshot in snapshots {
                // One failure must not stop the rest: throwing mid-undo would leave a
                // partially restored state with nothing to explain it.
                _ = try? service.restore(snapshot)
            }
        }
        undoManager.setActionName(
            String(localized: "Delete ^[\(snapshots.count) Todo](inflect: true)")
        )
    }

    /// Registers undo for a completion change.
    ///
    /// Undo restores the *previous value* with `setCompletion` rather than toggling back:
    /// if anything else changed the state meanwhile (Siri, a widget, a CloudKit merge from
    /// another device), a toggle would land on the wrong value.
    @MainActor
    static func registerCompletionChange(
        todoId: String,
        previousValue: Bool,
        undoManager: UndoManager?,
        service: TodoService
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: service) { service in
            _ = try? service.setCompletion(todoId: todoId, isCompleted: previousValue)
        }
        undoManager.setActionName(
            previousValue
                ? String(localized: "Mark Todo Incomplete")
                : String(localized: "Complete Todo")
        )
    }
}
