//
//  TimeRemainingView.swift
//  LiveActivity
//
//  Reusable view for displaying time remaining.
//

#if os(iOS)
import SwiftUI

/// View component for displaying remaining time with various styles.
public struct TimeRemainingView: View {
    public enum Style {
        case minimal
        case compact
        case full
    }

    let dueDate: Date
    let style: Style

    public init(dueDate: Date, style: Style) {
        self.dueDate = dueDate
        self.style = style
    }

    private var isOverdue: Bool {
        dueDate.timeIntervalSinceNow <= 0
    }

    public var body: some View {
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
#endif
