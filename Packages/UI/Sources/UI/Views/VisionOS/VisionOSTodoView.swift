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

// MARK: - Main Split View

public struct VisionOSTodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    @State private var viewModel = TodoListViewModel()
    @Environment(NavigationModel.self) private var navigationModel

    private var filteredTodos: [TodoAppEntity] {
        // ViewModel が entities をキャッシュしているので body 内 map は不要。
        viewModel.filteredTodos(from: viewModel.entities)
    }

    public init() {}

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        NavigationSplitView {
            VisionOSSidebar(
                todos: filteredTodos,
                viewModel: $viewModel,
                selectedTodo: $navigationModel.selectedTodo
            )
            .navigationTitle("Todos")
        } detail: {
            VisionOSDetailPane(selectedTodo: navigationModel.selectedTodo)
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            VisionOSBottomOrnament(viewModel: $viewModel)
        }
        .sheet(isPresented: $navigationModel.showingAddTodo) {
            VisionOSAddTodoSheet()
        }
        .onChange(of: todoItems, initial: true) {
            viewModel.update(from: todoItems)
        }
    }
}

// MARK: - Sidebar

private struct VisionOSSidebar: View {
    let todos: [TodoAppEntity]
    @Binding var viewModel: TodoListViewModel
    @Binding var selectedTodo: TodoAppEntity?
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        Group {
            if todos.isEmpty {
                VisionOSEmptyView()
            } else {
                List(todos, id: \.id, selection: $selectedTodo) { todo in
                    VisionOSTodoRow(todo: todo, isSelected: selectedTodo?.id == todo.id)
                        .tag(todo)
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigationModel.showAddTodo()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search todos")
    }
}

private struct VisionOSEmptyView: View {
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        ContentUnavailableView {
            Label("No Todos", systemImage: "checklist")
        } description: {
            Text("Tap the + button to add your first todo.")
        } actions: {
            Button("Add Todo") { navigationModel.showAddTodo() }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Detail Pane

private struct VisionOSDetailPane: View {
    let selectedTodo: TodoAppEntity?

    var body: some View {
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
}

// MARK: - Bottom Ornament

private struct VisionOSBottomOrnament: View {
    @Binding var viewModel: TodoListViewModel
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        HStack(spacing: 24) {
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

            Divider().frame(height: 24)

            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(TodoSortOrder.allCases) { order in
                        Text(order.displayName).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 24)

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
}

// MARK: - Add Sheet

/// Sheet container for `AddTodoView` on visionOS. Dismissal is driven by
/// `AddTodoIntent.perform()` via `navigationModel.dismissAddTodo()` — no need to
/// observe `@Query` count drift here.
private struct VisionOSAddTodoSheet: View {
    var body: some View {
        NavigationStack {
            AddTodoView()
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Todo Row

struct VisionOSTodoRow: View {
    let todo: TodoAppEntity
    let isSelected: Bool

    private var status: DueDateStatus {
        if let dueDate = todo.dueDate {
            return DueDateStatus.evaluate(date: dueDate, isCompleted: todo.isCompleted)
        }
        return .normal
    }

    var body: some View {
        HStack(spacing: 16) {
            TodoCheckbox(todo: todo)
                .contentShape(.hoverEffect, .rect(cornerRadius: 8))
                .hoverEffect(.highlight)

            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.title3)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                if let dueDate = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: icon).font(.caption)
                        Text(dueDate.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    }
                    .foregroundStyle(color)
                }
            }

            Spacer()

            FavoriteButton(todo: todo)
                .contentShape(.hoverEffect, .rect(cornerRadius: 8))
                .hoverEffect(.highlight)
        }
        .padding(.vertical, 8)
        .contentShape(.hoverEffect, .rect(cornerRadius: 12))
        .hoverEffect(.lift)
    }

    private var icon: String {
        switch status {
        case .overdue: return "exclamationmark.circle.fill"
        case .dueSoon: return "clock.badge.exclamationmark"
        case .normal: return "calendar"
        }
    }

    private var color: Color {
        switch status {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return .secondary
        }
    }
}

// MARK: - Detail View

struct VisionOSTodoDetailView: View {
    let todo: TodoAppEntity

    init(todo: TodoAppEntity) {
        self.todo = todo
    }

    var body: some View {
        // UUID parse に失敗した場合は @Query を投げずに不在表示へ落とす。
        if let targetId = UUID(uuidString: todo.id) {
            VisionOSTodoDetailQueryView(targetId: targetId)
        } else {
            ContentUnavailableView(
                "Todo Not Found",
                systemImage: "questionmark.circle",
                description: Text("This todo may have been deleted.")
            )
            .navigationTitle("Details")
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
                    VisionOSActionsSection(entity: TodoAppEntity(from: item))
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
                    VisionOSStatusBadge(title: "Completed", icon: "checkmark.circle.fill", color: .green)
                }
                if item.isFavorite {
                    VisionOSStatusBadge(title: "Favorite", icon: "star.fill", color: .yellow)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackgroundEffect()
    }
}

private struct VisionOSStatusBadge: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
    }
}

private struct VisionOSDueDateSection: View {
    let dueDate: Date
    let isCompleted: Bool

    var body: some View {
        // Liquid Glass はナビゲーション層 (Ornament) と主要 surface (Header) に
        // 限定する方針。本文セクションはコンテンツ層なので plain padding で表示。
        VStack(alignment: .leading, spacing: 12) {
            Text("Due Date")
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
        // 毎分再評価して overdue / dueSoon / normal の切替に追従。
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
            Text("Description").font(.headline).foregroundStyle(.secondary)
            Text(description).font(.body)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VisionOSSubtasksSection: View {
    let subtasks: [SubTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subtasks").font(.headline).foregroundStyle(.secondary)
            ForEach(subtasks.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { subtask in
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

private struct VisionOSActionsSection: View {
    let entity: TodoAppEntity

    var body: some View {
        // visionOS は .buttonStyle(.glass) / .glassProminent を未サポートのため
        // .bordered のままで運用 (空間 UI の hover effect 側で interactivity を担保)。
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

            Button(role: .destructive, intent: DeleteTodoIntent(todo: entity)) {
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
