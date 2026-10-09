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
    #if os(iOS) || os(visionOS)
    // Unavailable on macOS / watchOS. Only visionOS ever reports `.simplified`.
    @Environment(\.levelOfDetail) private var levelOfDetail
    #endif
    let todos: [TodoAppEntity]
    let incompleteCount: Int
    let loadFailed: Bool

    public init(todos: [TodoAppEntity], incompleteCount: Int, loadFailed: Bool = false) {
        self.todos = todos
        self.incompleteCount = incompleteCount
        self.loadFailed = loadFailed
    }

    private var isSimplified: Bool {
        #if os(iOS) || os(visionOS)
        levelOfDetail == .simplified
        #else
        false
        #endif
    }

    public var body: some View {
        if loadFailed {
            WidgetLoadFailureView()
        } else if isSimplified {
            SimplifiedTodoWidgetView(
                todos: todos,
                incompleteCount: incompleteCount,
                rowLimit: SimplifiedTodoWidgetView.rowLimit(for: family)
            )
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

/// The layout visionOS shows when the person is far from the widget: the count and a few
/// titles, large enough to read across a room. Due dates and the add link are dropped.
struct SimplifiedTodoWidgetView: View {
    let todos: [TodoAppEntity]
    let incompleteCount: Int
    let rowLimit: Int

    static func rowLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 0
        case .systemMedium: 2
        case .systemLarge: 3
        default: 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "checklist")
                    .font(.title)
                    .foregroundStyle(.orange)
                Spacer()
                Text(incompleteCount, format: .number)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
            }

            if todos.isEmpty {
                Spacer()
                Label {
                    Text(.copy("All done!"))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
            } else {
                ForEach(todos.prefix(rowLimit)) { todo in
                    Text(todo.title)
                        .font(.title2)
                        .lineLimit(1)
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                }
            }
            Spacer()
        }
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
                ForEach(todos.prefix(Self.rowLimit)) { todo in
                    TodoWidgetRow(todo: todo, compact: false)
                }
                if todos.count > Self.rowLimit {
                    Text(.copy("\(todos.count - Self.rowLimit) more"))
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

#Preview("Simplified", traits: .sizeThatFitsLayout) {
    let todos = [
        TodoAppEntity(id: "1", title: "Buy groceries", isCompleted: false, dueDate: Date()),
        TodoAppEntity(id: "2", title: "Call mom", isCompleted: false),
        TodoAppEntity(id: "3", title: "Write the release notes", isCompleted: false),
        TodoAppEntity(id: "4", title: "Book a dentist appointment", isCompleted: false),
    ]
    VStack(spacing: 16) {
        SimplifiedTodoWidgetView(todos: todos, incompleteCount: 4, rowLimit: 0)
            .frame(width: 158, height: 158)
        SimplifiedTodoWidgetView(todos: todos, incompleteCount: 4, rowLimit: 2)
            .frame(width: 338, height: 158)
        SimplifiedTodoWidgetView(todos: [], incompleteCount: 0, rowLimit: 3)
            .frame(width: 338, height: 158)
    }
    .padding()
}
