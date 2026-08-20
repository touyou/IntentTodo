//
//  ToggleTodoCompletionIntent.swift
//  TodoAppIntents
//
//  Siri / Shortcuts / UI / Widget / Live Activity すべての呼出元で共通に使う。
//

#if os(iOS)
import ActivityKit
import Domain
#endif
import AppIntents

public struct ToggleTodoCompletionIntent: AppIntent {
    public static var title: LocalizedStringResource { "Toggle Todo Completion" }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks a todo as completed or incomplete",
            categoryName: "Todos",
            searchKeywords: ["complete", "done", "finish", "toggle", "check"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// 書き込み系。Extension プロセスが SwiftData を書かないようアプリ本体に固定（WWDC 2026 #345）。
    /// iOS では `LiveActivityIntent` 準拠で実質アプリ実行だが、macOS / watchOS には
    /// その保証が無いので型で明示する。
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

        #if os(iOS)
        if result.isNowCompleted {
            // Live Activity は完了で用済み。`LiveActivityMonitor` の reconcile は
            // TodoListView が画面に居るときしか走らないので、ロック画面から完了
            // させたケースはここで畳まないと出っぱなしになる。
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

// Live Activity のボタンから呼ばれるため、`perform()` がアプリプロセスで走ることを
// 保証する `LiveActivityIntent` に準拠する（Activity の end 操作に必要）。
#if os(iOS)
extension ToggleTodoCompletionIntent: LiveActivityIntent {}
#endif
