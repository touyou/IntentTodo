//
//  TodoComplicationViews.swift
//  IntentTodoWatchApp
//
//  View components for todo complications.
//

import SwiftUI
import WidgetKit

// MARK: - Circular Complication

/// Circular complication showing incomplete count.
struct CircularComplicationView: View {
    let entry: TodoComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Text("\(entry.incompleteCount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("todo")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Corner Complication

/// Corner complication with gauge.
struct CornerComplicationView: View {
    let entry: TodoComplicationEntry

    private var progress: Double {
        guard entry.totalToday > 0 else { return 0 }
        return Double(entry.completedToday) / Double(entry.totalToday)
    }

    var body: some View {
        Text("\(entry.incompleteCount)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .widgetCurvesContent()
            .widgetLabel {
                Gauge(value: progress) {
                    Text("Done")
                } currentValueLabel: {
                    Text("\(entry.completedToday)/\(entry.totalToday)")
                }
                .gaugeStyle(.accessoryLinearCapacity)
            }
    }
}

// MARK: - Rectangular Complication

/// Rectangular complication with next due todo.
struct RectangularComplicationView: View {
    let entry: TodoComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checklist")
                Text("\(entry.incompleteCount) incomplete")
                    .font(.headline)
            }

            if let title = entry.nextDueTitle, let dueDate = entry.nextDueDate {
                Divider()

                HStack {
                    Image(systemName: dueDateIcon(for: dueDate))
                        .foregroundStyle(dueDateColor(for: dueDate))

                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.caption)
                            .lineLimit(1)

                        Text(dueDate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func dueDateIcon(for date: Date) -> String {
        if date < Date() { return "exclamationmark.circle.fill" }
        if date.timeIntervalSinceNow <= 3600 { return "clock.badge.exclamationmark" }
        return "clock"
    }

    private func dueDateColor(for date: Date) -> Color {
        if date < Date() { return .red }
        if date.timeIntervalSinceNow <= 3600 { return .orange }
        return .secondary
    }
}

// MARK: - Inline Complication

/// Inline complication for text-only displays.
struct InlineComplicationView: View {
    let entry: TodoComplicationEntry

    var body: some View {
        if let dueDate = entry.nextDueDate {
            Label {
                Text("\(entry.incompleteCount) todos • Next: \(dueDate, style: .relative)")
            } icon: {
                Image(systemName: "checklist")
            }
        } else {
            Label("\(entry.incompleteCount) todos", systemImage: "checklist")
        }
    }
}

// MARK: - Entry View Dispatcher

/// Entry view that adapts to complication family.
struct TodoComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodoComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}
