//
//  IntentTodoApp.swift
//  IntentTodo
//
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

    // `UIApplicationDelegate` and `NSApplicationDelegate` are separate protocols, so only
    // the adaptor is platform-specific; both delegates share `NotificationHandler`.
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    // Same instance stored in @State AND registered with AppDependencyManager.
    // Intents access it via @Dependency; views observe it via .environment().
    @State private var navigationModel: NavigationModel

    // MARK: - Initialization

    /// Launch argument that switches the app to an in-memory store, DEBUG only.
    ///
    /// The shared store outlives the process, so without this todos accumulate across UI
    /// tests: tests cannot assume an empty list, and the growing list slows redraws enough
    /// to time out waits.
    ///
    /// The AppIntents tests deliberately do *not* pass it — they want entity resolution and
    /// Spotlight indexing on the real shared store.
    #if DEBUG
    static let ephemeralStoreArgument = "-uitest-ephemeral-store"
    #endif

    init() {
        do {
            #if DEBUG
            let usesEphemeralStore = ProcessInfo.processInfo.arguments.contains(Self.ephemeralStoreArgument)
            let container = usesEphemeralStore
                ? try SharedModelContainer.createInMemoryContainer()
                : try SharedModelContainer.createContainer()
            #else
            let container = try SharedModelContainer.createContainer()
            #endif
            modelContainer = container
            AppDependencyManager.shared.add(dependency: container)

            // TodoAppEntity deferred properties fetch on demand via this shared
            // container (entities can't use @Dependency — that's intents-only).
            MainActor.assumeIsolated {
                TodoEntityStore.register(container: container)
            }
        } catch {
            logger.critical("ModelContainer init failed: \(String(reflecting: error))")
            if let nsError = error as NSError? {
                logger.critical("NSError domain=\(nsError.domain) code=\(nsError.code)")
                logger.critical("NSError userInfo=\(nsError.userInfo)")
            }
            fatalError("Could not create ModelContainer: \(String(reflecting: error))")
        }

        // The single business-logic layer, reachable from both intents and views. It owns
        // the repository, so intents never touch SwiftData directly.
        let todoService = TodoService.swiftDataBacked(container: modelContainer)
        AppDependencyManager.shared.add(dependency: todoService)

        // Seeds the Spotlight index; `IndexedEntity` conformance alone indexes nothing.
        // Incremental updates happen inside `TodoService`. Low priority so a large store
        // cannot compete with the first frame.
        Task(priority: .utility) {
            await todoService.indexAllForSpotlight()
        }

        // Parameterised App Shortcut phrases do not work until the system has fetched
        // suggestions at least once, so the handler is registered and invoked here.
        // Later invalidations come from `TodoService`. [Apple: wwdc2023-10102 9:52]
        MainActor.assumeIsolated {
            AppShortcutParameterUpdater.register {
                TodoAppShortcuts.updateAppShortcutParameters()
            }
            AppShortcutParameterUpdater.notifyEntitiesChanged()
        }

        // Same NavigationModel instance is stored in @State AND registered with
        // AppDependencyManager so intents can write navigation state via @Dependency.
        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)

        // Notification taps navigate through the same `NavigationModel`.
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
                // Focus changes that happen while the app is not running never reach
                // `perform()` (there is no AppIntents extension), so the current value is
                // re-read at launch and on foregrounding. [Apple: wwdc2022-10121 9:29]
                .task {
                    await TodoFocusFilterStore.shared.syncFromSystem()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await TodoFocusFilterStore.shared.syncFromSystem() }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - URL Handling

    /// Handle deep link URLs from widgets and from `TodoAppEntity`'s URL
    /// representation (`intenttodo://todo/<id>`).
    ///
    /// The URL spelling lives in `TodoDeepLink`; this only acts on the parsed result.
    private func handleURL(_ url: URL) {
        guard let link = TodoDeepLink(url: url) else { return }

        switch link {
        case .addTodo:
            navigationModel.navigateToRoot()
            navigationModel.showAddTodo()
        case .todo(let id):
            // A stale link to a deleted todo does nothing: staying put is less confusing
            // than opening an empty screen or showing an error.
            let service = TodoService.swiftDataBacked(container: modelContainer)
            guard let todo = service.todo(id: id) else { return }
            navigationModel.navigateToRoot()
            navigationModel.showDetail(for: todo)
        }
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                logger.info("Notification permission granted")
                // `requestAuthorization` also returns true when permission was already
                // granted, which makes this the per-launch point to clear stale records.
                MissedFeedback.clear(.notification)
            } else {
                // Denied leaves controls and widgets with no way to report failures. No
                // nagging here; `MissedFeedback` surfaces it if something is actually lost.
                logger.warning("Notification permission denied: Control / Widget failures can't be surfaced")
            }
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription)")
        }
    }
}
