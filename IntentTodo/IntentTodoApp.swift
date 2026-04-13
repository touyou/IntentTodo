//
//  IntentTodoApp.swift
//  IntentTodo
//
//  Created by 藤井陽介 on 2026/01/29.
//

import AppIntents
import SwiftUI
import SwiftData
import Domain
import TodoAppIntents
import UI
import UserNotifications

@main
struct IntentTodoApp: App {
    // MARK: - Properties

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer

    // Same instance stored in @State AND registered with AppDependencyManager.
    // Intents access it via @Dependency; views observe it via .environment().
    @State private var navigationModel: NavigationModel

    // MARK: - Initialization

    init() {
        do {
            let container = try SharedModelContainer.createContainer()
            modelContainer = container
            // Register the ModelContainer so intents can access SwiftData via @Dependency.
            AppDependencyManager.shared.add(dependency: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        // Same NavigationModel instance is stored in @State AND registered with
        // AppDependencyManager so intents can write navigation state via @Dependency.
        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            TodoListView()
                .environment(navigationModel)
                .task {
                    await requestNotificationPermission()
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - URL Handling

    /// Handle deep link URLs from widgets (e.g. intenttodo://addTodo from Home Widgets).
    private func handleURL(_ url: URL) {
        guard url.scheme == "intenttodo" else { return }

        switch url.host {
        case "addTodo":
            navigationModel.navigateToRoot()
            navigationModel.showAddTodo()
        default:
            break
        }
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("Notification permission granted")
            }
        } catch {
            print("Notification permission request failed: \(error)")
        }
    }
}
