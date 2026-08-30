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

1. Every bundle's `Metadata.appintents` counts are **identical** with and without the declarations — no duplication, even on a clean build with DerivedData deleted (`actions` 23 = 23 distinct intent types).
2. The full AppIntentsTesting suite is green with them declared — the same infrastructure Siri, Shortcuts and Spotlight use.
3. The Shortcuts app was checked on device: the action list and parameter display are intact.

**Still unverified: App Shortcut *phrase* routing through Siri.** AppIntentsTesting looks intents up by type name, so it structurally cannot exercise the phrase path; that check is manual by design (`app-intents-testing`). If it ever breaks, deleting the per-target files is the fallback.

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
