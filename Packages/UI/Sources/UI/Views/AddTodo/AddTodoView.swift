//
//  AddTodoView.swift
//  IntentTodo
//

import SwiftUI
import TodoAppIntents

/// A view for adding a new todo item.
///
/// This view collects todo details and creates the todo via AddTodoIntent.
public struct AddTodoView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var todoDescription = ""
    @State private var dueDate: Date?
    @State private var hasDueDate = false
    @State private var isFavorite = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let onAdd: (TodoAppEntity) -> Void

    // MARK: - Initialization

    /// Creates an add todo view.
    /// - Parameter onAdd: Callback when a todo is successfully added.
    public init(onAdd: @escaping (TodoAppEntity) -> Void) {
        self.onAdd = onAdd
    }

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
                        selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ),
                        displayedComponents: [.date]
                    )
                }

                Toggle("Mark as Favorite", isOn: $isFavorite)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
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
                Button("Add") {
                    Task {
                        await addTodo()
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    // MARK: - Actions

    @MainActor
    private func addTodo() async {
        isSubmitting = true
        errorMessage = nil

        let intent = AddTodoIntent(
            title: title,
            todoDescription: todoDescription.isEmpty ? nil : todoDescription,
            dueDate: hasDueDate ? dueDate : nil,
            isFavorite: isFavorite
        )

        do {
            let result = try await intent.perform()
            if let entity = result.value {
                onAdd(entity)
            }
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTodoView { _ in }
    }
}
