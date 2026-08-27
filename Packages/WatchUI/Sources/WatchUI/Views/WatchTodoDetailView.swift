//
//  WatchTodoDetailView.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// Detail view for a todo item on watchOS.
///
/// 受け取るのは `TodoAppEntity`。一覧からの `NavigationLink` も
/// `OpenTodoIntent`（Siri / Spotlight）が `NavigationModel.path` に積む値も
/// entity なので、両方が同じ入口を通る。iOS の `TodoDetailView` と同じ形。
public struct WatchTodoDetailView: View {
    private let todo: TodoAppEntity

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    public var body: some View {
        // id の parse に失敗したら `@Query` を投げずに不在表示へ落とす
        // （ランダム UUID で必ずヒットしないクエリを投げるより安い）。
        if let targetId = UUID(uuidString: todo.id) {
            WatchTodoDetailQueryView(targetId: targetId)
        } else {
            ContentUnavailableView(
                .copy("Todo Not Found"),
                systemImage: "questionmark.circle"
            )
        }
    }
}

/// `@Query` を発行するのは id の parse 成功後のみ。
private struct WatchTodoDetailQueryView: View {
    @Query private var todoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss

    private var todo: TodoItem? { todoItems.first }
    private var entity: TodoAppEntity? { todo.map { TodoAppEntity(from: $0) } }

    init(targetId: UUID) {
        _todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
    }

    var body: some View {
        Group {
            if let todo, let entity {
                detailContent(todo: todo, entity: entity)
            } else {
                ContentUnavailableView(
                    .copy("Todo Not Found"),
                    systemImage: "questionmark.circle"
                )
            }
        }
        .onChange(of: todo) { _, newValue in
            if newValue == nil {
                dismiss()
            }
        }
    }

    private func detailContent(todo: TodoItem, entity: TodoAppEntity) -> some View {
        List {
            Section { WatchTodoDetailHeaderSection(todo: todo, entity: entity) }

            if let dueDate = todo.dueDate {
                Section(.copy("Due Date")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dueDate.formatted(date: .complete, time: .omitted))
                        Text(dueDate.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = todo.todoDescription, !description.isEmpty {
                Section(.copy("Description")) {
                    Text(description)
                        .font(.caption)
                }
            }

            Section { WatchTodoDetailActionsSection(todo: todo, entity: entity) }
        }
        .navigationTitle(.copy("Details"))
        // Onscreen entity (WWDC 2026 #343): 開いている todo を Siri /
        // Apple Intelligence に知らせ、「これを完了して」を解決できるようにする。
        //
        // iOS 側は `.userActivity` に `appEntityIdentifier` を載せる形（Handoff の
        // タイトルも一緒に出したいため）。watchOS は Handoff の当て先が無いので、
        // Info.plist の `NSUserActivityTypes` 宣言が要らない単一 annotation を使う。
        .appEntityIdentifier(EntityIdentifier(for: entity))
    }
}

// MARK: - Header

private struct WatchTodoDetailHeaderSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    var body: some View {
        HStack {
            Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.headline)
        }
    }
}

// MARK: - Actions

private struct WatchTodoDetailActionsSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    todo.isFavorite ? .copy("Remove Favorite") : .copy("Add Favorite"),
                    systemImage: todo.isFavorite ? "star.slash" : "star"
                )
            }

            // 確認はアプリ側で取る（`DeleteTodoIntent` の `requestConfirmation` は
            // アプリ内ボタンからだと提示する面が無く失敗する）。
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label(.copy("Delete"), systemImage: "trash")
            }
        }
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
