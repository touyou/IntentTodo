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
            default:
                SmallTodoWidgetView(todos: todos, incompleteCount: incompleteCount)
            }
        }
    }
}

/// fetch 失敗時に表示する代替 View。空の Todo リスト ("All done!") とは
/// はっきり区別できる文言にしておく。
struct WidgetLoadFailureView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.orange)
            Text("Couldn't load todos")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Open the app to retry.")
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
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(incompleteCount)")
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
    let incompleteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(incompleteCount) remaining")
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
    let incompleteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Todos")
                    .font(.headline)
                Spacer()
                Text("\(incompleteCount) remaining")
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

            // アプリを開くだけのインタラクションは Apple 公式推奨に従い Link を使う
            // (Button(intent:) は開く以上の副作用がある場合に限定する)
            Link(destination: URL(string: "intenttodo://addTodo")!) {
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
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
