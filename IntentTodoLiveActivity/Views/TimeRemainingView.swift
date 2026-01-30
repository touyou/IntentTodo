//
//  TimeRemainingView.swift
//  IntentTodoLiveActivity
//
//  Reusable view for displaying time remaining.
//

import SwiftUI

// MARK: - Time Remaining View

/// View component for displaying remaining time with various styles.
struct TimeRemainingView: View {
    let dueDate: Date
    let style: Style

    enum Style {
        case minimal
        case compact
        case full
    }

    private var timeRemaining: TimeInterval {
        dueDate.timeIntervalSinceNow
    }

    private var isOverdue: Bool {
        timeRemaining <= 0
    }

    var body: some View {
        switch style {
        case .minimal:
            Text(timerInterval: Date()...dueDate, countsDown: true)
                .monospacedDigit()
                .font(.caption2)
                .foregroundStyle(isOverdue ? .red : .orange)

        case .compact:
            VStack(alignment: .trailing) {
                Text(timerInterval: Date()...dueDate, countsDown: true)
                    .monospacedDigit()
                    .font(.caption.bold())
                Text(isOverdue ? "overdue" : "remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(isOverdue ? .red : .primary)

        case .full:
            HStack(spacing: 4) {
                Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "timer")
                    .foregroundStyle(isOverdue ? .red : .orange)
                Text(timerInterval: Date()...dueDate, countsDown: true)
                    .monospacedDigit()
                    .font(.subheadline.bold())
            }
            .foregroundStyle(isOverdue ? .red : .primary)
        }
    }
}
