//
//  Category.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A category for organizing todo items.
@Model
public final class Category {
    // MARK: - Properties

    /// Unique identifier for the category.
    public var id: UUID

    /// The name of the category.
    public var name: String

    /// Optional hex color code for the category (e.g., "#FF5733").
    public var colorHex: String?

    /// Todo items belonging to this category.
    public var todos: [TodoItem]

    // MARK: - Initialization

    /// Creates a new category with the specified name.
    /// - Parameters:
    ///   - name: The name of the category.
    ///   - colorHex: Optional hex color code for visual distinction.
    public init(name: String, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.todos = []
    }
}
