# Recording the calls the system makes into your queries

A query that was never called and a query that returned nothing produce the same thing: an empty picker, empty search results, an entity that will not resolve. Nothing in the failure tells you which happened, and the two have opposite fixes — registration and metadata on one side, the query body and the store on the other.

Neither of the other observation channels answers it. `os_log` shows the calls live but keeps no history you can read after the fact, and it is awkward to reach when the caller is an extension. The donation stream records intent **execution**, not query calls. AppIntentsTesting covers the calls *it* makes, not the ones Siri, Spotlight or a widget make.

So have the app write them down. This is public API only — `UserDefaults` and `#function` — which is what makes it different from reading private paths.

## The shape

One append per query method, into the **App Group** `UserDefaults` (the caller may be an extension process, and the App Group is also what makes it readable from outside):

```swift
public struct QueryCallLogEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let query: String      // "TodoEntityQuery"
    public let caller: String     // #function at the call site
    public let requested: Int?    // identifiers the system asked for, nil where there is no input count
    public let returned: Int      // what you handed back
    public let process: String    // ProcessInfo.processName — app, widget extension, …
}

public static func record(
    query: String, caller: String, requested: Int? = nil, returned: Int,
    defaults: UserDefaults? = nil
) {
    #if DEBUG
    // read-modify-write under a lock, append, cap to N, re-encode
    #endif
}
```

Call sites stay one statement, with no `#if` of their own because `record` is empty outside DEBUG:

```swift
public func entities(for identifiers: [TodoAppEntity.ID]) async throws -> [TodoAppEntity] {
    let entities = /* … */
    QueryCallLog.record(query: Self.logName, caller: #function,
                        requested: identifiers.count, returned: entities.count)
    return entities
}
```

Four decisions worth keeping:

- **`requested` separate from `returned`.** `3 → 0` is the signature of a resolution failure and reads at a glance; a single count hides it. Leave it `nil` for `suggestedEntities()` / `allEntities()`, which have no input count — `0` would be a lie.
- **`process`.** Which process answered decides where `@Dependency` has to be registered and whether `allowedExecutionTargets` is right. It is also the only way to notice that the widget extension is answering a call you assumed the app handled.
- **Cap it** (a couple of hundred entries, oldest dropped). The whole array is re-encoded per call, and an uncapped diagnostic eventually becomes the slow thing you are diagnosing.
- **Encode dates as ISO 8601.** The log is read from outside the app more often than inside it, and a `timeIntervalSinceReferenceDate` double is unreadable in `plutil` output.

Cover every method the system can call, including the ones that only run when something else went right: `entities(for:)`, `entities(matching:)`, `suggestedEntities()`, `allEntities()`, `displayRepresentations(for:)`, `IndexedEntityQuery.reindex…`, and `IntentValueQuery.values(for:)`.

## Reading it

In-app, a DEBUG-only screen is enough (list, newest first, red when `requested > 0 && returned == 0`). Keep its copy out of the string catalogs — it never ships.

From outside:

```bash
python3 scripts/dump_query_call_log.py --group group.com.example.App              # booted simulator
python3 scripts/dump_query_call_log.py --group group.com.example.App --mac        # Mac app
python3 scripts/dump_query_call_log.py --group group.com.example.App --empty-only

python3 scripts/dump_query_call_log.py --group group.com.example.App --snapshot /tmp/qcl
# … invoke exactly once from Siri / Spotlight / Shortcuts / a widget …
python3 scripts/dump_query_call_log.py --group group.com.example.App --diff /tmp/qcl
```

The script goes through `defaults export` (`xcrun simctl spawn <udid> defaults export` for a simulator) rather than reading the container plist. Two reasons, both measured: `UserDefaults` writes are flushed lazily by `cfprefsd`, so a file read right after the call can miss it; and on macOS `~/Library/Group Containers` is TCC-protected, so opening the file fails without Full Disk Access while the domain read succeeds.

`--snapshot` / `--diff` is the same differential method the rest of this skill uses: mark, change exactly one thing (the **caller**, not the intent), read the delta.

## What it does and does not prove

A row is evidence the call happened, in that process, with those counts. **An absent row is not evidence the call did not happen** — the log only exists in DEBUG builds, only for processes that have the App Group, and it drops the oldest entries past the cap. Concurrent writers can lose an append, so treat counts as approximate and the presence of a call as the finding.

Before concluding "never called", confirm the log works at all with a positive control: invoke the same query from a path that definitely reaches it (a parameter picker in Shortcuts) and see the row appear.
