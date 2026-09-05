# Verifying sources against the target SDK

Use this when updating beta-era guidance or when documentation, a sample and the compiler disagree. Pin the Xcode build before deciding which API spelling or platform guard to use.

## Identify the evidence

| Source | Establishes | Does not establish |
|---|---|---|
| Xcode `Contents/version.plist` | Xcode version and `ProductBuildVersion` | the SDK used by an existing build artifact |
| `AdditionalDocumentation/*.md` | an overview and adoption examples | complete protocol conformances or current availability for every destination |
| Destination SDK `.swiftinterface` | public members, requirements and availability | runtime process selection, UI presentation or metadata extraction success |
| WWDC transcript | the explained behaviour and design intent | that an announced spelling shipped unchanged in a particular beta |
| Build + extracted metadata | compilation and the contract delivered to the system | Siri routing or the result shown by every caller |
| A runtime probe | behaviour in that OS, caller and configuration | other platforms, callers or SDK versions |

Record source checks as `[Apple SDK: Xcode …, symbol]`; reserve `[measured]` for execution. A previously recorded measurement remains dated to that run. Reading the same SDK today does not renew it.

## Locate local documentation

Start with the Xcode installation used by the project. Do not assume `/Applications/Xcode.app` or the global `xcode-select` selection points to the requested beta, and do not change the global selection just to read documentation.

Typical paths relative to the selected Xcode bundle:

- `Contents/version.plist`
- `Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/`
- `Contents/Developer/Platforms/<platform>.platform/Developer/SDKs/<sdk>/System/Library/Frameworks/<framework>.framework/Modules/`
- macOS frameworks may place modules under `Versions/A/Modules/`; `AppIntentsTesting` is under the platform's `Developer/Library/Frameworks/`.

Find the relevant `.swiftinterface` with `rg --files`, select the destination and architecture, then search the declaration **and its extensions**. Read surrounding `@available` attributes, including explicit `unavailable`; finding a type name anywhere in the file is not enough. Search framework overlays when an extension method is missing. Distinguish public API from underscored or documentation-hidden support symbols.

For copied reference files, compare with the bundled original. An identical file is one source, not independent corroboration. Keep downloaded samples outside Xcode synchronized project folders.

## Resolve an example mismatch

The beta 6 (27A5252f) bundled `AppIntents-Updates.md` is useful for discovery, but its abbreviated examples need declaration checks:

- `SnippetIntent` requires a `perform()` result conforming to `ShowsSnippetView`; a `snippet` property alone is insufficient. See [snippet guidance](../../app-intents-ui-and-feedback/references/snippets.md).
- `IndexedEntity` uses `attributeSet`; a helper named `searchableAttributes` is not the protocol witness unless connected explicitly. See [Spotlight guidance](../../app-intents-entities-and-search/references/spotlight.md).

Preserve the source as reference material; put corrected implementation guidance in the owning skill. When prose and declarations leave runtime semantics unclear, retain the uncertainty instead of deriving a guarantee from the API name.

## Close the loop

Update all active descriptions of the changed constraint, including code fences and platform tables. Keep history in the project's devlog and unresolved work in its issue tracker. Validate skill frontmatter and local links. If code or platform guards change, build the affected destinations and inspect their generated metadata. For documentation-only changes, report declaration checks separately from builds and runtime tests; do not claim the latter ran.
