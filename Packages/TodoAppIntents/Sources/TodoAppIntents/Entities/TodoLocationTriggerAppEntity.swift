//
//  TodoLocationTriggerAppEntity.swift
//  TodoAppIntents
//

// Exists only to satisfy `locationTrigger` on `.reminders.reminder`. The whole file is
// closed to watchOS: there is no schema there to require it, and a fallback type would only
// add an entity nothing references to the watch metadata.
#if !os(watchOS)

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

// MARK: - Helpers

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

    /// Shares its strings with `caseDisplayRepresentations`, so the String Catalog needs
    /// one entry rather than two.
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

#endif
