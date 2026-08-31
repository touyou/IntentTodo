//
//  QuickSnoozeTodoIntent.swift
//  TodoAppIntents
//

#if os(iOS)
import ActivityKit
import Domain
#endif
import AppIntents
import Foundation

/// Snoozes by a fixed interval without asking.
///
/// Split from `SnoozeTodoIntent` because of interaction, not because of the caller:
/// `SnoozeTodoIntent` uses `requestChoice` to pick a duration, and a Live Activity button
/// runs in the background with no surface to answer on.
public struct QuickSnoozeTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Quick Snooze Todo"
    public static let description = IntentDescription(
        "Pushes back the due date by the default interval without asking"
    )

    /// Hidden from Shortcuts: it is `SnoozeTodoIntent` minus the choice, so offering both
    /// would only make the picker ambiguous.
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.background]

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    public static var parameterSummary: some ParameterSummary {
        Summary("Snooze \(\.$todo) by 30 minutes")
    }

    @Parameter(title: "Todo", description: "The todo to snooze")
    public var todo: TodoAppEntity

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let result = try todoService.snooze(todoId: todo.id)

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
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }
    #endif
}

// Updating an activity requires `perform()` to run in the app process, which conformance
// to `LiveActivityIntent` is what guarantees.
#if os(iOS)
extension QuickSnoozeTodoIntent: LiveActivityIntent {}
#endif
