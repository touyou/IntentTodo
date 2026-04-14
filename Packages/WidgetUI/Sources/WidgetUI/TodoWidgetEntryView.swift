//
//  TodoWidgetEntryView.swift
//  WidgetUI
//
//  Views for different widget sizes. Takes plain value parameters so that
//  the owning Extension target does not need to expose its TimelineEntry type.
//

import AppIntents
import SwiftUI
import TodoAppIntents
import WidgetKit

/// Main entry view that switches based on widget family.
public struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let todos: [TodoAppEntity]

    public init(todos: [TodoAppEntity]) {
        self.todos = todos
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            SmallTodoWidgetView(todos: todos)
        case .systemMedium:
            MediumTodoWidgetView(todos: todos)
        case .systemLarge:
            LargeTodoWidgetView(todos: todos)
        default:
            SmallTodoWidgetView(todos: todos)
        }
    }
}

struct SmallTodoWidgetView: View {
    let todos: [TodoAppEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(todos.filter { !$0.isCompleted }.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
            }

            if todos.isEmpty {
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
                ForEach(todos.prefix(3)) { todo in
                    TodoWidgetRow(todo: todo, compact: true)
                }
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumTodoWidgetView: View {
    let todos: [TodoAppEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(todos.filter { !$0.isCompleted }.count) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if todos.isEmpty {
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
                ForEach(todos.prefix(4)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
            }
            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct LargeTodoWidgetView: View {
    let todos: [TodoAppEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(todos.filter { !$0.isCompleted }.count) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if todos.isEmpty {
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
                ForEach(todos.prefix(5)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
            }

            Spacer()

            Button(intent: LaunchAppIntent.addTodo()) {
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
