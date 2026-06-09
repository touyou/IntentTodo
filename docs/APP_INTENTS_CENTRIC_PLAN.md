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
| ValueRepresentation | `AppEntity.ValueRepresentation` `IntentValueRepresentation(exporting:importing:)` | 担当者を `IntentPerson` と相互変換 | B/U | ⬜ |
| RelevantEntities | `RelevantEntities.updateEntities(_:for:)` `AppEntityContext` | 「次の期限/緊急 Todo」を文脈寄付 | B/R | ⬜ |
| EntityCollection | `EntityCollection<TodoAppEntity>` `resolvedEntities()` | バルク完了/削除 Intent | U | ⬜ |
| ネイティブ Parameter 型 | `Duration` `PersonNameComponents` | 所要時間 / 担当者名を `@Parameter` | U | ⬜ |
| @UnionValue | `UnionValue()` | 複数 Entity 型を 1 パラメータ/結果で | B | ⬜ |
| LongRunningIntent | `LongRunningIntent` `performBackgroundTask` | 一括処理を長時間バックグラウンド | B/U | ⬜ |
| CancellableIntent | `withIntentCancellationHandler` `IntentCancellationReason` | 上記のグレースフルキャンセル | B/U | ⬜ |
| ExecutionTargets | `allowedExecutionTargets`（`IntentExecutionTargets`） | FromExtension 二重定義の整理可否を検証 | B | ⏳ |
| SyncableEntity | `_SyncableEntity`（要確認） | デバイス間 ID 同期 | B | ⏳ |

### #240 App Schema による Siri 体験 — https://developer.apple.com/jp/videos/play/wwdc2026/240/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| App Schema 適合 | `@AppEntity(schema: .reminders.*)` `@AppIntent(schema:)` | Todo を reminders ドメインへ意味的適合 | B/R | ⬜ |
| Transferable export | `Transferable` | Entity を他アプリへエクスポート | B | ⬜ |
| Onscreen recognition | `userActivity` `appEntityIdentifier` | （済）詳細画面の Todo を提供 | R | ✅ |

### #295 AppIntentsTesting — https://developer.apple.com/jp/videos/play/wwdc2026/295/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Intent 実行テスト | `makeIntent()` `run()`（AppIntentsTesting） | `AddTodoIntent` 等の `perform()` を実経路で | U | ⬜ |
| Entity query テスト | 同上 | `entities(matching:)` を TDD で | U | ⬜ |
| 複数 Intent 連鎖 | 同上 | Add → Toggle → Show を 1 テストで | U | ⬜ |

### #344 Code Along: アプリを Siri 対応 — https://developer.apple.com/jp/videos/play/wwdc2026/344/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| Entity の作り分け | `@AppEntity` `IndexedEntity` `TransientAppEntity` | Category/SubTask を Entity 化、検索用 Transient を試す | B/U | 🔨 |
| Spotlight セマンティック | `CSSearchableIndex` `IndexedEntity` | （一部済）semantic index 検証 | R | 🔨 |
| システムアクション Intent | `OpenIntent` `DeleteIntent`（system intent 群） | Open/Delete を system intent プロトコルへ | B | ⬜ |

### #343 高度な App Intent 機能 — https://developer.apple.com/jp/videos/play/wwdc2026/343/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| 会話的ダイアログ | `ProvidesDialog` `IntentDialog(full:supporting:)` | Siri 応答を full/supporting で強化 | B/R | 🔨 |
| 対話的な質問 | `requestConfirmation` `requestChoice` | 削除確認 / フィルタ選択 | B/R | ⬜ |
| ビジュアル応答 | `ShowsSnippetView` `DisplayRepresentation` | （済）Interactive Snippet | R | ✅ |
| 寄付による学習 | `IntentDonationManager` `IntentDonationMatchingPredicate` | Add/Complete を寄付、削除時 predicate | B/R | ⬜ |
| セマンティック検索 | `IndexedEntity` `IntentValueQuery` | 構造化検索 | B | ⬜ |
| Onscreen（コレクション） | `userActivity` + 選択アノテーション | 一覧での選択を onscreen 提供 | B/R | ⬜ |
| 既存統合へのエンティティ付与 | UserNotifications / AlarmKit / Now Playing | 通知に entity を紐付け | B | ⏳ |

### #297 Visual Intelligence 統合 — https://developer.apple.com/jp/videos/play/wwdc2026/297/

| 要素 | 主要シンボル | このアプリでの検証 | 目標深度 | 状態 |
|------|-------------|-------------------|---------|------|
| IntentValueQuery | `IntentValueQuery` `SemanticContentDescriptor` | カメラ/スクショ中の対象から該当 Todo | B/R | ⬜ |
| 結果を開く | `OpenIntent` | タップで詳細へ | B | ⬜ |
| 複数結果型 | `@UnionValue` | Todo / Category 混在結果 | B | ⬜ |
| システムストア連携 | EventKit / CNContactStore | 期限→カレンダー、担当者→連絡先 | B | ⏳ |

---

## 実行フェーズ（順序）

- **Phase 0 整地** ✅: `#2` を Intent 合成へ revert（`cab8e67`）、本計画を主眼に再焦点化。
- **Phase 1 基盤 + ドメイン橋渡し** 🔨（大半完了）:
  - ✅ `TodoAppEntity` の主要属性を `@Property` 公開（`48348aa`）
  - ✅ Category / SubTask を AppEntity 化 + Query（`1ef65ec`）、Todo→Category 関係を公開
  - ✅ `Duration`（`002e6a9`）/ `PersonNameComponents`（`6ca1c09`）/ `PlaceDescriptor`（`5e3b4c7`）を
    ネイティブ型として `@Parameter` + `@Property` 検証（保存は CloudKit 互換 primitive、入力は system 型）
  - ⬜ 残: `ValueRepresentation`(→`IntentPerson`) / `TransientAppEntity` / `EntityPropertyQuery`（後続 or Phase 4 と統合）
- **Phase 2 App Schema（reminders）**: #240 / #344。
- **Phase 3 高度な Intent**: #343（会話ダイアログ / `requestConfirmation` / `requestChoice` /
  `IntentDonationManager` / `RelevantEntities` / system intents `OpenIntent`・`DeleteIntent`）。
- **Phase 4 大量・実行制御**: #345（`EntityCollection` / `LongRunningIntent` / `CancellableIntent` /
  `allowedExecutionTargets` / `@UnionValue` / Syncable）。
- **Phase 5 Visual Intelligence**: #297（`IntentValueQuery` + Vision / `OpenIntent` / `@UnionValue` / EventKit・Contacts）。
- **Phase 6 テスト基盤**: #295（`AppIntentsTesting` で perform / query / 連鎖を検証）。

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
