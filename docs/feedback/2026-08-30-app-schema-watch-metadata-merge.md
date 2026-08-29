# Feedback: App Schema と埋め込み watchOS ターゲットの両立（FB24570185）

| | |
|---|---|
| 状態 | **提出済み**（2026-08-30） |
| FB 番号 | **FB24570185** |
| 対象 | Xcode 27.0 beta 6 (27A5252f) / App Intents / ビルドシステム |
| 追跡 | #57（GM SDK 到来時に再現確認）。起票元の #86 はクローズ済み |
| 経緯 | [docs/devlog/2026-08-29-schema-vs-watch-target.md](../devlog/2026-08-29-schema-vs-watch-target.md)（6 節が提出前の再検証） |

下の `---` 以降が**実際に提出した本文**（英語）。上半分は要約と、Apple の返信が来たときに見る材料。

## この Feedback が主張していること（1 行）

埋め込み watchOS ターゲットを持つアプリは、共有 `AppEntity` / `AppEnum` 型を**二重定義しない限り
いかなる App Schema にも適合できず**、しかも診断ゼロ・ビルド緑で出荷メタデータからスキーマが消える。

## 2026-08-30 の再検証で分かった追加事実（#86 起票時より強くなった点）

再検証は SDK / ビルド成果物 / 公式ドキュメントを独立に当たり直した。**結論は変わらず、根拠が 3 点増えた**。

1. **原因はマージ順序で、しかも「後勝ち」**。同じ型名のエントリが並ぶと**ファイルリストの後ろにあるほうが
   前を丸ごと置き換える**。Xcode が自動生成するファイルリストはパスのアルファベット順なので
   `Debug-iphonesimulator` < `Debug-watchsimulator` で **watchOS スライスが常に最後に来て必ず勝つ**。
   入力順を逆にするとスキーマは残る（＝スキーマの有無で優劣が決まっているわけではない）
2. **失われるのはスキーマだけではない**。エントリが**丸ごと**置き換わるので、`TodoAppEntity` の
   プロパティが **20 → 10** に減る（`note` / `dueDate` / `tags` / `urls` / `recurrence` /
   `locationTrigger` / `completionDate` / `creationDate` / `isFlagged` / `list` が消える）
3. **突き合わせキーは「モジュール名を含まない型名」**。mangled type name でも fully qualified 名でもない。
   合成プローブでキーだけ衝突させると、iOS アプリの出荷メタデータに
   **iOS バイナリに存在しない型の mangled name** が残った（＝シンボル同一性で照合していない）

再検証で確認できた既知事実（#86 の記述は正しかった）:

- `AppSchema` の **23 ドメイン全部**が `@available(watchOS, unavailable)` / `@available(tvOS, unavailable)`
  （Xcode 27 beta 6 の 5 プラットフォーム分の swiftinterface を走査。例外ゼロ）
- 公式ドキュメントの availability も一致（`AppSchema.RemindersEntity` は iOS / iPadOS / Mac Catalyst /
  macOS / visionOS 27.0 のみ）。**watchOS の記載は無い**
- iOS アプリターゲットの `IntentTodo.DependencyMetadataFileList` /
  `DependencyStaticMetadataFileList` に `Debug-watchsimulator/...` が並ぶ（Xcode の自動生成物）
- 公開 API での抜け道は無い（`AppSchema.Entity.init(_:)` は `@usableFromInline internal`）
- **公式ドキュメントはこの制約に一切触れていない**。App Schema のプラットフォーム制限、
  複数ターゲット間のメタデータマージ、watch アプリを埋め込んだ場合の注意——どれも記述が無い
- Apple 公式の Apple Intelligence サンプル 4 本は**いずれも watch ターゲットを持たない**
  （`SUPPORTED_PLATFORMS` は iphoneos / macosx / xros）

「メタデータの入力リストを絞る公開手段があるのでは」も当たったが、**無い**。`AppIntentsMetadata.xcspec` の
`LM_*` 設定はファイルリストの**パスごと**差し替えるもので、入力を 1 件ずつ除外する形にはなっていない
（かつ非公開）。

## 追加情報を求められたときに出せるもの

1. iOS アプリの `Metadata.appintents/extract.actionsdata`（正常時 / 壊れた時の 2 本）
2. Xcode 自動生成の `*.DependencyStaticMetadataFileList`（watchOS スライスが並んでいることを示す）
3. 下の "Isolated probe" の手順そのまま（Apple 側でこのリポジトリなしに再現できる）

---

## English submission body

### Title

App Intents metadata merge drops `assistantDefinedSchemas` from the iOS app when an embedded watchOS target declares the same type name — silently, with no diagnostic

### Summary

An iOS app that embeds a watchOS app and shares its `AppEntity` / `AppEnum` types between the two
cannot ship **any** App Schema conformance. The schema is present in every iOS-slice input, but it is
missing from the iOS app's final `Metadata.appintents/extract.actionsdata`.

Two individually reasonable decisions combine into this:

1. **App Schema does not exist on watchOS / tvOS.** All 23 domains of `AppSchema` are
   `@available(watchOS, unavailable)` / `@available(tvOS, unavailable)` (verified across the
   iPhoneOS / MacOSX / WatchOS / AppleTVOS / XROS swiftinterfaces in Xcode 27.0 beta 6 — no
   exceptions). This matches the announced availability of the new Siri (iPhone, iPad, Mac,
   visionOS), so I assume it is deliberate.
2. **The iOS app's metadata merge takes the watchOS slices as inputs.** The auto-generated
   `<Product>.DependencyMetadataFileList` and `<Product>.DependencyStaticMetadataFileList`
   for the iOS app target contain `Debug-watchsimulator/...` entries. These files are written by
   Xcode (`WriteAuxiliaryFile … IntentTodo.DependencyMetadataFileList`), not by me.

So the same type is extracted twice: once from the iOS slice (with the schema, because the domain is
available) and once from the watchOS slice (without it, because the domain is unavailable there).
The merge then keys entries by **unqualified type name** and lets the **last** input win. Xcode's
generated file list is sorted by path, so `Debug-iphonesimulator` always precedes
`Debug-watchsimulator` and the watchOS entry always wins.

**The build succeeds with no warning or error.** Nothing short of reading `extract.actionsdata`
by hand reveals it.

### Environment

- Xcode 27.0 beta 6 (27A5252f), iOS 27.0 SDK / watchOS 27.0 SDK
- macOS 27.0
- App: iOS app + embedded watchOS app + widget extension + Live Activity extension, all linking one
  local Swift package that defines the `AppEntity` / `AppEnum` / `AppIntent` types
- Schemas adopted: `.reminders.reminder`, `.reminders.list`, `.reminders.listType`,
  `.reminders.locationTrigger`, `.reminders.locationTriggerEvent`

### Steps to reproduce

**In a project:**

1. Create an iOS app with an embedded watchOS app target.
2. Put an `AppEntity` in a Swift package that both targets link, e.g. `TodoAppEntity`.
3. Adopt a schema on it for the platforms where the domain exists:
   `@AppEntity(schema: .reminders.reminder)`, wrapped in `#if !os(watchOS)` (the watchOS build cannot
   compile the macro — the domain accessor is unavailable there).
4. Build the iOS app scheme (clean build; the metadata task does not re-run incrementally).
5. Read `Build/Products/…/IntentTodo.app/Metadata.appintents/extract.actionsdata`.

**Isolated probe** (no project needed; this is how I characterised the merge policy). Take the two
`extract.actionsdata` files Xcode already produced for one shared module — the iOS slice
(`Debug-iphonesimulator/<Module>.appintents/…`) and the watchOS slice
(`Debug-watchsimulator/<Module>.appintents/…`) — and rename the watchOS-only entity key back to the
shared name to model step 3 above. Then run the app target's own
`appintentsmetadataprocessor` invocation (copied verbatim from the build log) with `--output` and
`--metadata-file-list` / `--static-metadata-file-list` pointed at temporary copies. Diff the
resulting `extract.actionsdata` against the run with the untouched lists.

### Expected

The iOS app's shipping metadata describes the iOS binary: `TodoAppEntity` carries
`assistantDefinedSchemas: [{reminders, ReminderEntity}]` and all 20 of its properties.

### Actual

`assistantDefinedSchemas: []`, and 10 of the 20 properties are gone. The record from the watchOS
slice replaced the iOS record wholesale.

Measured (Xcode 27.0 beta 6, isolated probe, only the inputs varied):

| Run | Inputs | `TodoAppEntity` | `CategoryAppEntity` | `TodoLocationTriggerAppEntity` |
|---|---|---|---|---|
| control | untouched lists (watch types have distinct names) | `reminders.ReminderEntity`, 20 properties | `reminders.ListEntity` | `reminders.LocationTriggerEntity` |
| collision | watchOS slice declares the same type names | **`[]`, 10 properties** | **`[]`** | `reminders.LocationTriggerEntity` (no watchOS counterpart, so untouched) |
| collision, reversed input order | same inputs, watchOS entries listed first | `reminders.ReminderEntity` | `reminders.ListEntity` | `reminders.LocationTriggerEntity` |

Enums behave the same way: with the collision, `TodoListType` and `TodoLocationTriggerEvent` lose
`reminders.ListType` / `reminders.LocationTriggerEvent`.

Three things follow from the reversed-order run:

- The rule is **last input wins**, not "the entry with a schema wins" and not "the entry with more
  data wins". The outcome depends purely on file-list order.
- Xcode's generated order makes the loss deterministic: `Debug-iphonesimulator` sorts before
  `Debug-watchsimulator`.
- The processor already knows which platform it is building for — `--platform-family iOS` is on its
  command line — so it has enough information to not let a foreign-platform slice overwrite.

One more characterisation: the merge key is the **unqualified type name**. In a probe where I
collided only the key and left `mangledTypeName` / `fullyQualifiedTypeName` pointing at the
watchOS-only type, the merged iOS metadata kept a `mangledTypeName` for a type that does not exist in
the iOS binary. The merge is name-based, not symbol-based, which also means two modules that happen
to use the same entity type name can overwrite each other.

Every run above exits 0 and prints only "Starting … / Writing Metadata.appintents". The loss is
silent with and without `--force-metadata-output`.

### Impact

Any app that ships a watch app and shares its App Intents model types is excluded from Apple
Intelligence schema adoption — not by a compile error, but by metadata that looks fine and is empty
where it matters. Because the symptom is invisible in Xcode, in the Shortcuts app, and at runtime in
the app itself, it is reasonable to assume shipping apps are affected without knowing.

I would also note that none of Apple's four Apple Intelligence sample apps (Calendar, Messaging,
Music, Photo) has a watch target — `SUPPORTED_PLATFORMS` is `iphoneos macosx xros` — so this
combination is not exercised by the samples.

### Workaround, and its cost

The only workaround I found is to give the watchOS build **different type names**
(`WatchTodoAppEntity` + `typealias`), so the names no longer collide. That works, and it is what the
app ships today.

The cost is a permanent duplicate declaration of every property and initializer, because
`@Property` / `@ComputedProperty` / `@DeferredProperty` are member attributes and cannot be factored
into an extension. In my app that is roughly 200 duplicated lines for one entity, and it has to be
re-done for every entity, enum, and schema I adopt.

Two non-workarounds, for completeness:

- Hand-writing the `__appSchemaEntity` member so the watchOS slice also claims the schema. It
  compiles, but it is an underscore-prefixed symbol that is not a protocol requirement — purely an
  agreement between the macro and the extractor — and it would emit metadata claiming
  `reminders.ReminderEntity` for a platform where schemas do not exist. I removed it for those
  reasons.
- Building the schema identifier directly (`AppSchema.Entity("ReminderEntity")`) so it can be
  declared under `#if`: `init(_:)` is `@usableFromInline internal`.
- Filtering the metadata inputs from the build: the `LM_*` settings in `AppIntentsMetadata.xcspec`
  replace whole file-list paths, not individual inputs, and are undocumented.

### What I'd like (in order of preference)

1. **Don't let a duplicate entry erase schemas and properties on merge** — union them, or prefer the
   richer record, or ignore entries whose platform family differs from `--platform-family`.
2. **Emit a diagnostic when a merge drops an `assistantDefinedSchemas` entry** (or drops properties).
   Even without a behaviour change, this would have turned a two-day investigation into a warning.
3. **A public way to say "apply this schema only where schemas exist"** — e.g. an availability-aware
   spelling of `@AppEntity(schema:)`, so one shared type can carry the declaration and have it be a
   no-op on watchOS / tvOS.
4. **Make the schema namespaces declarable (no-op) on watchOS / tvOS**, so shared types compile
   identically on every platform.
5. **Document the platform limitation and the multi-target merge**, either way. Today neither the
   App Schema domain pages nor "Making actions and content discoverable by Apple Intelligence"
   mentions that schemas are unavailable on watchOS / tvOS, or that an embedded watch target's
   metadata is merged into the containing app's.

Related: FB24548956 (`AppIntentsSSUTraining` rejecting system value types in `@Parameter` of
App Shortcut-registered intents) — same failure shape, in that the build stays green while a
shipping artifact loses content.
