//
//  CategoryAppEntity.swift
//  IntentTodo
//

import AppIntents
import Domain

/// An App Intents entity representing a todo category.
///
/// Exposes categories as first-class "nouns" so Siri / Shortcuts can reference,
/// filter, and navigate by category.
public struct CategoryAppEntity: AppEntity, Hashable {
    // MARK: - Properties

    /// The unique identifier for this entity (the category UUID as a string).
    public var id: String

    /// Optional hex color code (e.g. "#FF5733"). Not exposed as a queryable property.
    public var colorHex: String?

    /// The display name of the category.
    @Property(title: "Name")
    public var name: String

    // MARK: - AppEntity Requirements

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Category", comment: "Category type name"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) categories", comment: "Number of categories")
        )
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            image: .init(systemName: "folder")
        )
    }

    public static var defaultQuery: CategoryEntityQuery {
        CategoryEntityQuery()
    }

    // MARK: - Initialization

    /// Creates a new CategoryAppEntity from a Category model.
    @MainActor
    public init(from category: Domain.Category) {
        // Assign plain stored properties before @Property-wrapped ones to satisfy
        // definite-initialization (the wrapper changes init ordering).
        self.id = category.id.uuidString
        self.colorHex = category.colorHex
        self.name = category.name
    }

    /// Creates a new CategoryAppEntity with the given properties.
    public init(id: String, name: String, colorHex: String? = nil) {
        self.id = id
        self.colorHex = colorHex
        self.name = name
    }

    // MARK: - Hashable / Equatable

    // Synthesis is unavailable because the `@Property` wrapper backing isn't
    // `Hashable`; equality compares the snapshot, the hash uses the stable id.
    public static func == (lhs: CategoryAppEntity, rhs: CategoryAppEntity) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.colorHex == rhs.colorHex
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
