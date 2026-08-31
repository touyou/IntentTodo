//
//  TodoWidgetEntryView.swift
//  WidgetUI
//
//  Views for different widget sizes. Takes plain value parameters so that
//  the owning Extension target does not need to expose its TimelineEntry type.
//

import SwiftUI
import TodoAppIntents
import WidgetKit

/// Main entry view that switches based on widget family.
public struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let todos: [TodoAppEntity]
    let incompleteCount: Int
    let loadFailed: Bool

    public init(todos: [TodoAppEntity], incompleteCount: Int, loadFailed: Bool = false) {
        self.todos = todos
        self.incompleteCount = incompleteCount
        self.loadFailed = loadFailed
    }

    public var body: some View {
        if loadFailed {
            WidgetLoadFailureView()
        } else {
            switch family {
            case .systemSmall:
                SmallTodoWidgetView(todos: todos, incompleteCount: incompleteCount)
            case .systemMedium:
                MediumTodoWidgetView(todos: todos, incompleteCount: incompleteCount)
            case .systemLarge:
                LargeTodoWidgetView(todos: todos, incompleteCount: incompleteCount)
            case .systemExtraLargePortrait:
                ExtraLargePortraitTodoWidgetView(todos: todos, incompleteCount: incompleteCount)
            default:
                SmallTodoWidgetView(todos: todos, incompleteCount: incompleteCount)
            }
        }
    }
}

/// Shown when the fetch failed, worded so it cannot be mistaken for the empty state.
struct WidgetLoadFailureView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.orange)
            Text(.copy("Couldn't load todos"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(.copy("Open the app to retry."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SmallTodoWidgetView: View {
    let todos: [TodoAppEntity]
    let incompleteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text(.copy("Todos"))
                    .font(.headline)
                Spacer()
                Text(incompleteCount, format: .number)
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
                        Text(.copy("All done!"))
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
    let incompleteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text(.copy("Todos"))
                    .font(.headline)
                Spacer()
                Text(.copy("\(incompleteCount) remaining"))
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
                        Text(.copy("All done!"))
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
    let incompleteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text(.copy("Todos"))
                    .font(.headline)
                Spacer()
                Text(.copy("\(incompleteCount) remaining"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if todos.isEmpty {
                Spacer()
                WidgetAllDoneView()
                Spacer()
            } else {
                ForEach(todos.prefix(5)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
            }

            Spacer()

            WidgetAddTodoLink()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// The tall family added in the 27 releases.
///
/// Same skeleton as Large — header, rows, add link — with more rows. It needs its own case:
/// falling through to the Small fallback would show three rows in a very large frame.
struct ExtraLargePortraitTodoWidgetView: View {
    let todos: [TodoAppEntity]
    let incompleteCount: Int

    /// The provider supplies at most ten, all of which fit here.
    private static let rowLimit = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text(.copy("Todos"))
                    .font(.headline)
                Spacer()
                Text(.copy("^[\(incompleteCount) remaining todo](inflect: true)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if todos.isEmpty {
                Spacer()
                WidgetAllDoneView()
                Spacer()
            } else {
                ForEach(todos.prefix(Self.rowLimit)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
                if todos.count > Self.rowLimit {
                    Text(.copy("^[\(todos.count - Self.rowLimit) more todo](inflect: true)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            WidgetAddTodoLink()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Shown when everything is done. Shared by the Large and tall families.
struct WidgetAllDoneView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(.copy("All done!"))
                    .font(.title3)
                Text(.copy("No todos to display"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// A `Link`, per Apple's guidance: `Button(intent:)` is for interactions that do more than
/// open the app.
struct WidgetAddTodoLink: View {
    var body: some View {
        Link(destination: TodoDeepLink.addTodo.url) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(.copy("Add Todo"))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
