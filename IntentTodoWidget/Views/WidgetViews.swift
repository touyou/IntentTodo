//
//  WidgetViews.swift
//  IntentTodoWidget
//
//  Views for different widget sizes.
//

import AppIntents
import SwiftUI
import TodoAppIntents
import WidgetKit

// MARK: - Entry View

/// Main entry view that switches based on widget family.
struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodoWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTodoWidgetView(entry: entry)
        case .systemMedium:
            MediumTodoWidgetView(entry: entry)
        case .systemLarge:
            LargeTodoWidgetView(entry: entry)
        default:
            SmallTodoWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallTodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(entry.todos.filter { !$0.isCompleted }.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
            }

            if entry.todos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                        Text("All done!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.todos.prefix(3)) { todo in
                    TodoWidgetRow(todo: todo, compact: true)
                }
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumTodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(entry.todos.filter { !$0.isCompleted }.count) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.todos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All done!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                ForEach(entry.todos.prefix(4)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
            }
            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large Widget View

struct LargeTodoWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(entry.todos.filter { !$0.isCompleted }.count) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if entry.todos.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("All done!")
                            .font(.title3)
                        Text("No todos to display")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.todos.prefix(5)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
            }

            Spacer()

            // Quick Add Button
            Button(intent: OpenAddTodoIntent()) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Todo")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
