//
//  IntentTodoApp.swift
//  IntentTodo
//
//  Created by 藤井陽介 on 2026/01/29.
//

import AppIntents
import os.log
import SwiftData
import SwiftUI
import TodoAppIntents
import UI
import UserNotifications

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "IntentTodoApp")

@main
struct IntentTodoApp: App {
    // MARK: - Properties

    // UIApplicationDelegate と NSApplicationDelegate は別プロトコルのため、
    // プラットフォームごとに Adaptor を分岐（デファクトパターン）。
    // 通知ハンドラ本体は NotificationHandler に集約し、両 Delegate から共通に利用する。
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    let modelContainer: ModelContainer

    // Same instance stored in @State AND registered with AppDependencyManager.
    // Intents access it via @Dependency; views observe it via .environment().
    @State private var navigationModel: NavigationModel

    // MARK: - Initialization

    init() {
        do {
            let container = try SharedModelContainer.createContainer()
            modelContainer = container
            AppDependencyManager.shared.add(dependency: container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        // TodoService は Intent からも View からも参照可能な唯一のビジネスロジック層。
        // Repository を内包するため、Intent 側は SwiftData を直接触らない。
        let todoService = TodoService.swiftDataBacked(container: modelContainer)
        AppDependencyManager.shared.add(dependency: todoService)

        // Same NavigationModel instance is stored in @State AND registered with
        // AppDependencyManager so intents can write navigation state via @Dependency.
        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)

        // 通知タップ時のナビゲーションも同じ NavigationModel を使う。
        #if os(iOS) || os(visionOS) || os(macOS)
        MainActor.assumeIsolated {
            NotificationHandler.shared.navigationModel = navigation
        }
        #endif
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
                logger.info("Notification permission granted")
            } else {
                logger.info("Notification permission denied by user")
            }
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription)")
        }
    }
}
