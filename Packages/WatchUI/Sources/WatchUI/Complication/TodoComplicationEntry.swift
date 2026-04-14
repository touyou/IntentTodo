//
//  TodoComplicationEntry.swift
//  WatchUI
//

import WidgetKit

/// Timeline entry containing todo data for complications.
public struct TodoComplicationEntry: TimelineEntry {
    public let date: Date
    public let incompleteCount: Int
    public let nextDueDate: Date?
    public let nextDueTitle: String?
    public let completedToday: Int
    public let totalToday: Int

    public init(
        date: Date,
        incompleteCount: Int,
        nextDueDate: Date?,
        nextDueTitle: String?,
        completedToday: Int,
        totalToday: Int
    ) {
        self.date = date
        self.incompleteCount = incompleteCount
        self.nextDueDate = nextDueDate
        self.nextDueTitle = nextDueTitle
        self.completedToday = completedToday
        self.totalToday = totalToday
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
}
