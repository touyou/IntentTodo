//
//  CategoryAppEntity.swift
//  IntentTodo
//

import AppIntents
import Domain

/// An App Intents entity representing a todo category.
///
/// On most platforms this conforms to the reminders `list` assistant schema
/// (`@AppEntity(schema: .reminders.list)`) so Siri / Apple Intelligence treat a
/// category as a reminders list. The macro generates the schema conformance +
/// `typeDisplayRepresentation`; we supply the schema-required properties
/// (`name`, `type`) plus a query.
///
/// The reminders entity schemas are unavailable on watchOS (Xcode 27 beta 2
/// restricted them to non-watchOS platforms), so there we fall back to a plain
/// `AppEntity`. Siri / Apple Intelligence schema routing isn't used on watchOS,
/// so this loses nothing on that platform. A macro-attributed declaration can't
/// be split by `#if`, so the two variants are declared in full.
#if os(watchOS)
public struct CategoryAppEntity: AppEntity, Hashable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "List"

    // MARK: - Properties

    /// The unique identifier for this entity (the category UUID as a string).
    public var id: String

    /// Optional hex color code (e.g. "#FF5733"). Extra app property beyond the schema.
    public var colorHex: String?

    /// The display name of the list (schema-required).
    public var name: String

    /// The kind of list (schema-required). Always `.standard` for our categories.
    public var type: TodoListType

    // MARK: - AppEntity Requirements

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(name: name)
    }

    public static var defaultQuery: CategoryEntityQuery {
        CategoryEntityQuery()
    }

    // MARK: - Initialization

    /// Creates a new CategoryAppEntity from a Category model.
    @MainActor
    public init(from category: Domain.Category) {
        self.id = category.id.uuidString
        self.colorHex = category.colorHex
        self.name = category.name
        self.type = .standard
    }

    /// Creates a new CategoryAppEntity with the given properties.
    public init(id: String, name: String, colorHex: String? = nil, type: TodoListType = .standard) {
        self.id = id
        self.colorHex = colorHex
        self.name = name
        self.type = type
    }

    // MARK: - Hashable / Equatable

    public static func == (lhs: CategoryAppEntity, rhs: CategoryAppEntity) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.colorHex == rhs.colorHex && lhs.type == rhs.type
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
#else
@AppEntity(schema: .reminders.list)
public struct CategoryAppEntity: Hashable {
    // MARK: - Properties

    /// The unique identifier for this entity (the category UUID as a string).
    public var id: String

    /// Optional hex color code (e.g. "#FF5733"). Extra app property beyond the schema.
    public var colorHex: String?

    /// The display name of the list (schema-required).
    public var name: String

    /// The kind of list (schema-required). Always `.standard` for our categories.
    public var type: TodoListType

    // MARK: - AppEntity Requirements

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(name: name)
    }

    public static var defaultQuery: CategoryEntityQuery {
        CategoryEntityQuery()
    }

    // MARK: - Initialization

    /// Creates a new CategoryAppEntity from a Category model.
    @MainActor
    public init(from category: Domain.Category) {
        self.id = category.id.uuidString
        self.colorHex = category.colorHex
        self.name = category.name
        self.type = .standard
    }

    /// Creates a new CategoryAppEntity with the given properties.
    public init(id: String, name: String, colorHex: String? = nil, type: TodoListType = .standard) {
        self.id = id
        self.colorHex = colorHex
        self.name = name
        self.type = type
    }

    // MARK: - Hashable / Equatable

    // The schema macro adds non-`Hashable` property backing, so synthesis is
    // unavailable; equality compares the snapshot, the hash uses the stable id.
    public static func == (lhs: CategoryAppEntity, rhs: CategoryAppEntity) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.colorHex == rhs.colorHex && lhs.type == rhs.type
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
#endif

// MARK: - Display

/// Declared outside the `#if` so both variants share one implementation.
extension CategoryAppEntity {
    /// Builds a category's display representation from its name.
    ///
    /// Static so `CategoryEntityQuery.displayRepresentations(for:)` can build it
    /// straight from the model without constructing the entity.
    ///
    /// `synonyms:` widens Siri's matching — people refer to a category as
    /// "the Work list" or "the Work category" as often as by the bare name.
    /// The image is a closure so the system can skip it in text-only contexts.
    static func makeDisplayRepresentation(name: String) -> DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            synonyms: ["\(name) list", "\(name) category"]
        ) {
            DisplayRepresentation.Image(systemName: "folder")
        }
    }
}
