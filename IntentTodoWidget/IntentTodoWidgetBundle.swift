//
//  IntentTodoWidgetBundle.swift
//  IntentTodoWidget
//

import AppIntents
import SwiftUI
import WidgetKit

@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        // Widget Extension プロセスで .background Intent が実行される場合、
        // メインアプリの AppDependencyManager 登録は引き継がれないので、
        // この Extension プロセス側でも ModelContainer を登録する。
        // sharedWidgetModelContainer は WidgetModelContainer.swift で初期化済み。
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
    }

    var body: some Widget {
        // Home screen widgets
        IntentTodoWidget()

        // Control Center widgets (iOS 18+)
        if #available(iOS 18.0, *) {
            QuickAddTodoControl()
            TodoCountControl()
            ToggleUrgentTodoControl()
        }
    }
}
