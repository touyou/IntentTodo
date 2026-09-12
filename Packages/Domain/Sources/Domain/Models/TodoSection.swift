//
//  TodoSection.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A named subdivision of a category, holding a subset of its todos.
///
/// Every attribute has a default value and both relationships are optional, for CloudKit
/// compatibility — as in `TodoItem`.
@Model
public final class TodoSection {
    // MARK: - Properties

    // Type annotations are kept for the same reason as in `TodoItem`.
    // swiftlint:disable redundant_type_annotation

    /// Unique identifier for the section.
    public var id: UUID = UUID()

    /// The display name of the section.
    public var name: String = ""

    /// The order index for sorting sections within their category.
    public var sortIndex: Int = 0

    /// The category this section subdivides.
    ///
    /// The inverse is declared on `Category.sections`, which cascades: a section only
    /// means something inside a category, so deleting the category takes it along.
    public var category: Category?

    /// Todos filed under this section.
    ///
    /// Nullify rather than cascade — deleting a section keeps its todos and only drops
    /// the filing.
    @Relationship(deleteRule: .nullify, inverse: \TodoItem.section)
    public var todos: [TodoItem]? = []

    // swiftlint:enable redundant_type_annotation

    // MARK: - Initialization

    /// Creates a new section with the specified name.
    public init(name: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.category = nil
        self.todos = []
    }

    /// Recreates a section with an explicit identifier.
    ///
    /// Counterpart to `TodoItem.init(id:…)`: sections are cascade-deleted with their
    /// category, so undoing a category deletion has to bring them back under the same ids.
    public init(id: UUID, name: String, sortIndex: Int) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.category = nil
        self.todos = []
    }
}
