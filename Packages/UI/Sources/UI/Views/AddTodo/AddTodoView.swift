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
    @Environment(NavigationModel.self) private var navigationModel

    @State private var draft: TodoFormDraft
    @FocusState private var isTitleFocused: Bool

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
            locationTriggerEvent: draft.locationTriggerEvent,
            list: draft.list,
            section: draft.section,
            images: draft.attachments
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
            TodoFormSections(draft: $draft, titleFocus: $isTitleFocused) {
                keepAddingSection
            }
        }
        .onChange(of: navigationModel.addTodoResetCount) {
            startNextTodo()
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
                Button {
                    if hasChanges {
                        isConfirmingDiscard = true
                    } else {
                        dismiss()
                    }
                } label: {
                    ToolbarActionLabel(text: .copy("Cancel"), systemImage: "xmark")
                }
                .accessibilityIdentifier("cancelButton")
                .accessibilityLabel(.copy("Cancel"))
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(intent: addTodoIntent) {
                    ToolbarActionLabel(text: .copy("Add"), systemImage: "checkmark")
                }
                .accessibilityIdentifier("addButton")
                .accessibilityLabel(.copy("Add"))
                .disabled(!draft.isValid)
            }
        }
        .confirmDiscardingForm(
            hasChanges: hasChanges,
            isConfirming: $isConfirmingDiscard,
            onDiscard: { dismiss() }
        )
    }

    // MARK: - Keep Adding

    private var keepAddingSection: some View {
        @Bindable var navigationModel = navigationModel
        return Section {
            Toggle(.copy("Keep Adding"), isOn: $navigationModel.keepsAddingTodos)
                .accessibilityIdentifier("keepAddingToggle")
        } footer: {
            Text(.copy("After adding, the form clears for the next todo."))
        }
    }

    /// Clears the form after a successful add that kept the sheet open.
    ///
    /// List and section carry over: a run of todos usually goes to the same place.
    private func startNextTodo() {
        var next = TodoFormDraft()
        next.list = draft.list
        next.section = draft.section
        draft = next
        openedWith = next
        isTitleFocused = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTodoView()
    }
    .environment(NavigationModel())
}
