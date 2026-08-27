//
//  WatchTodoRow.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item on watchOS.
///
/// 行はタップ先が 2 つある: 左の丸が完了トグル、本体が詳細への遷移
/// （純正リマインダーの watch アプリと同じ分け方）。行全体を完了トグルにすると
/// 詳細（説明文 / 期限の時刻）を見る手段が watch から無くなる。
public struct WatchTodoRow: View {
    let todo: TodoItem
    private let entity: TodoAppEntity

    public init(todo: TodoItem) {
        self.todo = todo
        self.entity = TodoAppEntity(from: todo)
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? .copy("Mark as incomplete") : .copy("Mark as complete"))

            NavigationLink(value: NavigationDestination.todoDetail(entity)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(.body)
                        .lineLimit(2)

                    if let dueDate = todo.dueDate {
                        WatchDueDateLabel(date: dueDate, isCompleted: todo.isCompleted)
                    }
                }
            }
        }
        // Onscreen entity (WWDC 2026 #343): 表示中の行が「どの todo か」を Siri /
        // Apple Intelligence に知らせる。
        //
        // iOS 側は List に `.appEntityIdentifier(forSelectionType:)` を 1 つ付けて
        // 行を一括で紐付けているが、あれは List の **selection 値の型**を手がかりに
        // する仕組み。watchOS の一覧は selection を持たない（行が
        // トグル + NavigationLink）ため、行ごとの単一 annotation に落とす。
        .appEntityIdentifier(EntityIdentifier(for: entity))
    }
}
