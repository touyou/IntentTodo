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
        // Without a store the watch app has nothing to show, so this still traps — but it
        // logs why first. A bare `try!` leaves no message, and on the watch a launch crash
        // otherwise presents as "opens and immediately quits".
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

        // Registered synchronously: deferring to a `Task` can lose the race against an
        // intent that runs right after launch.
        AppDependencyManager.shared.add(dependency: container)

        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: container)
            AppDependencyManager.shared.add(dependency: todoService)
        }

        // `NavigationModel` too: `AddTodoIntent` calls `dismissAddTodo()` on success, so
        // without it **adding a todo fails outright** with "Failed to retrieve dependency of
        // type NavigationModel" — no crash, no error, nothing on screen.
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
