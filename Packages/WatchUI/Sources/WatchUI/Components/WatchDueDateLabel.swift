//
//  WatchDueDateLabel.swift
//  WatchUI
//

import Domain
import SwiftUI

/// Component for displaying due date with appropriate styling on watchOS.
public struct WatchDueDateLabel: View {
    let date: Date
    let isCompleted: Bool

    public init(date: Date, isCompleted: Bool) {
        self.date = date
        self.isCompleted = isCompleted
    }

    private var status: DueDateStatus {
        .evaluate(date: date, isCompleted: isCompleted)
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
        switch status {
        case .overdue: return "exclamationmark.circle.fill"
        case .dueSoon: return "clock.badge.exclamationmark"
        case .normal: return "calendar"
        }
    }

    private var color: Color {
        switch status {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .normal: return .secondary
        }
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
