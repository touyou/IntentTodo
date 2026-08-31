//
//  VisionOSTodoDetailView.swift
//  UI
//
//  visionOS detail pane for a single todo, split out of `VisionOSTodoView.swift`
//  so neither file outgrows the readable-length budget.
//

#if os(visionOS)
import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

struct VisionOSTodoDetailView: View {
    let todo: TodoAppEntity

    init(todo: TodoAppEntity) {
        self.todo = todo
    }

    var body: some View {
        // An unparseable id goes straight to the missing state, without querying.
        if let targetId = UUID(uuidString: todo.id) {
            VisionOSTodoDetailQueryView(targetId: targetId)
        } else {
            ContentUnavailableView(
                .copy("Todo Not Found"),
                systemImage: "questionmark.circle",
                description: Text(.copy("This todo may have been deleted."))
            )
            .navigationTitle(.copy("Details"))
        }
    }
}

private struct VisionOSTodoDetailQueryView: View {
    @Query private var todoItems: [TodoItem]
    private var todoItem: TodoItem? { todoItems.first }

    init(targetId: UUID) {
        _todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
    }

    var body: some View {
        ScrollView {
            if let item = todoItem {
                VStack(alignment: .leading, spacing: 32) {
                    VisionOSHeaderSection(item: item)
                    if let dueDate = item.dueDate {
                        VisionOSDueDateSection(dueDate: dueDate, isCompleted: item.isCompleted)
                    }
                    if let description = item.todoDescription, !description.isEmpty {
                        VisionOSDescriptionSection(description: description)
                    }
                    if let subTasks = item.subTasks, !subTasks.isEmpty {
                        VisionOSSubtasksSection(subtasks: subTasks)
                    }
                    VisionOSDetailsSection(item: item)
                    VisionOSAttributesSection(item: item)
                    VisionOSActionsSection(entity: TodoAppEntity(from: item))
                }
                .padding(40)
            } else {
                ContentUnavailableView(
                    .copy("Todo Not Found"),
                    systemImage: "questionmark.circle",
                    description: Text(.copy("This todo may have been deleted."))
                )
            }
        }
        .navigationTitle(.copy("Details"))
    }
}

// MARK: - Sections

private struct VisionOSHeaderSection: View {
    let item: TodoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                TodoCheckbox(todo: TodoAppEntity(from: item))
                    .scaleEffect(1.5)
                    .contentShape(.hoverEffect, .circle)
                    .hoverEffect(.highlight)

                Text(item.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
            }

            HStack(spacing: 12) {
                if item.isCompleted {
                    StatusBadge(title: .copy("Completed"), systemImage: "checkmark.circle.fill", color: .green, size: .prominent)
                }
                if item.isFavorite {
                    StatusBadge(title: .copy("Favorite"), systemImage: "star.fill", color: .yellow, size: .prominent)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }
}

private struct VisionOSDueDateSection: View {
    let dueDate: Date
    let isCompleted: Bool

    var body: some View {
        // Liquid Glass stays in the navigation layer (ornament) and the header; body
        // sections are content, so they use plain padding.
        VStack(alignment: .leading, spacing: 12) {
            Text(.copy("Due Date"))
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(dueDate.formatted(date: .complete, time: .omitted)).font(.title2)
                    Text(dueDate.formatted(date: .omitted, time: .shortened))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isCompleted {
                    VisionOSTimeRemainingIndicator(date: dueDate)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VisionOSTimeRemainingIndicator: View {
    let date: Date

    var body: some View {
        // Re-evaluated every minute to follow the due-date status transitions.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let status = DueDateStatus.evaluate(date: date, isCompleted: false, now: context.date)
            VStack {
                Image(systemName: Self.icon(for: status))
                    .font(.largeTitle)
                    .foregroundStyle(Self.color(for: status))
                Text(Self.label(for: status))
                    .font(.caption)
                    .foregroundStyle(Self.color(for: status))
            }
        }
    }

    private static func icon(for status: DueDateStatus) -> String {
        switch status {
        case .overdue: return "exclamationmark.triangle.fill"
        case .dueSoon: return "clock.badge.exclamationmark.fill"
        case .normal: return "clock"
        }
    }

    private static func color(for status: DueDateStatus) -> Color {
        switch status {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return .secondary
        }
    }

    private static func label(for status: DueDateStatus) -> String {
        switch status {
        case .overdue: return "Overdue"
        case .dueSoon: return "Due Soon"
        case .normal: return "Upcoming"
        }
    }
}

private struct VisionOSDescriptionSection: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.copy("Description")).font(.headline).foregroundStyle(.secondary)
            Text(description).font(.body)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VisionOSSubtasksSection: View {
    /// Sorted once at init rather than on every body evaluation.
    private let sortedSubtasks: [SubTask]

    init(subtasks: [SubTask]) {
        self.sortedSubtasks = subtasks.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.copy("Subtasks")).font(.headline).foregroundStyle(.secondary)
            ForEach(sortedSubtasks, id: \.id) { subtask in
                HStack {
                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                    Text(subtask.title).strikethrough(subtask.isCompleted)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Estimated duration, assignee and location. Hidden entirely when none are set.
private struct VisionOSDetailsSection: View {
    let item: TodoItem

    private var formattedDuration: String? {
        guard let seconds = item.estimatedDuration, seconds > 0 else { return nil }
        return Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var assignee: String? {
        item.assigneeName.flatMap { $0.isEmpty ? nil : $0 }
    }

    private var location: String? {
        item.locationName.flatMap { $0.isEmpty ? nil : $0 }
    }

    private var hasContent: Bool {
        formattedDuration != nil || assignee != nil || location != nil
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 12) {
                Text(.copy("Details")).font(.headline).foregroundStyle(.secondary)
                if let formattedDuration {
                    Label(formattedDuration, systemImage: "hourglass").font(.body)
                }
                if let assignee {
                    Label(assignee, systemImage: "person").font(.body)
                }
                if let location {
                    Label(location, systemImage: "mappin.and.ellipse").font(.body)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Shows and edits the schema-derived attributes.
///
/// The spatial UI stacks `VStack`s instead of using a `Form`, so the iOS sections are not
/// reused here — though the edit sheet itself is shared.
private struct VisionOSAttributesSection: View {
    @Environment(NavigationModel.self) private var navigationModel

    let item: TodoItem

    /// Collections are fetched by id rather than read in `body`, because reading one off a
    /// deleted object traps. See `TodoDetailContent.tags`.
    @State private var tags: [String] = []
    @State private var urls: [URL] = []

    private var recurrenceFrequency: TodoRecurrenceFrequency? {
        item.recurrenceFrequency.flatMap(TodoRecurrenceFrequency.init(rawValue:))
    }

    private var locationTriggerEvent: TodoLocationTriggerEvent? {
        item.locationTriggerEvent.flatMap(TodoLocationTriggerEvent.init(rawValue:))
    }

    var body: some View {
        @Bindable var navigationModel = navigationModel

        return VStack(alignment: .leading, spacing: 12) {
            Text(.copy("Tags")).font(.headline).foregroundStyle(.secondary)

            ForEach(tags, id: \.self) { tag in
                Label(tag, systemImage: "number").font(.body)
            }
            ForEach(urls, id: \.self) { url in
                Link(destination: url) {
                    Label(url.absoluteString, systemImage: "link")
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if let recurrenceFrequency {
                Label {
                    // The interval is appended as a multiplier: without it, weekly × 2 and
                    // weekly both read as "Weekly".
                    HStack(spacing: 4) {
                        Text(recurrenceFrequency.localizedStringResource)
                        if item.recurrenceInterval > TodoRecurrenceFrequency.minimumInterval {
                            Text(.copy("× \(item.recurrenceInterval)"))
                        }
                    }
                } icon: {
                    Image(systemName: "repeat")
                }
                .font(.body)
            }
            if let locationTriggerEvent {
                Label {
                    Text(locationTriggerEvent.localizedStringResource)
                } icon: {
                    Image(systemName: "location")
                }
                .font(.body)
            }

            Button(.copy("Edit Details")) {
                navigationModel.showAttributeEditor()
            }
            .buttonStyle(.bordered)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
            .accessibilityIdentifier("editDetailsButton")
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $navigationModel.showingAttributeEditor) {
            TodoAttributesEditView(todo: item, tags: tags, urls: urls)
        }
        .task(id: item.modifiedAt) {
            let entity = TodoAppEntity(from: item)
            let loadedTags = (try? await entity.tags) ?? []
            tags = loadedTags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            urls = (try? await entity.urls) ?? []
        }
    }
}

private struct VisionOSActionsSection: View {
    let entity: TodoAppEntity

    @State private var isConfirmingDelete = false

    var body: some View {
        // visionOS supports neither `.glass` nor `.glassProminent`; the hover effect already
        // carries the interactivity here.
        HStack(spacing: 20) {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    entity.isFavorite ? .copy("Remove from Favorites") : .copy("Add to Favorites"),
                    systemImage: entity.isFavorite ? "star.slash" : "star"
                )
            }
            .buttonStyle(.bordered)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)

            // Confirmed here: `requestConfirmation` has no surface to present on when the
            // caller is an in-app button.
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label(.copy("Delete"), systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
            .confirmationDialog(
                .copy("Delete “\(entity.title)”?"),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
                    Text(.copy("Delete"))
                }
            }
        }
    }
}
#endif
