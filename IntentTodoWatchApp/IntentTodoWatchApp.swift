//
//  IntentTodoWatchApp.swift
//  IntentTodoWatch
//
//  watchOS app for IntentTodo.
//  Provides quick todo management from the wrist.
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents
import WatchUI

@main
struct IntentTodoWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        // Use SharedModelContainer for data sharing
        // Note: watchOS uses a separate data store (no App Group sharing with iOS)
        // swiftlint:disable:next force_try
        let container = try! SharedModelContainer.createContainer()
        modelContainer = container

        Task { @MainActor in
            IntentDependencies.shared.configure(modelContainer: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchTodoListView()
        }
        .modelContainer(modelContainer)
    }
}
