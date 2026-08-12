//
//  TodoSummarySnippetIntent.swift
//  TodoAppIntents
//
//  Interactive snippet for list-level results (counts / summary). Presented from
//  `ShowTodoCountIntent` and `GetTodoSummaryIntent` via `snippetIntent:`.
//
//  Renders in Siri / Spotlight / Shortcuts, not in Control Center.
//

import AppIntents
import Repository
import SwiftUI

/// An interactive snippet summarizing the todo list.
public struct TodoSummarySnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Todo Summary Snippet"

    /// Not a user-facing action — only presented via `snippetIntent:` from other intents.
    public static let isDiscoverable = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: TodoSummarySnippetView(summary: Self.currentSummary()))
    }

    /// Reads the freshest counts from the shared container registered by the app
    /// (see ``TodoEntityStore``). The system re-performs a snippet intent after
    /// each contained `Button(intent:)`, so this must not cache.
    @MainActor
    private static func currentSummary() -> TodoListSummaryEntity? {
        guard let container = TodoEntityStore.container,
              let items = try? SwiftDataTodoRepository(modelContext: container.mainContext).fetchAll()
        else {
            return nil
        }
        return TodoListSummaryEntity(items: items)
    }
}

// MARK: - Snippet View

/// SwiftUI layout for ``TodoSummarySnippetIntent``.
struct TodoSummarySnippetView: View {
    let summary: TodoListSummaryEntity?

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 12) {
                Label(headline(for: summary), systemImage: "checklist")
                    .font(.headline)

                Text(detail(for: summary))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(intent: LaunchAppIntent.incompleteTodos()) {
                    Label("Open Incomplete Todos", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else {
            Label("Couldn't read your todos", systemImage: "exclamationmark.triangle")
                .padding()
        }
    }

    private func headline(for summary: TodoListSummaryEntity) -> String {
        summary.pendingCount == 0
            ? String(localized: "All caught up")
            : String(localized: "\(summary.pendingCount) pending")
    }

    private func detail(for summary: TodoListSummaryEntity) -> String {
        String(
            localized: "\(summary.overdueCount) overdue · \(summary.completedCount) completed · \(summary.totalCount) total"
        )
    }
}
