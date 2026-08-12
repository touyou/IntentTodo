# 04 — Process model, dependencies and packaging

Where an intent actually runs, where its dependencies must exist, and how to lay out packages so the system can see everything.

## The process is a heuristic, not a rule

When intents live in a package linked by several targets, **the system picks the process by heuristics** — it prefers the app if the app is already running, otherwise it launches an extension. [Apple: wwdc2026-345 15:59–16:55]

Pin it when you care:

```swift
public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
```

`.main` / `.appIntentsExtension` / `.widgetKitExtension` are the three options [Apple: wwdc2026-345 16:55]. `allowedExecutionTargets` controls **who performs**, not whether entity resolution happens — resolution runs regardless.

### Registration matrix

`AppDependencyManager.shared` is **per process**. Anything resolved with `@Dependency` must be registered in the process that executes.

| Caller | Executes in | Register in |
|---|---|---|
| Siri / Shortcuts | main app | `App.init()` |
| App UI `Button(intent:)` | main app | `App.init()` |
| Widget `Button(intent:)`, `.foreground(.immediate)` | main app | `App.init()` |
| Live Activity button | main app — `perform()` guaranteed [Apple]; entity pre-resolution measured there too [measured 2026-08-12] | `App.init()` |
| Widget timeline rendering (`entities(for:)`) | **widget extension** [measured 2026-08-12] | `WidgetBundle.init()` |
| Widget / control `.background`, no `allowedExecutionTargets` | **heuristic** — either | **both**, as insurance |
| …with `allowedExecutionTargets` set | pinned | that process only |

As long as any intent leaves `allowedExecutionTargets` unset, dual registration cannot be removed. That is the cost of the default, and it is cheap.

> Apple's line "If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target" is about **target membership at build time**, not a promise about the runtime process. [Apple]

## Registering dependencies

Register **synchronously** at each entry point. Wrapping registration in `Task { @MainActor in … }` lets `perform()` start before the task completes, and `@Dependency` resolution fails.

```swift
@main
struct MyApp: App {
    let modelContainer: ModelContainer
    @State private var navigation: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        // Entities cannot use @Dependency — give them an ambient store instead.
        MainActor.assumeIsolated { TodoEntityStore.register(container: container) }

        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }
}
```

```swift
@main
struct MyWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
        MainActor.assumeIsolated {
            AppDependencyManager.shared.add(
                dependency: TodoService.swiftDataBacked(container: sharedWidgetModelContainer)
            )
            TodoEntityStore.register(container: sharedWidgetModelContainer)   // separate registration!
        }
    }
    var body: some Widget { /* … */ }
}
```

Two details that cost real debugging time:

- **`MainActor.assumeIsolated`** — `WidgetBundle.init()` is not main-actor annotated, but `@MainActor` services must be built there.
- **`@Dependency` and the ambient store are two different registrations.** Registering only the first produces a working intent with an empty snippet — a hard symptom to localise. [measured 2026-08-12]

The Live Activity extension needs no registration of its own: it renders, and intent execution hops to the app.

## What can and cannot use `@Dependency`

| Type | `@Dependency` | Workaround |
|---|---|---|
| `AppIntent` (incl. `SnippetIntent`, `SetValueIntent`) | ✅ | — |
| `EntityQuery` and friends | ✅ | — |
| `IntentValueQuery` | ✅ (`_SupportsAppDependencies`) | — |
| **`AppEntity` / `TransientAppEntity`** | ❌ `Unknown attribute 'Dependency'` | ambient `@MainActor enum` store, registered per process |

Apple is explicit that dependency injection exists to pass data from the app to an **intent** [Apple]. Entity property getters (`@DeferredProperty`) therefore read an ambient store — Apple's own samples use the same ambient-`modelData` shape.

## Service-as-dependency

One `@MainActor final class` per domain, holding the repository. Intents call it; they never touch SwiftData themselves.

```swift
@MainActor
public final class TodoService {
    private let repository: any TodoRepositoryProtocol
    public init(repository: any TodoRepositoryProtocol) { self.repository = repository }

    public static func swiftDataBacked(container: ModelContainer) -> TodoService {
        TodoService(repository: SwiftDataTodoRepository(modelContext: container.mainContext))
    }

    public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
        defer { WidgetReloader.reloadAllWidgets() }     // no intent can forget it
        // …
    }
}
```

Use `container.mainContext`, not a fresh `ModelContext(container)` per call — a new context does not see unsaved state from the other one.

This replaces `MyRouter.shared` / `Dependencies.shared` singletons, which silently break across processes and cannot be substituted in tests.

## Packaging

### `AppIntentsPackage`: declare it in the package **and** in every consuming target

```swift
// In the package that owns the intents
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

```swift
// One per consuming target: app, widget extension, Live Activity extension, watch app
struct MyAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [TodoIntentsPackage.self] }
}
```

[Apple: wwdc2025-244 23:29–24:00 — "You **must** register each target as an App Intents Package to ensure proper indexing and validation."]

This reverses earlier guidance in this skill, which said app-side declaration broke Shortcuts routing. Re-verified [measured 2026-08-12]:

1. Every bundle's `Metadata.appintents` counts are **identical** with and without the declarations — no duplication, even on a clean build with DerivedData deleted (`actions` 23 = 23 distinct intent types).
2. The full AppIntentsTesting suite is green with them declared — the same infrastructure Siri, Shortcuts and Spotlight use.
3. The Shortcuts app was checked on device: the action list and parameter display are intact.

**Still unverified: App Shortcut *phrase* routing through Siri.** AppIntentsTesting looks intents up by type name, so it structurally cannot exercise the phrase path; that check is manual by design ([09](09-verification.md)). If it ever breaks, deleting the per-target files restores the old behaviour.

### `AppShortcutsProvider` must be in the app target

Intents, entities, enums and queries are aggregated from packages into the app's unified metadata. **`autoShortcuts` is not.** [measured; re-confirmed 2026-08-12 to be independent of the `includedPackages` change]

| Key | package `.appintents` | app `MyApp.app/Metadata.appintents` |
|---|---|---|
| `actions` | 20 | 20 ✅ |
| `entities` | 3 | 3 ✅ |
| `queries` | 3 | 3 ✅ |
| **`autoShortcuts`** | **8** | **0 ❌** |

The system reads only the app bundle's unified metadata, so `autoShortcuts: 0` means the App Shortcuts do not exist. The build is green, `XcodeRefreshCodeIssuesInFile` is clean, and nothing in the IDE mentions it. Moving the provider into the app target flips it to 8 immediately; the intents themselves stay `public` in the package and the provider imports them.

Check it directly:

```bash
python3 scripts/inspect_appintents_metadata.py --find MyProject
```

> Apple's API reference does not state "one `AppIntentsPackage` per app" anywhere we could find [inferred → superseded]; the current rule is Apple's documented procedure plus the measurements above.

### Extension targets stay thin

Each extension target holds only:

- the `@main` bundle declaration,
- `Info.plist` / entitlements,
- its `AppIntentsPackage` declaration,
- a dependency-registration shim.

Views, view models and intents live in packages so they stay previewable, reusable and testable. A `ControlConfigurationIntent` that the app never references can stay in the widget extension — putting it in a package compiles it for watchOS and visionOS too. Types defined in an extension target are a separate module and are **not** importable from the app; if you need to share one, move it into a package [Apple: wwdc2025-244 22:34].

### Package graph

```
Domain/          # models, shared value types — no dependencies
Repository/      # protocol + SwiftData implementation
AppIntents/      # ★ intents + entities + queries + Service — the core
UI/              # main app views
WidgetUI/ WatchUI/ LiveActivity/   # leaf presentation packages, one per extension
```

Rules: single direction, `Domain` depends on nothing, the intents package is the only home for business logic, and platform-specific packages declare only their platform (`.watchOS(.v26)`) so a wrong import fails at compile time.

Independent `Package.swift` files with relative-path dependencies (`.package(path: "../Domain")`) let each package build and test on its own and need no `xcworkspace` — drag the folder into the Xcode project.

## App Group data sharing

Extensions are separate processes with separate containers. Point every target at one App Group store, or the widget shows a different database than the app.

```swift
public enum SharedModelContainer {
    public static let appGroupIdentifier = "group.com.example.MyApp"

    public static func createContainer() throws -> ModelContainer {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return try ModelContainer(for: schema)
        }
        let config = ModelConfiguration(schema: schema, url: url.appending(path: "MyApp.store"))
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

Same for preferences: `UserDefaults(suiteName:)`, never `.standard`. The App Group capability must be added to every target by hand in Xcode. watchOS is a different device — App Groups do not reach it; use CloudKit or Watch Connectivity.

Migration ownership matters here too: see [07](07-data-and-side-effects.md).
