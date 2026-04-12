//
//  DebugNavigationIntent.swift
//  IntentTodo
//
//  最小検証用: メインターゲットで @Dependency が動くかを確認するIntent。
//  動作確認後に削除する。
//

import AppIntents
import os.log
import TodoAppIntents

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "DebugIntent")

/// @Dependency の動作確認専用 Intent。
/// Shortcuts から呼んで "internal error" が出ないかを検証する。
struct DebugNavigationIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug: Test Navigation Dependency"
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Dependency
    var navigationModel: NavigationModel

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        logger.info("DebugNavigationIntent.perform() called — @Dependency resolved OK")
        navigationModel.showAddTodo()
        return .result()
    }
}
