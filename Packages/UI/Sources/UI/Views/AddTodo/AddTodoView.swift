//
//  AddTodoView.swift
//  IntentTodo
//

import SwiftUI
import AppIntents
import Foundation
import TodoAppIntents

/// A view for adding a new todo item.
///
/// This view collects todo details and creates the todo via AddTodoIntent.
/// Uses `Button(intent:)` with a computed property for dynamic intent generation.
///
/// The fields themselves live in `TodoFormSections`, shared with the edit sheet.
public struct AddTodoView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var draft: TodoFormDraft

    /// The values the sheet opened with, so a half-filled form can ask before it is thrown
    /// away. Set from the same value as `draft` so the two cannot start out of step —
    /// `TodoFormDraft()` stamps `dueDate` with the current time.
    @State private var openedWith: TodoFormDraft

    @State private var isConfirmingDiscard = false

    private var hasChanges: Bool { draft != openedWith }

    // MARK: - Computed Intent

    /// Dynamically generated intent based on current form state.
    ///
    /// Duration and assignee are bridged into the native App Intents types the intent
    /// takes (`Duration`, `PersonNameComponents`). Location stays a `String` — see
    /// `AddTodoIntent.location`.
    private var addTodoIntent: AddTodoIntent {
        AddTodoIntent(
            title: draft.trimmedTitle,
            todoDescription: draft.descriptionValue,
            dueDate: draft.dueDateValue,
            isFavorite: draft.isFavorite,
            estimatedDuration: draft.estimatedDurationValue,
            assignee: draft.assigneeComponents,
            location: draft.locationValue,
            tags: draft.tags,
            urls: draft.urls,
            recurrenceFrequency: draft.recurrenceFrequency,
            recurrenceInterval: draft.recurrenceInterval,
            locationTriggerEvent: draft.locationTriggerEvent
        )
    }

    // MARK: - Initialization

    public init() {
        let draft = TodoFormDraft()
        _draft = State(initialValue: draft)
        _openedWith = State(initialValue: draft)
    }

    // MARK: - Body

    public var body: some View {
        Form {
            TodoFormSections(draft: $draft)
        }
        #if os(macOS)
        // `.automatic` sits flush against the window edge on macOS with no background.
        .formStyle(.grouped)
        #endif
        .navigationTitle(.copy("New Todo"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(.copy("Cancel")) {
                    if hasChanges {
                        isConfirmingDiscard = true
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier("cancelButton")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(intent: addTodoIntent) {
                    Text(.copy("Add"))
                }
                .accessibilityIdentifier("addButton")
                .disabled(!draft.isValid)
            }
        }
        .confirmDiscardingForm(
            hasChanges: hasChanges,
            isConfirming: $isConfirmingDiscard,
            onDiscard: { dismiss() }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTodoView()
    }
}
