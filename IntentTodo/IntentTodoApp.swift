//
//  IntentTodoApp.swift
//  IntentTodo
//
//

import AppIntents
import Domain
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
            // `ScreenshotFixture.isRequested` is part of the condition, not just the
            // separate argument: the fixture wipes the store before writing, so the two
            // decisions must not be able to disagree. Reading one flag rather than two
            // removes the failure where the fixture runs against the real store.
            let usesEphemeralStore = ProcessInfo.processInfo.arguments.contains(Self.ephemeralStoreArgument)
                || ScreenshotFixture.isRequested
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
                #if DEBUG
                // Screenshot runs pass the ephemeral-store argument too, so this replaces
                // the contents of a throwaway store rather than the person's own todos.
                .task {
                    await ScreenshotFixture.seedIfRequested(into: modelContainer)
                    openRequestedScreenshotScreen()
                }
                #if os(macOS)
                // A capture of the window comes out at the window's size times the backing
                // scale, and App Store Connect only accepts a fixed set of Mac sizes. 1440
                // x 900 points on a 2x display is 2880x1800, which is one of them.
                .frame(
                    minWidth: ScreenshotFixture.isRequested ? 1440 : nil,
                    maxWidth: ScreenshotFixture.isRequested ? 1440 : nil,
                    minHeight: ScreenshotFixture.isRequested ? 900 : nil,
                    maxHeight: ScreenshotFixture.isRequested ? 900 : nil
                )
                #endif
                #endif
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
        #if os(macOS)
        // Keyboard shortcuts for the actions the list and detail views expose. The
        // same `NavigationModel` the views observe, so a menu item and a button on
        // screen are two ways into one piece of state.
        .commands {
            TodoCommands(navigationModel: navigationModel)
        }
        #endif
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

    #if DEBUG
    /// Opens the screen a screenshot run asked for.
    ///
    /// visionOS is captured with `simctl`, which cannot tap anything, so the screen is
    /// selected at launch instead. A deep link would work from inside the app but not from
    /// `simctl openurl` — that puts an "Open in …?" confirmation over the capture.
    @MainActor
    private func openRequestedScreenshotScreen() {
        switch ScreenshotFixture.requestedScreen {
        case .list:
            break
        case .add:
            navigationModel.showAddTodo()
        case .detail:
            let service = TodoService.swiftDataBacked(container: modelContainer)
            guard let todo = service.todo(id: ScreenshotFixture.featuredTodoID.uuidString) else {
                logger.critical("Screenshot fixture's featured todo is missing")
                return
            }
            navigationModel.showDetail(for: todo)
        }
    }
    #endif

    private func requestNotificationPermission() async {
        #if DEBUG
        // The system alert lands on top of whatever is being captured. visionOS shows it
        // every run; the simulators elsewhere happen to auto-grant, which is not something
        // to rely on.
        guard !ScreenshotFixture.isRequested else { return }
        #endif

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
