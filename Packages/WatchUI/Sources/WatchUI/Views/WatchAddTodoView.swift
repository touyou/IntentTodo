//
//  WatchAddTodoView.swift
//  WatchUI
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// View for adding a new todo on watchOS.
public struct WatchAddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var todoItems: [TodoItem]
    @State private var title = ""
    @State private var baselineCount = 0

    public init() {}

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Todo title", text: $title)
                .textContentType(.none)
                .accessibilityIdentifier("todoTitleField")

            // Button(intent:) で発火することで、Intent の @Dependency が
            // AppDependencyManager から解決される (直接 perform() 呼びは不可)。
            Button(intent: AddTodoIntent(title: trimmedTitle)) {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedTitle.isEmpty)
            .accessibilityIdentifier("addButton")
        }
        .navigationTitle("New Todo")
        .task { baselineCount = todoItems.count }
        .onChange(of: todoItems.count) { _, newValue in
            if newValue > baselineCount { dismiss() }
        }
    }
}
