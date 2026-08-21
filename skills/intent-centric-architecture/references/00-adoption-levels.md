# 00 — Adoption levels

The expensive rules in this skill exist because of a *second process* or a *second platform*. A one-target app owes none of those. This file says what is live at which level, so a small project can adopt intent-centric design in an afternoon and a large one knows what it already owes.

**Never start at the top.** Each level is shippable on its own and each one earns the constraints of the next.

| Level | You have | New constraints | Verify with |
|---|---|---|---|
| **0** | one app target, no packages | rules 1, 2, 3, 5, 7, 8, 9 | Shortcuts app |
| **1** | + widget / control / Live Activity | + rules 4, 6, 10 — packaging, per-process registration, reload fan-out | + metadata inspector, AppIntentsTesting |
| **2** | + a second platform | availability guards ([08](08-platform-and-availability.md)) | + one build per destination |
| **3** | + system understanding (Spotlight, schemas, Visual Intelligence) | entity surface quality ([10](10-advanced-entity-apis.md), [13](13-schema-domains.md)) | + Spotlight, Siri by hand |

Rule numbers refer to the non-negotiables table in `SKILL.md`. Level 0 already owes seven of the ten, but six of them are free if the first intent is written the way this file shows — the three that arrive with the first extension are the ones that take real work.

## Level 0 — one action, reachable from outside the app

The goal is not coverage. It is to move **one real action** out of the view layer and prove it runs from Shortcuts.

What you write, in one file if you like:

```swift
import AppIntents

// 1. The logic, in a type that is not a View and not an intent.
@MainActor
final class TodoService {
    func create(title: String) throws -> String { /* persist, return id */ }
}

// 2. The intent: parameters, dialog, and a call into the service. Nothing else.
struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource { "Add Todo" }
    static var supportedModes: IntentModes { .background }
    static var parameterSummary: some ParameterSummary { Summary("Add todo titled \(\.$title)") }

    @Parameter(title: "Title") var title: String
    @Dependency var todoService: TodoService

    init() {}
    init(title: String) { self.title = title }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try todoService.create(title: title)
        return .result(dialog: "Added \(title).")
    }
}

// 3. Registration, synchronously, at the one entry point that exists.
@main
struct MyApp: App {
    init() {
        AppDependencyManager.shared.add(dependency: TodoService())
    }
    var body: some Scene { WindowGroup { RootView() } }
}

// 4. A phrase. In the app target — this file cannot live in a package (rule 5).
struct MyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddTodoIntent(),
                    phrases: ["Add a todo in \(.applicationName)"],
                    shortTitle: "Add Todo", systemImageName: "plus.circle")
    }
}

// 5. The app's own UI uses the same path.
Button(intent: AddTodoIntent(title: draft)) { Text("Add") }
```

**Live at this level:** every action is an intent (1), one action = one intent (2), logic in a service (3), the provider is in the app target (5), never call `perform()` yourself (7).

Two more apply the moment the app's own UI runs intents, and both are invisible until they bite:

- **(8)** an intent that calls `requestConfirmation` / `requestChoice` **cannot** be run from `Button(intent:)` — it fails silently. Confirm in SwiftUI and run a non-interactive twin ([05](05-ui-integration.md)). This trap needs no extension to hurt you.
- **(9)** a dialog returned to an in-app button is never shown. At level 0 that is all rule 9 asks of you ([06](06-feedback-channels.md)).

**Not yet your problem:** `AppIntentsPackage`, per-process registration, `allowedExecutionTargets`, App Groups, widget/control reloads, `#if os(...)` guards, assistant schemas. Adding them now is cost without benefit.

**An entity is optional here.** `AddTodoIntent(title: String)` needs none. Add `AppEntity` at the moment an intent needs to *refer to* an existing object ("complete **this** todo") — that is the trigger, not a checklist item.

**Exit criterion:** the action appears in the Shortcuts app, runs from there, and the app's own button runs the same intent. If it does not appear, go to rung 0 of [09](09-verification.md) before changing anything.

### Retrofitting an existing app

Do not rewrite. Inventory where actions already live, then invert the dependency:

| Where actions hide today | What it becomes |
|---|---|
| `ViewModel.toggleFavourite()` and friends | move the body to a service; the view model calls the service or the intent |
| a URL-scheme / universal-link handler with a `switch` | each case is an intent; the handler calls the **service**, never `perform()` |
| `NotificationCenter` names used as an action bus | the intent replaces the bus for user-visible actions |
| `Commands` / menu items on macOS | `Button(intent:)` in the menu, same intent |
| a "quick actions" sheet | already an action list — the closest thing you have to an intent catalogue |

Two mistakes to avoid while retrofitting:

- **Do not wrap an intent around a view model.** The intent must reach the data through something the intent's process can build (`@Dependency` on a service). A view model owned by a scene does not exist in a widget process.
- **Do not call `perform()` from the old handler** to "reuse" the intent. `@Dependency` is only injected on system dispatch ([05](05-ui-integration.md)). Both paths call the service instead.

## Level 1 — the action reaches a glance surface

Adding one widget, control or Live Activity changes the architecture, because a second **process** appears.

What you now owe:

1. **Move intents, entities and the service into a Swift package** so the app and the extension share one definition. Declare `AppIntentsPackage` in the package and, with `includedPackages`, in every consuming target — rule 6 ([04](04-process-and-dependencies.md)).
2. **Register dependencies in the extension's entry point too** (`WidgetBundle.init()`), or pin the intent with `allowedExecutionTargets` — rule 4. Process choice is a heuristic, and the failure is a runtime trap on a green build ([04](04-process-and-dependencies.md)).
3. **Reload timelines *and* controls from the service's `defer`** — rule 10 ([07](07-data-and-side-effects.md)).
4. **One App Group store**, or the widget renders a different database than the app ([04](04-process-and-dependencies.md)).
5. **Rule 9 grows teeth**: controls show neither dialog nor snippet, so failure needs a notification or nothing distinguishes it from "nothing happened" ([06](06-feedback-channels.md)).
6. **`Link` for "just open the app", `Button(intent:)` for acting** ([02](02-multi-surface-mapping.md)).

Pick the *one* surface where your action is genuinely wanted — [12](12-surface-catalog.md) maps action shapes to surfaces. Shipping one good control beats three widgets nobody adds.

**Exit criterion:** the metadata inspector shows the intent in both bundles, the surface updates after a mutation from a *different* caller, and an AppIntentsTesting case covers id resolution.

## Level 2 — a second platform

The intents already work; what breaks is availability. Read [08](08-platform-and-availability.md) *before* writing guards, and build every destination — a simulator build is not proof.

Sequence that stays cheap: pick the platform whose surface you actually want (a complication, a Mac menu bar, a spatial ornament), guard only the declarations that are missing there, and keep one public type with internal branches instead of per-platform twins.

## Level 3 — the system understands your content

Now the entity surface matters more than the intent count. In rough order of payoff:

1. **`@Property` on the members the system should read** — an entity with zero properties is invisible to Shortcuts filters, Siri and Spotlight ([01](01-actions-and-entities.md)).
2. **`OpenIntent`** for your main entity. Cheap, and it is the prerequisite for Spotlight results and Visual Intelligence ([11](11-interaction-and-scale.md)).
3. **Spotlight**: `IndexedEntity` + `indexingKey:` for semantic search ([10](10-advanced-entity-apis.md)).
4. **A schema domain**, if one genuinely matches your app ([13](13-schema-domains.md)). This is what turns "runs when asked by name" into "Siri understands the concept".
5. **Onscreen entities**, snippets, Visual Intelligence, scale APIs — as the need appears ([11](11-interaction-and-scale.md)).

At this level the verification ladder is no longer optional: schema conformances and index entries fail silently by design ([09](09-verification.md)).

## Anti-goal

Do not aim for a full grid of intents × surfaces. Every surface you add is a surface that can show stale or wrong data, and every intent you expose is one a user can wire into an automation and depend on forever. The measure is *actions people repeat*, not API coverage.

`python3 scripts/audit_intents.py . --coverage` prints which surfaces the project reaches today and what each missing one would take — a level check you can run rather than guess.
