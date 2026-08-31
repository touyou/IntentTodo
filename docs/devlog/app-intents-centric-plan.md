# 開発ログ: App Intents 中心設計 検証計画

`docs/APP_INTENTS_CENTRIC_PLAN.md` の状態が、どういう経緯で今の形になったかを記録する（SDK バージョン追従の顛末など）。

**フェーズごとの実施記録**（何をどのコミットで入れたか / 当時どう判断したか）と **Xcode 27 beta ごとの
追従**は、2026-08-31 にこのファイルの末尾へ移した（[実行フェーズの実施記録](#実行フェーズの実施記録2026-06-102026-08-27)
以降）。計画側には**到達状況の一覧だけ**を残している。

## 2026-06-10: reminders 本体スキーマ適合を保留 — マクロ生成 init が入れ子サブエンティティを要求

Phase 2 で App Schema (reminders) を検証中、`CategoryAppEntity` → `.reminders.list` / `TodoListType` →
`.reminders.listType` は適合できたが、コアの `TodoAppEntity` → `.reminders.reminder` は保留にした。
probe 検証の結果、reminder スキーマはマクロ生成 init が `EntityProperty<T>` 引数を取り、さらに
`section` / `locationTrigger` 等の入れ子サブエンティティを再帰的に要求することが判明。モデル（`TodoItem`）
から組み立てる自前 init と相性が悪く深掘りが必要と判断し、reminder 本体適合は独立タスクとして据え置いた。
list 階層での適合で App Schema の仕組み自体は検証済み。

## 2026-06-10: RelevantEntities は Todo ドメインに適合する AppEntityContext が無く不適合と結論

Phase 3 で `RelevantEntities.updateEntities(_:for:)` / `AppEntityContext` を検証したが、当時 API から
提供されている `AppEntityContext` は `.audio(...)` などドメイン固有の overlay context のみで、
todo/reminders 向けの context が存在しないと判明。「次の期限/緊急 Todo を文脈寄付する」という当初の
検証目標は達成不能と結論し 🚫 不適合として記録した。

## 2026-07-01: Xcode 27 beta 2 で watchOS の assistant schema が unavailable に → フォールバック追加

beta 2 で `reminders` / `system` ドメインの App Intents assistant schema が watchOS で unavailable に
なり、`TodoAppIntents`（watchOS でもコンパイルされる）のビルドが失敗するようになった。`CategoryAppEntity`
（`.reminders.list`）と `TodoListType`（`.reminders.listType`）はマクロ付き宣言を `#if` で分割できないため、
`#if os(watchOS)` で型を2系統に全書きして素の `AppEntity`/`AppEnum` にフォールバックし、
`ShowTodoSearchResultsIntent`（`.system.search`）は遷移先が watchOS に無いため `#if !os(watchOS)` で
丸ごと除外した（`9684418`）。watchOS は元々 Siri/Apple Intelligence のスキーマルーティングを使わないため
機能損失はない。

## 2026-07-02: Visual Intelligence が beta 2 で macOS に到達 — 「iOS 専用」の制約を解消

macOS/visionOS フルビルドで、Xcode 27 beta 2 から `VisualIntelligence` フレームワークが Mac にも
import 可能になったことが判明（`#if canImport(VisualIntelligence)` が Mac でも真になった）。Mac は
visual search の `IntentValueQuery` が返す entity 全てが openable（`OpenIntent` 保持）であることを
要求するため、`TodoOrCategory` union に含まれる `CategoryAppEntity` が not openable でビルド失敗して
いた（iOS シミュレータ/実機では発火せず Mac Catalyst 相当でのみ顕在化）。「iOS 専用」は当時 SDK に
フレームワークが存在しなかっただけの制約であり恒久的な不可能ではなかったため、Mac を除外せず
`OpenCategoryIntent`（`CategoryAppEntity` 用の `OpenIntent`、`perform()` は `navigateToRoot()` のみ）を
新設して union 全メンバを openable にし、iOS/macOS/visionOS の 3 destination フルビルドを green に
した（`8ddc76f`）。

このケースは「プラットフォーム限定は SDK 更新時に実ビルドで再検証すべき」という教訓として記録。

## 2026-07-08〜09: beta 3 で SSU training が PlaceDescriptor に壊れる — String へ暫定退避

beta 3 で `AppIntentsSSUTraining` が `GeoToolbox.PlaceDescriptorEntity` をドット付き変数名として
SSU 化しようとし、`^[a-zA-Z_][a-zA-Z_$0-9]*$` の正規表現チェックに落ちてビルドが赤くなった。暫定回避
として `PlaceDescriptor` を `@Parameter`/`@Property` から外し `String` に退避した（`35d772f`）。
同 beta で `AppShortcutsProvider` をアプリターゲットへ移動（`3280bed`）、および toolbar API 変更への
追従も行った。

## 2026-07-28: beta 4 でも SSU バグ未修正 — ワークアラウンド継続 + TransientAppEntity 実装

beta 4 で `PlaceDescriptor` の SSU training バグ（変数名正規表現エラー）が再現するか確認したところ、
DerivedData クリア後クリーンビルドでも未修正であることを確認し、`35d772f` のワークアラウンドを継続した。
並行して Phase 1 の残項目だった `TransientAppEntity` を実装（`TodoListSummaryEntity` +
`GetTodoSummaryIntent`、`df4a2aa`）し、Phase 1 を完了とした。

## 2026-08-11: beta 5 でも SSU バグ・watchOS unavailable の両方を再検証 — 変化なしを確認

beta 5 (27A5237l) で 2 つの既知 SDK 制約を実ビルドで再検証した。

- SSU バグ: `35d772f` を一旦 revert し、DerivedData クリア後クリーンビルドで
  `GeoToolbox.PlaceDescriptorEntity` の SSU 化エラーが再現することを確認 → 未修正と判断し revert を
  取り消してワークアラウンドを継続。
- watchOS assistant schema: `.reminders.list` / `.reminders.listType` / `.system.searchInApp` の
  ガードを外した watch 実ビルドで `'reminders' is unavailable in watchOS` 等のエラーを確認 → 依然
  unavailable と判断しフォールバックを継続。

このとき、SSU タスクは incremental ビルドだと直前の失敗結果（stale エラー）をログに再表示することを
実際に誤検知として観測したため、判定は必ず DerivedData クリア後のクリーンビルドで行う、という注意点も
記録した（`647acb6`）。

## 2026-08-11: 過去の記述を3点訂正 — resolvedEntities() は誤記ではない / RelevantEntities の実例引用ミス / reminder 本体適合への新しいリード

`docs/devlog/2026-08-11-constraint-recheck.md` による全項目再検証の一環で、本計画の記述を3点訂正した（`3140e5b`）。

1. `EntityCollection.resolvedEntities()`: wwdc2026-345 の書き起こしには文字列として登場しない
   （セッションの口頭説明は `.identifiers` のみ）ため誤記を疑ったが、Xcode 27 beta 5 の
   `AppIntents.swiftinterface` で `public func resolvedEntities() async throws -> [Entity]` の実在を
   確認し、SDK 由来の正当な API であると確定させた。
2. `RelevantEntities` 不適合の根拠として挙げていた実例が誤りだったと判明: wwdc2026-345 の実例は
   `.audio(.nowPlaying)` ではなく `.audio(.workout(activityType: .running))`。ただしどちらの例でも
   todo ドメインに適合しないという結論自体は変わらない。
3. reminder 本体スキーマ適合（保留中）について新しいリードを発見: wwdc2026-344 は同等にリッチな
   `calendar_event` スキーマ（`attendee` は `TransientAppEntity` の入れ子、`location` は union）に
   手書き init なしで適合させている。Xcode のスキーマ・コードスニペット機能で型の骨格を生成し、
   モデル→エンティティのマッピングは Query 側に持たせる流儀と見られる。本プロジェクトが試した
   「自前 `init(from: TodoItem)` で順次代入」というスタイルがマクロ生成 backing storage と衝突している
   可能性があり、#48 を再挑戦する際はこの CometCal パターン（スニペット生成 + Query 側 populate +
   入れ子は TransientAppEntity）を先に試すべき、という未実施の申し送りとして記録した。

---

## 実行フェーズの実施記録（2026-06-10〜2026-08-27）

> 2026-08-31 に `docs/APP_INTENTS_CENTRIC_PLAN.md` から移送。コミットハッシュと**当時の判断**が
> 混ざっているので、**現在のルールの出典としては使わない**（それは `docs/insights/` 側）。
> ここは「どの順序で、何をきっかけに入れたか」を追うための記録。

- **Phase 0 整地** ✅: `#2` を Intent 合成へ revert（`cab8e67`）、計画を主眼に再焦点化。
- **Phase 1 基盤 + ドメイン橋渡し** ✅:
  - `TodoAppEntity` の主要属性を `@Property` 公開（`48348aa`）
  - Category / SubTask を AppEntity 化 + Query（`1ef65ec`）、Todo→Category 関係を公開
  - `Duration`（`002e6a9`）/ `PersonNameComponents`（`6ca1c09`）/ `PlaceDescriptor`（`5e3b4c7`）を
    ネイティブ型として `@Parameter` + `@Property` 検証（保存は CloudKit 互換 primitive、入力は system 型）
  - `ValueRepresentation`(→`IntentPerson` / `PlaceDescriptor`) を `Transferable` 経由で実装（#44）
  - **Xcode 27 beta 4**: `TransientAppEntity`（`TodoListSummaryEntity` + `GetTodoSummaryIntent`）を実装。
    `EntityPropertyQuery` は不採用と判断（理由は `EnumerableEntityQuery` が Find と絞り込みを自動生成する
    ため。現在の結論は `APP_INTENTS_API_COVERAGE.md` にある）
- **Phase 2 App Schema（reminders）** ✅（reminder 本体まで適合。#56 完了）:
  - xcode27 を iOS 27 世代へ引き上げ（`.reminders` は iOS 27+ 限定のため）`ed22d80`
  - `TodoListType` → `@AppEnum(schema: .reminders.listType)` `ed22d80`
  - `CategoryAppEntity` → `@AppEntity(schema: .reminders.list)` `25d1d61`
  - コア `TodoAppEntity` → `@AppEntity(schema: .reminders.reminder)`（#83）。据え置き理由だった
    「`locationTrigger` の `PlaceDescriptor` が SSU training バグに衝突」は **2026-08-28 に否定**
    （SSU の variable になるのは App Shortcut 登録済み Intent の `@Parameter` だけ）。
    経緯: `2026-08-29-reminder-schema-conformance.md`
  - 4 属性（`tags` / `urls` / `recurrence` / `locationTriggerEvent`）の**書き込み経路**を Intent と UI に
    通した（#85）。このとき `parameterSummary` が Shortcuts 編集画面の allowlist だと分かった。
    経緯: `2026-08-29-attribute-write-paths.md`
  - watch 用に別型名を与える対処（`WatchTodoAppEntity` ほか）に至った経緯:
    `2026-08-29-schema-vs-watch-target.md`（Apple 報告: FB24570185）
- **Phase 3 高度な Intent** ✅（B 深度）: #343
  - `requestConfirmation`（DeleteTodoIntent）`27fc2db`
  - `IntentDonationManager` を `b4dbd63` で入れたが **#53 で不採用に決着し撤去**。
    実測: `2026-08-30-donation-observability.md`
  - `requestChoice`（SnoozeTodoIntent）`db6efa3`
  - system intents: `OpenIntent`→`OpenTodoIntent` `375efd1` / `DeleteIntent`→`DeleteTodosIntent` `92221d0`
  - 会話ダイアログ `IntentDialog(full:supporting:)`（ShowTodosIntent）`1f4bbc7`
  - `RelevantEntities` は適合不能と結論（上の 2026-06-10 の項）
- **Phase 4 大量・実行制御** ✅（B 深度）: #345
  - `CompleteTodosIntent` で `EntityCollection` + `LongRunningIntent` + `CancellableIntent` を同時実装 `8e2d637`
  - `allowedExecutionTargets [.main]`。当時は「FromExtension 分離は entity 解決回避が目的なので
    プロセス制御では統合できない」と結論していたが、2026-08-12 に前提の crash が iOS 27 で再現しないと
    実測し**分離ごと撤去**した（#42。entity 解決の有無は execution target では変えられない、という
    切り分け自体は今も有効）
  - `@UnionValue`（`TodoOrCategory`）+ `SearchEverythingIntent` `099dae3`
  - `SyncableEntity`（`TodoAppEntity`）`d347cb2`
- **Phase 5 Visual Intelligence** ✅（B 深度）: #297
  - `TodoVisualIntelligenceQuery: IntentValueQuery` / `TodoSemanticContentSearchIntent` `069aa48`
  - 結果タップ=`OpenTodoIntent` / 複数結果型=`@UnionValue TodoOrCategory` を再利用
  - Mac の openable 要件を満たすため `OpenCategoryIntent` を新設（上の 2026-07-02 の項）
  - EventKit / Contacts は別フレームワーク軸のため対象外（記録のみ）
- **Phase 6 テスト基盤** ✅: #295
  - `IntentTodoUITest`（UI テストバンドル必須）に AppIntentsTesting テストを追加 `be7cf2b`
    → 2026-08-12 に 10 件へ拡張し実 run グリーン（id 解決 / allEntities / suggestedEntities /
    Spotlight index / Toggle 往復 / QuickSnooze / TransientAppEntity）
  - 自己クリーンアップ設計（一意タイトルで作成 → 削除）
- **Phase 7 WWDC 2026 追加検証（#42–#48）** ✅（B 深度）:
  - #42: `allowedExecutionTargets` に `.widgetKitExtension` がある旨を記録訂正
  - #43: `@Property(indexingKey:)`（watchOS / tvOS は unavailable なので `#if` 分岐。visionOS は
    2026-08-28 に有効化。経緯: `2026-08-28-xcode27-beta6-recheck.md`）
  - #44: `TodoAppEntity: Transferable` + `ValueRepresentation`
  - #45: `UpdateTodoIntent` + `IntentParameter.valueState` + `TodoService.FieldUpdate`
  - #46: 一覧の `.appEntityIdentifier(forSelectionType:)` / 通知の `appEntityIdentifiers`
  - #47: `ShowTodoSearchResultsIntent`（`.system.searchInApp`）+ `pendingSearchText` 配線
  - #48: reminder 本体適合は**当時の再評価では据え置き**（list 適合 + 自前 Intent で新 Siri 連携は
    成立すると確認）→ その後 #56 で適合済み
- **Phase 10 未着手候補の消化** ✅（2026-08-22。4 destination グリーン / SPM テスト 89 件グリーン）:
  `UndoableIntent`（+ `TodoItemSnapshot` / `TodoUndoRegistrar`）/ Spotlight の client state バッチ /
  `DisplayRepresentation` の `synonyms:` と画像の遅延クロージャ / `displayRepresentations(for:)` /
  `findIntentDescription` / `shortcutTileColor` / `IntentError: CustomAppIntentErrorConvertible` /
  複数形 inflection / visionOS の onscreen annotation / `systemExtraLargePortrait`（#277）。
  donation の再導入はこの時点では見送った（後に #53 で決着）。
  経緯: `03-app-intents-core.md`（2026-08-22）
- **Phase 11 未採用だった Intent 種別の消化**（2026-08-26 着手）:
  - `SetFocusFilterIntent`（`TodoFocusFilterIntent`）— カテゴリ / 急ぎのみ / 完了を隠す
  - `ProgressReportingIntent` は**すでに採用済み**だったと判明（SDK で
    `LongRunningIntent: ProgressReportingIntent`）。「未実装の種別」ではなかったので、残っていた価値
    （3 契約をソースで押さえるテストの追加 / 手書き複数形の inflect 化）だけ消化した
  - `UISceneAppIntent` + `AppIntentSceneDelegate` — 狙いはマルチウィンドウではなく cold start
  - `URLRepresentableEntity` + `URLRepresentableIntent`（`TodoDeepLink` に綴りを集約）
  - 対象外と決めたもの: `AudioPlaybackIntent` / `CustomIntentMigratedAppIntent` /
    `LiveActivityStartingIntent` / `PredictableIntent`

### 適用済みの単発変更（フェーズに紐づかないもの）

| 変更 | 整合 | 状態 | コミット |
|------|------|------|---------|
| `@ComputedProperty` / `@DeferredProperty` | Entity 強化（#345） | ✅ keep | `e7321a9` |
| Onscreen Entities | 外部連携（#240/#343） | ✅ keep | `88deb66` |
| Interactive Snippet | ビジュアル応答（#343） | ✅ keep | `f96f0ca` |
| Intent Modes `.foreground(.dynamic)`（OpensIntent 廃止を伴う） | Intent 合成を外す副作用 → 取り消し。2026-08-27 に「適所なし」と結論（#55） | ↩︎ revert | `cab8e67` |

### Xcode 27 beta ごとの追従

| beta | 主な変更 | 対応コミット |
|------|---------|------------|
| beta 1 | iOS 27 世代へ引き上げ、`.reminders` schema 有効化 | `ed22d80` |
| beta 2 | watchOS で assistant schema 非対応化 → フォールバック追加、`VisualIntelligence` が Mac で import 可能に → `OpenCategoryIntent` 追加 | `9684418` `8ddc76f` |
| beta 3 | `PlaceDescriptor` の SSU training バグを回避し `String` へ退避、`AppShortcutsProvider` をアプリターゲットへ移動、toolbar API 追従 | `35d772f` `3280bed` |
| beta 4 | SSU バグ未修正・ワークアラウンド継続。`TransientAppEntity` 実装 | `df4a2aa` |
| beta 5 (27A5237l) | SSU バグ・watchOS assistant schema unavailable ともに未解消を再確認。コード変更なし | `647acb6` |
| beta 6 (27A5252f) | 同 2 件ともに未解消を再確認（revert → クリーンビルドで同一エラー / watchOS SDK の `@available(watchOS, unavailable)` 継続）。beta 6 で入った未記録の API は 4 つで、いずれも採用対象外と判定。コード変更なし | 経緯: `2026-08-28-xcode27-beta6-recheck.md` |

各フェーズは機能単位の小コミット + `BuildProject` 確認で進めた。R 深度（実機 Siri / Visual Intelligence）は
デバイス手動確認が必要なため、コード側は B/U まで到達させ、R は #30 に残している。
