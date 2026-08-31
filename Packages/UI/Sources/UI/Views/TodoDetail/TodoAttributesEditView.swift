//
//  TodoAttributesEditView.swift
//  UI
//

import Domain
import SwiftUI
import TodoAppIntents

/// Edits the schema-derived attributes of an existing todo.
///
/// Saving goes through `Button(intent: UpdateTodoIntent(...))`. Because that intent
/// distinguishes replace / clear / leave alone via `IntentParameter.valueState`, only the
/// four fields this screen owns are set; everything else stays `.unset` so the title and
/// due date cannot be rolled back.
struct TodoAttributesEditView: View {
    @Environment(\.dismiss) private var dismiss

    let entity: TodoAppEntity

    /// Only whether a location exists: an event without one is not a trigger.
    let hasLocation: Bool

    @State private var attributes: TodoAttributesDraft

    /// - Parameters:
    ///   - todo: the todo being edited; only its scalar attributes are read here.
    ///   - tags: fetched by the caller via id. Passed in because reading a collection
    ///     attribute off the model can trap — see `TodoDetailContent.tags`.
    ///   - urls: same.
    init(todo: TodoItem, tags: [String], urls: [URL]) {
        self.entity = TodoAppEntity(from: todo)
        self.hasLocation = !(todo.locationName ?? "").isEmpty
        _attributes = State(
            initialValue: TodoAttributesDraft(
                tags: tags,
                urls: urls,
                recurrenceFrequency: todo.recurrenceFrequency.flatMap(TodoRecurrenceFrequency.init(rawValue:)),
                recurrenceInterval: max(TodoRecurrenceFrequency.minimumInterval, todo.recurrenceInterval),
                locationTriggerEvent: todo.locationTriggerEvent.flatMap(TodoLocationTriggerEvent.init(rawValue:))
            )
        )
    }

    private var updateIntent: UpdateTodoIntent {
        UpdateTodoIntent(
            todo: entity,
            tags: attributes.tags,
            urls: attributes.urls,
            recurrenceFrequency: attributes.recurrenceFrequency,
            recurrenceInterval: attributes.recurrenceInterval,
            locationTriggerEvent: attributes.locationTriggerEvent
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TodoTagsSection(tags: $attributes.tags)
                TodoLinksSection(urls: $attributes.urls)
                TodoRecurrenceSection(
                    frequency: $attributes.recurrenceFrequency,
                    interval: $attributes.recurrenceInterval
                )
                TodoLocationTriggerSection(
                    event: $attributes.locationTriggerEvent,
                    hasLocation: hasLocation
                )
            }
            #if os(macOS)
            // `.automatic` sits flush against the window edge on macOS.
            .formStyle(.grouped)
            #endif
            .navigationTitle(.copy("Edit Details"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.copy("Cancel")) {
                        dismiss()
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
                }
            }
        }
    }
}
