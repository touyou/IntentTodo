//
//  TodoComplicationEntry.swift
//  WatchUI
//

import WidgetKit

/// Timeline entry containing todo data for complications.
///
/// Public because the provider and the entry view expose it, while the counts stay internal:
/// nothing outside this package reads them.
public struct TodoComplicationEntry: TimelineEntry, Sendable {
    public let date: Date
    let incompleteCount: Int
    let nextDueDate: Date?
    let nextDueTitle: String?
    let completedToday: Int
    let totalToday: Int
    /// Lets the view switch to "—" or a warning icon instead of showing "nothing due".
    let loadFailed: Bool

    init(
        date: Date,
        incompleteCount: Int,
        nextDueDate: Date?,
        nextDueTitle: String?,
        completedToday: Int,
        totalToday: Int,
        loadFailed: Bool = false
    ) {
        self.date = date
        self.incompleteCount = incompleteCount
        self.nextDueDate = nextDueDate
        self.nextDueTitle = nextDueTitle
        self.completedToday = completedToday
        self.totalToday = totalToday
        self.loadFailed = loadFailed
    }

    public static var placeholder: TodoComplicationEntry {
        TodoComplicationEntry(
            date: Date(),
            incompleteCount: 5,
            nextDueDate: Date().addingTimeInterval(3600),
            nextDueTitle: "Sample Todo",
            completedToday: 3,
            totalToday: 8
        )
    }

    /// Entry used when the fetch failed, so it cannot be read as "nothing due".
    static func unavailable(at date: Date = Date()) -> TodoComplicationEntry {
        TodoComplicationEntry(
            date: date,
            incompleteCount: 0,
            nextDueDate: nil,
            nextDueTitle: nil,
            completedToday: 0,
            totalToday: 0,
            loadFailed: true
        )
    }
}
