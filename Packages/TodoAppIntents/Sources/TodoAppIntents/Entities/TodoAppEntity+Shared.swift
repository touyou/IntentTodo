//
//  TodoAppEntity+Shared.swift
//  IntentTodo
//
//  Behaviour shared by both declarations of `TodoAppEntity` (see `TodoAppEntity.swift` for
//  why there are two). Only the property declarations and initialisers have to be
//  duplicated per platform — property macros must sit on the members themselves — so
//  everything else lives here once and reaches both through the typealias.
//

import AppIntents
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Domain
import Foundation
import GeoToolbox
import Repository
import SwiftData

// MARK: - AppEntity Requirements

public extension TodoAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Todo", comment: "Todo item type name"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) todos", comment: "Number of todos")
        )
    }

    var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(
            title: title,
            isCompleted: isCompleted,
            isFavorite: isFavorite,
            dueDate: dueDateValue
        )
    }

    static var defaultQuery: TodoEntityQuery {
        TodoEntityQuery()
    }
}

// MARK: - Display

extension TodoAppEntity {
    /// Builds a todo's display representation from raw field values.
    ///
    /// Static so `TodoEntityQuery.displayRepresentations(for:)` can build the same
    /// representation straight from a `TodoItem`, without constructing the entity
    /// (and its `CategoryAppEntity` relation) only to discard it.
    ///
    /// The image is passed as a closure so the system can skip materializing it in
    /// text-only contexts (`DisplayRepresentation.Components.text`).
    static func makeDisplayRepresentation(
        title: String,
        isCompleted: Bool,
        isFavorite: Bool,
        dueDate: Date?
    ) -> DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle(isCompleted: isCompleted, dueDate: dueDate),
            synonyms: ["\(title) todo", "\(title) task"]
        ) {
            image(isCompleted: isCompleted, isFavorite: isFavorite)
        }
    }

    /// Siri reads this subtitle aloud, so times are formatted as prose rather than
    /// positional ("14:30" is read digit by digit). Returns `nil`, not "", when there is
    /// nothing to say — an empty `LocalizedStringResource` is a lookup for an empty key.
    private static func subtitle(isCompleted: Bool, dueDate: Date?) -> LocalizedStringResource? {
        if isCompleted {
            return LocalizedStringResource("Completed", comment: "Todo completed status")
        }
        if let dueDate {
            return "Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return nil
    }

    private static func image(isCompleted: Bool, isFavorite: Bool) -> DisplayRepresentation.Image {
        if isCompleted {
            return .init(systemName: "checkmark.circle.fill")
        }
        if isFavorite {
            return .init(systemName: "star.fill")
        }
        return .init(systemName: "circle")
    }
}

// MARK: - Derived values

extension TodoAppEntity {
    /// The body of the `@ComputedProperty` has to live on the declaration, so only the
    /// logic is shared here.
    static func isOverdue(isCompleted: Bool, dueDate: Date?) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }
}

// MARK: - Deferred loaders

extension TodoAppEntity {
    /// Fetches subtask completion counts on the MainActor and formats a summary.
    ///
    /// Entities can't use `@Dependency` (that is intents-only), so the shared
    /// container is read from `TodoEntityStore`, which the app registers at launch.
    static func loadSubtaskProgress(forID id: String) async throws -> String {
        try await MainActor.run {
            guard let item = liveItem(forID: id) else {
                return String(localized: "No subtasks")
            }
            let subTasks = item.subTasks ?? []
            guard !subTasks.isEmpty else {
                return String(localized: "No subtasks")
            }
            let completed = subTasks.filter(\.isCompleted).count
            return "\(completed)/\(subTasks.count) completed"
        }
    }

    /// Looks a todo up in the shared container, or `nil` when it is gone.
    @MainActor
    static func liveItem(forID id: String) -> TodoItem? {
        guard let container = TodoEntityStore.container,
              let uuid = UUID(uuidString: id) else {
            return nil
        }
        let repository = SwiftDataTodoRepository(modelContext: container.mainContext)
        return try? repository.fetch(by: uuid)
    }
}

#if !os(watchOS)
extension TodoAppEntity {
    /// Re-fetches the tags by id. Same shape as `loadSubtaskProgress`.
    static func loadTags(forID id: String) async throws -> Set<String> {
        try await MainActor.run {
            guard let item = liveItem(forID: id) else { return [] }
            return Set(item.tags)
        }
    }

    /// Re-fetches the attached links by id.
    static func loadURLs(forID id: String) async throws -> [URL] {
        try await MainActor.run {
            guard let item = liveItem(forID: id) else { return [] }
            return item.urls
        }
    }
}
#endif

// MARK: - Hashable / Equatable

// The `@ComputedProperty` / `@DeferredProperty` macros add non-`Hashable`
// `EntityProperty` backing storage, so synthesis is unavailable. Equality
// compares the value snapshot fields; the hash uses the stable id.
// `location` (PlaceDescriptor) is excluded as it isn't guaranteed `Equatable`;
// the underlying stored name/coordinate are reflected via the model anyway.
//
// Only fields present on both declarations take part (`dueDateValue`, not `dueDate`).
public extension TodoAppEntity {
    static func == (lhs: TodoAppEntity, rhs: TodoAppEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.todoDescription == rhs.todoDescription
            && lhs.isCompleted == rhs.isCompleted
            && lhs.isFavorite == rhs.isFavorite
            && lhs.dueDateValue == rhs.dueDateValue
            && lhs.createdAt == rhs.createdAt
            && lhs.sortIndex == rhs.sortIndex
            && lhs.category == rhs.category
            && lhs.estimatedDuration == rhs.estimatedDuration
            && lhs.assigneeName == rhs.assigneeName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - IndexedEntity (Spotlight Integration)

#if os(iOS) || os(macOS) || os(visionOS)
/// Spotlight integration for todo items.
/// Allows users to search for todos via Spotlight with enhanced attributes.
extension TodoAppEntity: IndexedEntity {
    /// Only attributes that `@Property(indexingKey:)` cannot express. Filling a key from
    /// both sides is undefined, and `contentDescription` is already mapped from
    /// `todoDescription`, so completion state goes into `keywords` instead. `displayName`
    /// is a different key from `.title` and does not collide.
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = title
        if let dueDateValue {
            attributes.dueDate = dueDateValue
        }
        attributes.keywords = buildKeywords()
        return attributes
    }

    /// Builds keyword list for Spotlight search.
    private func buildKeywords() -> [String] {
        var keywords = ["todo", title]
        if isFavorite {
            keywords.append(contentsOf: ["favorite", "starred", "important"])
        }
        if isCompleted {
            keywords.append("completed")
        } else {
            keywords.append(contentsOf: ["incomplete", "pending"])
        }
        return keywords
    }
}
#endif
