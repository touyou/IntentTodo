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

        // Control Center widgets (visionOS 以外で利用可能。公式表で iOS/iPadOS/macOS/watchOS 対応)
        #if !os(visionOS)
        QuickAddTodoControl()
        TodoCountControl()
        ToggleUrgentTodoControl()
        #endif
    }
}
