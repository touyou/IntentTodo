//
//  DeleteButton.swift
//  IntentTodo
//

import SwiftUI
import AppIntents
import TodoAppIntents

/// A button component that deletes a todo via App Intent.
///
/// Usage:
/// ```swift
/// DeleteButton(todo: entity)
/// ```
public struct DeleteButton: View {
    // MARK: - Properties

    private let todo: TodoAppEntity

    // MARK: - Initialization

    /// Creates a delete button for the given todo.
    /// - Parameter todo: The todo entity to delete.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Body

    public var body: some View {
        // スワイプして現れる Delete を押す操作自体が確認になっているので、確認なし版を使う。
        // 確認付きの `DeleteTodoIntent` はアプリ内ボタンからだと確認を出す面が無く
        // 失敗する（docs/insights/06-control-widget-ios26.md 参照）。
        Button(intent: DeleteTodoImmediatelyIntent(todo: todo)) {
            Label(.copy("Delete"), systemImage: "trash")
        }
        .tint(.red)
        .accessibilityLabel(.copy("Delete todo"))
    }
}

// MARK: - Preview

#Preview {
    DeleteButton(
        todo: TodoAppEntity(
            id: UUID().uuidString,
            title: "Test Todo"
        )
    )
}
