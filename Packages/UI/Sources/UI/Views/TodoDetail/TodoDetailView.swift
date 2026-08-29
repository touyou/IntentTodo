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
        // `TodoAppEntity.id` (String) → `UUID` の parse に失敗したら、@Query を
        // 投げずに不在表示へ落とす。旧実装はランダム UUID で必ずヒットしないクエリ
        // を発行していたため SwiftData 側に無駄な往復が発生していた。
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
                    .copy("Todo Not Found"),
                    systemImage: "questionmark.circle",
                    description: Text(.copy("This todo may have been deleted."))
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
    /// Activity type advertised to Siri / Apple Intelligence as onscreen content.
    /// Must match the `NSUserActivityTypes` entry in the app's Info.plist.
    private static let viewingTodoActivityType = "dev.touyou.IntentTodo.ViewingTodo"

    @Environment(NavigationModel.self) private var navigationModel

    let todo: TodoItem

    /// 配列属性のスナップショット。
    ///
    /// **`todo.tags` / `todo.urls` を `body` の中で読んではいけない。** SwiftData は
    /// 削除済みオブジェクトの配列属性を読むと trap する（scalar は最後の値を返すので耐える）。
    /// 削除の直後 1 フレームだけ `@Query` の結果に削除済みオブジェクトが残るため、body から
    /// 読むと詳細画面の再描画でクラッシュする（`testDeleteTodoFromDetailView` で再現）。
    /// `!todo.isDeleted` のガードは効かない（この時点では false のまま）。
    ///
    /// 安全なのは **id から引き直す**こと。`TodoAppEntity` の `tags` / `urls` は同じ理由で
    /// `@DeferredProperty` になっているので、それを読んで state に写す。消えた todo は
    /// 「見つからない」に落ちるだけで済む。
    /// 経緯: docs/devlog/2026-08-29-reminder-schema-conformance.md（#83 で同じ罠を踏んだ）
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
                Button(.copy("Edit Details")) {
                    navigationModel.showAttributeEditor()
                }
                .accessibilityIdentifier("editDetailsButton")
            }
        }
        // 提示状態を `NavigationModel` に置くのは、閉じるのが `UpdateTodoIntent.perform()`
        // だから（`@Environment(\.dismiss)` は Intent から触れない）。
        .sheet(isPresented: $navigationModel.showingAttributeEditor) {
            // 配列はここでもモデルから読まず、スナップショットを渡す（シート提示中に
            // todo が消えると同じ trap を踏む）。scalar な属性はモデルから読んでよい。
            TodoAttributesEditView(todo: todo, tags: tags, urls: urls)
        }
        // 更新の契機は `modifiedAt`。scalar なので削除済みオブジェクトでも読める。
        // `UpdateTodoIntent` が保存すると進むので、保存後の表示もここで追従する。
        .task(id: todo.modifiedAt) {
            await refreshCollections(of: entity)
        }
    }

    /// `tags` / `urls` を id から引き直す。消えていれば空になる。
    ///
    /// `Set<String>` で返るので表示順は自分で決める。人が入れた順は保てないため、
    /// 照合順で並べて決定的にする（編集して保存すると保存順もこれに揃う）。
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
        // 毎分再評価して overdue/dueSoon の遷移に追従する。
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

    /// `DateComponentsFormatter` はインスタンス生成が高価なため、共有 formatter を使う。
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
    /// 表示前に `orderIndex` で sort 済みの配列を保持。`body` 評価のたびに sort
    /// を走らせていた旧実装を init 1 回に集約する。
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

            // 確認はアプリ側で取る。`DeleteTodoIntent` の `requestConfirmation` は
            // アプリ内ボタンからだと提示する面が無く失敗するため、確認後に
            // 確認なし版の Intent を実行する。
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
