//
//  WatchAddTodoView.swift
//  WatchUI
//

import SwiftUI
import TodoAppIntents

/// View for adding a new todo on watchOS.
public struct WatchAddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    public init() {}

    private var addIntent: AddTodoIntent {
        AddTodoIntent(title: title)
    }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Todo title", text: $title)
                .textContentType(.none)
                .accessibilityIdentifier("todoTitleField")

            Button {
                Task {
                    try? await addIntent.perform()
                    dismiss()
                }
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("addButton")
        }
        .navigationTitle("New Todo")
    }
}
