//
//  TodoRecurrence.swift
//  TodoAppIntents
//

import AppIntents
import Domain
import Foundation

/// How often a todo repeats.
///
/// The reminders schema wants `Calendar.RecurrenceRule` on the *entity*, but a rule
/// is not something Siri / Shortcuts can hand in as a parameter, and it can't be a
/// SwiftData attribute either (see `TodoRecurrence`). So the write path is expressed
/// as this enum plus an interval, and `TodoRecurrence.rule(frequency:interval:)`
/// assembles the rule on the read path.
///
/// Raw values are a persistence contract twice over — they are what `TodoItem`
/// stores *and* what a saved shortcut replays — so cases may be appended but never
/// renamed or reordered.
public enum TodoRecurrenceFrequency: String, AppEnum {
    case daily
    case weekly
    case monthly
    case yearly

    /// The smallest interval a repeat can have. `Calendar.RecurrenceRule` rejects 0.
    ///
    /// Lives here rather than on `TodoRecurrence` so callers outside the package (the
    /// app's forms) can spell the default without the bridging helper becoming public API.
    public static let minimumInterval = 1

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Recurrence"

    public static let caseDisplayRepresentations: [TodoRecurrenceFrequency: DisplayRepresentation] = [
        .daily: "Daily",
        .weekly: "Weekly",
        .monthly: "Monthly",
        .yearly: "Yearly"
    ]

    var calendarFrequency: Calendar.RecurrenceRule.Frequency {
        switch self {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }
}

/// Bridges between the App Intents / reminders-schema `Calendar.RecurrenceRule` type
/// and the CloudKit-safe primitives (frequency + interval) stored on `TodoItem`.
///
/// `Calendar.RecurrenceRule` can't be a SwiftData attribute — it compiles but SwiftData
/// traps while initialising the schema. Same shape as `TodoPlace`.
/// 経緯: docs/devlog/2026-08-29-reminder-schema-conformance.md
enum TodoRecurrence {
    /// The smallest interval a repeat can have. The constant itself lives on
    /// `TodoRecurrenceFrequency` so it is reachable from outside the package; this is
    /// an alias for the call sites that already talk about `TodoRecurrence`.
    static let minimumInterval = TodoRecurrenceFrequency.minimumInterval

    /// Rebuilds a rule from stored primitives, or `nil` when the todo doesn't repeat.
    ///
    /// An unrecognised raw value is treated as "doesn't repeat" rather than trapping —
    /// a value written by a newer build (or a CloudKit peer) shouldn't crash this one.
    static func rule(frequency: String?, interval: Int) -> Calendar.RecurrenceRule? {
        guard let frequency, let parsed = TodoRecurrenceFrequency(rawValue: frequency) else { return nil }
        return Calendar.RecurrenceRule(
            calendar: .current,
            frequency: parsed.calendarFrequency,
            interval: max(minimumInterval, interval)
        )
    }
}
