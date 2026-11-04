# Siri Metadata Analyzer (rung 0.5)

`sirimetadataanalyzer` reads an app's **built** App Intents metadata and reports how well Siri's model can use its tools. It ships in the Xcode 27.3 toolchain (not in 27.2), needs no device and no simulator run, and takes seconds. Measured with Xcode 27.3 beta (27C5020n); the JSON reports `rulesetVersion: "2027.0-draft"`, so expect rules to move.

## Running it

```bash
xcrun sirimetadataanalyzer path/to/MyApp.app --format json        # act on this
xcrun sirimetadataanalyzer path/to/MyApp.app --language en         # development language
xcrun sirimetadataanalyzer path/to/MyApp.app --language ja         # each shipping language
xcrun sirimetadataanalyzer path/to/MyApp.app --config analyzer.json
```

- It also accepts an extension's `Metadata.appintents` directly (widget, Live Activity, watch app).
- Exit status: `0` no error-level findings, `2` some, `1` the analysis could not run.
- **Build first, cleanly.** It reads build output; after a failed build it reads the previous one.
- The product name is the `.app` name, not the scheme name. Look it up with `xcodebuild -showBuildSettings` (`FULL_PRODUCT_NAME`).

## What a clean run does and does not mean [measured]

- **It analyses tools only.** An app with 34 intents and no `ToolIntent` got exactly one finding, `SMA109 No tools` (info), and an empty toolbox in the JSON. Description, property and schema-overlap rules had nothing to look at. Add the tools first, then measure.
- **Localised runs skip rules.** With `--language ja`: "English-only checks skipped: SMA105, SMA204, SMA205, SMA603; limited: SMA206, SMA605". Run the development language as well as the translations.
- It does not see overlapping jobs between your own tools, vague skill descriptions, or Swift type names in a skill body [Apple: Xcode 27.3 beta, `siri-app-integration` skill].
- A clean run proves the metadata's shape, not that Siri picks the right tool. That is rung 4 (SiriEvaluations).

## Findings seen on a real app

| Rule | Meaning | What to do |
|---|---|---|
| `SMA109` | no intent is a tool | adopt `ToolIntent` on the actions people would ask Siri for |
| `SMA202` | a tool parameter has no description | add one that says what the value means and its format. Leave it out only when the title says everything |
| `SMA203` | an entity property has no description | `@Property(description:)`, **27.3 only**: on an entity that also ships to earlier releases it does not build until the deployment target is 27.3 |
| `SMA206` | "placeholder text" in a description | see below |
| `SMA701` | a tool closely matches a system schema | adopt the schema if it does the same job; otherwise make title and description say how it differs |

### `SMA206` and app nouns

The placeholder rule matches individual words against a list that includes `todo` (also `foo`, `test`, `tmp`, `item 1`, …). In a to-do app every "the todo to toggle" is flagged, while the plural "todos" is not. When the word is the app's own noun, keep the copy (rewording the source text re-keys every catalog entry) and record the decision in a config file:

```json
{
  "suppressions": [
    { "rule": "SMA206", "subject": "ToggleTodoCompletionIntent.todo",
      "reason": "'todo' is the app's noun for an item, not placeholder text." }
  ]
}
```

`subject` is the finding's subject as printed (`IntentType` or `IntentType.parameter`). The other top-level keys (`disabledRules`, `severityOverrides`, `thresholds`) are optional. Suppressed findings are listed separately in the output with their reason, so the decision stays visible. Suppress only what you have decided to keep; do not use it to hide a finding you have not read.
