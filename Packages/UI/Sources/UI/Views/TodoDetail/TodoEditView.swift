//
//  TodoEditView.swift
//  UI
//

import Domain
import SwiftUI
import TodoAppIntents

/// Edits an existing todo.
///
/// Presents the same fields as the add sheet (`TodoFormSections`), so anything that can be
/// set while creating a todo can be changed afterwards.
///
/// Saving goes through `Button(intent: UpdateTodoIntent(...))`. Every field is passed, so
/// each parameter's `valueState` is `.set` — including `.set(nil)`, which is how the form
/// clears an optional field. The draft starts from the current values, so an untouched
/// field is written back unchanged.
struct TodoEditView: View {
    @Environment(\.dismiss) private var dismiss

    let entity: TodoAppEntity

    @State private var draft: TodoFormDraft

    /// The todo's values as the sheet opened, so edits can be confirmed before they are
    /// thrown away.
    @State private var openedWith: TodoFormDraft

    @State private var isConfirmingDiscard = false

    private var hasChanges: Bool { draft != openedWith }

    /// - Parameters:
    ///   - todo: the todo being edited; only its scalar attributes are read here.
    ///   - tags: fetched by the caller via id. Passed in because reading a collection
    ///     attribute off the model can trap — see `TodoDetailContent.tags`.
    ///   - urls: same.
    init(todo: TodoItem, tags: [String], urls: [URL]) {
        self.entity = TodoAppEntity(from: todo)
        let draft = TodoFormDraft(todo: todo, tags: tags, urls: urls)
        _draft = State(initialValue: draft)
        _openedWith = State(initialValue: draft)
    }

    private var updateIntent: UpdateTodoIntent {
        UpdateTodoIntent(
            todo: entity,
            title: draft.trimmedTitle,
            todoDescription: draft.descriptionValue,
            dueDate: draft.dueDateValue,
            isFavorite: draft.isFavorite,
            estimatedDuration: draft.estimatedDurationValue,
            assigneeName: draft.assigneeValue,
            locationName: draft.locationValue,
            tags: draft.tags,
            urls: draft.urls,
            recurrenceFrequency: draft.recurrenceFrequency,
            recurrenceInterval: draft.recurrenceInterval,
            locationTriggerEvent: draft.locationTriggerEvent
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TodoFormSections(draft: $draft)
            }
            #if os(macOS)
            // `.automatic` sits flush against the window edge on macOS.
            .formStyle(.grouped)
            #endif
            .navigationTitle(.copy("Edit Todo"))
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
                    .accessibilityIdentifier("cancelAttributesButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    // The sheet is closed by `UpdateTodoIntent.perform()`. Dismissing here
                    // as well would also close it when the intent fails, which reads as
                    // "saved".
                    Button(intent: updateIntent) {
                        Text(.copy("Save"))
                    }
                    .accessibilityIdentifier("saveAttributesButton")
                    .disabled(!draft.isValid)
                }
            }
        }
        .confirmDiscardingForm(
            hasChanges: hasChanges,
            isConfirming: $isConfirmingDiscard,
            onDiscard: { dismiss() }
        )
    }
}
