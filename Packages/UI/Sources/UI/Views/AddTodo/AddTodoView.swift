//
//  AddTodoView.swift
//  IntentTodo
//

import SwiftUI
import AppIntents
import TodoAppIntents

/// A view for adding a new todo item.
///
/// This view collects todo details and creates the todo via AddTodoIntent.
/// Uses `Button(intent:)` with a computed property for dynamic intent generation.
public struct AddTodoView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var todoDescription = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var isFavorite = false

    // MARK: - Computed Intent

    /// Dynamically generated intent based on current form state.
    private var addTodoIntent: AddTodoIntent {
        AddTodoIntent(
            title: title,
            todoDescription: todoDescription.isEmpty ? nil : todoDescription,
            dueDate: hasDueDate ? dueDate : nil,
            isFavorite: isFavorite
        )
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif

                TextField("Description (optional)", text: $todoDescription, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Toggle("Set Due Date", isOn: $hasDueDate.animation())

                if hasDueDate {
                    DatePicker(
                        "Due Date",
                        selection: $dueDate,
                        displayedComponents: [.date]
                    )
                }

                Toggle("Mark as Favorite", isOn: $isFavorite)
            }
        }
        .navigationTitle("New Todo")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(intent: addTodoIntent) {
                    Text("Add")
                }
                .disabled(!isValid)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTodoView()
    }
}
