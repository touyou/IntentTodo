//
//  FavoriteButton.swift
//  IntentTodo
//

import SwiftUI
import TodoAppIntents

/// A button component that toggles todo favorite status via App Intent.
///
/// Usage:
/// ```swift
/// FavoriteButton(todo: entity) { updatedEntity in
///     viewModel.updateTodo(updatedEntity)
/// }
/// ```
public struct FavoriteButton: View {
    // MARK: - Properties

    private let todo: TodoAppEntity
    private let onToggle: ((TodoAppEntity) -> Void)?

    @State private var isProcessing = false

    // MARK: - Initialization

    /// Creates a favorite button for the given todo.
    /// - Parameters:
    ///   - todo: The todo entity to display and toggle.
    ///   - onToggle: Optional callback when the favorite status is toggled.
    public init(
        todo: TodoAppEntity,
        onToggle: ((TodoAppEntity) -> Void)? = nil
    ) {
        self.todo = todo
        self.onToggle = onToggle
    }

    // MARK: - Body

    public var body: some View {
        Button {
            Task {
                await toggleFavorite()
            }
        } label: {
            Image(systemName: todo.isFavorite ? "star.fill" : "star")
                .font(.body)
                .foregroundStyle(todo.isFavorite ? .yellow : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .accessibilityLabel(todo.isFavorite ? "Remove from favorites" : "Add to favorites")
    }

    // MARK: - Actions

    @MainActor
    private func toggleFavorite() async {
        isProcessing = true
        defer { isProcessing = false }

        let intent = ToggleFavoriteIntent(todo: todo)
        do {
            let result = try await intent.perform()
            if let entity = result.value {
                onToggle?(entity)
            }
        } catch {
            // Error handling could be added here
        }
    }
}

// MARK: - Preview

#Preview("Not Favorite") {
    FavoriteButton(
        todo: TodoAppEntity(
            id: UUID().uuidString,
            title: "Test Todo",
            isFavorite: false
        )
    )
}

#Preview("Favorite") {
    FavoriteButton(
        todo: TodoAppEntity(
            id: UUID().uuidString,
            title: "Test Todo",
            isFavorite: true
        )
    )
}
