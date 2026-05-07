# 04 — Process model and `@Dependency`

How `@Dependency` resolution interacts with the multi-process reality of App Intents, and how to organize SPM packages so Intents stay routable.

## The process map

App Intents do not all run in the same process. The same Intent type may execute in different processes depending on caller and `supportedModes`.

| Caller | Mode | Executing process | Where to register `@Dependency` |
|---|---|---|---|
| Siri / Shortcuts | any | Main app | `App.init()` |
| UI `Button(intent:)` | any | Main app | `App.init()` |
| Widget `Button(intent:)` | `.foreground(.immediate)` | Main app | `App.init()` |
| Widget `Button(intent:)` | `.background` | **Widget Extension** | `WidgetBundle.init()` |
| `ControlWidgetButton` | `.background` | **Widget Extension** | `WidgetBundle.init()` |
| Live Activity button (`LiveActivityIntent`) | n/a | Main app | `App.init()` |

**`AppDependencyManager.shared` is per-process.** Each process has its own instance, so anything resolved with `@Dependency` must be registered in the *executing* process. Forgetting this in the widget extension is the most common runtime trap — the Intent compiles, but `@Dependency` traps when the system invokes it.

## Registering dependencies

Register synchronously at the entry point of every process that hosts intents.

### Main app

```swift
@main
struct MyApp: App {
    let modelContainer: ModelContainer
    @State private var navigation: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }

    var body: some Scene { /* … */ }
}
```

### Widget extension

```swift
@main
struct MyAppWidgetBundle: WidgetBundle {
    init() {
        let container = sharedWidgetModelContainer
        AppDependencyManager.shared.add(dependency: container)
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: container)
            AppDependencyManager.shared.add(dependency: todoService)
        }
    }

    var body: some Widget { /* … */ }
}
```

Two important details:

1. **Use a shared `ModelContainer`** (typically backed by an App Group). The widget extension cannot share the main app's in-memory container.
2. **`MainActor.assumeIsolated` is necessary** because `WidgetBundle.init()` is not main-actor by default but `@MainActor` services need to be constructed there.

### Live Activity extension

A `LiveActivityIntent` runs in the **main app**, not the Live Activity extension, so registration in `App.init()` is enough. The Live Activity extension itself only renders the Activity UI; intent execution hops back to the app process.

## Service-as-dependency pattern

Aggregate persistence and side effects in a single `@MainActor final class Service` per domain, register it once per process, and inject it into Intents via `@Dependency`. Intents stay thin and free of SwiftData / network code.

```swift
@MainActor
public final class TodoService {
    private let repository: TodoRepository

    public init(repository: TodoRepository) {
        self.repository = repository
    }

    public static func swiftDataBacked(container: ModelContainer) -> TodoService {
        TodoService(repository: SwiftDataTodoRepository(container: container))
    }

    public func create(title: String, dueDate: Date?) throws -> TodoAppEntity {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try repository.insert(.init(title: title, dueDate: dueDate))
        return TodoAppEntity(item: item)
    }

    public func toggleCompletion(id: String) throws {
        defer { WidgetReloader.reloadAllWidgets() }
        try repository.toggleCompletion(id: id)
    }
}
```

Intents become trivial:

```swift
struct AddTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Todo"
    @Parameter(title: "Title") var title: String
    @Parameter(title: "Due date") var dueDate: Date?
    @Dependency var todoService: TodoService

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let entity = try todoService.create(title: title, dueDate: dueDate)
        return .result(value: entity)
    }
}
```

This pattern replaces older approaches like `MyIntentRouter.shared` or `IntentDependencies.shared.testRepository`. It is testable (substitute a mock service via `@Dependency` resolution at registration time) and process-safe (each process registers its own concrete service).

## SPM packaging rules

When intents live in a Swift package, follow these rules to keep Shortcuts routing intact.

### Declare `AppIntentsPackage` exactly once, and only inside the package

```swift
// Inside Packages/MyAppIntents/Sources/MyAppIntents/Package.swift target
public struct MyAppIntentsPackage: AppIntentsPackage {}
```

**Do not** declare another `AppIntentsPackage` in the main app target — even with `includedPackages`. The system enforces a single `AppIntentsPackage` per app, and double-declaring breaks Shortcuts discovery silently.

### Make the entry types `public`

Intents, entities, queries, and the package conformer must be `public` so the app target can link them and the system can introspect them.

### Keep extensions thin, packages thick

Each extension target (Widget, Live Activity, Watch, etc.) should contain only:

- The `@main` bundle declaration.
- `Info.plist` and entitlements.
- A small dependency-registration shim if the extension needs to host intents.

Views, view models, and intent definitions live in SPM packages so they stay testable and reusable across extensions.

### Why this matters

- Tests can target the package directly via `swift test --package-path Packages/<name>`.
- The same `TodoAppEntity` definition is shared by main app, widget, watch, and Live Activity — no duplication, no drift.
- Mocking `TodoRepository` in unit tests is straightforward because the repository is a protocol parameter to the service.
