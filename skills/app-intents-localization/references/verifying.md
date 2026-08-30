# Verifying localization

Nothing here fails the build, so every check has to be run deliberately.

## The checker script

```bash
python3 scripts/check_intent_copy_localization.py
```

Reads the keys the system will look up out of the built `Metadata.appintents` and diffs them against each linking target's `Localizable.xcstrings`. Reports missing keys and untranslated values per target.

What it **cannot** see: `IntentDialog` strings, which are built inside `perform()` and never reach the metadata. Take stock of those with the temporary-package-catalog trick ([intent-copy](intent-copy.md)).

## Exporting

```sh
xcodebuild -exportLocalizations -project MyApp.xcodeproj -scheme MyApp \
  -localizationPath /tmp/loc -exportLanguage en -destination 'generic/platform=iOS'
```

- Swap `-exportLanguage ja` to inspect the translation side.
- **This command also updates the catalogs in your source tree**, so the extraction result is directly committable.
- Compare counts in `/tmp/loc/en.xcloc/Source Contents/Packages/<pkg>/…/Localizable.xcstrings` before and after a change to confirm a package's strings are now being picked up.

## Do not judge by unit counts

`ja.xliff` unit counts do **not** match catalog key counts:

- a String Set is **one** unit (the values are `<mrk>` children),
- a device variation is **two**.

So "the xliff has fewer units than the catalog has keys" is not evidence of missing translations.

## Machine checks that builds do not do

The ways translations break are all invisible to the compiler:

- a dropped `${applicationName}` or `${todo}` placeholder,
- a lost `%@` or a changed positional order,
- `&amp;` and friends leaking in from a tool,
- full-width Latin characters or half-width katakana,
- an English fragment left inside a `%@` because the sentence was assembled in Swift.

Read the catalogs directly and compare the placeholder *sets* between the source language and each translation before exporting. This is a few lines of script and it catches the whole class.

## UI tests: pin the app's language

Once a second language exists, the simulator launches the app in **the host machine's** preferred language. Every UI test that finds an element by an English accessibility label breaks at that moment.

```swift
app.launchArguments = [
    "--uitesting",
    "-AppleLanguages", "(en)",
    "-AppleLocale", "en_US",
]
```

And note that this breakage is **half silent**: any assertion written as `if element.waitForExistence(…) { XCTAssert… }` does not fail — it simply never runs (`app-intents-testing`). If you want to test the translated UI, add a separate test class that pins that language deliberately.

Comparing against a resource in a test has the same hazard: pin its locale explicitly (`resource.locale = Locale(identifier: "en")`) or the same test passes under `swift test` and fails through Xcode's test action.

## What still needs a device

- **Whether the system really reads the main-bundle `Localizable` table for intent copy.** That the identically-shaped `shortTitle` and `parameterSummary` keys *do* render in the translated language is strong evidence, but it is inference — open the Shortcuts app in that language and read one intent title.
- **How Siri pronounces things.** A dialog can be grammatical and still be read badly (`app-intents-entities-and-search`).
- **Whether the translated phrases route.** Phrase routing is not automatable at all (`app-intents-testing`).
