//
//  IntentTodoApp.swift
//  IntentTodo
//
//  Created by 藤井陽介 on 2026/01/29.
//

import SwiftUI
import SwiftData
import Domain
import TodoAppIntents
import UI

@main
struct IntentTodoApp: App {
    // MARK: - Properties

    let modelContainer: ModelContainer

    // MARK: - Initialization

    init() {
        // Create schema with all domain models
        let schema = Schema([
            TodoItem.self,
            SubTask.self,
            Category.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContainer = container

            // Configure IntentDependencies for App Intents
            Task { @MainActor in
                IntentDependencies.shared.configure(modelContainer: container)
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            TodoListView()
        }
        .modelContainer(modelContainer)
    }
}
