# Templates — entry points and packaging

## App entry point

```swift
@main
struct MyApp: App {
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    let modelContainer: ModelContainer
    @State private var navigationModel: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        // Entities can't use @Dependency — ambient store, registered per process.
        MainActor.assumeIsolated { TodoEntityStore.register(container: container) }

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        Task(priority: .utility) { await todoService.indexAllForSpotlight() }

        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)   // intents
        #if os(iOS) || os(visionOS) || os(macOS)
        MainActor.assumeIsolated { NotificationHandler.shared.navigationModel = navigation }
        #endif

        // Parameterised App Shortcut phrases do nothing until this has run once.
        AppShortcutParameterUpdater.registerAndPrime()
    }

    var body: some Scene {
        WindowGroup { RootView().environment(navigationModel) }
            .modelContainer(modelContainer)
    }
}
```

Everything in `init()` is synchronous on purpose. Wrapping registration in `Task { @MainActor in … }` lets `perform()` start first and resolution fail intermittently.

## Widget bundle entry point

```swift
@main
struct MyWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
        MainActor.assumeIsolated {
            AppDependencyManager.shared.add(
                dependency: TodoService.swiftDataBacked(container: sharedWidgetModelContainer))
            TodoEntityStore.register(container: sharedWidgetModelContainer)
        }
    }

    var body: some Widget {
        MyHomeWidget()
        #if !os(visionOS)
        QuickAddControl()
        TodoCountControl()
        ToggleTodoControl()
        #endif
    }
}
```

Registered here for read-only intents, entity resolution during timeline rendering, and snippet bodies — writing intents are pinned to `[.main]` and never run in this process.

## `AppIntentsPackage` set

```swift
// In the package that owns the intents
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

```swift
// One per consuming target: app, widget extension, Live Activity extension, watch app
import AppIntents
import TodoAppIntents

struct MyAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [TodoIntentsPackage.self] }
}
```

## `AppShortcutsProvider` — app target only

```swift
// MyApp/MyAppShortcuts.swift  ← NOT in a package: autoShortcuts is not aggregated
import AppIntents
import TodoAppIntents

struct MyAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .orange }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: ["Add a todo in \(.applicationName)",
                      "Create a new todo in \(.applicationName)"],   // distinct verbs, not endings
            shortTitle: "Add Todo",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: ["Show my todos in \(.applicationName)",        // keep one parameter-free phrase
                      "Show \(\.$filter) todos in \(.applicationName)"],   // AppEntity / AppEnum only
            shortTitle: "Show Todos",
            systemImageName: "list.bullet"
        )
    }
}
```

## App Group container

```swift
public enum SharedModelContainer {
    public static let appGroupIdentifier = "group.com.example.MyApp"

    /// The app passes a migration plan; extensions must not (only one process may migrate).
    public static func createContainer(
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> ModelContainer {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return try ModelContainer(for: schema)
        }
        let config = ModelConfiguration(schema: schema, url: url.appending(path: "MyApp.store"))
        return try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [config])
    }
}
```
