//
//  QuickSnoozeTodoIntent.swift
//  TodoAppIntents
//
//  Live Activity のボタン用スヌーズ。`SnoozeTodoIntent` と分かれている理由は
//  entity 解決の回避ではなく **対話の有無**: `SnoozeTodoIntent` は
//  `requestChoice` で期間を選ばせるが、Live Activity のボタンは
//  背景実行で問い合わせ先の UI が無いため、既定の 30 分固定で即実行する。
//

#if os(iOS)
import ActivityKit
import Domain
#endif
import AppIntents
import Foundation

public struct QuickSnoozeTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Quick Snooze Todo"
    public static let description = IntentDescription(
        "Pushes back the due date by the default interval without asking"
    )

    /// 期間を選ばせないぶん `SnoozeTodoIntent` の下位互換になるため、
    /// ユーザーが Shortcuts で選ぶ候補としては出さない。
    public static let isDiscoverable = false
    public static let supportedModes: IntentModes = [.background]

    /// 書き込み系。Extension プロセスが SwiftData を書かないようアプリ本体に固定（WWDC 2026 #345）。
    /// iOS では `LiveActivityIntent` 準拠で実質アプリ実行だが、他プラットフォームには
    /// その保証が無いので型で明示する。
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

// Live Activity のボタンから呼ばれるため、`perform()` がアプリプロセスで走ることを
// 保証する `LiveActivityIntent` に準拠する（Activity の update 操作に必要）。
#if os(iOS)
extension QuickSnoozeTodoIntent: LiveActivityIntent {}
#endif
