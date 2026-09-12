//
//  TodoAttributeSections.swift
//  UI
//
//  Form sections for the schema-derived attributes, composed by `TodoFormSections`.
//
//  They only collect input; writing happens in the caller's `Button(intent:)`, so the logic
//  is not duplicated per screen.
//

import AppIntents
import Domain
import PhotosUI
import SwiftData
import SwiftUI
import TodoAppIntents
import UniformTypeIdentifiers

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

// MARK: - Filing

/// Picks the list, and the section within it, the todo is filed under.
///
/// The two pickers are coupled: a section belongs to exactly one list, so choosing a
/// section adopts its list, and moving to another list drops a section that would no
/// longer be part of it. That is the same rule `TodoService.applyFiling` applies to the
/// values Siri and Shortcuts send, so the form can't express a filing the intents reject.
struct TodoFilingSection: View {
    @Binding var list: CategoryAppEntity?
    @Binding var section: TodoSectionAppEntity?

    @Query(sort: \Domain.Category.name)
    private var categories: [Domain.Category]

    @Query(sort: \TodoSection.sortIndex)
    private var sections: [TodoSection]

    /// Only the chosen list's sections are offerable; with no list there is nothing to
    /// subdivide, so the picker is hidden rather than shown empty.
    private var sectionsInList: [TodoSection] {
        guard let listID = list?.id else { return [] }
        return sections.filter { $0.category?.id.uuidString == listID }
    }

    var body: some View {
        Section {
            Picker(selection: $list) {
                Text(.copy("No List")).tag(CategoryAppEntity?.none)
                ForEach(categories, id: \.id) { category in
                    Text(category.name).tag(CategoryAppEntity?.some(CategoryAppEntity(from: category)))
                }
            } label: {
                Text(.copy("List"))
            }
            .accessibilityIdentifier("listPicker")
            .onChange(of: list) { _, newList in
                if section?.list.id != newList?.id { section = nil }
            }

            if !sectionsInList.isEmpty {
                Picker(selection: $section) {
                    Text(.copy("No Section")).tag(TodoSectionAppEntity?.none)
                    ForEach(sectionsInList, id: \.id) { candidate in
                        Text(candidate.name)
                            .tag(TodoSectionAppEntity?.some(TodoSectionAppEntity(from: candidate)))
                    }
                } label: {
                    Text(.copy("Section"))
                }
                .accessibilityIdentifier("sectionPicker")
            }
        }
    }
}

// MARK: - Attachments

/// Lists the attached images and offers a picker to add more.
///
/// Holds `TodoAttachmentValue` rather than the stored `TodoAttachment`: the form has to
/// survive the todo being deleted underneath it, and the intents take values anyway.
struct TodoAttachmentsSection: View {
    @Binding var attachments: [TodoAttachmentValue]

    @State private var picked: [PhotosPickerItem] = []

    /// Set while `loadTransferable` is in flight, so the row can't be tapped twice.
    @State private var isLoading = false

    var body: some View {
        Section {
            ForEach(attachments) { attachment in
                AttachmentRow(attachment: attachment)
            }
            .onDelete { offsets in
                attachments.remove(atOffsets: offsets)
            }

            PhotosPicker(selection: $picked, matching: .images) {
                Label {
                    Text(.copy("Add Image"))
                } icon: {
                    Image(systemName: "photo.badge.plus")
                }
            }
            .accessibilityIdentifier("addAttachmentButton")
            .disabled(isLoading)
        } header: {
            Text(.copy("Attachments"))
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
    }

    /// Reads the picked items into memory and clears the selection.
    ///
    /// The bytes are loaded here rather than at save time because the picker's items are
    /// only valid while the picker's scope is alive, and the form can sit open for a while.
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        defer {
            isLoading = false
            picked = []
        }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let type = item.supportedContentTypes.first
            attachments.append(
                TodoAttachmentValue(
                    filename: Self.filename(for: item, type: type),
                    typeIdentifier: type?.identifier,
                    data: data
                )
            )
        }
    }

    /// `PhotosPickerItem` has no filename, so one is derived from the asset identifier and
    /// the content type. The name is what the attachment is labelled with, and it is also
    /// half of how a saved edit recognises an image it already stored.
    private static func filename(for item: PhotosPickerItem, type: UTType?) -> String {
        let base = item.itemIdentifier ?? UUID().uuidString
        guard let ext = type?.preferredFilenameExtension else { return base }
        return "\(base).\(ext)"
    }
}

/// One attachment: its thumbnail and name.
private struct AttachmentRow: View {
    let attachment: TodoAttachmentValue

    var body: some View {
        Label {
            Text(attachment.filename)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            AttachmentThumbnail(data: attachment.data)
        }
    }
}

/// A small preview of the bytes, or a placeholder when they aren't an image.
struct AttachmentThumbnail: View {
    let data: Data

    /// The square side to render at. The form's rows want a small icon, the detail view a
    /// readable preview, and clipping has to happen at the final size.
    var side: CGFloat = 32

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
            #elseif canImport(AppKit)
            if let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: 4))
    }

    private var placeholder: some View {
        Image(systemName: "doc")
            .foregroundStyle(.secondary)
    }
}
