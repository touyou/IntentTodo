//
//  TodoSectionAppEntity.swift
//  TodoAppIntents
//

import AppIntents
import Domain
import Foundation
import SwiftData

// MARK: - Why watchOS gets a differently named type
//
// Same reason as `TodoAppEntity` / `CategoryAppEntity`: the schema domains do not exist on
// watchOS, and a shared type name would let the watch slice overwrite the schema-carrying
// iOS entry in the app's unified metadata (FB24570185). The type itself is needed on both
// platforms because `AddTodoIntent` / `UpdateTodoIntent` carry it as a parameter.

#if os(watchOS)

/// A named subdivision of a category (plain `AppEntity` fallback for watchOS).
public struct WatchTodoSectionAppEntity: AppEntity, Hashable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Section"

    public var id: String

    @Property(title: "Name")
    public var name: String

    @Property(title: "List")
    public var list: CategoryAppEntity

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(name: name, listName: list.name)
    }

    public static var defaultQuery: TodoSectionEntityQuery {
        TodoSectionEntityQuery()
    }

    @MainActor
    public init(from section: TodoSection) {
        self.id = section.id.uuidString
        self.name = section.name
        self.list = section.category.map { CategoryAppEntity(from: $0) } ?? .uncategorized
    }

    public init(id: String, name: String, list: CategoryAppEntity) {
        self.id = id
        self.name = name
        self.list = list
    }

    public static func == (lhs: WatchTodoSectionAppEntity, rhs: WatchTodoSectionAppEntity) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.list == rhs.list
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Call sites use the shared name on every platform. Only the metadata sees the two apart.
public typealias TodoSectionAppEntity = WatchTodoSectionAppEntity

#else

/// A named subdivision of a category.
///
/// Conforms to `.reminders.section`, which requires `name` plus a non-optional `list`.
/// The model's `category` is optional (CloudKit), so a section that somehow lost its
/// category is presented under the same synthetic list as an uncategorized todo.
@AppEntity(schema: .reminders.section)
public struct TodoSectionAppEntity: Hashable {
    /// The section's UUID as a string.
    public var id: String

    /// The display name of the section (schema-required).
    public var name: String

    /// The list this section subdivides (schema-required).
    public var list: CategoryAppEntity

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(name: name, listName: list.name)
    }

    public static var defaultQuery: TodoSectionEntityQuery {
        TodoSectionEntityQuery()
    }

    @MainActor
    public init(from section: TodoSection) {
        self.id = section.id.uuidString
        self.name = section.name
        self.list = section.category.map { CategoryAppEntity(from: $0) } ?? .uncategorized
    }

    public init(id: String, name: String, list: CategoryAppEntity) {
        self.id = id
        self.name = name
        self.list = list
    }

    // The schema macro adds non-`Hashable` property backing, so synthesis is
    // unavailable; equality compares the snapshot, the hash uses the stable id.
    public static func == (lhs: TodoSectionAppEntity, rhs: TodoSectionAppEntity) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.list == rhs.list
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#endif

// MARK: - Display

/// Declared outside the `#if` so both variants share one implementation.
extension TodoSectionAppEntity {
    /// Names the owning list in the subtitle: section names repeat across categories
    /// ("Today" under both Work and Home), so the name alone is ambiguous when Siri
    /// offers a choice.
    static func makeDisplayRepresentation(name: String, listName: String) -> DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(listName)") {
            DisplayRepresentation.Image(systemName: "list.bullet.indent")
        }
    }
}

// MARK: - Query

/// Resolves sections by id, by name, and in full.
///
/// Mirrors `CategoryEntityQuery`: takes the process-scoped `ModelContainer` via
/// `@Dependency` rather than reaching for a shared singleton.
public struct TodoSectionEntityQuery: EntityQuery {
    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    private func fetchAll() throws -> [TodoSection] {
        let descriptor = FetchDescriptor<TodoSection>(sortBy: [SortDescriptor(\.sortIndex)])
        return try modelContainer.mainContext.fetch(descriptor)
    }

    @MainActor
    public func entities(for identifiers: [TodoSectionAppEntity.ID]) async throws -> [TodoSectionAppEntity] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        guard !ids.isEmpty else { return [] }
        return try fetchAll()
            .filter { ids.contains($0.id) }
            .map { TodoSectionAppEntity(from: $0) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoSectionAppEntity] {
        try fetchAll().map { TodoSectionAppEntity(from: $0) }
    }
}

// MARK: - EntityStringQuery

extension TodoSectionEntityQuery: EntityStringQuery {
    /// Matches the section name and the owning list's name, so "the Work Today section"
    /// resolves as readily as "Today".
    @MainActor
    public func entities(matching string: String) async throws -> [TodoSectionAppEntity] {
        try fetchAll()
            .filter {
                $0.name.localizedStandardContains(string)
                    || ($0.category?.name.localizedStandardContains(string) ?? false)
            }
            .map { TodoSectionAppEntity(from: $0) }
    }
}

// MARK: - EnumerableEntityQuery

/// Sections are few (a handful per category), so loading all of them is cheap and it
/// lets the Shortcuts editor offer them as a list.
extension TodoSectionEntityQuery: EnumerableEntityQuery {
    @MainActor
    public func allEntities() async throws -> [TodoSectionAppEntity] {
        try fetchAll().map { TodoSectionAppEntity(from: $0) }
    }
}
