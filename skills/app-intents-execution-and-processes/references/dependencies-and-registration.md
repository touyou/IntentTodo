# Dependencies and registration

`AppDependencyManager.shared` is **per process**. Anything an intent resolves with `@Dependency` must have been registered in the process that executes it.

## The failure mode is silence

An intent that cannot resolve a dependency writes `Failed to retrieve dependency of type X.` to stderr and **the run fails**. It does not crash, and from a `Button(intent:)` there is no error UI at all — the screen simply does not change.

So the rule is not "register what you think runs here": **register everything that any intent in the linked package might need**, at every entry point. The same package is linked into every target, so the set of intents present is identical on all platforms. A watch app whose entry point registered only the container — and not the service — had every add/toggle action failing with no visible sign.

## Register synchronously

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

**Never wrap registration in `Task { @MainActor in … }`.** `perform()` can start before the task completes, and `@Dependency` resolution fails — intermittently, which is worse than always.

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
- **`@Dependency` and the ambient store are two different registrations.** Registering only the first produces a working intent with an **empty snippet** — a hard symptom to localise. [measured 2026-08-12]

The Live Activity extension needs no registration of its own: it renders, and intent execution hops to the app.

**Why register the service in the widget extension at all, if every writing intent is pinned to `[.main]`?** Because read-only intents, entity resolution during timeline rendering, and snippet bodies all run there.

## What can and cannot use `@Dependency`

| Type | `@Dependency` | Workaround |
|---|---|---|
| `AppIntent` (incl. `SnippetIntent`, `SetValueIntent`) | ✅ | — |
| `EntityQuery` and friends | ✅ | — |
| `IntentValueQuery` | ✅ (`_SupportsAppDependencies`) | — |
| **`AppEntity` / `TransientAppEntity`** | ❌ `Unknown attribute 'Dependency'` | ambient `@MainActor enum` store, registered per process |

Apple is explicit that dependency injection exists to pass data from the app to an **intent** [Apple]. Entity property getters (`@DeferredProperty`) therefore read an ambient store — Apple's own samples use the same ambient-`modelData` shape.

```swift
@MainActor
public enum TodoEntityStore {
    private static var container: ModelContainer?
    public static func register(container: ModelContainer) { Self.container = container }
    static func progress(for id: String) throws -> Double { /* read via container */ }
}
```

The ambient store is the one place a singleton-shaped thing is correct, and only because the alternative does not exist. It still needs registering **in every process** — that is what makes it not a singleton in the broken sense.

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
        defer { Self.dataDidChange() }     // no intent can forget it
        // …
    }
}
```

Use `container.mainContext`, not a fresh `ModelContext(container)` per call — a new context does not see unsaved state from the other one.

This replaces `MyRouter.shared` / `Dependencies.shared` singletons, which silently become **a different instance per process** and cannot be substituted in tests. Service responsibilities and the post-mutation hook are in `app-intents-centric-design`.

`TodoService`, `ModelContainer` and `@Observable @MainActor` classes all satisfy the `Sendable` requirement, so they can be shared through `@Dependency` without ceremony.

## Prefer adding a service method over putting a fetch in an intent

An intent that wants "the most urgent incomplete item, toggled" should call one service method, not fetch-then-mutate inside `perform()`. Keeping SwiftData calls out of intents is what makes them retriable and testable — and `audit_intents.py` flags the violation (`swiftdata-in-intent`).
