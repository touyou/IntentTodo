# Siri phrases

`AppShortcuts.xcstrings` is a **String Set**: one key per action, and the value is a *list* of things people might say. It is the one file in this area that is not a translation task.

## Requirements

- **Every value must contain `${applicationName}`.** Apple requires it, and phrases without it are rejected — silently, from the person's point of view.
- Keep parameter placeholders (`${todo}`, `${filter}`) intact.
- Word order changes freely between languages; the placeholder does not have to stay where it was.

```
Add a todo in ${applicationName}          →  ${applicationName}でやることを追加
How many todos do I have in ${...}        →  ${applicationName}のやることは何件
```

## Variations must vary the vocabulary

Each phrase is a recognition path. Two phrases that differ only in grammar add one path's worth of value: none.

The English set deliberately uses **different words**: `Snooze` / `Delay`, `Star` / `Favorite`. Translating those mechanically collapses them into one word with different particles or endings, and the variation stops working.

```
❌ 「〜をスヌーズ」「〜をスヌーズする」        differs only by する
❌ 「〜を削除」「〜から削除」                  differs only by the particle
❌ 「〜をお気に入りに追加」「〜をお気に入りにする」

✅ 「〜をスヌーズ」「〜を後回しにする」「〜を先送り」
✅ 「〜を削除」「〜を消す」
✅ 「〜をお気に入りに追加」「〜にスターを付ける」
```

The same principle applies to any target language: reach for the synonyms a person would actually use, not conjugations of one verb.

Languages do not need the same number of phrases. The value is a per-language `stringSet`, so add a phrase by appending to that language's array, not by adding a key (CheckItOut ships 3 in English and 5 in Japanese).

## When people say a different name than the display name

If the app is spoken by a name that is not its display name (CheckItOut is said as 「チェケラ」), add `INAlternativeAppNames` to the app's Info.plist, each entry with `INAlternativeAppName` and `INAlternativeAppNamePronunciationHint`. Otherwise Siri cannot tell which app a phrase spoken with that name belongs to. [Apple]

## Compare like with like

Judge redundancy only **within the same parameter shape**. A pair like:

```
Show my todos in ${applicationName}
Show ${filter} todos in ${applicationName}
```

is not a duplicate even if both translate to something that starts the same way. The parameter-free phrase exists so Siri can *ask* for the value instead of failing to match — keep one per intent (`app-intents-system-surfaces`).

## Budget

- ≤ 10 `AppShortcut` entries per app; ~1,000 phrases across them.
- Adding a language multiplies the phrase count, not the entry count. The 10-entry limit is per app, not per language.

## When Xcode extracts phrases for you

[measured: GRAPHICA, Xcode 27.0, 2026-10]

- The build's `.stringsdata` (`SWIFT_EMIT_LOC_STRINGS`) carried **only the first phrase of each shortcut**. Diffing it against `AppShortcuts.xcstrings` misses the rest; take the full list from the built metadata.
- Letting Xcode re-extract the phrases **demotes translations you already checked to `needs_review`**. Review the catalog diff before committing it, and keep `translated` where you have verified the wording.

## What phrases cannot carry

Only `AppEntity` and `AppEnum` parameters can be embedded [Apple: wwdc2022-10170 14:40–15:15]. A free-text `String` cannot appear in a phrase in any language; Siri asks for it afterwards.

And a parameterised phrase **does nothing until `updateAppShortcutParameters()` has run at least once** — a localisation problem that looks like one, because the phrase is present and correct and simply never matches.

## Voice-understanding assets

Each locale gets its own trained data, at `MyApp.app/<locale>.lproj/nlu.appintents/`. Two things to know:

- **A localised app does not use `Metadata.appintents/nlu/`.** Looking there and finding nothing is not evidence of failure.
- The build log's success line is `Archiving all locales` → `archived N locales`. If a `@Parameter` uses a system value type on an App-Shortcut-registered intent, generation fails for **every** locale in that target while the build still reports success (`app-intents-parameters-and-prompts`).
