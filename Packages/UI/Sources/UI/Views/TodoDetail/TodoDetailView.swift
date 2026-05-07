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
/// Actions use `Button(intent:)` for consistency with App Intents architecture.
public struct TodoDetailView: View {
    let todo: TodoAppEntity

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    public var body: some View {
        // `TodoAppEntity.id` (String) → `UUID` の parse に失敗したら、@Query を
        // 投げずに不在表示へ落とす。旧実装はランダム UUID で必ずヒットしないクエリ
        // を発行していたため SwiftData 側に無駄な往復が発生していた。
        if let targetId = UUID(uuidString: todo.id) {
            TodoDetailQueryView(targetId: targetId, fallbackTitle: todo.title)
        } else {
            ContentUnavailableView(
                "Todo Not Found",
                systemImage: "questionmark.circle",
                description: Text("This todo may have been deleted.")
            )
            .navigationTitle(todo.title)
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - Query Wrapper

/// `@Query` を発行するのは parse 成功後のみ。`@Environment(\.dismiss)` は
/// NavigationSplitView の detail ペインでは効かないため、todo 消滅時は
/// `NavigationModel.selectedTodo = nil` で selection を解除する (compact width で
/// 折り畳まれた NavigationStack 上でも selection クリアで自動 pop する)。
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
                    "Todo Not Found",
                    systemImage: "questionmark.circle",
                    description: Text("This todo may have been deleted.")
                )
            }
        }
        // Detail のタイトルは選択中の todo タイトルを反映 (macOS Mail / Notes と同じ慣習)。
        // Todo が消えたケースでは選択時のタイトルを保持して読みやすさを保つ。
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
    let todo: TodoItem

    private var entity: TodoAppEntity { TodoAppEntity(from: todo) }

    var body: some View {
        List {
            Section { TodoDetailHeaderSection(todo: todo, entity: entity) }

            if let dueDate = todo.dueDate {
                Section("Due Date") {
                    TodoDetailDueDateSection(dueDate: dueDate, isCompleted: todo.isCompleted)
                }
            }

            if let description = todo.todoDescription, !description.isEmpty {
                Section("Description") {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if let subTasks = todo.subTasks, !subTasks.isEmpty {
                Section("Subtasks") {
                    TodoDetailSubtasksSection(subtasks: subTasks)
                }
            }

            Section("Info") {
                TodoDetailMetadataSection(todo: todo)
            }

            Section {
                TodoDetailActionsSection(entity: entity)
            }
        }
        #if os(visionOS)
        .listStyle(.plain)
        #endif
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
                    StatusBadge(title: "Completed", systemImage: "checkmark.circle.fill", color: .green)
                }
                if todo.isFavorite {
                    StatusBadge(title: "Favorite", systemImage: "star.fill", color: .yellow)
                }
                if let dueDate = todo.dueDate, !todo.isCompleted {
                    switch DueDateStatus.evaluate(date: dueDate, isCompleted: false) {
                    case .overdue:
                        StatusBadge(title: "Overdue", systemImage: "exclamationmark.circle.fill", color: .red)
                    case .dueSoon:
                        StatusBadge(title: "Due Soon", systemImage: "clock.fill", color: .orange)
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
        // 毎分再評価して overdue/dueSoon の遷移に追従する。
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let interval = date.timeIntervalSince(context.date)
            if interval <= 0 {
                Label(
                    "Overdue by \(Self.format(-interval))",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            } else if interval <= DueDateStatus.dueSoonThreshold {
                Label(
                    "Due in \(Self.format(interval))",
                    systemImage: "clock.badge.exclamationmark.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Label("Due in \(Self.format(interval))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// `DateComponentsFormatter` はインスタンス生成が高価なため、共有 formatter を使う。
    private static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f
    }()

    private static func format(_ interval: TimeInterval) -> String {
        formatter.string(from: interval) ?? ""
    }
}

// MARK: - Subtasks

private struct TodoDetailSubtasksSection: View {
    let subtasks: [SubTask]

    var body: some View {
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
}

// MARK: - Metadata

private struct TodoDetailMetadataSection: View {
    let todo: TodoItem

    var body: some View {
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
                        Circle()
                            .fill(category.colorHex.flatMap(Color.init(hex:)) ?? Color.gray)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                    }
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Actions

private struct TodoDetailActionsSection: View {
    let entity: TodoAppEntity

    var body: some View {
        Group {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    entity.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: entity.isFavorite ? "star.slash" : "star"
                )
            }

            Button(role: .destructive, intent: DeleteTodoIntent(todo: entity)) {
                Label("Delete Todo", systemImage: "trash")
            }
        }
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
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&rgb) else { return nil }

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
