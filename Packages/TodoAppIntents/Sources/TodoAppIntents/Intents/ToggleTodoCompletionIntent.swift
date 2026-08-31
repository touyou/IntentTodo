//
//  ToggleTodoCompletionIntent.swift
//  TodoAppIntents
//

#if os(iOS)
import ActivityKit
import Domain
#endif
import AppIntents

/// Flips a todo's completion state. One intent for every caller: Siri, Shortcuts, the
/// app's own UI, widgets and Live Activity buttons all run this type.
public struct ToggleTodoCompletionIntent: UndoableIntent {
    public static var title: LocalizedStringResource { "Toggle Todo Completion" }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks a todo as completed or incomplete",
            categoryName: "Todos",
            searchKeywords: ["complete", "done", "finish", "toggle", "check"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    /// On iOS the `LiveActivityIntent` conformance already guarantees that; macOS and
    /// watchOS have no such guarantee, so state it in the type.
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Toggle completion of \(\.$todo)")
    }

    @Parameter(title: "Todo", description: "The todo to toggle")
    public var todo: TodoAppEntity

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let result = try todoService.toggleCompletion(todoId: todo.id)
        TodoUndoRegistrar.registerCompletionChange(
            todoId: todo.id,
            previousValue: !result.isNowCompleted,
            undoManager: undoManager,
            service: todoService
        )

        #if os(iOS)
        if result.isNowCompleted {
            // `LiveActivityMonitor` only reconciles while the list is on screen, so a
            // completion coming from the lock screen has to end the activity here.
            await endMatchingLiveActivity(for: todo.id)
        }
        #endif

        return .result(value: result.entity)
    }

    #if os(iOS)
    @MainActor
    private func endMatchingLiveActivity(for todoId: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
        where activity.attributes.todoId == todoId {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }
    #endif
}

// Ending an activity requires `perform()` to run in the app process, which conformance to
// `LiveActivityIntent` is what guarantees.
#if os(iOS)
extension ToggleTodoCompletionIntent: LiveActivityIntent {}
#endif
