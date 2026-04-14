//
//  SnoozeTodoFromExtensionIntent.swift
//  TodoAppIntents
//
//  Variant for Live Activity context. Uses SharedModelContainer directly and
//  conforms to LiveActivityIntent on iOS.
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
        Summary("Snooze \(\.$todo) by 30 minutes")
    }

    @Parameter(title: "Todo")
    public var todo: TodoAppEntity

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let container = try SharedModelContainer.createContainer()
        let repository = SwiftDataTodoRepository(modelContext: ModelContext(container))
        let result = try TodoActions.snooze(todoId: todo.id, using: repository)
        WidgetReloader.reloadAllWidgets()

        #if os(iOS)
        await updateMatchingLiveActivity(for: todo.id, newDueDate: result.newDueDate, title: result.title)
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
