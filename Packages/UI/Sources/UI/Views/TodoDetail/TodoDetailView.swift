//
//  TodoDetailView.swift
//  IntentTodo
//

import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// Detail view for a single todo item.
///
/// Actions use `Button(intent:)` for consistency with App Intents architecture.
public struct TodoDetailView: View {
    let todo: TodoAppEntity

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    public var body: some View {
        // An unparseable id goes straight to the missing state instead of issuing a query
        // that cannot match.
        if let targetId = UUID(uuidString: todo.id) {
            TodoDetailQueryView(targetId: targetId, fallbackTitle: todo.title)
        } else {
            ContentUnavailableView(
                .copy("Todo Not Found"),
                systemImage: "questionmark.circle",
                description: Text(.copy("This todo may have been deleted."))
            )
            .navigationTitle(todo.title)
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Query Wrapper

/// `@Environment(\.dismiss)` does nothing in a split view's detail pane, so a todo that
/// disappears is handled by clearing `NavigationModel.selectedTodo` — which also pops the
/// collapsed navigation stack at compact width.
private struct TodoDetailQueryView: View {
    @Query private var todoItems: [TodoItem]
    @Environment(NavigationModel.self) private var navigationModel

    let fallbackTitle: String

    private var todo: TodoItem? { todoItems.first }

    init(targetId: UUID, fallbackTitle: String) {
        self.fallbackTitle = fallbackTitle
        _todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
    }

    var body: some View {
        Group {
            if let todo {
                TodoDetailContent(todo: todo)
            } else {
                ContentUnavailableView(
                    .copy("Todo Not Found"),
                    systemImage: "questionmark.circle",
                    description: Text(.copy("This todo may have been deleted."))
                )
            }
        }
        // Falls back to the title captured at selection time so a deleted todo does not
        // leave the pane untitled.
        .navigationTitle(todo?.title ?? fallbackTitle)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: todo) { _, newValue in
            if newValue == nil {
                navigationModel.selectedTodo = nil
            }
        }
    }
}

// MARK: - Detail Content

private struct TodoDetailContent: View {
    /// Activity type advertised to Siri / Apple Intelligence as onscreen content.
    /// Must match the `NSUserActivityTypes` entry in the app's Info.plist.
    private static let viewingTodoActivityType = "dev.touyou.IntentTodo.ViewingTodo"

    @Environment(NavigationModel.self) private var navigationModel

    let todo: TodoItem

    /// Snapshot of the collection attributes.
    ///
    /// **Never read `todo.tags` or `todo.urls` inside `body`.** Reading a collection
    /// attribute off a deleted SwiftData object traps (scalars survive), and for one frame
    /// after a delete the `@Query` result still contains that object — enough to crash the
    /// detail view mid-redraw. A `!todo.isDeleted` guard does not help; it is still false at
    /// that point.
    ///
    /// Fetching by id is safe, which is why the entity exposes these as
    /// `@DeferredProperty`: a deleted todo simply resolves to nothing.
    @State private var tags: [String] = []
    @State private var urls: [URL] = []

    private var entity: TodoAppEntity { TodoAppEntity(from: todo) }

    var body: some View {
        @Bindable var navigationModel = navigationModel

        return List {
            Section { TodoDetailHeaderSection(todo: todo, entity: entity) }

            if let dueDate = todo.dueDate {
                Section(.copy("Due Date")) {
                    TodoDetailDueDateSection(dueDate: dueDate, isCompleted: todo.isCompleted)
                }
            }

            if let description = todo.todoDescription, !description.isEmpty {
                Section(.copy("Description")) {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if let subTasks = todo.subTasks, !subTasks.isEmpty {
                Section(.copy("Subtasks")) {
                    TodoDetailSubtasksSection(subtasks: subTasks)
                }
            }

            if !tags.isEmpty {
                Section(.copy("Tags")) {
                    TodoDetailTagsSection(tags: tags)
                }
            }

            if !urls.isEmpty {
                Section(.copy("Links")) {
                    TodoDetailLinksSection(urls: urls)
                }
            }

            Section(.copy("Info")) {
                TodoDetailMetadataSection(todo: todo)
            }

            Section {
                TodoDetailActionsSection(entity: entity)
            }
        }
        #if os(visionOS)
        .listStyle(.plain)
        #endif
        // Onscreen Entities (WWDC 2026): advertise the visible todo to Siri /
        // Apple Intelligence so the person can ask about "this" todo. The
        // association is cleared automatically when the view goes away.
        .userActivity(Self.viewingTodoActivityType) { activity in
            activity.title = String(localized: .copy("Viewing \(todo.title)"))
            activity.appEntityIdentifier = EntityIdentifier(for: entity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(.copy("Edit")) {
                    navigationModel.showAttributeEditor()
                }
                .accessibilityIdentifier("editDetailsButton")
            }
        }
        // Presentation state lives in `NavigationModel` because the intent is what closes
        // the sheet, and an intent cannot reach `@Environment(\.dismiss)`.
        .sheet(isPresented: $navigationModel.showingAttributeEditor) {
            // Snapshots again, not the model's collections: a todo deleted while the sheet
            // is up would trap the same way. Scalars are safe to read.
            TodoEditView(todo: todo, tags: tags, urls: urls)
        }
        // Keyed on `modifiedAt`: a scalar, so it stays readable even for a deleted object,
        // and it advances whenever `UpdateTodoIntent` saves.
        .task(id: todo.modifiedAt) {
            await refreshCollections(of: entity)
        }
    }

    /// Re-fetches the collections by id, yielding empty for a deleted todo.
    ///
    /// Tags come back as a `Set`, so the order is chosen here: collation order, which at
    /// least makes it deterministic.
    private func refreshCollections(of entity: TodoAppEntity) async {
        let loadedTags = (try? await entity.tags) ?? []
        tags = loadedTags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        urls = (try? await entity.urls) ?? []
    }
}

// MARK: - Header

private struct TodoDetailHeaderSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TodoCheckbox(todo: entity)
                Text(todo.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
            }

            HStack(spacing: 8) {
                if todo.isCompleted {
                    StatusBadge(title: .copy("Completed"), systemImage: "checkmark.circle.fill", color: .green)
                }
                if todo.isFavorite {
                    StatusBadge(title: .copy("Favorite"), systemImage: "star.fill", color: .yellow)
                }
                if let dueDate = todo.dueDate, !todo.isCompleted {
                    switch DueDateStatus.evaluate(date: dueDate, isCompleted: false) {
                    case .overdue:
                        StatusBadge(title: .copy("Overdue"), systemImage: "exclamationmark.circle.fill", color: .red)
                    case .dueSoon:
                        StatusBadge(title: .copy("Due Soon"), systemImage: "clock.fill", color: .orange)
                    case .normal:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Due Date Section

private struct TodoDetailDueDateSection: View {
    let dueDate: Date
    let isCompleted: Bool

    private var color: Color {
        switch DueDateStatus.evaluate(date: dueDate, isCompleted: isCompleted) {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar").foregroundStyle(color)
                Text(dueDate.formatted(date: .complete, time: .omitted)).font(.body)
            }

            HStack {
                Image(systemName: "clock").foregroundStyle(color)
                Text(dueDate.formatted(date: .omitted, time: .shortened)).font(.body)
            }

            if !isCompleted {
                TodoDetailTimeRemainingLabel(date: dueDate)
            }
        }
    }
}

// MARK: - Time Remaining

private struct TodoDetailTimeRemainingLabel: View {
    let date: Date

    var body: some View {
        // Re-evaluated every minute to follow the overdue / due-soon transitions.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let interval = date.timeIntervalSince(context.date)
            if interval <= 0 {
                Label(
                    .copy("Overdue by \(Self.format(-interval))"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            } else if interval <= DueDateStatus.dueSoonThreshold {
                Label(
                    .copy("Due in \(Self.format(interval))"),
                    systemImage: "clock.badge.exclamationmark.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Label(.copy("Due in \(Self.format(interval))"), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Shared because `DateComponentsFormatter` is expensive to construct.
    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    private static func format(_ interval: TimeInterval) -> String {
        formatter.string(from: interval) ?? ""
    }
}

// MARK: - Subtasks

private struct TodoDetailSubtasksSection: View {
    /// Sorted once at init rather than on every body evaluation.
    private let sortedSubtasks: [SubTask]

    init(subtasks: [SubTask]) {
        self.sortedSubtasks = subtasks.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        ForEach(sortedSubtasks, id: \.id) { subtask in
            HStack {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                Text(subtask.title)
                    .strikethrough(subtask.isCompleted)
                    .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
            }
        }
    }
}

// MARK: - Actions

private struct TodoDetailActionsSection: View {
    let entity: TodoAppEntity

    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    entity.isFavorite ? .copy("Remove from Favorites") : .copy("Add to Favorites"),
                    systemImage: entity.isFavorite ? "star.slash" : "star"
                )
            }

            // Confirmed here, not by the intent: `requestConfirmation` has no surface to
            // present on when the caller is an in-app button, so the confirming intent
            // would fail silently. The non-confirming one runs afterwards.
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label(.copy("Delete Todo"), systemImage: "trash")
            }
            .accessibilityIdentifier("deleteTodoButton")
        }
        .confirmationDialog(
            .copy("Delete “\(entity.title)”?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
                Text(.copy("Delete"))
            }
            .accessibilityIdentifier("confirmDeleteTodoButton")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TodoDetailView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Sample Todo",
                isCompleted: false,
                isFavorite: true,
                dueDate: Date().addingTimeInterval(1800)
            )
        )
    }
}
