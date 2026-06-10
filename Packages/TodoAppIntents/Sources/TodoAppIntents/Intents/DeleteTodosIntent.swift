//
//  DeleteTodosIntent.swift
//  TodoAppIntents
//
//  Adopts the system `DeleteIntent` protocol (WWDC 2026 #344) for bulk deletion.
//  The single-item, UI-driven DeleteTodoIntent stays as-is; this variant gives
//  the system a semantic "delete these entities" action over a collection.
//

import AppIntents

/// Deletes one or more todos.
///
/// Conforms to `DeleteIntent`, whose contract is an `entities: [Entity]` array
/// (the associated `Entity` type is inferred from it). Modeling delete as a
/// collection is why this is separate from the single-item `DeleteTodoIntent`,
/// which UI `Button(intent:)` calls drive with one `TodoAppEntity`.
public struct DeleteTodosIntent: DeleteIntent {
    public static var title: LocalizedStringResource { "Delete Todos" }

    public static var description: IntentDescription {
        IntentDescription(
            "Deletes one or more todo items",
            categoryName: "Todos",
            searchKeywords: ["delete", "remove", "trash", "clear"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$entities)")
    }

    @Parameter(title: "Todos", description: "The todos to delete")
    public var entities: [TodoAppEntity]

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(entities: [TodoAppEntity]) {
        self.entities = entities
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Destructive action — confirm once for the whole batch. Throws (and
        // cancels) if the person declines.
        try await requestConfirmation(
            dialog: IntentDialog(deletionPrompt)
        )

        for entity in entities {
            try todoService.delete(todoId: entity.id)
            // Drop donations referencing a now-deleted todo so the system stops
            // suggesting actions it can no longer perform (IntentDonationManager).
            try? await IntentDonationManager.shared.deleteDonations(
                matching: .entityIdentifiers([EntityIdentifier(for: entity)])
            )
        }

        return .result()
    }

    private var deletionPrompt: LocalizedStringResource {
        if entities.count == 1, let only = entities.first {
            return "Delete “\(only.title)”?"
        }
        return "Delete \(entities.count) todos?"
    }
}
