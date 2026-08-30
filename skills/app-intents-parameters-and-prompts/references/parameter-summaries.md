# Parameter summaries and parameter types

## The allowlist rule

`parameterSummary` decides **which parameters the Shortcuts editor shows at all**.

> "`ParameterSummary` is not cosmetic — it is the allowlist for which parameters the Shortcuts editor surfaces. […] every other `@Parameter` is **silently omitted** from the editor UI, even though it still exists and still resolves." [Apple: App Intents guidance]

Two ways in:

```swift
public static var parameterSummary: some ParameterSummary {
    Summary("Add todo titled \(\.$title)") {   // 1. interpolated → part of the sentence
        \.$dueDate                              // 2. trailing block → separate editable rows
        \.$isFavorite
        \.$estimatedDuration
        \.$assignee
        \.$location
        \.$tags
        \.$urls
    }
}
```

Anything in neither place is invisible in the editor.

### Why it hides

| | |
|---|---|
| Build | green |
| `XcodeRefreshCodeIssuesInFile` | clean |
| Siri, when the value is named out loud | works |
| AppIntentsTesting `makeIntent(param:)` | works — it bypasses the editor |
| Shortcuts app | the row is not there |

Only the last one, or the metadata, tells you.

### Verify against the built metadata

```bash
python3 ../app-intents-testing/scripts/inspect_appintents_metadata.py --find MyProject -v
```

Look at `actionConfiguration.actionSummary.wrapper`:

```json
"otherParameterIdentifiers": [
  "todoDescription", "dueDate", "isFavorite", "estimatedDuration", "assignee",
  "location", "tags", "urls", "recurrenceFrequency", "recurrenceInterval",
  "locationTriggerEvent"
]
```

That is the trailing block, verbatim. Diff it against the intent's `@Parameter` list; anything missing from both this array and the summary sentence is unreachable. Mechanical, and no device needed.

### Ordering and conditionals

- Rows appear in **summary order**: interpolated parameters (in sentence order), then the trailing block in the order written. Declaration order in the type is irrelevant.
- `When(\.$mode, .equalTo, .recurring) { \.$interval } otherwise: { }` shows a row only in the relevant state.
- `Switch(\.$kind) { Case(.event) { … } Case(.reminder) { … } }` for more than two.
- A `@UnionValue` parameter can drive `When` / `Switch` too.

### Design consequences

- **Merging intents by parameter only pays off if the parameter is editable.** `ShowTodosIntent(filter:)` replacing four intents is a win in Shortcuts *only* once `\.$filter` is in the summary; before that, Shortcuts users can reach the default and nothing else.
- **Adding a `@Parameter` is not adding a write path.** If the intent is meant to be how people set an attribute, the summary edit and, usually, a UI field are part of the same change.
- Keep the sentence short. Everything that does not read naturally in a sentence belongs in the trailing block, not crammed into the prose.

## Parameter types

| Need | Use | Note |
|---|---|---|
| Closed set of options | `AppEnum` | fixed picker; embeddable in a Siri phrase |
| Reference to an app object | `AppEntity` | embeddable in a phrase; re-resolved by id before `perform()` |
| Many objects | `EntityCollection<T>` | skips per-id resolution (`app-intents-entities-and-search`) |
| Free text | `String` | **not** embeddable in a phrase [Apple: wwdc2022-10170 14:40–15:15] |
| Either of two entity types | `@UnionValue` enum | usable in `@Parameter`, `ReturnsValue`, `When` / `Switch` |
| A tri-state update | any type, read via `$param.valueState` | [asking-and-updating](asking-and-updating.md) |

A **non-optional `AppEnum`** auto-disambiguates — the system asks the person to pick instead of failing. Prefer that over an optional with a silent default.

**`AppEnum` raw values are persisted by string** in every shortcut someone has built. Cases can be added; renaming or reordering silently breaks their automations [Apple]. Every case also needs a `caseDisplayRepresentations` entry — a missing one is a runtime `fatalError`, not a compile error [Apple].

If the same enum is a stored model value as well, the raw string is a contract twice over. Say so in a comment where it is declared.

### Types Siri and Shortcuts cannot pass

Some values are natural on the *entity* side but cannot be a parameter at all — `Calendar.RecurrenceRule` is the clear example (it is also not a storable SwiftData attribute). Express the write side as primitives the system can pass (an `AppEnum` frequency plus an `Int` interval) and reassemble the rich value on the read side. Two parameters that people can actually set beat one they cannot.

## ⚠️ System value types as `@Parameter`

`GeoToolbox.PlaceDescriptor`, `LinkPresentation.LinkMetadata`, `MediaIntents.AudioSearch` and `Photos.PHAsset` are documented as supported parameter types, but using one on an intent that is **registered in an `AppShortcutsProvider`** makes `AppIntentsSSUTraining` fail:

```
GeoToolbox.PlaceDescriptorEntity must match regular expression ^[a-zA-Z_][a-zA-Z_$0-9]*$
```

and the target's `nlu` assets are **not generated at all** — every App Shortcut in that target loses its voice-understanding data. The tool exits 0, so the build succeeds locally.

The generator writes the parameter's **type name** into `root.ssu.yaml` as a variable name, and the validator's regular expression rejects the dot. Generator and validator disagree, so there is no app-side fix other than avoiding the type there.

```yaml
variables:
- name: GeoToolbox.PlaceDescriptorEntity     # the dot is what fails
  type: ssu/parameter
```

### Exact scope [measured 2026-08-28 / 2026-08-29, Xcode 26.6 and 27 beta 6]

| Shape | Result |
|---|---|
| `@Parameter` of an App-Shortcut-registered intent | ❌ |
| same intent, not registered as an App Shortcut | ✅ |
| entity `@Property var place: PlaceDescriptor` | ✅ — entity properties never become SSU variables |
| `@AppIntent(schema:)` / `@AppEntity(schema:)` derived members | ✅ |
| `Transferable` → `ValueRepresentation(exporting:) -> PlaceDescriptor` | ✅ |
| `[URL]`, `[String]` parameters | ✅ — `URL` is a metadata primitive, no dotted type name |

So the condition is not "array or not" and not "system type or not": it is **a dotted type name reaching the SSU variable list**, which only `@Parameter` does.

The workaround, therefore, is minimal: keep the `@Parameter` as a `String` (plus latitude/longitude if relevant) and build the real value inside `perform()`. Everything else keeps the native type — restoring an entity `@Property` to `PlaceDescriptor?` also fixed a real bug, because the previous `String` round-trip was dropping the coordinates.

Reproduces in Apple's own `UnicornChat` sample with a 13-line addition, so it is not a project-configuration problem. **FB24548956**.

### Measuring it

- **Always a clean build.** `AppIntentsSSUTraining` does not re-run when `Metadata.appintents` is unchanged, and the incremental log replays the previous output. Use a throwaway `-derivedDataPath`.
- **Success looks like** `Archiving all locales` → `archived N locales` in the log, plus files on disk.
- **In a localised app the assets are at `<locale>.lproj/nlu.appintents/`**, not `Metadata.appintents/nlu/`. A single-locale reproduction project puts them in the latter, which makes it easy to look in the wrong place and declare failure.
