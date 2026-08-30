# UI copy in a Swift package

A different problem from intent copy, in the same project. Views in a package hit **two independent traps**, and both look fine while the app has only one language.

## Trap 1: no catalog in the package → the strings are extracted nowhere

Extraction is **per target**, and only targets with a catalog produce output. Before the package has one, `xcodebuild -exportLocalizations` shows **zero** of its literals — not in the package's xcloc, and not in the app's either.

Two things are needed:

```swift
// Package.swift
let package = Package(
    name: "UI",
    defaultLocalization: "en",   // without this the catalog is not a localisation resource
    …
    targets: [
        .target(
            name: "UI",
            resources: [.process("Resources")]   // Sources/UI/Resources/Localizable.xcstrings
        )
    ]
)
```

`LocalizedStringResource` from `AppIntents` is the exception that hides this: intent copy shows up in the *app's* catalog via the metadata path, which makes it look as though package strings are being extracted too.

## Trap 2: `Text("…")` reads `Bundle.main` at runtime

`LocalizedStringKey`'s default bundle is the main bundle, so it **never** finds the catalog shipped inside `UI_UI.bundle`. Translations go in and are not read.

Give each such package one accessor and route all UI copy through it:

```swift
extension LocalizedStringResource {
    static func copy(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

Text(.copy("Cancel"))
Label(.copy("Completed"), systemImage: "checkmark.circle.fill")
Section(.copy("Due Date")) { … }
```

SwiftUI has `LocalizedStringResource` overloads for `Text` / `Label` / `Button` / `Toggle` / `Section` / `Picker` / `TextField` / `LabeledContent` / `ContentUnavailableView` / `DatePicker` / `navigationTitle` / `accessibilityLabel` / `confirmationDialog` / `alert` / `searchable(prompt:)`, so nothing has to be rewritten into ViewBuilder form.

Keep the declaration **internal**, not `public`: if one such package imports another, two `public static func copy` members become ambiguous at the call site.

A lint rule that flags bare `Text("…")` in these packages is worth having — this is exactly the kind of omission that reads fine forever in the source language.

## The exception: `LocalizedStringKey`-only interpolations

`\(date, style: .relative)`, `\(timerInterval:)` and `\(Image)` exist only on `LocalizedStringKey`; `String.LocalizationValue` (what `.copy` takes) cannot express them. For those, name the bundle directly — same destination:

```swift
Text("Due \(date, style: .relative)", bundle: .module)
```

A number on its own does not go through either path: `Text("\(count)")` produces the untranslatable key `"%lld"`. Use `Text(count, format: .number)`.

## Trap 3: carrying UI copy in a `String`

`Text` and `Label` pick the **verbatim** initialiser for a `String`. It compiles, it displays correctly, and the literal is never extracted.

```swift
// ❌ the caller's literal is not extracted
StatusBadge(title: "Completed", …)          // private let title: String

// ✅
StatusBadge(title: .copy("Completed"), …)   // private let title: LocalizedStringResource
```

So: any property, parameter or `displayName` that carries **copy** should be typed `LocalizedStringResource`. Verbatim display of **data** (`todo.title`) is not affected — that is what verbatim is for.

Concatenating for accessibility (`label += ", completed"`) is the same mistake in another shape: the separator and the word order are locale-dependent. Localise each piece and join with `parts.formatted(.list(type:width:))`.

## Where the files end up

```
MyApp.app/UI_UI.bundle/ja.lproj/Localizable.strings
MyApp.app/PlugIns/MyWidget.appex/WidgetUI_WidgetUI.bundle/ja.lproj/…
```

A language with no translations at all produces **no `.strings` file** — which is why a source-language-only project has an apparently empty `UI_UI.bundle` and looks broken when you first go looking.
