# Rung 0 — the built metadata

App Intents are not the Swift types you wrote — they are the `Metadata.appintents` bundle the build produced. Reading it directly catches things nothing else reports.

```bash
python3 scripts/inspect_appintents_metadata.py --find MyProject -v
python3 scripts/inspect_appintents_metadata.py path/to/MyApp.app -v

# or, by hand:
python3 -c "import json;d=json.load(open('<…>/MyApp.app/Metadata.appintents/extract.actionsdata'));\
print({k:len(v) for k,v in d.items() if isinstance(v,(list,dict))})"
```

## What each anomaly means

| Reading | Means |
|---|---|
| `autoShortcuts: 0` while the package's own bundle shows 8 | the `AppShortcutsProvider` is in a package. It must be in the app target (`app-intents-execution-and-processes`) |
| an entity with `0 props` | nothing about it is visible to Shortcuts filters, Siri or Spotlight — the members are plain `var`s, not `@Property` |
| no `assistantDefinedSchemas` entry on a type annotated `@AppEntity(schema:)` | the schema conformance did not land, even though `displayTypeName` shows the macro ran |
| **two** types claiming the same schema | a platform fallback shares a type name with the schema version — the watch slice will overwrite the iOS one. A summary "all clear" does **not** catch this (`app-intents-entities-and-search`) |
| an entity's property count dropped after adding a platform | same collision — the later slice replaced the entry wholesale |
| `actionSummary.wrapper.otherParameterIdentifiers` shorter than the `@Parameter` list | those parameters are not editable in Shortcuts (`app-intents-parameters-and-prompts`) |
| an action present in the package bundle but missing from the app bundle | target membership or an `includedPackages` problem |
| a value type printed as a dotted system entity name (`GeoToolbox.PlaceDescriptorEntity`) | fine on an entity `@Property`; on an App-Shortcut-registered intent's `@Parameter` it breaks SSU training |
| `com.apple.appintents.entity.Syncable` next to an entity | `SyncableEntity` landed |

None of these break the build, produce a warning, or show up in `XcodeRefreshCodeIssuesInFile`.

## Where the files are

| Path | Contents |
|---|---|
| `MyApp.app/Metadata.appintents/extract.actionsdata` | the unified metadata the system reads |
| `MyApp.app/Metadata.appintents/root.ssu.yaml` | Siri understanding source, including the parameter `variables` |
| `MyApp.app/Metadata.appintents/nlu/` | voice-understanding assets — **single-locale apps only** |
| `MyApp.app/<locale>.lproj/nlu.appintents/` | the same assets in a **localised** app |
| `<Pkg>.appintents/Metadata.appintents/extract.actionsdata` | one per package / target, before aggregation |

The `nlu` split matters: looking only inside `Metadata.appintents` in a localised app makes it look as though the assets were never generated. Success in the build log reads `Archiving all locales` → `archived N locales`.

## Judge SSU questions only on a clean build

`AppIntentsSSUTraining` does not re-run when `Metadata.appintents` is unchanged, and the incremental log **replays the previous output**. Use a throwaway derived-data path so you do not disturb the shared one:

```bash
xcodebuild -project MyApp.xcodeproj -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' \
  -derivedDataPath /tmp/CleanDD CODE_SIGNING_ALLOWED=NO build
```

Then check for `must match regular expression`, `Could not archive SSU` and `emitted errors` — the tool exits 0 either way, so `BUILD SUCCEEDED` proves nothing here.

## Comparing before and after

The metadata is the right place to verify most structural changes, because the diff is mechanical: property counts per entity, schema claims per type, parameter identifiers per action. When a change is supposed to alter one of those and does not, that is the finding.

If you need to isolate the merge behaviour itself, `appintentsmetadataprocessor` can be invoked directly with the real build's arguments and only the input list changed — that is how the input-order rule was established (`app-intents-entities-and-search`).
