//
//  IntentTodoWidgetBundle.swift
//  IntentTodoWidget
//

import AppIntents
import SwiftUI
import TodoAppIntents
import WidgetKit

@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        // Widget Extension プロセスで .background Intent が実行される場合、
        // メインアプリの AppDependencyManager 登録は引き継がれないので、
        // この Extension プロセス側でも依存関係を登録する。
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)

        // Intent が TodoService を @Dependency で受け取れるよう登録。
        // WidgetBundle.init は main actor で評価されるため assumeIsolated で包む。
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: sharedWidgetModelContainer)
            AppDependencyManager.shared.add(dependency: todoService)
        }
    }

    var body: some Widget {
        // Home screen widgets
        IntentTodoWidget()

        // Control Center widgets (visionOS 以外で利用可能。公式表で iOS/iPadOS/macOS/watchOS 対応)
        #if !os(visionOS)
        QuickAddTodoControl()
        TodoCountControl()
        ToggleUrgentTodoControl()
        #endif
    }
}
