//
//  TodoComplication.swift
//  IntentTodoWatch
//
//  watchOS complications for IntentTodo.
//  Shows next deadline, progress, and incomplete count.
//

import ClockKit
import SwiftData
import SwiftUI
import WidgetKit
import Domain

// MARK: - Complication Entry

struct TodoComplicationEntry: TimelineEntry {
    let date: Date
    let incompleteCount: Int
    let nextDueDate: Date?
    let nextDueTitle: String?
    let completedToday: Int
    let totalToday: Int

    static var placeholder: TodoComplicationEntry {
        TodoComplicationEntry(
            date: Date(),
            incompleteCount: 5,
            nextDueDate: Date().addingTimeInterval(3600),
            nextDueTitle: "Sample Todo",
            completedToday: 3,
            totalToday: 8
        )
    }
}

// MARK: - Complication Provider

struct TodoComplicationProvider: TimelineProvider {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([TodoItem.self, SubTask.self, Category.self])
        let config = ModelConfiguration(schema: schema)
        // swiftlint:disable:next force_try
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> TodoComplicationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoComplicationEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoComplicationEntry>) -> Void) {
        let entry = makeEntry()

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    @MainActor
    private func makeEntry() -> TodoComplicationEntry {
        let context = modelContainer.mainContext

        // Fetch incomplete todos
        let incompleteDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.dueDate)]
        )

        let incompleteTodos: [TodoItem]
        do {
            incompleteTodos = try context.fetch(incompleteDescriptor)
        } catch {
            incompleteTodos = []
        }

        // Find next due todo
        let nextDueTodo = incompleteTodos.first { $0.dueDate != nil }

        // Today's stats
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let todayDescriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { item in
                item.createdAt >= startOfDay && item.createdAt < endOfDay
            }
        )

        let todayTodos: [TodoItem]
        do {
            todayTodos = try context.fetch(todayDescriptor)
        } catch {
            todayTodos = []
        }

        let completedToday = todayTodos.filter { $0.isCompleted }.count

        return TodoComplicationEntry(
            date: Date(),
            incompleteCount: incompleteTodos.count,
            nextDueDate: nextDueTodo?.dueDate,
            nextDueTitle: nextDueTodo?.title,
            completedToday: completedToday,
            totalToday: todayTodos.count
        )
    }
}

// MARK: - Complication Views

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

// MARK: - Complication Widget

struct TodoComplicationWidget: Widget {
    let kind = "TodoComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoComplicationProvider()) { entry in
            TodoComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Todos")
        .description("Track your incomplete todos.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

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

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}

#Preview("Corner", as: .accessoryCorner) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}
