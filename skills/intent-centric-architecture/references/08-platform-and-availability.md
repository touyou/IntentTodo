# 08 — Platform and availability

One intent surface, five platforms. This is where the surface area for OS-specific failures lives.

## Availability matrix

Every row here was confirmed by building, not by reading. Re-check on SDK bumps — several of these moved between betas.

| API | iOS / iPadOS | macOS | watchOS | visionOS | Guard |
|---|---|---|---|---|---|
| `ControlWidget` & friends | ✅ | ✅ | ✅ | ❌ | `#if !os(visionOS)` |
| `TargetContentProvidingIntent` / `onAppIntentExecution` | ✅ | ❌ | ❌ | ✅ | `#if os(iOS) \|\| os(visionOS)` |
| `UISceneAppIntent` (`_AppIntents_UIKit`) | ✅ | ❌ (no framework) | ❌ (framework, no type) | ✅ | `#if canImport(_AppIntents_UIKit) && !os(watchOS)` |
| `@Property(indexingKey:)` | ✅ | ✅ | ❌ | ❌ | `#if os(iOS) \|\| os(macOS)` |
| assistant schemas (`.reminders.*`, `.system.*`) | ✅ (iOS 27+) | ✅ | ❌ | ✅ | `#if os(watchOS)` fallback or exclude |
| `VisualIntelligence` | ✅ device; ❌ **simulator** | ✅ | ❌ | ❌ (framework present on device SDK!) | `#if canImport(VisualIntelligence) && !os(visionOS)` |
| `CoreSpotlight` | ✅ | ✅ | ❌ | ✅ | `#if canImport(CoreSpotlight)` |
| `ActivityKit` / Live Activities | ✅ | ❌ | ❌ | ❌ | `#if os(iOS)` |
| `ControlCenter.reloadAllControls()` | ✅ | ✅ | ✅ | ❌ | `#if !os(visionOS)` |
| `Button(role:intent:)` | ✅ | ✅ | ❌ | ✅ | drop `role:` on watchOS |
| `Glass*ButtonStyle` (`.buttonStyle(.glass)`) | ✅ | ✅ | ✅ | ❌ | avoid on visionOS |

## `canImport` is an existence check, not an availability check

`#if canImport(X)` says the framework can be imported. It says nothing about whether the **API inside** is available on this platform. That gap produces the worst class of failure: simulator builds pass, device builds fail.

Two measured cases:

- **VisualIntelligence.** visionOS *simulator*: `canImport` false → code excluded → build succeeds. visionOS *device SDK*: `canImport` true → the `.visualIntelligence.*` schema compiles → `'visualIntelligence' is unavailable in visionOS`. Also absent from the **iOS simulator** SDK, which is why `IntentValueQuery` cannot be tested there at all ([09](09-verification.md)).
- **`_AppIntents_UIKit` on watchOS.** Framework present, `UISceneAppIntent` and `UIScene` absent → `Cannot find type 'UISceneAppIntent' in scope`.

Rules:

- Pair `canImport` with `os()` whenever the API's platform support is narrower than the framework's.
- **Never treat a simulator build as proof.** Xcode Cloud and archives build against the device SDK; `canImport` can differ.
- When a feature spans several files (intent + query + view), keep the guard **identical in all of them** — a mismatched guard leaves dangling references.
- Build **every** destination (iOS, My Mac, visionOS, watchOS) before believing a platform claim. `XcodeRefreshCodeIssuesInFile` runs in one context and sees none of this.

> Standing lesson: "platform-limited" is often a statement about the SDK *at the time it was written*. When an SDK updates, remove the guard and let the build tell you. That is how Visual Intelligence on macOS turned out to be possible after all.

## watchOS

- **Assistant schemas are unavailable** (`'reminders' is unavailable in watchOS`, `'system' is unavailable in watchOS`) [measured, still true in Xcode 27 beta 5]. A shared intents package compiles for watchOS too, so schema-annotated types must be split. **A macro-annotated declaration cannot be split with `#if`** between the attribute and the body (`Expected '}' in struct`) — you have to write the whole type twice:

```swift
#if os(watchOS)
public struct CategoryAppEntity: AppEntity, Hashable { /* plain version */ }
#else
@AppEntity(schema: .reminders.list)
public struct CategoryAppEntity: Hashable { /* schema version */ }
#endif
```

Intents that only make sense with a schema (an in-app search intent, say) can be excluded wholesale with `#if !os(watchOS)`. No functionality is lost: watchOS does not route those experiences.

- **CPU is the binding constraint.** Patterns that are cosmetic on iPhone are shipping requirements here: collapse two `filter` passes into one, hoist repeated `Date()` out of hot closures, move `sorted` out of `body` into `init`.
- `Button(intent:)` works; only the `role:` overload is missing.

## macOS

- Native macOS, not Catalyst, is what most of this assumes. The `openable` requirement for Visual Intelligence results is enforced **at compile time only on the macOS destination** — an iOS build never tells you an entity lacks an `OpenIntent` ([11](11-interaction-and-scale.md)).
- `@UIApplicationDelegateAdaptor` and `@NSApplicationDelegateAdaptor` depend on different protocols and cannot be unified. Keep one cross-platform delegate body (e.g. a `UNUserNotificationCenterDelegate` class, whose signature is identical on all platforms) and `#if` only the adaptor and the app-delegate shell.
- `@Environment(\.dismiss)` inside a `NavigationSplitView` **detail** pane is a no-op (also on iPad regular width). To clear the detail, write to your selection state in the navigation model.
- To keep iOS-only embedded extensions out of a Mac build, add `platformFilter = ios;` to the relevant `PBXBuildFile` entries.

## visionOS

- No Control Center [Apple: "Developing a WidgetKit strategy" support table]. `#if !os(visionOS)`; `if #available` cannot stop type resolution.
- `glassBackgroundEffect()` is the native spatial material (visionOS 1.0+) and is distinct from iOS 26's `glassEffect(_:in:)`. Prefer `hoverEffect(.highlight)` / `.lift` for interactivity over interactive glass.
- `.buttonStyle(.glass)` / `.glassProminent` are not available; use `.bordered` / `.borderedProminent` plus hover effects.

## Liquid Glass: where *not* to use it

Apple's HIG is clearer about restraint than about adoption, and standard SwiftUI navigation chrome on iOS 26+ is already glass-rendered without opting in.

| Layer | Liquid Glass | Examples |
|---|---|---|
| Navigation / system chrome | ✅ automatic | toolbar, nav bar, sidebar, tab bar |
| Floating / ornament | ✅ explicit | visionOS ornament, floating action button |
| Content surface | ❌ don't | badges, chips, cards, list rows |

Reviewer skills tend to suggest `.glassEffect` wherever a translucent chip exists. Resist: glass on content dilutes the navigational signal it is supposed to carry. If you inherit a codebase that glassed every section, the right refactor is usually to **remove** it from content and keep it on the main surface and floating chrome — not to consolidate everything into one `GlassEffectContainer`.

Rule of thumb: if the person *reads* it, don't glass it. If they *navigate* with it or it floats above content, glass is fair game.

## Conditional compilation style

| Condition | Use for |
|---|---|
| `#if os(iOS) \|\| os(visionOS)` | UIKit-dependent code, `.topBarTrailing`, scene delegates |
| `#if os(macOS)` | AppKit-dependent code |
| `#if os(iOS)` | ActivityKit / Live Activities |
| `#if !os(visionOS)` | controls |
| `#if os(watchOS)` | complication-specific views, schema fallbacks |

Branch at the boundary where the shape genuinely differs. One public type whose internals branch beats `iOSFooView` / `macOSFooView` / `VisionOSFooView` parallel types, which drift apart in padding and colour and bite later.
