# 引き継ぎ — App Intents 中心設計 WWDC2026 要素検証（xcode27 ブランチ）

> このファイルは作業を別セッションで再開するための引き継ぎメモ。
> 最終更新: 2026-06-10

## 0. まず読む

1. **`docs/APP_INTENTS_CENTRIC_PLAN.md`** — 目的・スコープ・セッション別検証チェックリスト・フェーズ計画。
2. **`docs/insights/03-app-intents-core.md`** の「Xcode 27 / WWDC 2026 で採用した API」節 — 実装パターンと**落とし穴**（再開時に踏まないこと）。

## 1. 前提（変えないこと）

- **目的**: 「App Intents を設計の中心に据えるとどう組み立てられるか」の実証。指定 6 セッション
  (345/240/295/344/343/297) の要素を **xcode27 ブランチで網羅的に実装・検証**する。
- **スコープ外**: `docs/references/` の広範な WWDC2026 更新、**FoundationModels**（生成AI）。
- **ブランチ**: `xcode27`（26.x ベータ SDK 検証用、**main 未マージ**。ベータ中は分離維持）。
- **進め方**: 機能ごとに小さくコミット + 各段で `BuildProject` 確認（細かいコミットで OK）。残タスクを
  中途半端に残さず、各要素は完了させるかブロッカーを記録して保留にする。
- **現在ビルド緑**。`git status` の唯一の差分 `IntentTodoWatchApp …xcscheme` は元からの変更で本作業外。

## 2. 完了済み（コミット付き）

### Phase 0 整地
- `cab8e67` revert: ShowTodosIntent を Intent 合成(OpensIntent)へ戻す（`.foreground(.dynamic)` は保留、適所再選定）
- `c3ba707` 検証計画ドキュメント整備

### Phase 1 基盤 + ドメイン橋渡し ✅
- `48348aa` TodoAppEntity 主要属性を `@Property` 公開
- `1ef65ec` Category/SubTask を AppEntity 化 + Query、Todo→Category 関係公開
- `002e6a9` `Duration` をネイティブ Parameter 型で導入
- `6ca1c09` `PersonNameComponents`（担当者）
- `5e3b4c7` `PlaceDescriptor`（場所, GeoToolbox）

### Phase 2 App Schema(reminders) ✅（list 階層）/ ⏳（reminder 本体は保留）
- `ed22d80` **iOS 27 世代へ引き上げ**（全 Package `.v27` + tools 6.4、xcodeproj deployment 27.0）+ `TodoListType`→`@AppEnum(schema: .reminders.listType)`
- `25d1d61` `CategoryAppEntity`→`@AppEntity(schema: .reminders.list)`
- `bad37a3` 知見記録（reminder 本体保留の理由）

### Phase 3 高度な Intent ✅（B 深度で完了。R=実機 Siri 手動確認は残る）
- `27fc2db` DeleteTodoIntent に `requestConfirmation(dialog:)`
- `b4dbd63` IntentDonationManager（Add で `donate()` / Delete で `deleteDonations(matching:.entityIdentifiers([EntityIdentifier(for:)]))`）
- `db6efa3` SnoozeTodoIntent に `requestChoice`（30分/1時間/1日のスヌーズ時間選択）。`IntentChoiceOption` は Equatable
- `375efd1` `OpenTodoIntent`（system intent `OpenIntent` 適合、target: TodoAppEntity → showDetail）
- `92221d0` `DeleteTodosIntent`（system intent `DeleteIntent` 適合、`entities: [TodoAppEntity]` のバルク削除）
- `1f4bbc7` ShowTodosIntent の dialog を `IntentDialog(full:supporting:)` に強化
- 🚫 `RelevantEntities` は **不適合と確定**: `AppEntityContext` が `.audio(.nowPlaying)` 等のドメイン固有 context
  しか持たず、todo/reminders 向けが無い。Apple が追加するまで保留（insights/03 に記録）。

## 3. 残作業（次セッションの起点）

> Phase 3 は完了。次は **Phase 4**（推奨順: 4 → 5 → 6）。

### Phase 4 大量・実行制御（#345）
- `EntityCollection<TodoAppEntity>` でバルク完了/削除 Intent（新設）
- `LongRunningIntent` + `CancellableIntent`（`withIntentCancellationHandler`）
- `allowedExecutionTargets`（`IntentExecutionTargets`）— FromExtension 二重定義の整理可否を検証
- `@UnionValue`（`UnionValue()` マクロ）
- `SyncableEntity`（id が UUID なら `struct ... : AppEntity, SyncableEntity` 追加だけ。Phase 5 と相性）

### Phase 5 Visual Intelligence（#297）
- `IntentValueQuery` + `SemanticContentDescriptor`（カメラ/スクショ → 該当 Todo）
- `OpenIntent`（結果タップ）/ `@UnionValue`（複数結果型）/ EventKit・Contacts 連携

### Phase 6 テスト基盤（#295）
- `AppIntentsTesting`（`makeIntent()` / `run()`）で perform / query / 複数 Intent 連鎖を検証。
  ⚠️ XCUITest バンドルで動く（別ターゲット構成が要る点に注意）。SPM Testing とは別。

### 保留（独立タスク化）
- **コア TodoAppEntity → `@AppEntity(schema: .reminders.reminder)`**。判明事項（probe 検証済）:
  - マクロ生成 init は **`EntityProperty<T>` 引数**を取り、自前の順次代入 init は
    `self.images used before being initialized` で弾かれる（SDK27 @State マクロ化と同根）。
  - reminder スキーマは `section` / `locationTrigger` 等の **入れ子サブエンティティを再帰要求**。
  - 解法候補: entity を「スキーマ純正形（extra を計算プロパティ化 or 除去）」に作り替え、`init(from:)` を
    マクロ生成 init へ委譲。`section`/`locationTrigger`(.reminders.section/.locationTrigger) も定義要。
    大きい再設計のため独立 PR 推奨。詳細は insights/03 参照。

## 4. 再開時の決まり事（落とし穴の要点）

- **AppEntity は `@Dependency` 不可**（intents 専用）。entity の遅延取得は `TodoEntityStore.container` 経由。
- **`@Property` / スキーママクロ導入で `Hashable` 合成が壊れる** → `==`/`hash(into:)` を明示実装。
- **`@Property` / マクロ propertyの init は、プレーン格納プロパティを先に代入**（DI 順序）。
- **`.reminders` 等のスキーマは iOS 27+ 限定**（deployment 27 + tools 6.4 で対応済）。
- `Domain.Category` は型名衝突するので限定必須。
- 新規 `*FromExtensionIntent` 変種は**追加しない**（LA/Widget 専用ワークアラウンド）。
- データ更新 Intent は末尾で Widget reload（`TodoService` の defer で自動。新規 Service メソッドでも踏襲）。

## 5. 再開手順

1. `git switch xcode27` → `BuildProject` で緑を確認。
2. `docs/APP_INTENTS_CENTRIC_PLAN.md` のチェックリストで次要素を選ぶ（推奨順: Phase 4 → 5 → 6）。
3. 新 API は実装前に `DocumentationSearch` / 必要なら `WebFetch` でシンボル・可用性を確定（特に RelevantEntities）。
4. 機能ごとに実装 → `BuildProject` → 該当 SPM テスト → コミット。落とし穴は insights/03 に追記。
