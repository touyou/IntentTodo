//
//  WatchAddTodoView.swift
//  WatchUI
//

import SwiftUI
import TodoAppIntents

/// View for adding a new todo on watchOS.
public struct WatchAddTodoView: View {
    @State private var title = ""

    public init() {}

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField(.copy("Todo title"), text: $title)
                .textContentType(.none)
                .accessibilityIdentifier("todoTitleField")

            // Button(intent:) で発火することで、Intent の @Dependency が
            // AppDependencyManager から解決される (直接 perform() 呼びは不可)。
            Button(intent: AddTodoIntent(title: trimmedTitle)) {
                Label(.copy("Add"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedTitle.isEmpty)
            .accessibilityIdentifier("addButton")
        }
        .navigationTitle(.copy("New Todo"))
        // シートを閉じるのは `AddTodoIntent` の完了時（`dismissAddTodo()` →
        // `NavigationModel.showingAddTodo`）。件数差分で閉じる形は、他デバイスや
        // ウィジェットからの追加で誤クローズするため使わない（iOS 側と同じ理由）。
    }
}
