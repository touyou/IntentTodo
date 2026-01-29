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
/// FavoriteButton(todo: entity)
/// ```
public struct FavoriteButton: View {
    // MARK: - Properties

    private let todo: TodoAppEntity

    // MARK: - Initialization

    /// Creates a favorite button for the given todo.
    /// - Parameter todo: The todo entity to display and toggle.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Body

    public var body: some View {
        Button(intent: ToggleFavoriteIntent(todo: todo)) {
            Image(systemName: todo.isFavorite ? "star.fill" : "star")
                .font(.body)
                .foregroundStyle(todo.isFavorite ? .yellow : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todo.isFavorite ? "Remove from favorites" : "Add to favorites")
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
