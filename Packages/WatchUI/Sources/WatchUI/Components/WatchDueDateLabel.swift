//
//  WatchDueDateLabel.swift
//  WatchUI
//

import SwiftUI

/// Component for displaying due date with appropriate styling on watchOS.
public struct WatchDueDateLabel: View {
    let date: Date
    let isCompleted: Bool

    public init(date: Date, isCompleted: Bool) {
        self.date = date
        self.isCompleted = isCompleted
    }

    private var isOverdue: Bool {
        !isCompleted && date < Date()
    }

    private var isDueSoon: Bool {
        !isCompleted && date.timeIntervalSinceNow <= 3600 && date.timeIntervalSinceNow > 0
    }

    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(formattedDate)
                .font(.caption2)
        }
        .foregroundStyle(color)
    }

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
