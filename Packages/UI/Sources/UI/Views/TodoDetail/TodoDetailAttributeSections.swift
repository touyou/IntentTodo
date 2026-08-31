//
//  TodoDetailAttributeSections.swift
//  UI
//
//  The attribute sections of the detail screen, split out from `TodoDetailView.swift` for
//  file length.
//

import Domain
import SwiftUI
import TodoAppIntents

// MARK: - Tags

struct TodoDetailTagsSection: View {
    let tags: [String]

    var body: some View {
        ForEach(tags, id: \.self) { tag in
            Label(tag, systemImage: "number")
                .font(.subheadline)
        }
    }
}

// MARK: - Links

struct TodoDetailLinksSection: View {
    let urls: [URL]

    var body: some View {
        ForEach(urls, id: \.self) { url in
            Link(destination: url) {
                Label(url.absoluteString, systemImage: "link")
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

// MARK: - Metadata

struct TodoDetailMetadataSection: View {
    let todo: TodoItem

    /// Formats the stored seconds as "1h 30m".
    private var formattedDuration: String? {
        guard let seconds = todo.estimatedDuration, seconds > 0 else { return nil }
        return Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        Group {
            LabeledContent(.copy("Created")) {
                Text(todo.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent(.copy("Modified")) {
                Text(todo.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let category = todo.category {
                LabeledContent(.copy("Category")) {
                    HStack {
                        Circle()
                            .fill(category.colorHex.flatMap(Color.init(hex:)) ?? Color.gray)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                    }
                }
            }
            // Values are plain `Text`, matching the rows above: a `Label` in the value
            // position stretches the row vertically.
            if let formattedDuration {
                LabeledContent(.copy("Estimated Duration")) {
                    Text(formattedDuration)
                }
            }
            if let assignee = todo.assigneeName, !assignee.isEmpty {
                LabeledContent(.copy("Assignee")) {
                    Text(assignee)
                }
            }
            if let location = todo.locationName, !location.isEmpty {
                LabeledContent(.copy("Location")) {
                    Text(location)
                }
            }
            // The schema attributes that fit on one row; tags and urls grow, so they get
            // sections of their own.
            if let frequency = recurrenceFrequency {
                LabeledContent(.copy("Repeat")) {
                    // The frequency reads from the enum's own display representations, so
                    // it matches Siri. The interval is appended as a multiplier: phrasing it
                    // as "Every 2 weeks" would need a key per frequency and plural form.
                    HStack(spacing: 4) {
                        Text(frequency.localizedStringResource)
                        if todo.recurrenceInterval > TodoRecurrenceFrequency.minimumInterval {
                            Text(.copy("× \(todo.recurrenceInterval)"))
                        }
                    }
                }
            }
            if let event = locationTriggerEvent {
                LabeledContent(.copy("Location Trigger")) {
                    Text(event.localizedStringResource)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var recurrenceFrequency: TodoRecurrenceFrequency? {
        todo.recurrenceFrequency.flatMap(TodoRecurrenceFrequency.init(rawValue:))
    }

    private var locationTriggerEvent: TodoLocationTriggerEvent? {
        todo.locationTriggerEvent.flatMap(TodoLocationTriggerEvent.init(rawValue:))
    }
}
