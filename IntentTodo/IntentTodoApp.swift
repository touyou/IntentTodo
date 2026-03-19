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
import UserNotifications

@main
struct IntentTodoApp: App {
    // MARK: - Properties

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer

    // MARK: - Initialization

    init() {
        // Use SharedModelContainer for data sharing with extensions
        do {
            let container = try SharedModelContainer.createContainer()
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

    /// Handle deep link URLs from widgets.
    private func handleURL(_ url: URL) {
        guard url.scheme == "intenttodo" else { return }

        switch url.host {
        case "addTodo":
            IntentAppState.shared.requestShowAddTodo()
        default:
            break
        }
    }

    // MARK: - Private Methods

    /// Request notification permission for Control Center feedback.
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
