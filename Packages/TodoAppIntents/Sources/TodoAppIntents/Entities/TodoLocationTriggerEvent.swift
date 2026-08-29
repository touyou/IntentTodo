//
//  TodoLocationTriggerEvent.swift
//  TodoAppIntents
//

import AppIntents

/// Whether arriving at or leaving a place should surface the todo.
///
/// On most platforms this conforms to the reminders `locationTriggerEvent` assistant
/// schema, which requires exactly the cases `arrive` and `depart` (`leave` is
/// rejected with `requires enum case 'depart'`). The reminders schemas are
/// unavailable on watchOS, so there it falls back to a plain `AppEnum` under a
/// distinct type name — same reasoning as `WatchTodoListType`.
/// 詳細: docs/insights/03-app-intents-core.md
#if os(watchOS)
public enum WatchTodoLocationTriggerEvent: String, AppEnum {
    case arrive
    case depart

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location Trigger Event"

    public static let caseDisplayRepresentations: [WatchTodoLocationTriggerEvent: DisplayRepresentation] = [
        .arrive: "Arriving",
        .depart: "Leaving"
    ]
}

/// Call sites use the shared name on every platform.
public typealias TodoLocationTriggerEvent = WatchTodoLocationTriggerEvent
#else
@AppEnum(schema: .reminders.locationTriggerEvent)
public enum TodoLocationTriggerEvent: String {
    case arrive
    case depart

    public static let caseDisplayRepresentations: [TodoLocationTriggerEvent: DisplayRepresentation] = [
        .arrive: "Arriving",
        .depart: "Leaving"
    ]
}
#endif
