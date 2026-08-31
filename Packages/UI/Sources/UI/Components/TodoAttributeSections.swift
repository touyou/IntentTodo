//
//  TodoAttributeSections.swift
//  UI
//
//  Form sections for the schema-derived attributes, shared by the add screen and the edit
//  sheet.
//
//  They only collect input; writing happens in the caller's `Button(intent:)`, so the logic
//  is not duplicated per screen.
//

import AppIntents
import SwiftUI
import TodoAppIntents

// MARK: - Draft

/// Draft state while the form is being edited.
///
/// Not a mutable `TodoAppEntity`: its `tags` and `urls` are deferred properties and so are
/// absent from the snapshot, which makes it useless as a starting point.
struct TodoAttributesDraft {
    var tags: [String] = []
    var urls: [URL] = []
    var recurrenceFrequency: TodoRecurrenceFrequency?
    var recurrenceInterval: Int = TodoRecurrenceFrequency.minimumInterval
    var locationTriggerEvent: TodoLocationTriggerEvent?
}

// MARK: - Tags

/// Lists the tags and offers a field to add one.
struct TodoTagsSection: View {
    @Binding var tags: [String]

    @State private var newTag = ""

    private var trimmedNewTag: String {
        newTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Uses the same comparison as the save path (`TodoAttributes.isSameTag`). A looser
    /// check here would accept tags that normalisation then silently drops.
    private var canAddNewTag: Bool {
        guard !trimmedNewTag.isEmpty else { return false }
        return !tags.contains { TodoAttributes.isSameTag($0, trimmedNewTag) }
    }

    var body: some View {
        Section {
            ForEach(tags, id: \.self) { tag in
                Label(tag, systemImage: "number")
            }
            .onDelete { offsets in
                tags.remove(atOffsets: offsets)
            }

            HStack {
                TextField(.copy("Add Tag"), text: $newTag)
                    .accessibilityIdentifier("tagField")
                    .onSubmit(addTag)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                Button(.copy("Add"), action: addTag)
                    .accessibilityIdentifier("addTagButton")
                    .disabled(!canAddNewTag)
                    .buttonStyle(.borderless)
            }
        } header: {
            Text(.copy("Tags"))
        }
    }

    private func addTag() {
        guard canAddNewTag else { return }
        tags.append(trimmedNewTag)
        newTag = ""
    }
}

// MARK: - Links

/// Lists the attached links and offers a field to add one.
struct TodoLinksSection: View {
    @Binding var urls: [URL]

    @State private var newLink = ""

    private var parsedNewLink: URL? {
        TodoLinkInput.url(from: newLink)
    }

    private var canAddNewLink: Bool {
        guard let parsedNewLink else { return false }
        return !urls.contains(parsedNewLink)
    }

    var body: some View {
        Section {
            ForEach(urls, id: \.self) { url in
                // Not a `Link`: opening a URL mid-edit is not what the tap means here.
                Label(url.absoluteString, systemImage: "link")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .onDelete { offsets in
                urls.remove(atOffsets: offsets)
            }

            HStack {
                TextField(.copy("Add Link"), text: $newLink)
                    .accessibilityIdentifier("linkField")
                    .onSubmit(addLink)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    #endif

                Button(.copy("Add"), action: addLink)
                    .accessibilityIdentifier("addLinkButton")
                    .disabled(!canAddNewLink)
                    .buttonStyle(.borderless)
            }
        } header: {
            Text(.copy("Links"))
        }
    }

    private func addLink() {
        guard let parsedNewLink, canAddNewLink else { return }
        urls.append(parsedNewLink)
        newLink = ""
    }
}

/// Turns field text into a `URL`.
enum TodoLinkInput {
    /// Adds `https://` when the scheme is missing.
    ///
    /// `URL(string:)` accepts `"example.com"` as a scheme-less relative URL, which would
    /// store links that cannot be opened.
    static func url(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let candidate = URL(string: trimmed) else { return nil }
        if candidate.scheme != nil {
            return candidate
        }
        return URL(string: "https://\(trimmed)")
    }
}

// MARK: - Recurrence

/// Recurrence frequency and interval.
struct TodoRecurrenceSection: View {
    @Binding var frequency: TodoRecurrenceFrequency?
    @Binding var interval: Int

    /// Wide enough to stay meaningful for yearly recurrence, narrow enough for a stepper.
    private static let intervalRange = TodoRecurrenceFrequency.minimumInterval...30

    var body: some View {
        Section {
            Picker(selection: $frequency.animation()) {
                Text(.copy("Never")).tag(TodoRecurrenceFrequency?.none)
                // Reads the `AppEnum`'s own `caseDisplayRepresentations` through
                // `localizedStringResource`, so Siri and the app UI share one set of words.
                // A second copy in this package's catalog would rot separately.
                ForEach(TodoRecurrenceFrequency.allCases, id: \.self) { option in
                    Text(option.localizedStringResource).tag(TodoRecurrenceFrequency?.some(option))
                }
            } label: {
                Text(.copy("Repeat"))
            }
            .accessibilityIdentifier("recurrencePicker")

            if frequency != nil {
                Stepper(value: $interval, in: Self.intervalRange) {
                    LabeledContent(.copy("Repeat Every")) {
                        Text(interval, format: .number)
                    }
                }
                .accessibilityIdentifier("recurrenceIntervalStepper")
            }
        }
    }
}

// MARK: - Location trigger

/// Whether arriving or leaving surfaces the todo.
struct TodoLocationTriggerSection: View {
    @Binding var event: TodoLocationTriggerEvent?

    /// A trigger needs both a place and an event, so the picker stays usable and the footer
    /// explains why it has no effect yet.
    let hasLocation: Bool

    var body: some View {
        Section {
            Picker(selection: $event) {
                Text(.copy("Never")).tag(TodoLocationTriggerEvent?.none)
                ForEach(TodoLocationTriggerEvent.allCases, id: \.self) { option in
                    Text(option.localizedStringResource).tag(TodoLocationTriggerEvent?.some(option))
                }
            } label: {
                Text(.copy("Location Trigger"))
            }
            .accessibilityIdentifier("locationTriggerPicker")
        } footer: {
            if event != nil && !hasLocation {
                Text(.copy("Add a location for this to take effect."))
            }
        }
    }
}
