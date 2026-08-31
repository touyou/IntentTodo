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
public struct AddTodoView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var todoDescription = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var isFavorite = false

    @State private var assignee = ""
    @State private var location = ""
    @State private var hasEstimatedDuration = false
    @State private var estimatedDurationMinutes = 30

    /// The schema-derived attributes.
    @State private var attributes = TodoAttributesDraft()

    /// Duration choices, in minutes.
    private static let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240]

    // MARK: - Computed Intent

    /// Dynamically generated intent based on current form state.
    ///
    /// Duration and assignee are bridged into the native App Intents types the intent
    /// takes (`Duration`, `PersonNameComponents`). Location stays a `String` — see
    /// `AddTodoIntent.location`.
    private var addTodoIntent: AddTodoIntent {
        AddTodoIntent(
            title: title,
            todoDescription: todoDescription.isEmpty ? nil : todoDescription,
            dueDate: hasDueDate ? dueDate : nil,
            isFavorite: isFavorite,
            estimatedDuration: hasEstimatedDuration
                ? .seconds(estimatedDurationMinutes * 60)
                : nil,
            assignee: assigneeComponents,
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            tags: attributes.tags,
            urls: attributes.urls,
            recurrenceFrequency: attributes.recurrenceFrequency,
            recurrenceInterval: attributes.recurrenceInterval,
            locationTriggerEvent: attributes.locationTriggerEvent
        )
    }

    private var trimmedAssignee: String {
        assignee.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var assigneeComponents: PersonNameComponents? {
        guard !trimmedAssignee.isEmpty else { return nil }
        return PersonNameComponentsFormatter().personNameComponents(from: trimmedAssignee)
    }

    private var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Formats minutes as "30m" or "1h 30m".
    private static func durationLabel(minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            Section {
                TextField(.copy("Title"), text: $title)
                    .accessibilityIdentifier("todoTitleField")
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif

                TextField(.copy("Description (optional)"), text: $todoDescription, axis: .vertical)
                    .accessibilityIdentifier("todoDescriptionField")
                    .lineLimit(3...6)
            }

            Section {
                Toggle(.copy("Set Due Date"), isOn: $hasDueDate.animation())
                    .accessibilityIdentifier("dueDateToggle")

                if hasDueDate {
                    DatePicker(
                        .copy("Date"),
                        selection: $dueDate,
                        displayedComponents: [.date]
                    )
                    .accessibilityIdentifier("dueDatePicker")

                    DatePicker(
                        .copy("Time"),
                        selection: $dueDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .accessibilityIdentifier("dueTimePicker")
                }

                Toggle(.copy("Mark as Favorite"), isOn: $isFavorite)
                    .accessibilityIdentifier("favoriteToggle")
            }

            Section(.copy("Details")) {
                Toggle(.copy("Set Estimated Duration"), isOn: $hasEstimatedDuration.animation())
                    .accessibilityIdentifier("estimatedDurationToggle")

                if hasEstimatedDuration {
                    Picker(.copy("Duration"), selection: $estimatedDurationMinutes) {
                        ForEach(Self.durationOptions, id: \.self) { minutes in
                            Text(Self.durationLabel(minutes: minutes)).tag(minutes)
                        }
                    }
                    .accessibilityIdentifier("estimatedDurationPicker")
                }

                TextField(.copy("Assignee (optional)"), text: $assignee)
                    .accessibilityIdentifier("assigneeField")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif

                TextField(.copy("Location (optional)"), text: $location)
                    .accessibilityIdentifier("locationField")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
            }

            TodoTagsSection(tags: $attributes.tags)
            TodoLinksSection(urls: $attributes.urls)
            TodoRecurrenceSection(
                frequency: $attributes.recurrenceFrequency,
                interval: $attributes.recurrenceInterval
            )
            TodoLocationTriggerSection(
                event: $attributes.locationTriggerEvent,
                hasLocation: !trimmedLocation.isEmpty
            )
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
                    dismiss()
                }
                .accessibilityIdentifier("cancelButton")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(intent: addTodoIntent) {
                    Text(.copy("Add"))
                }
                .accessibilityIdentifier("addButton")
                .disabled(!isValid)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTodoView()
    }
}
