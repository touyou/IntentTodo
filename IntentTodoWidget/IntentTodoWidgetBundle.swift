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
        //
        // ただし書き込み系 Intent は全て `allowedExecutionTargets = [.main]` で
        // アプリ本体に固定済み (WWDC 2026 #345)。このプロセスで実行され得るのは
        // 読み取り系 (ShowTodoCountIntent / GetTodoSummaryIntent / SearchEverythingIntent 等)
        // と entity 解決・snippet 描画だけで、SwiftData の書き手はアプリ本体のみ。
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)

        // 読み取り系 Intent が TodoService を @Dependency で受け取れるよう登録。
        // WidgetBundle.init は main actor で評価されるため assumeIsolated で包む。
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: sharedWidgetModelContainer)
            AppDependencyManager.shared.add(dependency: todoService)

            // SnippetIntent と TodoAppEntity の deferred property は @Dependency を
            // 使えず TodoEntityStore から読むため、こちらの登録も別途必要
            // (無いと Extension プロセスでの解決時に中身が空になる)。
            TodoEntityStore.register(container: sharedWidgetModelContainer)
        }
    }

    var body: some Widget {
        // Home screen widgets
        IntentTodoWidget()

        // Control Center widgets (visionOS 以外で利用可能。公式表で iOS/iPadOS/macOS/watchOS 対応)
        #if !os(visionOS)
        QuickAddTodoControl()
        TodoCountControl()
        ToggleTodoControl()
        #endif
    }
}
