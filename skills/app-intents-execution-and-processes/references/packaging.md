# Packaging and target layout

## `AppIntentsPackage`: declare it in the package **and** in every consuming target

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

The worry this raises is duplicate registration breaking Shortcuts routing. It does not [measured 2026-08-12]:

1. Every bundle's `Metadata.appintents` counts are **identical** with and without the declarations.
2. The full AppIntentsTesting suite is green with them declared — the same infrastructure Siri, Shortcuts and Spotlight use.
3. The Shortcuts app was checked on device: the action list and parameter display are intact.

**Still unverified: App Shortcut *phrase* routing through Siri.** AppIntentsTesting looks intents up by type name, so it structurally cannot exercise the phrase path; that check is manual by design (`app-intents-testing`). If it ever breaks, deleting the per-target files is the fallback.

### What the declaration actually does — aggregation follows linkage, not declarations

Reason 1 above is identical *because static linking has already merged the metadata*, not because
"duplicate registration was avoided". Extraction runs per target, and a statically linked
dependency's extracted metadata lands in the consuming target's `extract.actionsdata` with **no
declaration anywhere** [measured 2026-09-11, SDK 27 / tools 27A266a]:

| bundle | `AppIntentsPackage` declared | `extract.packagedata` | `actions` / `entities` / `queries` |
|---|---|---|---|
| the intents package | yes, no `includedPackages` | `{"includes":[]}` | 24 / 5 / 4 |
| a UI package depending on it | **no** | **file absent** | 24 / 5 / 4 |
| the app | yes, with `includedPackages` | `{"includes":["14TodoAppIntents0aC7PackageV"]}` | 24 / 7 / 4 |

So the declaration writes exactly one thing: `extract.packagedata`, holding the **mangled type names**
of the packages listed in `includedPackages` (`14TodoAppIntents0aC7PackageV` demangles to
`TodoAppIntents.TodoIntentsPackage`). `extract.actionsdata` is unaffected. The same session says so,
with a condition the quote above omits:

> "You should use App Intents Package when referencing code not compiled into a static library."
> [wwdc2025-244 24:00]

That is the case the `includes` list exists for — naming a target across a **dynamic** boundary
(framework, dynamic library). SwiftPM in Xcode links statically by default, so in a package-based app
the declarations are inert until some product becomes dynamic.

**Practical consequence: never try to fix "a type is missing from the metadata" by adding or removing
`includedPackages`.** Check target membership and how the dependency is linked. Keep the per-target
declarations anyway — they match Apple's documented step, cost nothing, and start carrying weight the
moment a dependency goes dynamic.

## Will restructuring orphan already-saved shortcuts? (`persistentIdentifier`)

What the Shortcuts app and donations persist is `identifier` in `extract.actionsdata`. Its default is
`PersistentlyIdentifiable.persistentIdentifier`, which is the **bare type name with no module prefix**
[measured: `AddTodoIntent.persistentIdentifier == "AddTodoIntent"`; entities, queries and enums behave
the same]. Module names appear only in `fullyQualifiedTypeName`, `mangledTypeName` and
`defaultQueryIdentifier`, all resolved within a single build.

| What you change | Already-saved shortcuts |
|---|---|
| move a type from the app target into a package | **fine** — `identifier` is still the type name |
| rename the package or module | **fine** — no module name in `identifier` |
| **rename the type** | **orphaned** — the old `identifier` simply stops existing |

So the only dangerous refactor is a **type rename**. It reads as "restructuring broke it" because
extracting types into a package is when you are most tempted to tidy up their names. Pin the old name:

```swift
public struct ShowTodoCountIntent: AppIntent {
    // Keeps the identity of the previous type name for already-saved shortcuts.
    public static let persistentIdentifier = "ShowTodoCountIntent"
```

That is what the protocol is for: "useful for maintaining the identity of a type, even when its type
name is changed." Like `title`, it is read at build time, so it must be a constant.

On a clean build the override is consistent everywhere: the `actions` dictionary key, `identifier`, a
statically linked consumer's merged metadata, and — importantly — `autoShortcuts[].actionIdentifier`
for an intent registered in `AppShortcutsProvider`. An App Shortcut is not left pointing at the old
identifier. `mangledTypeName` does not change [measured 2026-09-11].

> **Read metadata from a clean build.** An incremental build can leave a package's `*.appintents`
> unregenerated after its dependency changed, and the app's merged metadata then contains *both* the old
> and new identifiers while `autoShortcuts` still names the old one — which looks exactly like a broken
> App Shortcut. Deleting the output does not force regeneration; build into a fresh
> `-derivedDataPath` instead.

Because `actions` / `entities` / `queries` are dictionaries keyed on the bare identifier, **two
statically linked modules must not expose two types with the same name** — the later entry replaces
the earlier one wholesale.

An `AppEntity` reference has a second layer: what gets stored is the pair (the type's
`persistentIdentifier`, the instance's `AppEntity.ID`). Pinning the type name does not help if the ID
scheme changes.

## `AppShortcutsProvider` must be in the app target

Intents, entities, enums and queries are aggregated from packages into the app's unified metadata. **`autoShortcuts` is not** — and this is independent of the `includedPackages` question above [measured 2026-07-08; re-confirmed 2026-08-12]:

| Key | package `.appintents` | app `MyApp.app/Metadata.appintents` |
|---|---|---|
| `actions` | 20 | 20 ✅ |
| `entities` | 3 | 3 ✅ |
| `queries` | 3 | 3 ✅ |
| **`autoShortcuts`** | **8** | **0 ❌** |

The system reads only the app bundle's unified metadata, so `autoShortcuts: 0` means the App Shortcuts **do not exist**. The build is green, `XcodeRefreshCodeIssuesInFile` is clean, and nothing in the IDE mentions it. Moving the provider into the app target flips it to 8 immediately; the intents themselves stay `public` in the package and the provider imports them.

Check it directly with the metadata inspector in `app-intents-testing`:

```bash
python3 scripts/inspect_appintents_metadata.py --find MyProject
```

`audit_intents.py` also catches the placement statically (`shortcuts-provider-placement`).

## Extension targets stay thin

Each extension target holds only:

- the `@main` bundle declaration,
- `Info.plist` / entitlements,
- its `AppIntentsPackage` declaration,
- a dependency-registration shim.

Views, view models and intents live in packages so they stay previewable, reusable and testable.

A `ControlConfigurationIntent` that the app never references can stay in the widget extension — putting it in a package compiles it for watchOS and visionOS too. Types defined in an extension target are a separate module and are **not** importable from the app; if you need to share one, move it into a package [Apple: wwdc2025-244 22:34].

## Package graph

```
Domain/          # models, shared value types — no dependencies
Repository/      # protocol + SwiftData implementation
AppIntents/      # ★ intents + entities + queries + Service — the core
UI/              # main app views
WidgetUI/ WatchUI/ LiveActivity/   # leaf presentation packages, one per extension
```

Rules: single direction, `Domain` depends on nothing, the intents package is the only home for business logic, and platform-specific packages declare only their platform (`.watchOS(.v27)`) so a wrong import fails at compile time.

Independent `Package.swift` files with relative-path dependencies (`.package(path: "../Domain")`) let each package build and test on its own and need no `xcworkspace` — drag the folder into the Xcode project.

**Packages that own user-facing text need `defaultLocalization` and a String Catalog resource**, or their literals are extracted nowhere. Intent copy is a different case again — `app-intents-localization`.

## The watch-target metadata merge

If the project embeds a watchOS app, **the iOS app's metadata processor receives the watchOS slices as input**. Xcode generates that file list itself (`<App>.DependencyMetadataFileList`), so it is not something you configure.

The consequence only bites when the same **type name** appears in both slices: the later entry replaces the earlier one wholesale, and Xcode's path-ordered list puts `Debug-watchsimulator` last, so the watch version always wins. Full mechanism, measurements and the correct fix (distinct type names) are in `app-intents-entities-and-search` — it matters most for App Schema, which does not exist on watchOS at all.

## Tests must be in the scheme

A package test target that is not listed in the scheme's `TestAction` does not run under `xcodebuild test` or ⌘U, and **stops being compiled** — so it does not go red when the code it tests changes shape, it stops existing. For a local package, the `TestableReference` needs `ReferencedContainer = "container:Packages/<name>"` and a `BuildableName` that is the target name without `.xctest`.

Add every new test target to the scheme in the same change that creates it.

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

Same for preferences: `UserDefaults(suiteName:)`, never `.standard`. The App Group capability must be added to every target by hand in Xcode. **watchOS is a different device — App Groups do not reach it**; use CloudKit or Watch Connectivity.

Migration ownership matters here too: give the `SchemaMigrationPlan` only to the app's container (`app-intents-centric-design`).

## Keeping iOS-only extensions out of a Mac build

Add `platformFilter = ios;` to the relevant `PBXBuildFile` entries. If a tool or skill is available that edits the project file for you, prefer it — hand-editing `project.pbxproj` while Xcode has the project open can corrupt it.
