//
//  ToggleTodoCompletionFromExtensionIntent.swift
//  TodoAppIntents
//
//  Variant for Live Activity / Widget Extension contexts. Does not use @Dependency
//  because AppDependencyManager registrations may differ per process.
//  Uses SharedModelContainer (App Group) directly so it works regardless of process.
//  Also conforms to LiveActivityIntent on iOS so it can drive Dynamic Island / lock screen buttons.
//

#if os(iOS)
import ActivityKit
#endif
import AppIntents
import Domain
import Repository
import SwiftData

public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static var title: LocalizedStringResource { "Toggle Todo Completion" }
    public static let description = IntentDescription("Internal variant used by Live Activity / Widget buttons.")

    /// Marked as not discoverable so Shortcuts users only see the Primary `ToggleTodoCompletionIntent`.
    public static let isDiscoverable = false

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Toggle completion of \(\.$todo)")
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
        let result = try TodoActions.toggleCompletion(todoId: todo.id, using: repository)
        WidgetReloader.reloadAllWidgets()

        #if os(iOS)
        if result.isNowCompleted {
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
            await activity.end(dismissalPolicy: .immediate)
        }
    }
    #endif
}

#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
