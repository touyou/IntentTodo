//
//  TodoDetailView.swift
//  IntentTodo
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// Detail view for a single todo item.
///
/// Displays comprehensive information about a todo including:
/// - Title and description
/// - Due date with time
/// - Completion and favorite status
/// - Creation and modification dates
/// - Subtasks (future)
///
/// Actions use `Button(intent:)` for consistency with App Intents architecture.
public struct TodoDetailView: View {
    // MARK: - Properties

    private let todoId: String

    @Query private var todoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss

    private var todo: TodoItem? {
        guard let uuid = UUID(uuidString: todoId) else { return nil }
        return todoItems.first { $0.id == uuid }
    }

    // MARK: - Initialization

    /// Creates a detail view for the specified todo.
    /// - Parameter todo: The todo entity to display.
    public init(todo: TodoAppEntity) {
        self.todoId = todo.id
        // Note: SwiftData Query with predicate requires non-optional comparison
        // We filter by id in the computed property instead
        _todoItems = Query()
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let todo {
                detailContent(for: todo)
            } else {
                ContentUnavailableView(
                    "Todo Not Found",
                    systemImage: "questionmark.circle",
                    description: Text("This todo may have been deleted.")
                )
            }
        }
        .navigationTitle("Details")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: todo) { _, newValue in
            // Automatically dismiss when todo is deleted
            if newValue == nil {
                dismiss()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func detailContent(for todo: TodoItem) -> some View {
        let entity = TodoAppEntity(from: todo)

        List {
            // Header Section
            Section {
                headerSection(todo: todo, entity: entity)
            }

            // Due Date Section
            if let dueDate = todo.dueDate {
                Section("Due Date") {
                    dueDateSection(dueDate: dueDate, isCompleted: todo.isCompleted)
                }
            }

            // Description Section
            if let description = todo.todoDescription, !description.isEmpty {
                Section("Description") {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Subtasks Section
            if !todo.subTasks.isEmpty {
                Section("Subtasks") {
                    subtasksSection(subtasks: todo.subTasks)
                }
            }

            // Metadata Section
            Section("Info") {
                metadataSection(todo: todo)
            }

            // Actions Section
            Section {
                actionsSection(entity: entity)
            }
        }
        #if os(visionOS)
        .listStyle(.plain)
        #endif
    }

    private func headerSection(todo: TodoItem, entity: TodoAppEntity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with completion checkbox
            HStack(spacing: 12) {
                TodoCheckbox(todo: entity)

                Text(todo.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
            }

            // Status badges
            HStack(spacing: 8) {
                if todo.isCompleted {
                    StatusBadge(
                        title: "Completed",
                        systemImage: "checkmark.circle.fill",
                        color: .green
                    )
                }

                if todo.isFavorite {
                    StatusBadge(
                        title: "Favorite",
                        systemImage: "star.fill",
                        color: .yellow
                    )
                }

                if let dueDate = todo.dueDate, !todo.isCompleted {
                    if isOverdue(dueDate) {
                        StatusBadge(
                            title: "Overdue",
                            systemImage: "exclamationmark.circle.fill",
                            color: .red
                        )
                    } else if isDueSoon(dueDate) {
                        StatusBadge(
                            title: "Due Soon",
                            systemImage: "clock.fill",
                            color: .orange
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dueDateSection(dueDate: Date, isCompleted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(dueDateColor(dueDate, isCompleted: isCompleted))
                Text(dueDate.formatted(date: .complete, time: .omitted))
                    .font(.body)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(dueDateColor(dueDate, isCompleted: isCompleted))
                Text(dueDate.formatted(date: .omitted, time: .shortened))
                    .font(.body)
            }

            // Time remaining/overdue indicator
            if !isCompleted {
                timeRemainingLabel(for: dueDate)
            }
        }
    }

    private func subtasksSection(subtasks: [SubTask]) -> some View {
        ForEach(subtasks.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { subtask in
            HStack {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                Text(subtask.title)
                    .strikethrough(subtask.isCompleted)
                    .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
            }
        }
    }

    private func metadataSection(todo: TodoItem) -> some View {
        Group {
            LabeledContent("Created") {
                Text(todo.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            LabeledContent("Modified") {
                Text(todo.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let category = todo.category {
                LabeledContent("Category") {
                    HStack {
                        if let colorHex = category.colorHex,
                           let color = Color(hex: colorHex) {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                        } else {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 10, height: 10)
                        }
                        Text(category.name)
                    }
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func actionsSection(entity: TodoAppEntity) -> some View {
        Group {
            // Toggle favorite
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    entity.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: entity.isFavorite ? "star.slash" : "star"
                )
            }

            // Delete
            Button(role: .destructive, intent: DeleteTodoIntent(todo: entity)) {
                Label("Delete Todo", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func isOverdue(_ date: Date) -> Bool {
        date < Date()
    }

    private func isDueSoon(_ date: Date) -> Bool {
        let oneHour = TimeInterval(3600)
        return date.timeIntervalSinceNow <= oneHour && date.timeIntervalSinceNow > 0
    }

    private func dueDateColor(_ date: Date, isCompleted: Bool) -> Color {
        if isCompleted { return .secondary }
        if isOverdue(date) { return .red }
        if isDueSoon(date) { return .orange }
        return .secondary
    }

    @ViewBuilder
    private func timeRemainingLabel(for date: Date) -> some View {
        let timeInterval = date.timeIntervalSinceNow

        if timeInterval <= 0 {
            Label(
                "Overdue by \(formatTimeInterval(-timeInterval))",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.red)
        } else if timeInterval <= 3600 {
            Label(
                "Due in \(formatTimeInterval(timeInterval))",
                systemImage: "clock.badge.exclamationmark.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        } else {
            Label(
                "Due in \(formatTimeInterval(timeInterval))",
                systemImage: "clock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval) ?? ""
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Color Extension

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
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
