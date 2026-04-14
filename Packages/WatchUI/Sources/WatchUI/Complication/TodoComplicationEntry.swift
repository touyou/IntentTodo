//
//  TodoComplicationEntry.swift
//  WatchUI
//

import WidgetKit

/// Timeline entry containing todo data for complications.
///
/// 型自体は `TodoComplicationProvider` と `TodoComplicationEntryView` が
/// public に露出するため public だが、内部状態 (count 等) は同一パッケージ
/// からのみアクセスされるので internal に留める。
public struct TodoComplicationEntry: TimelineEntry {
    public let date: Date
    let incompleteCount: Int
    let nextDueDate: Date?
    let nextDueTitle: String?
    let completedToday: Int
    let totalToday: Int

    init(
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
