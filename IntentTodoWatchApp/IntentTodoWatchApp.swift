//
//  IntentTodoWatchApp.swift
//  IntentTodoWatch
//
//  watchOS app for IntentTodo.
//  Provides quick todo management from the wrist.
//

import AppIntents
import Domain
import os.log
import SwiftData
import SwiftUI
import TodoAppIntents
import WatchUI

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "IntentTodoWatchApp")

@main
struct IntentTodoWatchApp: App {
    let modelContainer: ModelContainer

    /// Same instance stored in `@State` AND registered with `AppDependencyManager`,
    /// as on iOS: intents write navigation state via `@Dependency`, views observe it.
    @State private var navigationModel: NavigationModel

    init() {
        // 開けなければ watch アプリには表示できるデータが何も無いので fatalError のまま。
        // `try!` と違うのは理由がログに残ること — トラップはメッセージを持たず、
        // 起動直後のクラッシュは Watch 単体では「開いてすぐ落ちる」以外に手掛かりが無い。
        // メインアプリの `IntentTodoApp.init()` と同じ形。
        let container: ModelContainer
        do {
            container = try SharedModelContainer.createContainer()
        } catch {
            logger.critical("Watch ModelContainer init failed: \(String(reflecting: error))")
            let nsError = error as NSError
            logger.critical("NSError domain=\(nsError.domain) code=\(nsError.code)")
            logger.critical("NSError userInfo=\(nsError.userInfo)")
            fatalError("Could not create ModelContainer for the watch app: \(String(reflecting: error))")
        }
        modelContainer = container

        // @Dependency で解決できるよう AppDependencyManager に同期登録する。
        // Task {} で遅延するとアプリ起動直後の Intent 実行で resolve 漏れが起きる。
        AppDependencyManager.shared.add(dependency: container)

        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: container)
            AppDependencyManager.shared.add(dependency: todoService)
        }

        // NavigationModel も登録する。`AddTodoIntent` は完了時に
        // `navigationModel.dismissAddTodo()` を呼ぶため、未登録だと watch では
        // **Todo 追加そのものが失敗する**（"Failed to retrieve dependency of type
        // NavigationModel"。クラッシュしないので画面も変わらず無音で終わる）。
        // 経緯: docs/devlog/07-platform-specific.md（2026-08-27 の実機確認）
        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }

    var body: some Scene {
        WindowGroup {
            WatchTodoListView()
                .environment(navigationModel)
        }
        .modelContainer(modelContainer)
    }
}
