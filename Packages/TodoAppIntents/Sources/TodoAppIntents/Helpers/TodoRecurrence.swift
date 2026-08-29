//
//  TodoRecurrence.swift
//  TodoAppIntents
//

import Domain
import Foundation

/// Bridges between the App Intents / reminders-schema `Calendar.RecurrenceRule` type
/// and the CloudKit-safe primitives (frequency + interval) stored on `TodoItem`.
///
/// `Calendar.RecurrenceRule` can't be a SwiftData attribute — it compiles but SwiftData
/// traps while initialising the schema. Same shape as `TodoPlace`.
/// 経緯: docs/devlog/2026-08-29-reminder-schema-conformance.md
enum TodoRecurrence {
    /// The frequencies the app can express. Stored as the raw string on the model.
    enum Frequency: String, CaseIterable {
        case daily
        case weekly
        case monthly
        case yearly

        var calendarFrequency: Calendar.RecurrenceRule.Frequency {
            switch self {
            case .daily: .daily
            case .weekly: .weekly
            case .monthly: .monthly
            case .yearly: .yearly
            }
        }
    }

    /// Rebuilds a rule from stored primitives, or `nil` when the todo doesn't repeat.
    ///
    /// An unrecognised raw value is treated as "doesn't repeat" rather than trapping —
    /// a value written by a newer build (or a CloudKit peer) shouldn't crash this one.
    static func rule(frequency: String?, interval: Int) -> Calendar.RecurrenceRule? {
        guard let frequency, let parsed = Frequency(rawValue: frequency) else { return nil }
        return Calendar.RecurrenceRule(
            calendar: .current,
            frequency: parsed.calendarFrequency,
            interval: max(1, interval)
        )
    }
}
