//
//  TodoFocusFilter.swift
//  TodoAppIntents
//
//  Per-Focus filtering, written by `TodoFocusFilterIntent` and read by the list UI and the
//  widgets.
//
//  One reader lives in another process, so the value travels through the App Group
//  UserDefaults. Deciding *which* todos survive stays in one pure function here, so the app
//  and the widget cannot disagree.
//
//

import Domain
import Foundation

// MARK: - Value

/// Which todos stay visible while a Focus is on.
public struct TodoFocusFilter: Equatable, Sendable, Codable {
    /// Category to keep, or `nil` to not filter by category.
    public var categoryID: String?

    /// Carried alongside the id so the Settings cell and the in-app indicator do not have
    /// to resolve it. A rename catches up on the next Focus change.
    public var categoryName: String?

    /// Keep only todos that are due soon or overdue.
    public var showsUrgentOnly: Bool

    /// Hide completed todos.
    public var hidesCompleted: Bool

    /// No filtering: the value when no Focus is active and when none is configured.
    public static let inactive = TodoFocusFilter(
        categoryID: nil,
        categoryName: nil,
        showsUrgentOnly: false,
        hidesCompleted: false
    )

    public init(
        categoryID: String? = nil,
        categoryName: String? = nil,
        showsUrgentOnly: Bool = false,
        hidesCompleted: Bool = false
    ) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.showsUrgentOnly = showsUrgentOnly
        self.hidesCompleted = hidesCompleted
    }

    /// Whether anything is being filtered, which is also the indicator's condition.
    public var isActive: Bool {
        categoryID != nil || showsUrgentOnly || hidesCompleted
    }

    // MARK: - Application

    /// Applies the filter to a list of todos.
    ///
    /// A pure function called from both the list UI and the widget, so the two cannot
    /// disagree. `now` is injectable to make "due soon" testable at a fixed time.
    public func apply(to todos: [TodoAppEntity], now: Date = Date()) -> [TodoAppEntity] {
        guard isActive else { return todos }
        return todos.filter { todo in
            if let categoryID, todo.category?.id != categoryID { return false }
            if hidesCompleted, todo.isCompleted { return false }
            if showsUrgentOnly, !Self.isUrgent(todo, now: now) { return false }
            return true
        }
    }

    /// "Urgent" is defined by `DueDateStatus`, the same threshold the badges use — a
    /// different one here would contradict what the rows show.
    static func isUrgent(_ todo: TodoAppEntity, now: Date) -> Bool {
        guard let dueDate = todo.dueDateValue else { return false }
        switch DueDateStatus.evaluate(date: dueDate, isCompleted: todo.isCompleted, now: now) {
        case .overdue, .dueSoon:
            return true
        case .normal:
            return false
        }
    }

    // MARK: - Notification filter criteria

    /// Criteria attached to notifications the app raises for itself, such as a failed
    /// control action.
    ///
    /// Notifications that do not match `FocusFilterAppContext.notificationFilterPredicate`
    /// are silenced [Apple: wwdc2022-10121 13:15], and a silenced failure notification is
    /// indistinguishable from "nothing happened" — so this is always allowed.
    public static let systemNotificationCriteria = "system"

    /// Criteria for notifications about a todo. Uncategorised todos use `category:none`.
    public static func notificationCriteria(categoryID: String?) -> String {
        "category:\(categoryID ?? "none")"
    }

    /// The criteria this filter lets through, or `nil` to not filter notifications at all.
    ///
    /// `showsUrgentOnly` and `hidesCompleted` describe how the *list* looks and have no
    /// bearing on which notifications are relevant, so they are not applied here.
    public var allowedNotificationCriteria: [String]? {
        guard let categoryID else { return nil }
        return [Self.systemNotificationCriteria, Self.notificationCriteria(categoryID: categoryID)]
    }

    // MARK: - Shared storage

    /// Key used in the App Group UserDefaults.
    static let sharedDefaultsKey = "focusFilter"

    /// `nil` when the App Group is unavailable; callers fall back to no filtering.
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
    }

    /// Reads the stored filter, falling back to `.inactive` when absent or unreadable.
    ///
    /// Synchronous and nonisolated because widget timeline generation calls it too.
    public static func loadFromSharedDefaults(_ defaults: UserDefaults? = nil) -> TodoFocusFilter {
        guard let defaults = defaults ?? sharedDefaults(),
              let data = defaults.data(forKey: sharedDefaultsKey),
              let filter = try? JSONDecoder().decode(TodoFocusFilter.self, from: data) else {
            return .inactive
        }
        return filter
    }

    /// Stores the filter. `.inactive` removes the key, which readers treat the same way.
    public func saveToSharedDefaults(_ defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? Self.sharedDefaults() else { return }
        guard isActive else {
            defaults.removeObject(forKey: Self.sharedDefaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.sharedDefaultsKey)
    }
}
