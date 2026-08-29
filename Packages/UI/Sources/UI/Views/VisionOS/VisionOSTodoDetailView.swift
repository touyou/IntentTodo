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
        // UUID parse に失敗した場合は @Query を投げずに不在表示へ落とす。
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
        // Liquid Glass はナビゲーション層 (Ornament) と主要 surface (Header) に
        // 限定する方針。本文セクションはコンテンツ層なので plain padding で表示。
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
            Text(.copy("Description")).font(.headline).foregroundStyle(.secondary)
            Text(description).font(.body)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VisionOSSubtasksSection: View {
    /// 表示前に sort 済み。body 評価のたびに sort を走らせていた旧実装を init 1 回に集約。
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

/// WWDC 2026 で追加した属性 (所要時間 / 担当者 / 場所) を表示。いずれも未設定なら
/// セクションごと非表示。
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

/// reminders スキーマ属性（tags / urls / recurrence / locationTriggerEvent）の表示と編集。
///
/// 空間 UI は `Form` ではなく `VStack` を積む形なので、iOS 側の
/// `TodoDetailTagsSection` などは再利用せずここに置く。編集シートの中身
/// （`TodoAttributesEditView`）は共通。
private struct VisionOSAttributesSection: View {
    @Environment(NavigationModel.self) private var navigationModel

    let item: TodoItem

    /// 配列属性は `body` から読まず id 経由で引き直す（削除済みオブジェクトの配列読みは
    /// trap する）。詳細: `TodoDetailContent.tags` のコメント
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
                    Text(recurrenceFrequency.localizedStringResource)
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
        // visionOS は .buttonStyle(.glass) / .glassProminent を未サポートのため
        // .bordered のままで運用 (空間 UI の hover effect 側で interactivity を担保)。
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

            // 確認はアプリ側で取る（`DeleteTodoIntent` の `requestConfirmation` は
            // アプリ内ボタンからだと提示する面が無く失敗する）。
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
