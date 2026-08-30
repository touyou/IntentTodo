# Intent copy: extraction and resolution

Extraction and resolution are **two separate questions**, and getting them confused is what makes this area hard.

## Resolution: the linking target's main bundle, enforced

`Metadata.appintents/extract.actionsdata` stores each string as `{"alternatives": [], "key": "Add Todo"}` — **no bundle, no table**. The system looks the key up in the main bundle of whichever target is running.

The compiler enforces the same thing:

```swift
// ❌ AppIntents requires 'LocalizedStringResource' to use the main bundle
public static var title: LocalizedStringResource {
    LocalizedStringResource("Complete Todos", bundle: .atURL(Bundle.module.bundleURL))
}
```

So intent copy goes in the app's / extension's / watch app's own `Localizable.xcstrings`. There is no way to serve it from the package that declares the intents.

Where the built app actually keeps it:

```
MyApp.app/ja.lproj/Localizable.strings                   intent copy (manual keys + parameterSummary)
MyApp.app/ja.lproj/AppShortcuts.strings                  Siri phrases (String Set)
MyApp.app/ja.lproj/nlu.appintents                        ja voice-understanding data
MyApp.app/ja.lproj/InfoPlist.strings                     CFBundleDisplayName etc.
MyApp.app/UI_UI.bundle/ja.lproj/…                        view-package UI copy
MyApp.app/PlugIns/*.appex/ja.lproj/…                     each extension's own intent copy
MyApp.app/Watch/MyWatchApp.app/ja.lproj/…                the watch app's
```

## Extraction: only `parameterSummary`, and only because of AppShortcuts

If the intents package has no `defaultLocalization` and no resources, **string extraction does not run for that module** — no `.stringsdata` files at all. The intent-related keys that do reach a catalog come from exactly two places:

| Source | Contents |
|---|---|
| `appshortcutstringsprocessor` | every intent's `parameterSummary` format strings, plus the `AppShortcuts` table |
| ordinary Swift extraction in the app target | anything literally written there, e.g. `shortTitle` in `AppShortcutsProvider` |

Everything else — `title`, `IntentDescription`, `categoryName`, `searchKeywords`, `@Parameter(title:/description:)`, entity and enum `DisplayRepresentation`, `IntentDialog` — is in **neither**.

A measured example of the gap, on a project that already looked fully localised:

| Kind | In the catalog | Missing |
|---|---|---|
| intent `title` | 7 | 16 |
| `IntentDescription` | 0 | 20 |
| `@Parameter(title:)` | 0 | 19 |
| `@Parameter(description:)` | 0 | 17 |
| `parameterSummary` | 14 | 0 |
| `categoryName` / `searchKeywords` | 0 | 27 |
| entity / enum `DisplayRepresentation` | 1 | 27 |

The seven present `title`s were a coincidence: the same strings had also been written as `shortTitle` in the app target.

**`parameterSummary` is duplicated into every linking target's catalog** with the same key. That means the same 14 keys appear in 7 catalogs — and fixing the phrasing in one of them leaves the wording varying by which target ran the intent, with nothing failing.

## The workflow

1. Add the keys to each linking target's `Localizable.xcstrings` with `extractionState: "manual"`.
2. Mark pure-interpolation keys (`%@`, from `DisplayRepresentation(title: "\(title)")`) `shouldTranslate: false`.
3. Run the checker after any intent-copy change:

   ```bash
   python3 scripts/check_intent_copy_localization.py
   ```

   It reads the keys the system will look up out of the built metadata and diffs them against every catalog that needs them.
4. If symbol generation collides — intent copy commonly puts `todo` and `Todo`, or `category` and `Category`, in one catalog — set `STRING_CATALOG_GENERATE_SYMBOLS = NO` on those targets. The generated symbols are usually referenced nowhere.
5. **Fill in every catalog.** Do not fix one and move on.

### `IntentDialog` needs a different inventory method

Dialogs are built inside `perform()`, so they never appear in the metadata and the checker cannot see them. To take stock:

1. Temporarily add `defaultLocalization: "en"` + `resources: [.process("Resources")]` + an empty `Localizable.xcstrings` to the intents package.
2. Build. Xcode extracts everything, including the runtime dialog strings.
3. Read the key list; add the ones you need as manual keys in the real targets.
4. **Remove the package catalog again** — left in place it is translated and never read, which is worse than absent.

## Sharing enum labels with your own UI

`AppEnum` inherits `CaseDisplayRepresentable`, which supplies `localizedStringResource` by default:

```swift
public protocol CaseDisplayRepresentable: CustomLocalizedStringResourceConvertible, CaseIterable, Hashable {
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { get }
}
extension CaseDisplayRepresentable {
    public var localizedStringResource: LocalizedStringResource { get }
}
```

So `Text(option.localizedStringResource)` renders the `caseDisplayRepresentations` string — resolved from the app target's main bundle, i.e. **the manual key you already added**. Keeping a second copy of those words in a UI package's catalog is how Siri and the app end up saying different things.

(`CaseIterable` is transitively required too, so `allCases` works without adding the conformance.)

## Catalog key ordering

Xcode writes keys in `String.localizedStandardCompare` order — case-insensitive, lowercase first on ties — **not** codepoint order:

```
Xcode:  ["Delete", "Delete “%@”?", "Delete ${entities}", …]
sorted: ["Delete", "Delete ${entities}", "Delete “%@”?", …]     # $ (0x24) < “ (0x201C)
```

Python cannot reproduce ICU collation, so if you need to sort, pass the key list through Swift.

But catalogs written by a *script* are usually in codepoint order already, so a project can have both conventions in different files. **Match each file's existing order**; the check is that the diff contains no deleted lines (`git diff --numstat`, second column 0). Format as `json.dumps(..., indent=2, separators=(",", " : "))` with no trailing newline to match Xcode byte-for-byte.

## Adding a language

Adding to `knownRegions` and attaching catalogs to targets both modify `project.pbxproj`. **Do not hand-edit it** — Xcode can crash if the file changes underneath an open project, and a `git checkout` of it counts as a hand edit too. Use a tool that owns the project file (in Xcode, the localisation planner via `xcode-integration:translation-coordinator`).

Note also that **an extension's catalog may not live in its own folder.** Xcode's planner sometimes attaches one catalog to several targets via `membershipExceptions`, so a widget's strings can live in the watch app's file. Follow the target membership, not the directory name.
