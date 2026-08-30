---
name: app-intents-localization
description: Translate the words an App Intent shows and speaks. Use when intent names, descriptions, parameter labels, Siri responses or entity titles stay in the original language after the rest of the app is translated, when strings never show up in the String Catalog to be translated at all, when Siri phrases need to work in another language, when views live in a Swift package and their text is not being extracted, when a translated sentence still has English words stitched into it, or when adding a language to a project that uses App Intents.
---

# Localizing App Intents copy

Two facts decide almost everything here, and both are counter-intuitive:

1. **Intent copy is resolved from the *main bundle* of whichever target links it** — and the compiler enforces this, so the package-bundle pattern that works for UI copy is unavailable.
2. **Almost none of it is extracted automatically.** Only `parameterSummary` lands in a String Catalog by itself. Everything else needs manual keys.

Together they produce a very specific failure: **the build is green, the source language looks perfect, and only the translated language shows English**. Nothing else catches it.

Assumes the rules in `app-intents-centric-design`.

## What is extracted, and what is not

| Copy | Auto-extracted? | Where it resolves |
|---|---|---|
| `parameterSummary` format strings | ✅ by `appshortcutstringsprocessor`, into **every linking target's** catalog | main bundle |
| App Shortcut phrases | ✅ into `AppShortcuts.xcstrings` (a String Set) | main bundle |
| `shortTitle` written in the app target | ✅ (ordinary Swift extraction) | main bundle |
| intent `title` | ❌ | main bundle |
| `IntentDescription`, `categoryName`, `searchKeywords` | ❌ | main bundle |
| `@Parameter(title:)` / `@Parameter(description:)` | ❌ | main bundle |
| entity / enum `DisplayRepresentation`, `typeDisplayRepresentation` | ❌ | main bundle |
| `IntentDialog` (built inside `perform()`) | ❌ — and invisible to the checker script too | main bundle |
| UI copy in a **view** package | ❌ unless the package has its own catalog | that package's bundle |

If the intents live in a package with no `defaultLocalization` and no resources, **string extraction never runs for that module at all** — no `.stringsdata` files are produced. Any intent `title` that happens to be translated in such a project is a coincidence: the identical string was also written as a `shortTitle` in the app target, where extraction does run.

## Why you cannot fix it with a package catalog

Adding `defaultLocalization` + a catalog to the intents package *does* make Xcode extract 200 keys, which looks like the answer. It is not: the translations land in `MyPkg_MyPkg.bundle/ja.lproj/Localizable.strings`, and `LocalizedStringResource("Complete Todos")` looks in `Bundle.main`. Specifying the bundle explicitly is a compile error:

```swift
// ❌ AppIntents requires 'LocalizedStringResource' to use the main bundle
public static var title: LocalizedStringResource {
    LocalizedStringResource("Complete Todos", bundle: .atURL(Bundle.module.bundleURL))
}
```

The metadata backs this up: it stores `{"key": "Add Todo"}` and records **no bundle and no table**. Main bundle is the only option, by construction.

So a catalog in the intents package is a *dead* catalog — translated and never read. Useful only as a temporary extraction tool (see below); remove it afterwards.

## The shape that works

1. **Put manual keys in each linking target's `Localizable.xcstrings`** (`extractionState: "manual"`). Every target that links the intents needs its own copy: the app, each extension, the watch app.
2. **Keep duplicated copy identical across those catalogs.** The same `parameterSummary` key appears in every linking target's catalog; fixing one leaves the phrasing varying by caller, with a green build.
3. **Check for gaps mechanically.** The compiler gives you nothing here:

   ```bash
   python3 scripts/check_intent_copy_localization.py
   ```

   It reads the keys out of the built metadata and diffs them against the catalogs, per target.
4. **Mark interpolation-only keys `shouldTranslate: false`.** `DisplayRepresentation(title: "\(title)")` produces the key `%@`, which is not translatable.
5. **Set `STRING_CATALOG_GENERATE_SYMBOLS = NO`** on those targets if you hit symbol-generation collisions — intent copy routinely puts `todo` and `Todo` in one catalog, and the generated symbols are usually unused anyway.
6. **UI copy in a view package needs the package's own catalog *and* an accessor** — different problem, same file: [package-ui-copy](references/package-ui-copy.md).

## Never assemble grammar in Swift

The subtlest breakage in this area, because it survives translation:

```swift
// ❌ the key becomes "You have no %@s." — the "s" and the noun stay English
let noun = "incomplete todo"
IntentDialog(full: "You have no \(noun)s.")

// ❌ same problem
let verb = count == 1 ? "is" : "are"

// ✅ let inflection do it
IntentDialog(full: "You have ^[\(pending) pending todo](inflect: true).")

// ✅ or localise the fragment itself, so it is a key
let noun = String(localized: count == 1 ? "todo" : "todos")
```

A translated `"You have no %@s."` reads as "*incomplete todo*はありません。" — grammatical in neither language. Plurality and inflection belong to the translation, not to the code.

Same rule for accessibility labels: `label += ", completed"` bakes in an English separator and word order. Localise the pieces and join with `parts.formatted(.list(type:width:))`.

## Siri phrases are variations, not translations

`AppShortcuts.xcstrings` is a **String Set**: one key per action, many spoken forms. Translating them one-to-one destroys the point.

```
Add a todo in ${applicationName}     →  ${applicationName}でやることを追加
How many todos do I have in ${...}   →  ${applicationName}のやることは何件
```

- **Every value must contain `${applicationName}`** (Apple's requirement; phrases without it are rejected).
- Keep `${todo}` / `${filter}` parameter placeholders.
- **Vary the vocabulary, not the endings.** The English set uses `Snooze` / `Delay` / `Star` / `Favorite` — genuinely different words, each adding a recognition path. Mechanically translated, they collapse into one word with different particles, which adds nothing.
- Compare variations only **within the same parameter shape**. A phrase with `${filter}` and one without are deliberately different, not duplicates.

Details and examples: [siri-phrases](references/siri-phrases.md).

## References

| File | Covers |
|---|---|
| [intent-copy](references/intent-copy.md) | where each kind of copy resolves, the manual-key workflow, the temporary-extraction trick for `IntentDialog`, catalog key ordering, sharing enum labels with the UI |
| [package-ui-copy](references/package-ui-copy.md) | why a view package needs both a catalog and an accessor, the `String`-typed-property trap, `LocalizedStringKey`-only interpolations |
| [siri-phrases](references/siri-phrases.md) | String Sets, `${applicationName}`, writing variations that add recognition paths |
| [verifying](references/verifying.md) | `-exportLocalizations`, the checker script, what unit counts do and do not mean, UI tests and host language |
