//
//  WatchDueDateLabel.swift
//  IntentTodoWatchApp
//
//  Component for displaying due date with appropriate styling.
//

import SwiftUI

/// Component for displaying due date with appropriate styling.
///
/// Shows different icons and colors based on:
/// - Overdue (red, exclamation icon)
/// - Due soon (orange, clock icon)
/// - Normal (secondary, calendar icon)
struct WatchDueDateLabel: View {
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        !isCompleted && date < Date()
    }

    private var isDueSoon: Bool {
        !isCompleted && date.timeIntervalSinceNow <= 3600 && date.timeIntervalSinceNow > 0
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(formattedDate)
                .font(.caption2)
        }
        .foregroundStyle(color)
    }

    // MARK: - Private Helpers

    private var iconName: String {
        if isOverdue { return "exclamationmark.circle.fill" }
        if isDueSoon { return "clock.badge.exclamationmark" }
        return "calendar"
    }

    private var color: Color {
        if isOverdue { return .red }
        if isDueSoon { return .orange }
        return .secondary
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
