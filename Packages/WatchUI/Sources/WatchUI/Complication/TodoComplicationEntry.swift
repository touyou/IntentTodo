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
public struct TodoComplicationEntry: TimelineEntry, Sendable {
    public let date: Date
    let incompleteCount: Int
    let nextDueDate: Date?
    let nextDueTitle: String?
    let completedToday: Int
    let totalToday: Int
    /// fetch が失敗した場合は true。complication 表示で「予定なし」と区別するため、
    /// View 側で "—" や warning icon に切り替える。
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

    /// Fetch 失敗時の表示用エントリ。「予定なし」(全 0) との誤認を防ぐ。
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
