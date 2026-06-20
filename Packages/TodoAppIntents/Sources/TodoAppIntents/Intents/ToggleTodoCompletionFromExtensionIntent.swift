//
//  ToggleTodoCompletionFromExtensionIntent.swift
//  TodoAppIntents
//
//  ⚠️ Apple bug workaround (keep until Issue #30 A-3 is verified fixed).
//
//  When an Intent with `@Parameter var todo: TodoAppEntity` runs inside the
//  Live Activity Extension process, App Intents calls TodoEntityQuery.entities(for:)
//  to resolve the entity before perform(). SwiftData then trips an internal
//  assertion and the Extension crashes with EXC_BREAKPOINT.
//
//  This variant sidesteps that path by accepting the UUID string directly and
//  skipping entity resolution. Delete this file (and its Snooze sibling) once
//  Apple fixes the Extension-process entity resolution bug — do NOT introduce
//  new FromExtension variants without re-checking Issue #30 A-3 first.
//

#if os(iOS)
import ActivityKit
import Domain
#endif
import AppIntents

public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static var title: LocalizedStringResource { "Toggle Todo Completion" }
    public static let description = IntentDescription("Internal variant used by Live Activity / Widget buttons.")

    /// Shortcuts には露出させない (FromExtension はユーザーに直接選ばせる Intent ではないため)。
    public static let isDiscoverable = false

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Toggle completion of todo \(\.$todoId)")
    }

    @Parameter(title: "Todo ID")
    public var todoId: String

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let result = try todoService.toggleCompletion(todoId: todoId)

        #if os(iOS)
        if result.isNowCompleted {
            await endMatchingLiveActivity(for: todoId)
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

#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
