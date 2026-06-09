# WWDC 2026 アップデート整理（IntentTodo 適用検討）

> このドキュメントは WWDC 2026（iOS/iPadOS/macOS/watchOS/visionOS の次期世代 = "27" 世代 SDK）の
> アップデートのうち、**App Intents 中心設計の IntentTodo に取り込めそうなもの**を棚卸しし、
> 「すでに対応したもの / これから試せるもの / 適合が低いもの」を一望できるようにしたものです。
> 各項目には**根拠セッション URL**と `docs/references/` の対応資料を併記しています。
>
> 作成: 2026-06-10 / 対象ブランチ: `xcode27`（ベータ SDK 検証用、`main` 未マージ）

---

## 0. まず押さえる線引き — 「26 ベースライン近代化」 vs 「27 独自 API」

今回 `xcode27` ブランチで対応した 4 つ（プロパティマクロ / Intent Modes / Onscreen Entities /
Interactive Snippet）は、**deployment target iOS 26.0 のまま `@available` 無しでビルドが通りました**。
つまりこれらは **iOS 26 世代ですでに使えるベースライン API**（WWDC 2025 系）で、「26 を正しく使い切る近代化」です。

一方、下記セッション 345 / 343 / 240 / 297 が "新機能" として紹介するもの
（`EntityCollection` / `RelevantEntities` / `ValueRepresentation` / `LongRunningIntent` /
`App Schema` / `IntentDonationManager` / Visual Intelligence の `IntentValueQuery` 等）は
**WWDC 2026（27 世代）で追加**されたもので、これが「27 独自 API を試す」対象になります。

> **availability 方針メモ**: 27 独自 API を入れる場合は、`main` を 26 ベースラインに保ったまま
> `xcode27` ブランチで (a) deployment を 27 に上げる か (b) `if #available(iOS 27, *)` /
> `@available(iOS 27, *)` でガードして部分採用する、のどちらかにする。
> どの API が 26 で使えて何が 27 専用かは、**実装時に deployment 26 でビルドして
> "is only available in ... or newer" が出るかどうかで判定**するのが確実（今回の 4 機能はこの方法で 26 可と確認済み）。

---

## 1. 根拠セッション一覧（ユーザー指定の 6 本）

| # | セッション（日本語 / 英語） | URL | 主トピック |
|---|---------------------------|-----|-----------|
| 345 | App Intent フレームワークの新機能 / What's new in App Intents framework | https://developer.apple.com/jp/videos/play/wwdc2026/345/ | Entity 強化・パラメータ型拡張・実行制御 |
| 240 | App Schema によるインテリジェントな Siri 体験の構築 / Building intelligent Siri experiences with App Schema | https://developer.apple.com/jp/videos/play/wwdc2026/240/ | App Schema・Transferable・Onscreen |
| 295 | AppIntentsTesting による App Intent の検証 / Verify App Intents with AppIntentsTesting | https://developer.apple.com/jp/videos/play/wwdc2026/295/ | テストフレームワーク |
| 344 | Code Along: アプリを Siri に対応させる方法 | https://developer.apple.com/jp/videos/play/wwdc2026/344/ | App Schema 実装ハンズオン |
| 343 | Siri / Apple Intelligence 向けの高度な App Intent 機能 / Advanced App Intents techniques | https://developer.apple.com/jp/videos/play/wwdc2026/343/ | Dialog・Snippet・寄付・検索・Onscreen |
| 297 | アプリにビジュアルインテリジェンスを統合するためのベストプラクティス / Best practices for integrating Visual Intelligence | https://developer.apple.com/jp/videos/play/wwdc2026/297/ | Visual Intelligence・IntentValueQuery |

> 参考（WWDC 2025 / iOS 26 ベースラインの土台）: 「Get to know App Intents」(wwdc2025/244)、
> 「Explore new advances in App Intents」(wwdc2025/275)。今回対応の 4 機能はこの世代の API。

---

## 2. 領域別の適合マップ（App Intents / Siri 系）

凡例: ✅=`xcode27` で対応済み / 🔜=有力候補 / 🤔=適合は中 / ⛔=この Todo アプリには過剰

| 領域 | 何ができる | 主要シンボル | 根拠 | IntentTodo 適合 | 状態 |
|------|-----------|-------------|------|----------------|------|
| Entity プロパティマクロ | スナップショット外から導出/遅延取得した値を公開 | `@ComputedProperty` `@DeferredProperty` | 345 / refs:AppIntents-Updates | 高 | ✅ |
| Intent Modes | background 優先 + 動的に前面化 | `.foreground(.dynamic)` `continueInForeground` `systemContext` | 345 / refs:AppIntents-Updates | 高 | ✅ |
| Onscreen Entities | 表示中コンテンツを Siri に提供 | `.userActivity` `appEntityIdentifier` `EntityIdentifier` | 240 / 343 / 344 | 高 | ✅ |
| Interactive Snippet | 結果をボタン付き UI で提示 | `SnippetIntent` `ShowsSnippetView` `.result(view:)` | 343 | 高 | ✅ |
| **EntityCollection** | 大量エンティティを ID のみで扱い解決を遅延 | `EntityCollection<Entity>` `resolvedEntities()` | 345 | 中（一括完了/削除に有効） | 🔜 |
| **RelevantEntities** | 文脈別におすすめエンティティを寄付 | `RelevantEntities.updateEntities(_:for:)` `AppEntityContext` | 345 / 343 | 高（次の期限/緊急 Todo の提案） | 🔜 |
| **ValueRepresentation** | Entity ↔ システム型を相互変換しアプリ間連携 | `AppEntity.ValueRepresentation` `IntentValueRepresentation` | 345 / 240 | 中 | 🤔 |
| **IntentDonationManager** | 実行を学習させ Siri/Spotlight 提案を強化 | `IntentDonationManager` `IntentDonationMatchingPredicate` | 343 | 高（Add/Complete の寄付） | 🔜 |
| **LongRunningIntent** | 30 秒超の処理を継続・キャンセル対応 | `LongRunningIntent` `CancellableIntent` `performBackgroundTask` | 345 | 低（Todo の操作は短時間） | ⛔ |
| **ExecutionTargets** | メインアプリ/拡張の実行プロセスを明示制御 | `ExecutionTargets` | 345 | 中（FromExtension 回避の本筋解になり得る） | 🤔 |
| **@UnionValue パラメータ** | 1 パラメータで複数 Entity 型を受ける | `@UnionValue` | 345 / 297 | 低 | ⛔ |
| **Visual Intelligence** | カメラ/スクショから一致コンテンツを返す | `IntentValueQuery` `SemanticContentDescriptor` `VisualIntelligenceSearchIntent` | 297 / refs:Implementing-Visual-Intelligence | 低〜中（Todo は視覚対象が薄い） | 🤔 |
| **App Schema** | ドメイン語彙に準拠し Siri 理解を底上げ | `@AppEntity(schema:)` `@AppIntent(schema:)` | 240 / 344 | 中（reminders ドメイン適合次第） | 🤔 |
| **AppIntentsTesting** | 実システム経路で Intent をユニットテスト | `makeIntent()` `run()`（AppIntentsTesting） | 295 | 高（perform() を初めて素直にテスト可能） | 🔜 |

---

## 3. 各候補の詳細（なぜ効くか / どこに入れるか）

### 🔜 RelevantEntities — 「次にやること」を OS に提案させる（343 / 345）
`RelevantEntities.updateEntities(_:for:)` で「期限が近い Todo」「緊急 Todo」を文脈付きで寄付すると、
Spotlight / Siri 提案 / ウィジェット候補に反映される。Action-Centered Design（毎日確認する情報・頻繁に変わる情報）と直結。
- 入れどころ: `TodoService` の mutation 後 or 起動時に donate。既存の `WidgetReloader` 呼び出しの近く。

### 🔜 IntentDonationManager — 行動学習で提案精度を上げる（343）
`AddTodoIntent` / `ToggleTodoCompletionIntent` 実行を `IntentDonationManager` に寄付し、
よく使うアクションを Siri/Spotlight が先回り提案。`IntentDonationMatchingPredicate` で削除（Todo 消滅時）も可能。
- 入れどころ: 各 mutation Intent の `perform()` 末尾。

### 🔜 EntityCollection — 一括操作を軽く（345）
「期限切れを全部完了」「選択した複数を削除」のような複数 Todo 操作で、`@Parameter var todos: EntityCollection<TodoAppEntity>`
を使うとパラメータ解決時に全件をハイドレートしないので速い。`identifiers` だけで済む処理は解決を回避。
- 入れどころ: 新規 `CompleteTodosIntent` / `DeleteTodosIntent`（バルク版）。

### 🔜 AppIntentsTesting — perform() を本物の経路でテスト（295）
現状 `ShowTodosIntent.perform()` 等は `@Dependency` 解決の都合で SPM 単体テストを書けず、`screenTarget` 等の純関数だけ検証している。
`AppIntentsTesting` の `makeIntent()` / `run()` は実システム経路で実行するため、**perform() を初めて素直にテストできる**。
- 注意: XCUITest バンドルで動く（別プロセス）。現状の SPM Testing とは別ターゲット構成が要る。

### 🤔 ExecutionTargets — FromExtension パターンの "本筋" 解（345）
現在 Live Activity Extension での SwiftData クラッシュ回避に `*FromExtensionIntent`（todoId 版）を手動で用意している（Issue #30 A-3）。
`ExecutionTargets` で実行プロセスを明示できれば、この二重定義を畳める可能性がある。要検証だが本命の整理対象。

### 🤔 Visual Intelligence / App Schema — ドメイン適合を見てから（297 / 240 / 344）
Visual Intelligence は「視覚対象 → コンテンツ」が本質で、Todo は視覚的実体が薄いため適合は限定的（例: レシート撮影 → 買い物 Todo 化、なら有効）。
App Schema は reminders 系ドメインに語彙が用意されていれば底上げになるが、独自概念が多いと旧来の `@AppEntity` のままが無難。

---

## 4. 今回 `xcode27` で対応済みのもの（再掲・実装の根拠付き）

| 機能 | 実装箇所 | コミット | 根拠セッション / 資料 |
|------|---------|---------|----------------------|
| `@ComputedProperty` `isOverdue` / `@DeferredProperty` `subtaskProgress` | `TodoAppEntity.swift` + `TodoEntityStore.swift` | `e7321a9` | 345 / refs:AppIntents-Updates |
| `.foreground(.dynamic)` + `continueInForeground` | `ShowTodosIntent.swift` | `93d0230` | 345 / refs:AppIntents-Updates |
| Onscreen Entity（`userActivity` + `appEntityIdentifier`） | `TodoDetailView.swift` + Info.plist | `88deb66` | 240 / 343 / 344 |
| Interactive Snippet（`SnippetIntent`） | `TodoSnippetIntent.swift` + `AddTodoIntent.swift` | `f96f0ca` | 343 |

> 実装上の落とし穴（@Dependency 不可・Hashable 合成破壊・OpensIntent との矛盾・Info.plist 登録）は
> `docs/insights/03-app-intents-core.md` の「Xcode 27 / WWDC 2026 で採用した API」を参照。

---

## 5. App Intents 以外の WWDC 2026 更新（`docs/references/` にある分、Todo アプリ視点）

| 領域 | 概要 | 資料 | 適合 |
|------|------|------|------|
| FoundationModels | 端末内 LLM で Todo 自動生成 / サマリー / Tool Calling | refs:FoundationModels-Using-on-device-LLM | 高（マーキー機能。`@Generable` で構造化生成） |
| AlarmKit | 期限 Todo を本物のアラーム/タイマーに | refs:SwiftUI-AlarmKit-Integration | 中（dueDate と相性良） |
| Liquid Glass | ナビ/ツールバー/ウィジェットのガラス適応 | refs:SwiftUI/UIKit/WidgetKit-…-Liquid-Glass | 中（既に navigation 層へ限定適用済み） |
| Widgets for visionOS | visionOS 向けウィジェット | refs:Widgets-for-visionOS | 中 |
| 新 Toolbar 機能 | ツールバー API 拡張 | refs:SwiftUI-New-Toolbar-Features | 低〜中 |
| SwiftData クラス継承 | モデルの継承サポート | refs:SwiftData-Class-Inheritance | 低（現スキーマで十分） |

> その他（Swift Concurrency / InlineArray・Span / Charts 3D / StoreKit / MapKit GeoToolbox /
> Styled Text Editing / WebKit / AttributedString / Assistive Access）は現時点で Todo 機能との直接適合は低い。

---

## 6. 推奨する次の一手（優先度順・私見）

1. **FoundationModels で Todo 自動生成**（高インパクト・マーキー）。`@Generable` な `GeneratedTodo` を
   `LanguageModelSession` で生成し、`AddTodoIntent` に流す。`SystemLanguageModel.availability` でフォールバック必須。
2. **RelevantEntities + IntentDonationManager**（低リスク・体験向上）。既存 `TodoService` に donate を足すだけ。
3. **AppIntentsTesting 導入**（品質基盤）。perform() を実経路でテストできるようになる。
4. **EntityCollection でバルク操作 Intent**（自然な拡張）。
5. ExecutionTargets による FromExtension 整理は "要検証" 枠。Visual Intelligence / App Schema はドメイン適合を見てから。

---

## 参照リンク

- Apple: App Intents updates — https://developer.apple.com/documentation/Updates/AppIntents
- Apple: Adopting App Intents to support system experiences — https://developer.apple.com/documentation/AppIntents/adopting-app-intents-to-support-system-experiences
- Apple: Displaying static and interactive snippets — https://developer.apple.com/documentation/AppIntents/displaying-static-and-interactive-snippets
- Apple: Making onscreen content available to Siri and Apple Intelligence — https://developer.apple.com/documentation/AppIntents/making-onscreen-content-available-to-siri-and-apple-intelligence
- Apple: Integrating your app with visual intelligence — https://developer.apple.com/documentation/VisualIntelligence/integrating-your-app-with-visual-intelligence
- Apple: Foundation Models — https://developer.apple.com/documentation/FoundationModels
- ローカル資料: `docs/references/`（gitignore 対象）/ 実装インサイト: `docs/insights/03-app-intents-core.md`
