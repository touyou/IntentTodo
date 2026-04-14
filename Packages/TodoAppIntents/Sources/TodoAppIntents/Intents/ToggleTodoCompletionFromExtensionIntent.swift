//
//  ToggleTodoCompletionFromExtensionIntent.swift
//  TodoAppIntents
//
//  FromExtension variant: parameter is `todoId: String` (not TodoAppEntity).
//
//  App Intents が TodoAppEntity パラメータを持つ Intent を実行するとき、
//  perform() 前に TodoEntityQuery.entities(for:) を呼んで entity を解決しようとする。
//  Live Activity Extension のプロセスで解決されると SwiftData が内部 assertion で
//  trap することがあるため、呼び出し元（LA）が todoId を知っているケースでは
//  entity resolution を経由しない String パラメータ版を用意する。
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

    /// Shortcuts には露出させない (FromExtension はユーザーに直接選ばせる Intent ではないため)。
    public static let isDiscoverable = false

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Toggle completion of todo \(\.$todoId)")
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
        let result = try TodoActions.toggleCompletion(todoId: todoId, using: repository)
        WidgetReloader.reloadAllWidgets()

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
            await activity.end(dismissalPolicy: .immediate)
        }
    }
    #endif
}

#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
