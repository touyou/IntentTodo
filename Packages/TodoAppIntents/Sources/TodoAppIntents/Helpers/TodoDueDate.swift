//
//  TodoDueDate.swift
//  TodoAppIntents
//

import Foundation

/// Bridges between the reminders schema's `DateComponents` due date and the `Date` the
/// model stores.
///
/// The schema uses `DateComponents` because it can express "a day with no time of day",
/// which a `Date` cannot. The model keeps a `Date`, so both directions lose something:
/// a components value with no time lands at the start of that day, and a stored date is
/// published to the day/minute.
enum TodoDueDate {
    /// The fields the entity and the intents both publish, so a round trip is stable.
    static let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

    static func components(from date: Date?) -> DateComponents? {
        date.map { Calendar.current.dateComponents(components, from: $0) }
    }

    /// Resolves components against the current calendar.
    ///
    /// Returns `nil` for components that don't name a date at all (an empty value), so
    /// "no due date" survives the trip rather than becoming today.
    static func date(from components: DateComponents?) -> Date? {
        guard let components, components.isValidDate(in: .current) || hasDateFields(components) else {
            return nil
        }
        return Calendar.current.date(from: components)
    }

    private static func hasDateFields(_ components: DateComponents) -> Bool {
        components.year != nil || components.month != nil || components.day != nil
    }
}
