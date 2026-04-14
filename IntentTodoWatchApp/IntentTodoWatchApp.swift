//
//  IntentTodoWatchApp.swift
//  IntentTodoWatch
//
//  watchOS app for IntentTodo.
//  Provides quick todo management from the wrist.
//

import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents
import WatchUI

@main
struct IntentTodoWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        // swiftlint:disable:next force_try
        let container = try! SharedModelContainer.createContainer()
        modelContainer = container

        // @Dependency var modelContainer を解決するために AppDependencyManager に同期登録。
        // Task {} で遅延するとアプリ起動直後の Intent 実行で resolve 漏れが起きる。
        AppDependencyManager.shared.add(dependency: container)
    }

    var body: some Scene {
        WindowGroup {
            WatchTodoListView()
        }
        .modelContainer(modelContainer)
    }
}
