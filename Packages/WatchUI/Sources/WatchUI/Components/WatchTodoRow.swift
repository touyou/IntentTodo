//
//  WatchTodoRow.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item on watchOS.
public struct WatchTodoRow: View {
    let todo: TodoItem
    private let entity: TodoAppEntity

    public init(todo: TodoItem) {
        self.todo = todo
        self.entity = TodoAppEntity(from: todo)
    }

    public var body: some View {
        Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
            HStack {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)

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
        .buttonStyle(.plain)
        // Onscreen entity (WWDC 2026 #343): 表示中の行が「どの todo か」を Siri /
        // Apple Intelligence に知らせる。
        //
        // iOS 側は List に `.appEntityIdentifier(forSelectionType:)` を 1 つ付けて
        // 行を一括で紐付けているが、あれは List の **selection 値の型**を手がかりに
        // する仕組み。watchOS の一覧は selection を持たない（行が
        // `Button(intent:)`）ため、行ごとの単一 annotation に落とす。
        .appEntityIdentifier(EntityIdentifier(for: entity))
    }
}
