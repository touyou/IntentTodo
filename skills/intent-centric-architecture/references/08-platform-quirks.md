# 08 — Platform quirks (visionOS, Liquid Glass, watchOS)

When the same Intent + Entity surface lights up on five platforms, the surface area for OS-specific quirks balloons. This reference collects the recurring ones — knowing them ahead of time saves a build cycle.

## visionOS

### `GlassButtonStyle` / `GlassProminentButtonStyle` — not available on visionOS

`buttonStyle(.glass)` and `buttonStyle(.glassProminent)` are part of the iOS 26+ Liquid Glass API but visionOS does **not** ship these styles. Using them in code that compiles for visionOS will fail. visionOS-aware UI typically falls back to:

- `.buttonStyle(.bordered)` / `.buttonStyle(.borderedProminent)` for the button shell, plus
- `.contentShape(.hoverEffect, .capsule)` + `.hoverEffect(.highlight)` for spatial interactivity

Apple's `Glass*ButtonStyle` documentation does not list visionOS in the Availability section (verified 2026-04). Re-check before assuming any new release adds support.

### `glassBackgroundEffect()` is the visionOS-native API

visionOS has its own `glassBackgroundEffect()` modifier (visionOS 1.0+) that pre-dates iOS 26's `glassEffect(_:in:)`. They are distinct APIs:

- `glassBackgroundEffect()` — visionOS-only, applies the system spatial glass material.
- `glassEffect(_:in:)` — iOS / iPadOS / macOS / watchOS / tvOS 26+, also visionOS 26+, the new Liquid Glass primitive.
- `GlassEffectContainer` — iOS / iPadOS / macOS / watchOS / tvOS 26+, also visionOS 26+. Not yet documented as composing well with `glassBackgroundEffect()` — keep them in separate subtrees if you need both.

### Spatial hover effects, not interactive glass

For interactive surfaces in visionOS, prefer the spatial idiom (`hoverEffect(.highlight)` / `.lift`) over `glassEffect(.regular.interactive())`. The hover effect is the platform-native interactivity signal in spatial computing.

## Liquid Glass philosophy — where to apply, where to refuse

Apple's Liquid Glass HIG (WWDC25) is clearer on **where not to use it** than on where to use it. Standard SwiftUI navigation chrome on iOS 26+ is already glass-rendered automatically — you do not opt into it.

| Layer | Liquid Glass | Examples |
|---|---|---|
| Navigation / system chrome | ✅ Automatic | toolbar, navigation bar, sidebar, tab bar |
| Floating / ornament | ✅ Explicit | visionOS ornament, floating action button, hovering controls |
| Content surface | ❌ Don't | badges, chips, cards, list rows, info sections |

Skill-based reviewers (including the `swiftui-liquid-glass` skill) tend to suggest "you should add `.glassEffect` here too" wherever a `.background(color.opacity(...))` chip exists. **Resist.** Adding glass to content chips creates visual noise and dilutes the navigational signal that real Liquid Glass surfaces carry. If the surrounding navigation chrome is already glass and the standard SwiftUI controls are flowing through it, the user is already getting the Liquid Glass experience without you decorating individual content elements.

Rule of thumb: if the element is *something the user reads*, do not glass it. If it is *something the user navigates with* or *something floating above content*, glass is fair game.

### Reducing existing glass usage is also a refactor

When inheriting a codebase that uses `glassBackgroundEffect()` on every section of a Detail view, the right refactor is usually to **remove the effect from content sections and keep it on the main surface (Header) and floating chrome (Ornament)**, not to migrate them all into a single `GlassEffectContainer`. The skill review may suggest "consolidate", but the real fix is "trim".

## watchOS

### CPU is the binding constraint

watchOS hardware has materially weaker CPU than iPhone. Patterns that are merely "nice to clean up" on iOS are "shipping requirements" on watchOS:

- Two `filter` calls on the same array → switch to a single-pass partition (loop with two `append` arrays).
- Repeated `Date()` instantiation in a hot computation → hoist to a single `let now = Date()` at the start of the closure.
- `body`-level `sorted` → move into `init` so the sort runs once per view instance, not per render.

Mentally tag these patterns "must-fix on watchOS" rather than "would-be-nice", and audit them when designing watchOS variants from existing iOS code.

### Liquid Glass is unavailable in the typical sense on watchOS

Even though watchOS 26+ technically has the `glassEffect` API, the watchOS UX idiom does not call for it. The standard watchOS view chrome already provides the platform-native material. Apply `.glassEffect` only when explicitly mimicking iOS Liquid Glass for a cross-platform consistency reason.

## macOS

### NavigationSplitView detail pane and `@Environment(\.dismiss)`

`@Environment(\.dismiss)` from inside a `NavigationSplitView` *detail* pane does not pop the detail back to "no selection" — it is silently a no-op on macOS / iPad regular width. To clear the detail pane programmatically, write to your `NavigationModel`'s `selectedTodo` (or equivalent selection binding), not `dismiss()`.

This is most often hit when a Detail view detects "underlying object was deleted" and tries to dismiss itself. Write the selection clear into the navigation model instead — it works on both compact (iPhone, where `NavigationSplitView` collapses to `NavigationStack`) and regular widths.

## Multi-platform conditional compilation

Use `#if os(...)` only at the boundary where the shape genuinely differs. Inside SPM packages, declare a single public type whose internals branch on platform; do not duplicate whole types per platform.

```swift
// ✅ Single type, branch where it matters.
public struct StatusBadge: View {
    public enum Size { case compact, prominent }
    public var body: some View {
        Label(title, systemImage: systemImage)
            .font(size == .compact ? .caption : .subheadline)
            // … padding etc.
    }
}
```

Avoid having `iOSStatusBadge`, `macOSStatusBadge`, `VisionOSStatusBadge` parallel types — that pattern produces drift (different default colors, different padding) that bites later.
