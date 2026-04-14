//
//  SnoozeTodoFromExtensionIntent.swift
//  TodoAppIntents
//
//  FromExtension variant: parameter is `todoId: String` (not TodoAppEntity).
//  See ToggleTodoCompletionFromExtensionIntent.swift for rationale.
//

#if os(iOS)
import ActivityKit
#endif
import AppIntents
import Domain
import Foundation
import Repository
import SwiftData

public struct SnoozeTodoFromExtensionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Snooze Todo"
    public static let description = IntentDescription("Internal variant used by Live Activity buttons.")
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.background]

    public static var parameterSummary: some ParameterSummary {
        Summary("Snooze todo \(\.$todoId) by 30 minutes")
    }

    @Parameter(title: "Todo ID")
    public var todoId: String

    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    public init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
        let result = try TodoActions.snooze(todoId: todoId, using: repository)
        WidgetReloader.reloadAllWidgets()

        #if os(iOS)
        await updateMatchingLiveActivity(for: todoId, newDueDate: result.newDueDate, title: result.title)
        #endif

        return .result(value: result.entity)
    }

    #if os(iOS)
    @MainActor
    private func updateMatchingLiveActivity(for todoId: String, newDueDate: Date, title: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
        where activity.attributes.todoId == todoId {
            let contentState = TodoDeadlineActivityAttributes.ContentState(
                title: title,
                dueDate: newDueDate,
                isCompleted: false
            )
            await activity.update(using: contentState)
        }
    }
    #endif
}

#if os(iOS)
extension SnoozeTodoFromExtensionIntent: LiveActivityIntent {}
#endif
