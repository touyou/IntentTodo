# Tests that lie

Six shapes that pass while the feature is broken. Each has hidden a real failure for a long time.

## 1. The conditional assertion

**Never write one.**

```swift
// ❌ green when the element never appears
if deleteButton.waitForExistence(timeout: 3) {
    deleteButton.tap()
    XCTAssertFalse(row.exists)
}

// ✅
XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
deleteButton.tap()
XCTAssertFalse(row.exists)
```

This shape conceals exactly the failures intent tests cannot see: a confirmation-based intent failing silently from `Button(intent:)` (`app-intents-ui-and-feedback`) leaves the element absent, the branch unentered, and the suite green. `audit_intents.py` flags it (`conditional-assert`).

The related lesson: an intent that works through Siri and AppIntentsTesting can still be broken from the UI, because **the caller changes the behaviour**. UI tests are not redundant with intent tests.

## 2. Waiting a fixed number of seconds

`sleep(1)` advances whether or not the state changed, so a broken feature and a slow one look the same. Wait on the condition: `waitForExistence` / `waitForNonExistence`. Faster, and failures fail.

## 3. Asserting on a localised string

Once the app has more than one language, `String(localized: "Delete todo")` resolves in **the host machine's** preferred language on the simulator — so a test that passes under `swift test` fails under Xcode's test action, or vice versa.

Two halves:

- Pin the app's language in the test: `app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]`.
- If you must compare a resource, pin its locale: `resource.locale = Locale(identifier: "en")`.

This failure is **half silent**: the assertions that were written conditionally (#1) do not fail, they just stop running. Accessibility labels on generic components — "Delete todo", "Mark as complete" — are the usual casualties, because they have no identifier to fall back on.

## 4. A store that carries over between tests

A shared App Group store outlives the process, so items accumulate across runs. Tests that assume an empty list stop being meaningful, and list redraws get slow enough to time out.

Pass a launch argument (`-uitest-ephemeral-store`) that a `#if DEBUG` branch honours by using an in-memory container.

**AppIntentsTesting wants the opposite** — the real store, so entity resolution and Spotlight behave as they do in production. Give the two bundles different launch arguments rather than one compromise.

## 5. A test target that is not in the scheme

A package test target that is not listed in the scheme's `TestAction` **does not run and stops being compiled**. It does not go red when the code it covers changes shape — it stops existing. A whole package's test suite can silently fall out of CI this way.

For a local package: `ReferencedContainer = "container:Packages/<name>"`, `BuildableName` = the target name without `.xctest`. Add the entry in the same change that creates the target.

## 6. Parallelisation that only adds cost

Enabling parallel UI test execution clones the simulator, booting a whole OS per clone. With a single UI test class there is nothing to distribute, so the clone cost is pure overhead. Measure before enabling; for most projects with one or two UI test classes, off is faster.

## And when the measurement itself lies

Two false negatives worth remembering, both from reading the wrong thing:

- **File `mtime` is not the last write.** A memory-mapped log can have a months-old `mtime` and current contents. Read the contents' timestamps.
- **A derived record may not exist yet.** Some system streams are generated on a schedule — minutes, not seconds. `+0` right after the action can mean "not yet", not "never". Give a positive control the same patience you give the experiment, or the control produces the false negative too.
