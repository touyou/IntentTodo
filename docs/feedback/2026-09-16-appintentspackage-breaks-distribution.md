# Feedback: `AppIntentsPackage` を宣言すると配布ビルドで App Intents が丸ごと読まれない（下書き）

| | |
|---|---|
| 状態 | **下書き**（未提出） |
| FB 番号 | — |
| 対象 | Xcode 27.0 (27A266a) / App Intents / App Store・TestFlight 配布 |
| 追跡 | #30（配布経路まで通す観点） |
| 経緯 | [docs/devlog/2026-09-15-appintentspackage-breaks-distribution.md](../devlog/2026-09-15-appintentspackage-breaks-distribution.md) |

下の `---` 以降が提出本文（英語）。上半分は要約と、提出前に詰めるべき点。

## この Feedback が主張していること（1 行）

静的リンクの Swift Package に Intent を置いた構成で Apple 公式手順どおり `AppIntentsPackage` を
宣言すると、**TestFlight / App Store 経由で入れた場合にだけ**アプリの App Intents が
バンドルごと読み込まれない。Xcode 経由のインストールでは Debug / Release とも再現しない。

## 強い点

- **同一ソース・同一構成での A/B が実在する**。実際に公開しているアプリ（Intento / app id 6788623037）の
  **build 36（宣言あり = 壊れる）と build 37（宣言なし = 直る）**が両方 TestFlight に残っている。
  Apple 側は追加の再現プロジェクトなしに突き合わせられる
- **成果物の同一性を測ってある**。macOS の Release ローカルビルドと App Store 配布版のバンドルは
  `_MASReceipt` 以外完全一致。配布パイプラインが何かを落としているのではない
- **出荷メタデータは健全**。`actions` 26 / `entities` 9 / `queries` 6 / `enums` 8 /
  `autoShortcuts` 8、`isDiscoverable: true`、形式 `version 3.0`。読む側が拒否している
- **公式ガイダンス自体が矛盾している**。wwdc2025-244 は 23:29 で "You **must** register each target"
  と言い、24:00 で "You **should** use App Intents Package when referencing code **not compiled into
  a static library**" と言う。前者だけ聞いて実装すると踏む

## 弱い点（提出前に自覚しておく）

- **機序は仮説のまま**。`extract.packagedata` のマングル名（`14TodoAppIntents0aC7PackageV`）の解決に
  失敗している、という推定までしか行っていない。因果は A/B で取ったが、内部の失敗点は見ていない。
  本文でもそう書く（断定しない）
- **端末側のログを取れていない**。配布インストール時の取り込みが何を言っているかは未確認。
  `linkd` を流しても該当ログが出なかった
- **最小再現プロジェクトが無い**。この不具合は配布経路を通さないと出ないので、**再現には Apple 側で
  TestFlight 配布してもらう必要がある**。そこが普通の Feedback と違う

## 追加情報を求められたときに出せるもの

1. 出荷版 `Metadata.appintents/extract.actionsdata` と `extract.packagedata`（壊れた build 36 側）
2. 宣言を外した Release ビルドの同ファイル（`extract.packagedata` が無くなり、`extract.actionsdata` の
   件数は据え置きであることを示す）
3. TestFlight のビルド二分の表（build 8 / 13 が OK、28 / 29 / 36 が NG、37 で復帰）
4. 該当 commit（`c4f20ef` が宣言追加、`bc5ab0f` が全廃）

---

## English submission body

### Title

Declaring `AppIntentsPackage` with statically linked Swift packages makes the app's App Intents
entirely unreadable when installed from TestFlight / the App Store — silently, and only through
distribution

### Summary

My app puts its `AppIntent` / `AppEntity` / `EntityQuery` / `AppEnum` types in a local Swift package,
and follows the documented step of registering each consuming target as an App Intents Package:

```swift
// in the package
public struct TodoIntentsPackage: AppIntentsPackage {}

// in the app target, the widget extension, the Live Activity extension, the watch app
struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [TodoIntentsPackage.self] }
}
```

All packages are statically linked (Xcode's default for local packages; the app bundle has no
`Frameworks/`).

With those declarations present:

- Installed by Xcode (**Debug or Release**): everything works. 8 App Shortcuts appear in the
  Shortcuts app, Spotlight surfaces them, Siri phrases resolve.
- Installed from **TestFlight or the App Store**: the app's App Intents are not ingested at all.
  The app does not even appear in the Shortcuts app's list of apps. Actions that a user had already
  placed in a saved shortcut report that the action no longer exists.

Removing the `AppIntentsPackage` declarations — and changing nothing else — fixes it. I verified this
with two TestFlight builds of the shipping app, described under "A/B evidence" below.

There is no diagnostic at any point: the build succeeds, App Store Connect validation is clean,
the app runs normally, and nothing appears in the device log from the app's side.

### Environment

- Xcode 27.0 (27A266a), iOS 27.0 / macOS 27.0 / visionOS 27.0 SDKs
- macOS 27.0 (26A428) for the Mac-side measurements; iPhone on iOS 27.0
- App: iOS + macOS (native) + visionOS + embedded watchOS app + widget extension +
  Live Activity extension. Seven local Swift packages, all statically linked
- Shipping app: "Intento", app id 6788623037

### A/B evidence

Two TestFlight builds of the same app, same Xcode version, same Xcode Cloud workflow. The only
App Intents-related difference is the presence of the `AppIntentsPackage` declarations.

| Build | `AppIntentsPackage` declared | `extract.packagedata` in bundle | Shortcuts / Spotlight / Siri after TestFlight install |
|---|---|---|---|
| 36 | yes (package + 4 consuming targets) | `{"includes":["14TodoAppIntents0aC7PackageV"],"version":1}` | **nothing — the app is absent from the Shortcuts app** |
| 37 | no | file absent | works (8 App Shortcuts, Spotlight, Siri) |

Both builds are still in TestFlight if it helps to compare them directly.

I also bisected further back through TestFlight history, which lands on the same commit:

| Build | Uploaded (UTC) | Result |
|---|---|---|
| 8 | 2026-07-09 10:29 | works |
| 13 | 2026-08-11 15:22 | works |
| 28 | 2026-08-27 01:56 | broken |
| 29 | 2026-09-09 22:29 | broken |

The only change between build 13 and build 14 that touches App Intents structure is the commit that
added the `AppIntentsPackage` declarations.

### The shipped artifact is correct

I want to rule out "the build or the distribution pipeline lost something", because that was my first
assumption and it is wrong.

Reading the **App Store copy** of the Mac app
(`/Applications/…/Contents/Resources/Metadata.appintents/extract.actionsdata`):

| | |
|---|---|
| `actions` / `entities` / `queries` / `enums` | 26 / 9 / 6 / 8 |
| `autoShortcuts` | 8 |
| `autoShortcutProviderMangledName` | the app target's `AppShortcutsProvider` |
| `AddTodoIntent` | `isDiscoverable: true`, `visibilityMetadata.assistantOnly: false`, `requiredCapabilities: []` |
| `version.json` | `{"toolsVersion":"27A266a","version":"3.0"}` — same format version as Apple's own apps on the same OS |

And the App Store copy of the Mac app is **byte-structurally identical to a local Release build** of
the same commit: diffing the two bundle trees yields only `Contents/_MASReceipt`. So the artifact the
store delivers is the artifact Xcode produced, and that artifact's metadata is complete and marked
discoverable.

Removing the declarations changes exactly one thing in the output:

```
extract.packagedata                                              removed from every bundle
actions 26 / entities 9 / queries 6 / enums 8 / autoShortcuts 8   unchanged
ja.lproj/nlu.appintents, en.lproj/nlu.appintents                  unchanged
```

Nothing is lost by removing it, which is consistent with static linking already merging the
package's extraction output into each consuming target's `extract.actionsdata`.

### What I think is happening (hypothesis, not measured)

`extract.packagedata` is the only place in App Intents metadata where a **type is referenced by
mangled name for resolution at load time** — here `14TodoAppIntents0aC7PackageV`
(`TodoAppIntents.TodoIntentsPackage`). My guess is that resolving it fails in a distributed build and
the ingestion of the bundle is abandoned as a whole, rather than falling back to the actions that are
already present in `extract.actionsdata`.

That would be consistent with the distribution-only nature of the failure: `STRIP_INSTALLED_PRODUCT`
and `STRIP_SWIFT_SYMBOLS` apply on the distributed product, not on what Xcode installs during
development.

I want to be clear that I have **not** confirmed this mechanism. I could not find a log line from the
system side at install time (streaming `linkd` and `com.apple.appintents` on macOS produced nothing
for this bundle). What I did establish is the causation, by the A/B above.

### Expected

Either of:

- Declaring `AppIntentsPackage` on a statically linked package is harmless, as the documentation's
  "you must register each target" phrasing implies; or
- if it is genuinely inapplicable to static linking, it fails loudly at build time.

### Actual

The app's entire App Intents surface disappears, only for users who install through the store, with
no signal to the developer at any stage.

### Impact

The severity comes from where the failure lands. A developer testing locally — in the simulator, on a
device from Xcode, in Debug or Release — sees a fully working app. The failure appears only after
shipping, and it does not look like an App Intents problem from the outside: the app simply is not in
the Shortcuts app's list, as though it had never adopted App Intents.

In my case it shipped to the App Store. Users who had built shortcuts against the app found their
saved shortcuts reporting that the actions no longer existed.

The guidance I followed pushes toward the failing configuration. WWDC25 session 244 says at 23:29:

> "You must register each target as an App Intents Package to ensure proper indexing and validation."

and then at 24:00:

> "You should use App Intents Package when referencing code not compiled into a static library."

The first is stated as a requirement and is the sentence a developer acts on; the second is the
condition that actually matters, and it is easy to read as an additional note rather than a
restriction. Neither the `AppIntentsPackage` nor the `includedPackages` reference page mentions
linkage at all.

### What I'd like (in order of preference)

1. **Don't fail closed.** If a package reference in `extract.packagedata` cannot be resolved, still
   ingest the actions, entities and queries that are present in `extract.actionsdata`. A missing
   dynamic-library reference should cost the app the intents in that library, not all of them.
2. **Make it work with static linking**, so the documented "register each target" step is safe
   regardless of how the package is linked.
3. **Diagnose it.** Either at build time (the extractor knows the linkage — the app bundle has no
   `Frameworks/`) or at ingestion time with a log line naming the bundle and the unresolved package.
   Either one would have turned a multi-day investigation into a warning.
4. **Document the linkage condition on the API pages**, not only as a spoken aside in a session:
   `AppIntentsPackage` / `includedPackages` should say that it is for code not compiled into a static
   library, and that declaring it otherwise is unnecessary.

### Note on reproducing this

This does not reproduce from a local install, which is the whole difficulty: an Xcode-installed
build of the broken configuration works. Reproducing it requires distributing through TestFlight or
the App Store. That is why I am offering the two builds of the real app (36 and 37) rather than a
synthetic sample — they are the A/B pair, already distributed, and they differ only in this
declaration.

If a minimal project is needed anyway, the shape is: an app target + one local Swift package holding
one `AppIntent` and an `AppShortcutsProvider` in the app target, with and without the
`AppIntentsPackage` declarations, distributed through TestFlight both ways.

Related: FB24570185 (App Intents metadata merge silently dropping `assistantDefinedSchemas` when an
embedded watchOS target shares type names) and FB24548956 (`AppIntentsSSUTraining` rejecting system
value types in `@Parameter` of App Shortcut-registered intents) — same failure shape, in that the
build stays green while a shipping artifact loses content.
