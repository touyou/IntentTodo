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
    }

    var body: some Scene {
        WindowGroup {
            WatchTodoListView()
        }
        .modelContainer(modelContainer)
    }
}
