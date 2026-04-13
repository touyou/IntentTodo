//
//  VisionOSTodoView.swift
//  IntentTodo
//
//  visionOS-specific views for spatial computing.
//  Optimized for Apple Vision Pro interaction patterns.
//

#if os(visionOS)
import Domain
import RealityKit
import SwiftData
import SwiftUI
import TodoAppIntents

// MARK: - visionOS Main View

/// Main todo view optimized for visionOS.
///
/// Uses spatial design patterns:
/// - Glass material backgrounds
/// - Ornaments for secondary controls
/// - Hover effects for eye tracking
/// - Comfortable spacing for hand gestures
public struct VisionOSTodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    @State private var viewModel = TodoListViewModel()
    @Environment(NavigationModel.self) private var navigationModel
    @State private var selectedTodo: TodoAppEntity?

    private var allTodos: [TodoAppEntity] {
        todoItems.map { TodoAppEntity(from: $0) }
    }

    private var filteredTodos: [TodoAppEntity] {
        viewModel.filteredTodos(from: allTodos)
    }

    public init() {}

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        NavigationSplitView {
            sidebarContent
                .navigationTitle("Todos")
        } detail: {
            detailContent
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            bottomOrnament
        }
        .sheet(isPresented: $navigationModel.showingAddTodo) {
            addTodoSheet
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        Group {
            if filteredTodos.isEmpty {
                emptyView
            } else {
                todoList
            }
        }
        .toolbar {
            toolbarContent
        }
        .searchable(text: $viewModel.searchText, prompt: "Search todos")
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Todos", systemImage: "checklist")
        } description: {
            Text("Tap the + button to add your first todo.")
        } actions: {
            Button("Add Todo") {
                navigationModel.showAddTodo()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var todoList: some View {
        List(filteredTodos, id: \.id, selection: $selectedTodo) { todo in
            VisionOSTodoRow(todo: todo, isSelected: selectedTodo?.id == todo.id)
                .tag(todo)
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let todo = selectedTodo {
            VisionOSTodoDetailView(todo: todo)
        } else {
            ContentUnavailableView(
                "Select a Todo",
                systemImage: "hand.tap",
                description: Text("Choose a todo from the list to view details.")
            )
        }
    }

    // MARK: - Ornament

    private var bottomOrnament: some View {
        HStack(spacing: 24) {
            // Filter menu
            Menu {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(TodoFilter.allCases) { filterOption in
                        Label(filterOption.displayName, systemImage: filterOption.systemImage)
                            .tag(filterOption)
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 24)

            // Sort menu
            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(TodoSortOrder.allCases) { order in
                        Text(order.displayName)
                            .tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 24)

            // Add button
            Button {
                navigationModel.showAddTodo()
            } label: {
                Label("Add Todo", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassBackgroundEffect()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                navigationModel.showAddTodo()
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var addTodoSheet: some View {
        NavigationStack {
            AddTodoView()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onChange(of: todoItems.count) { oldCount, newCount in
            if newCount > oldCount {
                navigationModel.dismissAddTodo()
            }
        }
    }
}

// MARK: - visionOS Todo Row

/// Todo row optimized for visionOS interaction.
struct VisionOSTodoRow: View {
    let todo: TodoAppEntity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Checkbox with hover effect
            TodoCheckbox(todo: todo)
                .contentShape(.hoverEffect, .rect(cornerRadius: 8))
                .hoverEffect(.highlight)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.title3)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                if let dueDate = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: dueDateIcon(for: dueDate))
                            .font(.caption)
                        Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                    }
                    .foregroundStyle(dueDateColor(for: dueDate))
                }
            }

            Spacer()

            // Favorite button with hover effect
            FavoriteButton(todo: todo)
                .contentShape(.hoverEffect, .rect(cornerRadius: 8))
                .hoverEffect(.highlight)
        }
        .padding(.vertical, 8)
        .contentShape(.hoverEffect, .rect(cornerRadius: 12))
        .hoverEffect(.lift)
    }

    private func dueDateIcon(for date: Date) -> String {
        if date < Date() { return "exclamationmark.circle.fill" }
        if date.timeIntervalSinceNow <= 3600 { return "clock.badge.exclamationmark" }
        return "calendar"
    }

    private func dueDateColor(for date: Date) -> Color {
        if todo.isCompleted { return .secondary }
        if date < Date() { return .red }
        if date.timeIntervalSinceNow <= 3600 { return .orange }
        return .secondary
    }
}

// MARK: - visionOS Todo Detail

/// Detail view optimized for visionOS spatial design.
struct VisionOSTodoDetailView: View {
    let todo: TodoAppEntity

    @Query private var todoItems: [TodoItem]

    private var todoItem: TodoItem? {
        guard let uuid = UUID(uuidString: todo.id) else { return nil }
        return todoItems.first { $0.id == uuid }
    }

    init(todo: TodoAppEntity) {
        self.todo = todo
        let todoUUID = UUID(uuidString: todo.id)
        _todoItems = Query(
            filter: #Predicate<TodoItem> { item in
                item.id == todoUUID
            }
        )
    }

    var body: some View {
        ScrollView {
            if let item = todoItem {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    headerSection(item)

                    // Due date
                    if let dueDate = item.dueDate {
                        dueDateSection(dueDate, isCompleted: item.isCompleted)
                    }

                    // Description
                    if let description = item.todoDescription, !description.isEmpty {
                        descriptionSection(description)
                    }

                    // Subtasks
                    if !item.subTasks.isEmpty {
                        subtasksSection(item.subTasks)
                    }

                    // Actions
                    actionsSection(TodoAppEntity(from: item))
                }
                .padding(40)
            } else {
                ContentUnavailableView(
                    "Todo Not Found",
                    systemImage: "questionmark.circle",
                    description: Text("This todo may have been deleted.")
                )
            }
        }
        .navigationTitle("Details")
    }

    private func headerSection(_ item: TodoItem) -> some View {
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

            // Status badges
            HStack(spacing: 12) {
                if item.isCompleted {
                    statusBadge(title: "Completed", icon: "checkmark.circle.fill", color: .green)
                }
                if item.isFavorite {
                    statusBadge(title: "Favorite", icon: "star.fill", color: .yellow)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }

    private func statusBadge(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func dueDateSection(_ dueDate: Date, isCompleted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due Date")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(dueDate.formatted(date: .complete, time: .omitted))
                        .font(.title2)
                    Text(dueDate.formatted(date: .omitted, time: .shortened))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isCompleted {
                    timeRemainingIndicator(for: dueDate)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }

    private func timeRemainingIndicator(for date: Date) -> some View {
        let interval = date.timeIntervalSinceNow
        let isOverdue = interval <= 0
        let isDueSoon = interval > 0 && interval <= 3600

        return VStack {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : (isDueSoon ? "clock.badge.exclamationmark.fill" : "clock"))
                .font(.largeTitle)
                .foregroundStyle(isOverdue ? .red : (isDueSoon ? .orange : .secondary))

            Text(isOverdue ? "Overdue" : (isDueSoon ? "Due Soon" : "Upcoming"))
                .font(.caption)
                .foregroundStyle(isOverdue ? .red : (isDueSoon ? .orange : .secondary))
        }
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(description)
                .font(.body)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }

    private func subtasksSection(_ subtasks: [SubTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subtasks")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(subtasks.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { subtask in
                HStack {
                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                    Text(subtask.title)
                        .strikethrough(subtask.isCompleted)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }

    private func actionsSection(_ entity: TodoAppEntity) -> some View {
        HStack(spacing: 20) {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    entity.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: entity.isFavorite ? "star.slash" : "star"
                )
            }
            .buttonStyle(.bordered)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)

            Button(intent: DeleteTodoIntent(todo: entity), role: .destructive) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
        }
    }
}

// MARK: - Previews

#Preview {
    VisionOSTodoListView()
        .environment(NavigationModel())
}
#endif
