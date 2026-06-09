//
//  TodoSnippetIntent.swift
//  TodoAppIntents
//
//  WWDC 2026 interactive snippet. Presented as an overlay (e.g. after AddTodoIntent
//  runs from Siri / Shortcuts) so the person can act on the todo without opening the
//  app. The system re-performs this SnippetIntent after each contained Button(intent:)
//  runs, so we always fetch the freshest entity state to render correct labels.
//

import AppIntents
import Repository
import SwiftData
import SwiftUI

/// An interactive snippet that shows a single todo with quick follow-up actions.
public struct TodoSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Todo Snippet"

    /// Not a user-facing action — only presented via `snippetIntent:` from other intents.
    public static let isDiscoverable = false

    @Parameter(title: "Todo ID")
    public var todoId: String

    public init() {}

    public init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        let entity = Self.fetchEntity(forID: todoId)
        return .result(view: TodoSnippetView(entity: entity))
    }

    /// Reads the current entity from the shared container registered by the app
    /// (see ``TodoEntityStore``). Returns `nil` if the todo was deleted meanwhile.
    @MainActor
    private static func fetchEntity(forID id: String) -> TodoAppEntity? {
        guard let container = TodoEntityStore.container,
              let uuid = UUID(uuidString: id),
              let item = try? SwiftDataTodoRepository(modelContext: container.mainContext).fetch(by: uuid)
        else {
            return nil
        }
        return TodoAppEntity(from: item)
    }
}

// MARK: - Snippet View

/// SwiftUI layout for ``TodoSnippetIntent``. Buttons are wired to App Intents per
/// Apple's guidance ("like widgets, initialize the snippet's Button with an AppIntent").
struct TodoSnippetView: View {
    let entity: TodoAppEntity?

    var body: some View {
        if let entity {
            VStack(alignment: .leading, spacing: 12) {
                Label(entity.title, systemImage: entity.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.headline)

                HStack(spacing: 8) {
                    Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
                        Label(
                            entity.isCompleted ? "Mark Incomplete" : "Mark Complete",
                            systemImage: entity.isCompleted ? "arrow.uturn.left" : "checkmark"
                        )
                    }

                    Button(intent: ToggleFavoriteIntent(todo: entity)) {
                        Label(
                            entity.isFavorite ? "Remove Favorite" : "Add Favorite",
                            systemImage: entity.isFavorite ? "star.slash" : "star"
                        )
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else {
            Label("Todo not found", systemImage: "questionmark.circle")
                .padding()
        }
    }
}
