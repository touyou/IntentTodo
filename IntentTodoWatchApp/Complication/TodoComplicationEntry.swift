//
//  TodoComplicationEntry.swift
//  IntentTodoWatchApp
//
//  Timeline entry for todo complications.
//

import WidgetKit

/// Timeline entry containing todo data for complications.
struct TodoComplicationEntry: TimelineEntry {
    let date: Date
    let incompleteCount: Int
    let nextDueDate: Date?
    let nextDueTitle: String?
    let completedToday: Int
    let totalToday: Int

    static var placeholder: TodoComplicationEntry {
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
