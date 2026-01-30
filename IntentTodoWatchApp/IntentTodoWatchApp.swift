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

@main
struct IntentTodoWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([TodoItem.self, SubTask.self, Category.self])
        let config = ModelConfiguration(schema: schema)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [config])
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
