# App Intents 中心設計 — WWDC 2026 要素 検証計画

> このリポジトリの主眼は **「App Intents を設計の中心に据えると、アプリをどう組み立てられるか」の実証**。
> 本計画のゴールは **指定 6 セッションから抽出した要素を実装し、しっかり検証できること**。
> 「分かりやすい例」として App Schema を挙げたが、それに限らず **各セッションの要素を網羅的に試す**。
>
> 作成: 2026-06-10 / 検証ブランチ: `xcode27`（27 世代ベータ SDK 用、**2026-08-27 に `main` へマージ済み**。以降の作業は `main`）
>
> **このファイルは「どのセッションの要素を、どの深度まで検証したか」の一覧**（＝到達状況の地図）。
> 実装形と落とし穴は [insights/](INSIGHTS.md)、API 単位の採用状況は
> [APP_INTENTS_API_COVERAGE.md](APP_INTENTS_API_COVERAGE.md)、**実施の記録と経緯**（どのコミットで
> 何を入れたか / 当時どう判断したか / beta ごとの追従）は
> [devlog/app-intents-centric-plan.md](devlog/app-intents-centric-plan.md)、これからやることは
> GitHub issue（#30 / #57 / #68）にある。

---

## スコープ

**対象**: 下記 6 セッションから抽出した App Intents / Siri 系の要素すべて（検証チェックリスト参照）。

**対象外**:
- `docs/references/` の広範な WWDC 2026 アップデート（Liquid Glass / Toolbar / Charts 3D 等）。今回の更新対象ではない。
- **FoundationModels（端末内 LLM）**。本リポジトリの主眼ではない。

> 単純な Todo に留まらず、App Schema / Visual Intelligence / cross-app を意味あるものにするため、
> Todo モデルを **システム型に橋渡しできる属性**（場所 / 担当者 / 所要時間）へ広げる（Phase 1）。

## 検証の深さ（凡例）

各要素の「検証」は到達できる範囲で最深を狙うが、ランタイム依存があるため 3 段階で記録する:
- **B**: ビルド/型レベルで正しく成立（コンパイル＝API 採用が妥当）
- **U**: SPM/AppIntentsTesting で perform / query を単体検証
- **R**: 実機（Siri / Spotlight / Visual Intelligence / Apple Intelligence）で挙動確認（デバイス必須・手動）

状態: ✅ 完了 / 🔨 着手中 / ⬜ 未着手 / ⏳ 要確認（シンボル/可用性）

---

## 設計の3本柱
1. **名詞 = Entity**: `AppEntity` + `@Property` 公開、関連（Category / SubTask）も Entity 化、Query で探せる・辿れる。
2. **動詞 = Intent**: 全アクションを App Intent 化、`Button(intent:)` を唯一の実行経路、Intent 合成（`OpensIntent`）まで活用。
3. **外部連携サーフェス**: App Schema / Visual Intelligence / Onscreen / cross-app / システム提案。

---

## セッション別 検証チェックリスト

### #345 App Intent フレームワークの新機能 — https://developer.apple.com/jp/videos/play/wwdc2026/345/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Entity プロパティマクロ | `@ComputedProperty` `@DeferredProperty` | `isOverdue` / `subtaskProgress` | U | ✅ |
| ValueRepresentation | `AppEntity.ValueRepresentation` `IntentValueRepresentation(exporting:importing:)` | 担当者を `IntentPerson` / 場所を `PlaceDescriptor` へ export | B | ✅ U（2026-08-12 `exported(as: IntentPerson.self)` を実 run） |
| RelevantEntities | `RelevantEntities.updateEntities(_:for:)` `AppEntityContext` | 「次の期限/緊急 Todo」を文脈寄付 | B/R | 🚫 不適合 |
| EntityCollection | `EntityCollection<TodoAppEntity>` `resolvedEntities()` | バルク完了 Intent | U | ✅ U（2026-08-12 `CompleteTodosIntent` を実 run） |
| ネイティブ Parameter 型 | `Duration` `PersonNameComponents` | 所要時間 / 担当者名を `@Parameter` | U | ✅ Phase 1 |
| @UnionValue | `UnionValue()` | 複数 Entity 型を 1 パラメータ/結果で | B | ✅ U（2026-08-12 `SearchEverythingIntent` を実 run） |
| LongRunningIntent | `LongRunningIntent` `performBackgroundTask` | 一括処理を長時間バックグラウンド | B/U | ✅ U（2026-08-12 実 run） |
| CancellableIntent | `withIntentCancellationHandler` `IntentCancellationReason` | 上記のグレースフルキャンセル | B/U | ✅(B) `8e2d637` |
| ExecutionTargets | `allowedExecutionTargets`（`IntentExecutionTargets` = `.main` / `.appIntentsExtension` / `.widgetKitExtension`） | **書き込み系はすべて `[.main]`**、読み取り系は固定しない。呼出元ごとの Intent 複製（旧 FromExtension 分離）は撤去済み | B | ✅ |
| SyncableEntity | `SyncableEntity`（`String`/`UUID` id でそのまま適合） | デバイス間 ID 同期 | B | ✅ `d347cb2` |

### #240 App Schema による Siri 体験 — https://developer.apple.com/jp/videos/play/wwdc2026/240/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| App Schema 適合 | `@AppEntity(schema: .reminders.*)` `@AppIntent(schema:)` | Todo を reminders ドメインへ意味的適合 | B/R | ✅ list / listType / `.system.searchInApp` / reminder 本体（#56 完了） |
| Transferable export | `Transferable` `ProxyRepresentation` `ValueRepresentation` | Entity を他アプリへエクスポート（title / IntentPerson / PlaceDescriptor） | B | ✅ (#44) |
| Onscreen recognition | `userActivity` `appEntityIdentifier` | 詳細画面の単一 Todo（済）+ 一覧の `forSelectionType:`（#46） | R | ✅ U（2026-08-12 `viewAnnotations()` を実 run） |

### #295 AppIntentsTesting — https://developer.apple.com/jp/videos/play/wwdc2026/295/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Intent 実行テスト | `makeIntent()` `run()`（AppIntentsTesting） | `AddTodoIntent` / `ToggleTodoCompletionIntent` / `QuickSnoozeTodoIntent` / `GetTodoSummaryIntent` を実経路で | U | ✅ U（2026-08-12 実 run 10 件グリーン） |
| Entity query テスト | 同上 | `entities(matching:)` / `entities(identifiers:)` / `allEntities()` / `suggestedEntities()` / `spotlightQuery()` | U | ✅ U（2026-08-12） |
| 複数 Intent 連鎖 | 同上 | Add → Show / Add → Toggle → Toggle を 1 テストで | U | ✅ U（2026-08-12） |

### #344 Code Along: アプリを Siri 対応 — https://developer.apple.com/jp/videos/play/wwdc2026/344/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Entity の作り分け | `@AppEntity` `IndexedEntity` `TransientAppEntity` | Category/SubTask を Entity 化、`TodoListSummaryEntity`（Transient）を `GetTodoSummaryIntent` で返す | B | ✅ |
| Spotlight セマンティック | `CSSearchableIndex` `IndexedEntity` `@Property(indexingKey:)` | title→`\.title` / description→`\.contentDescription`（#43。overload は watchOS / tvOS で unavailable なので `#if` 分岐） | B | ✅ (#43) |
| システムアクション Intent | `OpenIntent` `DeleteIntent`（system intent 群） | Open/Delete を system intent プロトコルへ | B | ✅ `375efd1`/`92221d0` |
| IntentParameter.valueState | `$param.valueState`（`.set` / `.unset`） | `UpdateTodoIntent` で「新値 / 明示クリア / 据え置き」を区別 | B | ✅ U（2026-08-12 三状態を実 run。テスト側で `.set(nil)` を出すには型付き nil が要る） |

### #343 高度な App Intent 機能 — https://developer.apple.com/jp/videos/play/wwdc2026/343/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| 取り消し可能な操作 | `UndoableIntent` `undoManager` | 削除 3 Intent + 完了トグルを undo 可能に（`TodoItemSnapshot` で同じ id へ復元） | B/U | ✅ U（2026-08-22） |
| 会話的ダイアログ | `ProvidesDialog` `IntentDialog(full:supporting:)` | Siri 応答を full/supporting で強化 | B/R | ✅(B) `1f4bbc7` |
| 対話的な質問 | `requestConfirmation` `requestChoice` | 削除確認 / スヌーズ時間選択 | B/R | ✅(B) `27fc2db`/`db6efa3` |
| ビジュアル応答 | `ShowsSnippetView` `DisplayRepresentation` | （済）Interactive Snippet | R | ✅ |
| 寄付による学習 | `IntentDonationManager` `IntentDonationMatchingPredicate` | 一度採用したが**撤去**。`perform()` 内の donate は規約違反で、`Button(intent:)` の実行はシステムが既に donate している（2026-08-30 実測）。`deleteDonations(matching:)` は削除経路に残す | B/R | ⏸ 不採用（#53） |
| セマンティック検索 | `IndexedEntity` `@Property(indexingKey:)` `.system.searchInApp` | indexingKey(#43) + in-app 検索スキーマ(#47) | B | ✅ (#43/#47) |
| Onscreen（コレクション） | `.appEntityIdentifier(forSelectionType:)` | 一覧の各行を onscreen 提供 | B | ✅ (#46)（詳細画面側は `viewAnnotations()` でテスト済み） |
| 既存統合へのエンティティ付与 | `UNMutableNotificationContent.appEntityIdentifiers` | Control のエラー通知に entity を紐付け | B | ✅ (#46) |

### #297 Visual Intelligence 統合 — https://developer.apple.com/jp/videos/play/wwdc2026/297/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| IntentValueQuery | `IntentValueQuery` `SemanticContentDescriptor` | カメラ/スクショ中の対象から該当 Todo | B/R | ✅(B) `069aa48`（**iOS シミュレータではテスト不可** — VisualIntelligence.framework が Simulator SDK に無く、ビルドから丸ごと除外されるため） |
| 結果を開く | `OpenIntent` | タップで詳細へ | B | ✅ `375efd1`(OpenTodoIntent 再利用) |
| 複数結果型 | `@UnionValue` | Todo / Category 混在結果 | B | ✅ `099dae3`(TodoOrCategory 再利用) |
| システムストア連携 | EventKit / CNContactStore | 期限→カレンダー、担当者→連絡先 | B | ⏭ 別軸(記録のみ) |

---

## 実行フェーズ（到達状況）

**フェーズごとの実施記録**（何をどのコミットで入れたか / 当時どう判断したか / beta ごとの追従）は
[docs/devlog/app-intents-centric-plan.md](devlog/app-intents-centric-plan.md#実行フェーズの実施記録2026-06-102026-08-27)
へ移した。ここには到達状況だけを置く。

| フェーズ | 内容 | 到達深度 |
|---|---|:--:|
| **0 整地** | 計画の焦点合わせ | ✅ |
| **1 基盤 + ドメイン橋渡し** | `@Property` 公開 / Category・SubTask の Entity 化 / ネイティブ型パラメータ / `ValueRepresentation` / `TransientAppEntity` | ✅ B・U |
| **2 App Schema（reminders）** | `listType` / `list` / **`reminder` 本体**（#56）+ 4 属性の書き込み経路（#85） | ✅ B |
| **3 高度な Intent** | `requestConfirmation` / `requestChoice` / system intents / `IntentDialog(full:supporting:)` | ✅ B（R は #30） |
| **4 大量・実行制御** | `EntityCollection` + `LongRunningIntent` + `CancellableIntent` / `allowedExecutionTargets` / `@UnionValue` / `SyncableEntity` | ✅ B・U |
| **5 Visual Intelligence** | `IntentValueQuery` / `.visualIntelligence.semanticContentSearch` / macOS の openable 要件 | ✅ B（実機 visual search は #30） |
| **6 テスト基盤** | AppIntentsTesting（UI テストバンドル）23 テスト | ✅ U |
| **7 WWDC 2026 追加検証（#42–#48）** | `indexingKey:` / `Transferable` / `valueState` / コレクション onscreen / `.system.searchInApp` | ✅ B |
| **10 未着手候補の消化** | `UndoableIntent` / Spotlight client state / `synonyms:` / `displayRepresentations(for:)` / `shortcutTileColor` / inflection / `systemExtraLargePortrait` | ✅ B・U |
| **11 未採用だった Intent 種別** | `SetFocusFilterIntent` / `UISceneAppIntent` + `AppIntentSceneDelegate` / `URLRepresentableEntity` | ✅ B |

対象外と決めたもの: `AudioPlaybackIntent`（再生機能なし）/ `CustomIntentMigratedAppIntent`（SiriKit 資産なし）/
`LiveActivityStartingIntent`（deprecated）/ `PredictableIntent`（donation ゼロでは提案が出ない）/
`RelevantEntities`（todo 向け `AppEntityContext` が無い）/ EventKit・Contacts 連携（別フレームワーク軸）。

各要素の**実装形と落とし穴**は [insights/03](insights/03-app-intents-core.md) 以下、**API 単位の状態**は
[APP_INTENTS_API_COVERAGE.md](APP_INTENTS_API_COVERAGE.md) にある。

---

## 未採用 API の扱い

**API ごとの採用状況は [docs/APP_INTENTS_API_COVERAGE.md](APP_INTENTS_API_COVERAGE.md) に一元化**した
（採用済み / 意図的不使用 / 対象外 / 未採用候補を全 API 分 1 行ずつ）。次の拡張を考えるとき・
新しい API を見つけたときはそちらを見る / 足す。着手すると決めたものの消化は **#68**。

**決着済みの判断**（コード側に痕跡が残らないので、結論だけここに残す）:

- `SpotlightSearchTool` + `LanguageModelSession`（#52）— **スコープ外**。前提の Spotlight への entity 寄付は
  済んでいるが、残りは FoundationModels 側の導線と結果表示 UI で、作業の主体が App Intents から離れる
- UI タップ由来の donation（#53）— **入れない**。公式の 2 方式はどちらも「UI からは Intent を直接呼ぶ」
  前提で、「UI も `Button(intent:)` で Siri と同じ経路を通す」原則と両立しない。加えて
  `Button(intent:)` の実行はシステムが既に donation として記録している（2026-08-30 実測）。
  **再訪の条件**: `PredictableIntent` による提案を機能として欲しくなったとき
- watchOS の onscreen annotation（#54）— **実装済み**。行ごとの単一 annotation（`List` に selection が
  無く `forSelectionType:` が効かない）。自動テスト不可のため手動確認は #30

> 洗い出しの経緯（`.swift` 全走査 / 公式サンプル 4 本との突き合わせ）は
> [docs/devlog/03-app-intents-core.md](devlog/03-app-intents-core.md)（2026-08-21）、
> 実装形は [docs/insights/03-app-intents-core.md](insights/03-app-intents-core.md) の Phase 9 にある。

---

## 既知の SDK 制約

> **Xcode 27 beta 6 時点で未解消**: system value 型（`PlaceDescriptor` ほか）の SSU training バグ
> （**App Shortcut に登録した Intent の `@Parameter`** に置くと発火。`AddTodoIntent.location` の `String`
> 退避のみ継続中。`TodoAppEntity.location` は 2026-08-29 に `PlaceDescriptor?` へ戻した。FB24548956）と、
> watchOS での `reminders`/`system` assistant schema unavailable（フォールバック継続中）。SDK 更新時は
> `35d772f` を revert + DerivedData クリア後クリーンビルドで再検証する
> （SSU タスクは incremental ビルドだと stale エラーを再表示するため要注意）。GM SDK 到来時の棚卸しは **#57** で追跡。
> **SSU の件は Apple 報告済み**で、リリース版 Xcode 26.6 でも再現するため GM で直る保証はない。
> 経緯: [docs/devlog/2026-08-28-ssu-system-value-type-bug.md](devlog/2026-08-28-ssu-system-value-type-bug.md) /
> [docs/devlog/app-intents-centric-plan.md](devlog/app-intents-centric-plan.md)

## availability 方針

`main` は iOS 27 ベースライン（`.reminders` 系 assistant schema が 27+ 限定のため `ed22d80` で引き上げ、
2026-08-27 のマージで `main` にも反映）。それより新しい世代の API を試す際は、deployment 27 でビルドして
"is only available in ... or newer" が出るかで世代を判定し、新世代専用なら `@available(iOS 28, *)` 相当でガード。
実装の落とし穴は `docs/insights/03-app-intents-core.md`「Xcode 27 / WWDC 2026 で採用した API」を参照。

## 参考（iOS 26 ベースラインの土台）
- wwdc2025/244「Get to know App Intents」/ wwdc2025/275「Explore new advances in App Intents」

> WWDC 2022〜2026 のセッション一覧・要点・非推奨タイムラインは `docs/WWDC_APP_INTENTS_SESSIONS.md` を参照。

