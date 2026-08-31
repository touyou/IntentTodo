//
//  TodoFormSections.swift
//  UI
//
//  The editing form itself, shared by the add sheet and the edit sheet. The two screens
//  differ only in which intent their confirmation button runs, so a field added here shows
//  up on both and the screens cannot drift apart.
//

import AppIntents
import Domain
import Foundation
import SwiftUI
import TodoAppIntents

// MARK: - Draft

/// Draft state for every field a person can edit, including the schema-derived attributes.
///
/// Not a mutable `TodoAppEntity`: its `tags` and `urls` are deferred properties and so are
/// absent from the snapshot, which makes it useless as a starting point.
struct TodoFormDraft: Equatable {
    var title = ""
    var todoDescription = ""
    var hasDueDate = false
    var dueDate = Date()
    var isFavorite = false
    var hasEstimatedDuration = false
    var estimatedDurationMinutes = Self.defaultDurationMinutes
    var assignee = ""
    var location = ""
    var tags: [String] = []
    var urls: [URL] = []
    var recurrenceFrequency: TodoRecurrenceFrequency?
    var recurrenceInterval = TodoRecurrenceFrequency.minimumInterval
    var locationTriggerEvent: TodoLocationTriggerEvent?

    static let defaultDurationMinutes = 30

    /// Duration choices, in minutes.
    static let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240]

    init() {}

    /// Starts the form from an existing todo.
    ///
    /// - Parameters:
    ///   - todo: only scalar attributes are read; those stay readable even for an object
    ///     the store has already deleted.
    ///   - tags: fetched by the caller via id. Passed in because reading a collection
    ///     attribute off the model can trap — see `TodoDetailContent.tags`.
    ///   - urls: same.
    init(todo: TodoItem, tags: [String], urls: [URL]) {
        title = todo.title
        todoDescription = todo.todoDescription ?? ""
        hasDueDate = todo.dueDate != nil
        dueDate = todo.dueDate ?? Date()
        isFavorite = todo.isFavorite
        if let seconds = todo.estimatedDuration, seconds > 0 {
            hasEstimatedDuration = true
            estimatedDurationMinutes = max(1, Int((seconds / 60).rounded()))
        }
        assignee = todo.assigneeName ?? ""
        location = todo.locationName ?? ""
        self.tags = tags
        self.urls = urls
        recurrenceFrequency = todo.recurrenceFrequency.flatMap(TodoRecurrenceFrequency.init(rawValue:))
        recurrenceInterval = max(TodoRecurrenceFrequency.minimumInterval, todo.recurrenceInterval)
        locationTriggerEvent = todo.locationTriggerEvent.flatMap(TodoLocationTriggerEvent.init(rawValue:))
    }

    // MARK: - Values handed to the intents

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool { !trimmedTitle.isEmpty }

    var descriptionValue: String? {
        let trimmed = todoDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var dueDateValue: Date? { hasDueDate ? dueDate : nil }

    var estimatedDurationValue: Duration? {
        hasEstimatedDuration ? .seconds(estimatedDurationMinutes * 60) : nil
    }

    var trimmedAssignee: String {
        assignee.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `AddTodoIntent` takes the native `PersonNameComponents`; `UpdateTodoIntent` stores
    /// the formatted name, so both spellings are offered here.
    var assigneeComponents: PersonNameComponents? {
        guard !trimmedAssignee.isEmpty else { return nil }
        return PersonNameComponentsFormatter().personNameComponents(from: trimmedAssignee)
    }

    var assigneeValue: String? {
        trimmedAssignee.isEmpty ? nil : trimmedAssignee
    }

    var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var locationValue: String? {
        trimmedLocation.isEmpty ? nil : trimmedLocation
    }

    /// The picker's choices plus the todo's own value, which Siri or Shortcuts may have set
    /// to something off the list. Without it the picker would render blank and saving would
    /// quietly round the duration to a listed option.
    static func durationOptions(including minutes: Int) -> [Int] {
        durationOptions.contains(minutes) ? durationOptions : (durationOptions + [minutes]).sorted()
    }

    /// Formats minutes as "30m" or "1h 30m".
    static func durationLabel(minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

// MARK: - Discard confirmation

extension View {
    /// Guards an edited form against being closed by accident.
    ///
    /// Two halves, because SwiftUI has no way to see a dismiss *attempt*:
    /// - the swipe-down / tap-outside is blocked outright while there are changes
    ///   (resizing between detents still works, and Cancel stays reachable in the toolbar)
    /// - Cancel raises the dialog instead of dismissing
    ///
    /// The save path is untouched: `AddTodoIntent` / `UpdateTodoIntent` close the sheet by
    /// flipping `NavigationModel`'s presentation flag, which `interactiveDismissDisabled`
    /// does not block.
    ///
    /// `dismissalConfirmationDialog(_:shouldPresent:)` would express all of this directly,
    /// but it never fires for sheets on iOS 27 — measured, not assumed.
    func confirmDiscardingForm(
        hasChanges: Bool,
        isConfirming: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        interactiveDismissDisabled(hasChanges)
            .confirmationDialog(
                Text(.copy("Discard Changes?")),
                isPresented: isConfirming,
                titleVisibility: .visible
            ) {
                // The dialog supplies its own cancel action, which means "keep editing".
                Button(role: .destructive, action: onDiscard) {
                    Text(.copy("Discard Changes"))
                }
                .accessibilityIdentifier("discardChangesButton")
            } message: {
                Text(.copy("Your changes haven’t been saved."))
            }
    }
}

// MARK: - Sections

/// Every editable field, in the order both screens present them.
struct TodoFormSections: View {
    @Binding var draft: TodoFormDraft

    var body: some View {
        Group {
            Section {
                TextField(.copy("Title"), text: $draft.title)
                    .accessibilityIdentifier("todoTitleField")
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif

                TextField(
                    .copy("Description (optional)"),
                    text: $draft.todoDescription,
                    axis: .vertical
                )
                .accessibilityIdentifier("todoDescriptionField")
                .lineLimit(3...6)
            }

            Section {
                Toggle(.copy("Set Due Date"), isOn: $draft.hasDueDate.animation())
                    .accessibilityIdentifier("dueDateToggle")

                if draft.hasDueDate {
                    DatePicker(
                        .copy("Date"),
                        selection: $draft.dueDate,
                        displayedComponents: [.date]
                    )
                    .accessibilityIdentifier("dueDatePicker")

                    DatePicker(
                        .copy("Time"),
                        selection: $draft.dueDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .accessibilityIdentifier("dueTimePicker")
                }

                Toggle(.copy("Mark as Favorite"), isOn: $draft.isFavorite)
                    .accessibilityIdentifier("favoriteToggle")
            }

            Section(.copy("Details")) {
                Toggle(
                    .copy("Set Estimated Duration"),
                    isOn: $draft.hasEstimatedDuration.animation()
                )
                .accessibilityIdentifier("estimatedDurationToggle")

                if draft.hasEstimatedDuration {
                    Picker(.copy("Duration"), selection: $draft.estimatedDurationMinutes) {
                        let options = TodoFormDraft.durationOptions(
                            including: draft.estimatedDurationMinutes
                        )
                        ForEach(options, id: \.self) { minutes in
                            Text(TodoFormDraft.durationLabel(minutes: minutes)).tag(minutes)
                        }
                    }
                    .accessibilityIdentifier("estimatedDurationPicker")
                }

                TextField(.copy("Assignee (optional)"), text: $draft.assignee)
                    .accessibilityIdentifier("assigneeField")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif

                TextField(.copy("Location (optional)"), text: $draft.location)
                    .accessibilityIdentifier("locationField")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
            }

            TodoTagsSection(tags: $draft.tags)
            TodoLinksSection(urls: $draft.urls)
            TodoRecurrenceSection(
                frequency: $draft.recurrenceFrequency,
                interval: $draft.recurrenceInterval
            )
            TodoLocationTriggerSection(
                event: $draft.locationTriggerEvent,
                hasLocation: !draft.trimmedLocation.isEmpty
            )
        }
    }
}
