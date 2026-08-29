//
//  TodoLocationTriggerAppEntity.swift
//  TodoAppIntents
//

import AppIntents
import Domain
import Foundation
import GeoToolbox
import SwiftData

/// A place-plus-event pair that says when a todo should surface.
///
/// Exists to satisfy `.reminders.reminder`'s required `locationTrigger` property.
/// The schema requires `place` (`PlaceDescriptor`) and `event`, both non-optional.
///
/// The trigger has no identity of its own — it is derived from a todo's location
/// primitives (`locationName` / `locationLatitude` / `locationLongitude`) plus
/// `locationTriggerEvent`, so **its `id` is the owning todo's id**. That keeps the
/// query resolvable without a second store.
///
/// watchOS falls back to a plain `AppEntity` under a distinct type name, for the
/// same reason as `WatchCategoryAppEntity` (a single mangled name carrying both a
/// schema and a schema-less shape lets the merge into the iOS app's unified
/// metadata drop the schema).
/// 詳細: docs/insights/03-app-intents-core.md
#if os(watchOS)
public struct WatchTodoLocationTriggerAppEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location Trigger"

    public var id: String

    @Property(title: "Place")
    public var place: PlaceDescriptor

    @Property(title: "Event")
    public var event: TodoLocationTriggerEvent

    public static var defaultQuery: TodoLocationTriggerEntityQuery {
        TodoLocationTriggerEntityQuery()
    }

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(place: place, event: event)
    }

    public init(id: String, place: PlaceDescriptor, event: TodoLocationTriggerEvent) {
        self.id = id
        self.place = place
        self.event = event
    }
}


// スキーマ識別子は文字列なので watchOS でも手書きで適合できる。
// 詳細: CategoryAppEntity の同名 extension のコメント
extension WatchTodoLocationTriggerAppEntity: AssistantSchemaEntity {
    // swiftlint:disable:next identifier_name
    public static let __appSchemaEntity = "reminders.locationTrigger"
}

public typealias TodoLocationTriggerAppEntity = WatchTodoLocationTriggerAppEntity
#else
@AppEntity(schema: .reminders.locationTrigger)
public struct TodoLocationTriggerAppEntity {
    public var id: String
    public var place: PlaceDescriptor
    public var event: TodoLocationTriggerEvent

    public static var defaultQuery: TodoLocationTriggerEntityQuery {
        TodoLocationTriggerEntityQuery()
    }

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(place: place, event: event)
    }

    public init(id: String, place: PlaceDescriptor, event: TodoLocationTriggerEvent) {
        self.id = id
        self.place = place
        self.event = event
    }
}
#endif

// MARK: - Shared helpers

extension TodoLocationTriggerAppEntity {
    /// Builds a trigger from a todo's stored primitives, or `nil` when the todo has
    /// no usable place or no event set.
    ///
    /// Both halves are required: a place without an event isn't a trigger, and an
    /// event without a place has nothing to fire on.
    @MainActor
    static func make(from item: TodoItem) -> TodoLocationTriggerAppEntity? {
        guard
            let rawEvent = item.locationTriggerEvent,
            let event = TodoLocationTriggerEvent(rawValue: rawEvent),
            let place = TodoPlace.descriptor(
                name: item.locationName,
                latitude: item.locationLatitude,
                longitude: item.locationLongitude
            )
        else {
            return nil
        }
        return TodoLocationTriggerAppEntity(id: item.id.uuidString, place: place, event: event)
    }

    /// Siri reads the subtitle aloud, so this spells the event out rather than
    /// abbreviating it.
    ///
    /// The place name is runtime data, so it goes through `"\(value)"` interpolation
    /// rather than `LocalizedStringResource(stringLiteral:)`.
    static func makeDisplayRepresentation(
        place: PlaceDescriptor,
        event: TodoLocationTriggerEvent
    ) -> DisplayRepresentation {
        let name = place.commonName ?? place.address
        let title: LocalizedStringResource = if let name, !name.isEmpty {
            "\(name)"
        } else {
            "Location"
        }
        return DisplayRepresentation(title: title, subtitle: subtitle(for: event))
    }

    /// 同じ文言を `caseDisplayRepresentations` と共有する（キーが同じなので catalog の
    /// エントリは 1 つで済む）。
    private static func subtitle(for event: TodoLocationTriggerEvent) -> LocalizedStringResource {
        switch event {
        case .arrive: "Arriving"
        case .depart: "Leaving"
        }
    }
}

// MARK: - Query

/// Resolves triggers by the owning todo's id.
///
/// Mirrors `CategoryEntityQuery`: takes the process-scoped `ModelContainer` via
/// `@Dependency` rather than reaching for a shared singleton.
public struct TodoLocationTriggerEntityQuery: EntityQuery {
    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    public func entities(for identifiers: [String]) async throws -> [TodoLocationTriggerAppEntity] {
        let ids = Set(identifiers.compactMap { UUID(uuidString: $0) })
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<TodoItem>()
        return try modelContainer.mainContext.fetch(descriptor)
            .filter { ids.contains($0.id) }
            .compactMap { TodoLocationTriggerAppEntity.make(from: $0) }
    }
}
