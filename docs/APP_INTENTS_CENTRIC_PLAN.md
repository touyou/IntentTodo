# App Intents 中心設計 — WWDC 2026 要素 検証計画

> このリポジトリの主眼は **「App Intents を設計の中心に据えると、アプリをどう組み立てられるか」の実証**。
> 本計画のゴールは **指定 6 セッションから抽出した要素を `xcode27` ブランチで実装し、しっかり検証できること**。
> 「分かりやすい例」として App Schema を挙げたが、それに限らず **各セッションの要素を網羅的に試す**。
>
> 作成: 2026-06-10 / 対象ブランチ: `xcode27`（ベータ SDK 検証用、`main` 未マージ）

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
| ValueRepresentation | `AppEntity.ValueRepresentation` `IntentValueRepresentation(exporting:importing:)` | 担当者を `IntentPerson` / 場所を `PlaceDescriptor` へ export | B | ✅ (#44) |
| RelevantEntities | `RelevantEntities.updateEntities(_:for:)` `AppEntityContext` | 「次の期限/緊急 Todo」を文脈寄付 | B/R | 🚫 不適合 |
| EntityCollection | `EntityCollection<TodoAppEntity>` `resolvedEntities()` | バルク完了 Intent | U | ✅(B) `8e2d637` |
| ネイティブ Parameter 型 | `Duration` `PersonNameComponents` | 所要時間 / 担当者名を `@Parameter` | U | ✅ Phase 1 |
| @UnionValue | `UnionValue()` | 複数 Entity 型を 1 パラメータ/結果で | B | ✅ `099dae3` |
| LongRunningIntent | `LongRunningIntent` `performBackgroundTask` | 一括処理を長時間バックグラウンド | B/U | ✅(B) `8e2d637` |
| CancellableIntent | `withIntentCancellationHandler` `IntentCancellationReason` | 上記のグレースフルキャンセル | B/U | ✅(B) `8e2d637` |
| ExecutionTargets | `allowedExecutionTargets`（`IntentExecutionTargets` = `.main` / `.appIntentsExtension` / `.widgetKitExtension`） | FromExtension 整理可否を検証→**統合不可と結論**（#42 で `.widgetKitExtension` の存在を反映、結論不変） | B | ✅ `8e2d637` |
| SyncableEntity | `SyncableEntity`（`String`/`UUID` id でそのまま適合） | デバイス間 ID 同期 | B | ✅ `d347cb2` |

### #240 App Schema による Siri 体験 — https://developer.apple.com/jp/videos/play/wwdc2026/240/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| App Schema 適合 | `@AppEntity(schema: .reminders.*)` `@AppIntent(schema:)` | Todo を reminders ドメインへ意味的適合 | B/R | ⬜ |
| Transferable export | `Transferable` `ProxyRepresentation` `ValueRepresentation` | Entity を他アプリへエクスポート（title / IntentPerson / PlaceDescriptor） | B | ✅ (#44) |
| Onscreen recognition | `userActivity` `appEntityIdentifier` | 詳細画面の単一 Todo（済）+ 一覧の `forSelectionType:`（#46） | R | ✅ |

### #295 AppIntentsTesting — https://developer.apple.com/jp/videos/play/wwdc2026/295/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Intent 実行テスト | `makeIntent()` `run()`（AppIntentsTesting） | `AddTodoIntent` を実経路で | U | ✅(B) `be7cf2b` |
| Entity query テスト | 同上 | `entities(matching:)` | U | ✅(B) `be7cf2b` |
| 複数 Intent 連鎖 | 同上 | Add → Show を 1 テストで | U | ✅(B) `be7cf2b` |

### #344 Code Along: アプリを Siri 対応 — https://developer.apple.com/jp/videos/play/wwdc2026/344/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Entity の作り分け | `@AppEntity` `IndexedEntity` `TransientAppEntity` | Category/SubTask を Entity 化、検索用 Transient を試す | B/U | 🔨 |
| Spotlight セマンティック | `CSSearchableIndex` `IndexedEntity` `@Property(indexingKey:)` | title→`\.title` / description→`\.contentDescription`（#43。iOS/macOS 限定 overload） | B | ✅ (#43) |
| システムアクション Intent | `OpenIntent` `DeleteIntent`（system intent 群） | Open/Delete を system intent プロトコルへ | B | ✅ `375efd1`/`92221d0` |
| IntentParameter.valueState | `$param.valueState`（`.set` / `.unset`） | `UpdateTodoIntent` で「新値 / 明示クリア / 据え置き」を区別 | B | ✅ (#45) |

### #343 高度な App Intent 機能 — https://developer.apple.com/jp/videos/play/wwdc2026/343/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| 会話的ダイアログ | `ProvidesDialog` `IntentDialog(full:supporting:)` | Siri 応答を full/supporting で強化 | B/R | ✅(B) `1f4bbc7` |
| 対話的な質問 | `requestConfirmation` `requestChoice` | 削除確認 / スヌーズ時間選択 | B/R | ✅(B) `27fc2db`/`db6efa3` |
| ビジュアル応答 | `ShowsSnippetView` `DisplayRepresentation` | （済）Interactive Snippet | R | ✅ |
| 寄付による学習 | `IntentDonationManager` `IntentDonationMatchingPredicate` | Add/Complete を寄付、削除時 predicate | B/R | ⬜ |
| セマンティック検索 | `IndexedEntity` `@Property(indexingKey:)` `.system.search` | indexingKey(#43) + in-app 検索スキーマ(#47) | B | ✅ (#43/#47) |
| Onscreen（コレクション） | `.appEntityIdentifier(forSelectionType:)` | 一覧の各行を onscreen 提供 | B | ✅ (#46) |
| 既存統合へのエンティティ付与 | `UNMutableNotificationContent.appEntityIdentifiers` | toggle 通知に entity を紐付け | B | ✅ (#46) |

### #297 Visual Intelligence 統合 — https://developer.apple.com/jp/videos/play/wwdc2026/297/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| IntentValueQuery | `IntentValueQuery` `SemanticContentDescriptor` | カメラ/スクショ中の対象から該当 Todo | B/R | ✅(B) `069aa48` |
| 結果を開く | `OpenIntent` | タップで詳細へ | B | ✅ `375efd1`(OpenTodoIntent 再利用) |
| 複数結果型 | `@UnionValue` | Todo / Category 混在結果 | B | ✅ `099dae3`(TodoOrCategory 再利用) |
| システムストア連携 | EventKit / CNContactStore | 期限→カレンダー、担当者→連絡先 | B | ⏭ 別軸(記録のみ) |

---

## 実行フェーズ（順序）

- **Phase 0 整地** ✅: `#2` を Intent 合成へ revert（`cab8e67`）、本計画を主眼に再焦点化。
- **Phase 1 基盤 + ドメイン橋渡し** 🔨（大半完了）:
  - ✅ `TodoAppEntity` の主要属性を `@Property` 公開（`48348aa`）
  - ✅ Category / SubTask を AppEntity 化 + Query（`1ef65ec`）、Todo→Category 関係を公開
  - ✅ `Duration`（`002e6a9`）/ `PersonNameComponents`（`6ca1c09`）/ `PlaceDescriptor`（`5e3b4c7`）を
    ネイティブ型として `@Parameter` + `@Property` 検証（保存は CloudKit 互換 primitive、入力は system 型）
  - ✅ `ValueRepresentation`(→`IntentPerson` / `PlaceDescriptor`) を `Transferable` 経由で実装（#44）
  - ⬜ 残: `TransientAppEntity` / `EntityPropertyQuery`（後続 or Phase 4 と統合）
- **Phase 2 App Schema（reminders）** ✅（list 階層で適合・検証）/ ⏳（reminder 本体は保留）:
  - ✅ xcode27 を iOS 27 世代へ引き上げ（`.reminders` は iOS 27+ 限定のため）`ed22d80`
  - ✅ `TodoListType` → `@AppEnum(schema: .reminders.listType)` `ed22d80`
  - ✅ `CategoryAppEntity` → `@AppEntity(schema: .reminders.list)`（Category = reminders のリスト）`25d1d61`
  - ⏳ コア `TodoAppEntity` → `@AppEntity(schema: .reminders.reminder)` は **保留**（#48 で優先度再考 → 据え置き）。
    判明事項（probe 検証）: reminder スキーマはマクロ生成 init が `EntityProperty<T>` 引数を取り、
    さらに `section` / `locationTrigger` 等の **入れ子サブエンティティを再帰的に要求**するため、
    モデルから組み立てる自前 init と相性が悪く深掘りが必要。連携面では list 適合で App Schema の
    仕組み自体は検証済みのため、reminder 本体適合は独立タスクとして将来再挑戦する。
    **#48 再評価**: 具体的前提（`.reminders.section` = name+list / `.reminders.locationTrigger` = place(PlaceDescriptor)+event /
    `.reminders.locationTriggerEvent` = arrive/depart）を確認したが、コアブロッカー（生成 init の `EntityProperty<T>` +
    初期化規約）はサブエンティティを揃えても不変。**新 Siri 連携は本体適合なしでも成立**（list 適合 + discoverable な
    自前 Intent 群 + `OpenIntent`/`DeleteIntent` + `.system.search`(#47) + `indexingKey`(#43)）と確認したため、本体適合は
    SDK のスキーママクロ init 規約が扱いやすくなるのを待つ独立タスクとして据え置く。詳細は insights/03「Phase 7」。
- **Phase 3 高度な Intent** ✅（B 深度で完了。R は実機 Siri 手動確認が残る）: #343
  - ✅ `requestConfirmation`（DeleteTodoIntent）`27fc2db`
  - ✅ `IntentDonationManager`（Add で donate / Delete で deleteDonations）`b4dbd63`
  - ✅ `requestChoice`（SnoozeTodoIntent でスヌーズ時間選択）`db6efa3`
  - ✅ system intents: `OpenIntent`→`OpenTodoIntent` `375efd1` / `DeleteIntent`→`DeleteTodosIntent`（バルク）`92221d0`
  - ✅ 会話ダイアログ `IntentDialog(full:supporting:)`（ShowTodosIntent）`1f4bbc7`
  - 🚫 `RelevantEntities`: **Todo/reminders ドメインに適合する `AppEntityContext` が存在しない**（`.audio(.nowPlaying)`
    と framework overlay の domain context のみ）ため適合不能。詳細は insights/03 参照。
- **Phase 4 大量・実行制御** ✅（B 深度で完了。U/R は実機・一部テストが残る）: #345
  - ✅ `CompleteTodosIntent` で `EntityCollection` + `LongRunningIntent` + `CancellableIntent` を同時実装 `8e2d637`
  - ✅ `allowedExecutionTargets [.main]`。FromExtension 分離は entity 解決回避が目的でプロセス制御では**統合不可**と結論 `8e2d637`
    （#42: 選択肢は `.main` / `.appIntentsExtension` / `.widgetKitExtension` の 3 種。`.widgetKitExtension` を踏まえても
    LA は target 対象外 + entity 解決の有無は target で変えられないため結論不変。entity 解決の実行先が `[.main]` で本体に
    寄るかは R 深度で未検証）
  - ✅ `@UnionValue`（`TodoOrCategory`）+ `SearchEverythingIntent` `099dae3`
  - ✅ `SyncableEntity`（`TodoAppEntity`、String UUID id でそのまま適合）`d347cb2`
  - 詳細・落とし穴は insights/03「Phase 4: 大量・実行制御」を参照。
- **Phase 5 Visual Intelligence** ✅（B 深度で完了。R=実機 visual search は手動確認が残る）: #297
  - ✅ `TodoVisualIntelligenceQuery: IntentValueQuery`（`values(for: SemanticContentDescriptor)` → `[TodoOrCategory]`）`069aa48`
  - ✅ `TodoSemanticContentSearchIntent`（`@AppIntent(schema: .visualIntelligence.semanticContentSearch)`）`069aa48`
  - ✅ 結果タップ=`OpenTodoIntent` / 複数結果型=`@UnionValue TodoOrCategory` を再利用
  - ⏭ EventKit/Contacts は別フレームワーク連携のため本ブランチ対象外（記録のみ）。詳細 insights/03。
- **Phase 6 テスト基盤** ✅（B 深度で完了。実 run は手動/CI）: #295
  - ✅ `IntentTodoUITest`（UIテストバンドル必須）に AppIntentsTesting テストを追加 `be7cf2b`
  - ✅ `makeIntent`/`run`(AddTodo) / `entities(matching:)` / Add→Show 連鎖。buildForTesting + live diagnostics 0件。
  - 自己クリーンアップ設計（一意タイトルで作成→削除）。詳細 insights/03。
- **Phase 7 WWDC 2026 追加検証（#42–#48）** ✅（B 深度。iOS/visionOS/watchOS の 3 スキームで `BuildProject` グリーン）:
  - ✅ #42: `allowedExecutionTargets` に `.widgetKitExtension` がある旨を記録訂正（FromExtension 統合不可の結論は不変）
  - ✅ #43: `@Property(indexingKey:)` で title→`\.title` / 新設 description→`\.contentDescription`（iOS/macOS 限定 overload を `#if` 分岐）
  - ✅ #44: `TodoAppEntity: Transferable` + `ValueRepresentation` で title / `IntentPerson`(担当者) / `PlaceDescriptor`(場所) を export
  - ✅ #45: `UpdateTodoIntent` + `IntentParameter.valueState` + `TodoService.update`/`FieldUpdate`（新値/明示クリア/据え置きを区別）
  - ✅ #46: 一覧に `.appEntityIdentifier(forSelectionType:)` / toggle 通知に `UNMutableNotificationContent.appEntityIdentifiers`
  - ✅ #47: `ShowTodoSearchResultsIntent`（`@AppIntent(schema: .system.search)`）+ `NavigationModel.pendingSearchText` 配線。ownership/requestValue は未採用
  - ✅ #48: reminder 本体スキーマ適合は再評価のうえ据え置き（list 適合 + 自前 Intent で新 Siri 連携は成立を確認）
  - 詳細・落とし穴は insights/03「Phase 7」。R 深度（実機 Siri/Spotlight/Visual Intelligence）は手動。

> 各フェーズは機能単位の小コミット + `BuildProject` 確認で進める。R 深度（実機 Siri/Visual Intelligence）は
> デバイス手動確認が必要なため、コード側は B/U まで到達させ、R は別途手動検証メモを残す。

---

## すでに適用済みの変更

| 変更 | 整合 | 状態 | コミット |
|------|------|------|---------|
| `@ComputedProperty` / `@DeferredProperty` | Entity 強化（#345） | ✅ keep | `e7321a9` |
| Onscreen Entities | 外部連携（#240/#343） | ✅ keep | `88deb66` |
| Interactive Snippet | ビジュアル応答（#343） | ✅ keep | `f96f0ca` |
| Intent Modes `.foreground(.dynamic)`（OpensIntent 廃止を伴う） | Intent 合成を外す副作用 → 取り消し | ↩︎ revert | `cab8e67` |

---

## availability 方針

`main` は iOS 26 ベースライン維持。`xcode27` で 27 世代 API を試す際は、deployment 26 でビルドして
"is only available in ... or newer" が出るかで 26/27 を判定し、27 専用なら `@available(iOS 27, *)` でガード。
実装の落とし穴は `docs/insights/03-app-intents-core.md`「Xcode 27 / WWDC 2026 で採用した API」を参照。

## 参考（iOS 26 ベースラインの土台）
- wwdc2025/244「Get to know App Intents」/ wwdc2025/275「Explore new advances in App Intents」
