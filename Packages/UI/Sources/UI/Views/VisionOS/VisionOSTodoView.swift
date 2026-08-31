//
//  VisionOSTodoView.swift
//  IntentTodo
//
//  visionOS-specific views for spatial computing.
//  Optimized for Apple Vision Pro interaction patterns.
//

#if os(visionOS)
import AppIntents
import Domain
import RealityKit
import SwiftData
import SwiftUI
import TodoAppIntents

// MARK: - Main Split View

public struct VisionOSTodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    @State private var viewModel = TodoListViewModel()
    @State private var showingSettings = false
    @Environment(NavigationModel.self) private var navigationModel

    private var filteredTodos: [TodoAppEntity] {
        // Mapped on every body evaluation rather than cached: `@Query` returns reference
        // types, so changing a field in place would not fire an `onChange`-based cache.
        viewModel.filteredTodos(from: todoItems.map { TodoAppEntity(from: $0) })
    }

    public init() {}

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        NavigationSplitView {
            VisionOSSidebar(
                todos: filteredTodos,
                viewModel: $viewModel,
                selectedTodo: $navigationModel.selectedTodo,
                showingSettings: $showingSettings
            )
            .navigationTitle(.copy("Todos"))
        } detail: {
            VisionOSDetailPane(selectedTodo: navigationModel.selectedTodo)
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            VisionOSBottomOrnament(viewModel: $viewModel)
        }
        .sheet(isPresented: $navigationModel.showingAddTodo) {
            VisionOSAddTodoSheet()
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        // Apply a filter pushed by LaunchAppIntent (Siri "show my favorite todos", …)
        // so the app lands on the list the caller asked for, like TodoListView does.
        .onChange(of: navigationModel.pendingFilter) { _, newValue in
            applyPendingFilter(newValue)
        }
        .onAppear { applyPendingFilter(navigationModel.pendingFilter) }
    }

    /// Copies an intent-supplied filter into the list's filter state, then clears
    /// the pending value so it isn't re-applied.
    private func applyPendingFilter(_ filterType: TodoFilterType?) {
        guard let filterType else { return }
        viewModel.filter = TodoFilter(filterType)
        navigationModel.pendingFilter = nil
    }
}

// MARK: - Sidebar

private struct VisionOSSidebar: View {
    let todos: [TodoAppEntity]
    @Binding var viewModel: TodoListViewModel
    @Binding var selectedTodo: TodoAppEntity?
    @Binding var showingSettings: Bool
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
                // Collection onscreen (WWDC 2026 #343) — same treatment as
                // `TodoListSidebar` on iOS/macOS, so "the third one" resolves on visionOS
                // too. `forSelectionType:` is only honoured when applied to a `List`.
                .appEntityIdentifier(forSelectionType: TodoAppEntity.self) { todo in
                    EntityIdentifier(for: TodoAppEntity.self, identifier: todo.id)
                }
            }
        }
        .toolbar {
            // Entry point for the integration settings; `ShortcutsLink` exists on visionOS.
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(.copy("Settings"))
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigationModel.showAddTodo()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: .copy("Search todos"))
    }
}

private struct VisionOSEmptyView: View {
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        ContentUnavailableView {
            Label(.copy("No Todos"), systemImage: "checklist")
        } description: {
            Text(.copy("Tap the + button to add your first todo."))
        } actions: {
            Button(.copy("Add Todo")) { navigationModel.showAddTodo() }
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
                .copy("Select a Todo"),
                systemImage: "hand.tap",
                description: Text(.copy("Choose a todo from the list to view details."))
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
                FilterPicker(selection: $viewModel.filter)
            } label: {
                Label(.copy("Filter"), systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 24)

            Menu {
                SortPicker(selection: $viewModel.sortOrder)
            } label: {
                Label(.copy("Sort"), systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 24)

            Button {
                navigationModel.showAddTodo()
            } label: {
                Label(.copy("Add Todo"), systemImage: "plus.circle.fill")
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
        // `dueDate` is a `DateComponents?` projection required by the schema, so comparisons
        // and formatting use the stored `dueDateValue`.
        if let dueDate = todo.dueDateValue {
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

                if let dueDate = todo.dueDateValue {
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

// MARK: - Previews

#Preview {
    VisionOSTodoListView()
        .environment(NavigationModel())
}
#endif
