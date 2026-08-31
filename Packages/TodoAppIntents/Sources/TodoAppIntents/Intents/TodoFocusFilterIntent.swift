//
//  TodoFocusFilterIntent.swift
//  TodoAppIntents
//

import AppIntents
import Foundation
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "TodoFocusFilterIntent")

/// Narrows which todos are shown while a Focus is on. Appears under
/// Settings > Focus > App Filters, and the system calls `perform()` on every Focus change.
/// [Apple: wwdc2022-10121 4:17]
///
/// No `allowedExecutionTargets`: Focus decides where a filter runs — the app if it is
/// running, otherwise an AppIntents extension [Apple: wwdc2022-10121 9:29] — so pinning it
/// has no effect. This app has no extension, so transitions that happen while it is not
/// running are picked up by `TodoFocusFilterStore.syncFromSystem()` at launch.
public struct TodoFocusFilterIntent: SetFocusFilterIntent {
    public static let title: LocalizedStringResource = "Filter Todos"

    public static let description = IntentDescription(
        "Choose which todos to show while this Focus is on",
        categoryName: "Todos"
    )

    /// A Focus change must never bring the app forward.
    public static var supportedModes: IntentModes { .background }

    // MARK: - Parameters

    @Parameter(title: "Category")
    public var category: CategoryAppEntity?

    @Parameter(title: "Only Urgent Todos", default: false)
    public var showsUrgentOnly: Bool

    @Parameter(title: "Hide Completed Todos", default: false)
    public var hidesCompleted: Bool

    public init() {}

    public init(category: CategoryAppEntity?, showsUrgentOnly: Bool, hidesCompleted: Bool) {
        self.category = category
        self.showsUrgentOnly = showsUrgentOnly
        self.hidesCompleted = hidesCompleted
    }

    // MARK: - Value bridging

    /// Lowers the parameters into the app's value type. Used by both `perform()` and
    /// `current`.
    public var resolvedFilter: TodoFocusFilter {
        TodoFocusFilter(
            categoryID: category?.id,
            categoryName: category?.name,
            showsUrgentOnly: showsUrgentOnly,
            hidesCompleted: hidesCompleted
        )
    }

    // MARK: - Display

    /// Shown in the Settings cell, and expected to reflect what is configured rather than
    /// being static. [Apple: wwdc2022-10121 8:07]
    public var displayRepresentation: DisplayRepresentation {
        let filter = resolvedFilter
        guard filter.isActive else {
            return DisplayRepresentation(
                title: "Show All Todos",
                subtitle: "No filtering"
            )
        }

        var configured: [LocalizedStringResource] = []
        var values: [String] = []

        if let categoryName = filter.categoryName {
            configured.append("Category")
            values.append(categoryName)
        }
        if filter.showsUrgentOnly {
            configured.append("Urgency")
            values.append(String(localized: "Urgent only"))
        }
        if filter.hidesCompleted {
            configured.append("Completed")
            values.append(String(localized: "Hidden"))
        }

        return DisplayRepresentation(
            title: "Filter \(configured, format: .list(type: .and))",
            subtitle: "\(values.formatted())"
        )
    }

    // MARK: - App Context

    /// Notifications whose `filterCriteria` do not match `notificationFilterPredicate` are
    /// silenced [Apple: wwdc2022-10121 13:15], so the predicate is only returned when a
    /// category is set, and the allow list always includes `systemNotificationCriteria` —
    /// a swallowed failure notification is indistinguishable from "nothing happened".
    public var appContext: FocusFilterAppContext {
        guard let allowed = resolvedFilter.allowedNotificationCriteria else {
            return FocusFilterAppContext()
        }
        return FocusFilterAppContext(
            notificationFilterPredicate: NSPredicate(format: "SELF IN %@", allowed)
        )
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        let filter = resolvedFilter
        logger.info(
            "focus filter applied category=\(filter.categoryID ?? "nil", privacy: .public) urgentOnly=\(filter.showsUrgentOnly) hidesCompleted=\(filter.hidesCompleted)"
        )
        TodoFocusFilterStore.shared.apply(filter)
        // Widgets read the same setting through shared storage, so redraw them now.
        WidgetReloader.reloadAllWidgets()
        return .result()
    }
}
