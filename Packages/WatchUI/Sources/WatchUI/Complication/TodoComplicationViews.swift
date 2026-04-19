//
//  TodoComplicationViews.swift
//  WatchUI
//

import SwiftUI
import WidgetKit

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

/// Entry view that adapts to complication family.
public struct TodoComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodoComplicationEntry

    public init(entry: TodoComplicationEntry) {
        self.entry = entry
    }

    public var body: some View {
        if entry.loadFailed {
            UnavailableComplicationView(family: family)
        } else {
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
}

/// fetch 失敗時に表示する代替。「予定なし」(全 0) と区別がつく見た目に。
struct UnavailableComplicationView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Todos —", systemImage: "exclamationmark.triangle")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Couldn't load")
                        .font(.headline)
                }
                Text("Open the app to retry.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .accessoryCorner:
            Text("—")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .widgetCurvesContent()
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
            }
        }
    }
}
