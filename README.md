# IntentTodo

App Intents 中心設計に基づいたマルチプラットフォーム Todo アプリです。

## 特徴

- **App Intents 中心設計**: すべてのアクションを App Intent として定義し、`Button(intent:)` で統一的に実行
- **SwiftData**: モダンなデータ永続化（CloudKit対応）
- **マルチプラットフォーム**: iOS / iPadOS / macOS（ネイティブ）/ watchOS / visionOS 対応
- **Extension対応**: Widget / Live Activity / Control Center / Complication / Siri Shortcuts / Spotlight / 集中モード
- **WWDC 2026 の App Intents 要素を網羅検証**: App Schema / Visual Intelligence / AppIntentsTesting /
  `UndoableIntent` / `LongRunningIntent` / `SyncableEntity` など（採用状況は
  [docs/APP_INTENTS_API_COVERAGE.md](docs/APP_INTENTS_API_COVERAGE.md)）
- **TDD**: テスト駆動開発で実装

## 要件

- iOS 27.0+ / macOS 27.0+ / watchOS 27.0+ / visionOS 27.0+
- Xcode 27.0+
- Swift 6.0+

## App Intents 中心設計の適応状況

### プラットフォーム別

| プラットフォーム | 実行パターン | AppIntent活用 | 検証状況 |
|:--|:--|:--|:--|
| **iOS / iPadOS** | `Button(intent:)` | ✅ 全アクション | ✅ 検証済み |
| **macOS**（ネイティブ、Catalyst ではない） | `Button(intent:)` | ✅ 全アクション | 🔶 主要アクション + CloudKit 同期は確認済み、残りは [#30](https://github.com/touyou/IntentTodo/issues/30) |
| **watchOS** | `Button(intent:)` | ✅ 全アクション | 🔲 実機確認は [#30](https://github.com/touyou/IntentTodo/issues/30) |
| **visionOS** | `Button(intent:)` + Spatial UI | ✅ 全アクション | 🔲 実機確認は [#30](https://github.com/touyou/IntentTodo/issues/30) |

### Extension別

| Extension | 実行パターン | 備考 |
|:--|:--|:--|
| **Home Widget** | `Button(intent:)` / `Link(destination:)` | Small / Medium / Large / ExtraLargePortrait。単純なアプリ起動は `Link` が公式推奨（[公式ドキュメント](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)）。行タップは `TodoDeepLink` 経由で該当 Todo の詳細へ |
| **Control Center** | `ControlWidgetButton(action:)` / `ControlWidgetToggle(isOn:action:)` | クイック追加 / 未完了数 / 完了トグル（対象を設定で固定）。値の供給は `ControlValueProvider`、`kind` は reverse-DNS 形式必須 |
| **Live Activity** | `Button(intent:)` | `ToggleTodoCompletionIntent` / `QuickSnoozeTodoIntent` が `LiveActivityIntent` に条件付き準拠 |
| **Siri / Shortcuts** | `AppShortcutsProvider` | 8 件。うち 5 件はフレーズにパラメータを埋め込み |
| **Spotlight** | `IndexedEntity` + `@Property(indexingKey:)` | iOS / macOS。名前付き index + client state バッチ |
| **Visual Intelligence** | `IntentValueQuery` + `.visualIntelligence.semanticContentSearch` | iOS / macOS（`#if canImport(VisualIntelligence)`） |
| **集中モード** | `SetFocusFilterIntent` | カテゴリ / 急ぎのみ / 完了を隠す。リストとウィジェットの両方に効く |
| **Complication** (watchOS) | 表示のみ | Circular / Corner / Rectangular / Inline |

### 定義済み AppIntent 一覧（25 本）

すべての Intent を `TodoAppIntents` SPM パッケージに集約。Extension からも `import TodoAppIntents` で参照する。
**SwiftData を書き換える Intent は `allowedExecutionTargets = [.main]`** を宣言する（表の「本体固定」列）。

| Intent | プロトコル / 特徴 | Mode | 本体固定 | 用途 |
|:--|:--|:--|:--:|:--|
| `AddTodoIntent` | `OpensIntent` | `.background` | ✅ | Todo 追加 |
| `UpdateTodoIntent` | `IntentParameter.valueState` | `.background` | ✅ | 部分更新（新値 / 明示クリア / 据え置き） |
| `ToggleTodoCompletionIntent` | `UndoableIntent` + `LiveActivityIntent`(iOS) | `.background` | ✅ | 完了切替（完了時に Live Activity を終了） |
| `SetTodoCompletionIntent` | `SetValueIntent`（内部用） | `.background` | ✅ | 完了状態の絶対値セット（Control のトグル用） |
| `CompleteTodosIntent` | `LongRunningIntent` + `CancellableIntent` + `EntityCollection` | `.background` | ✅ | バルク完了（進捗 / キャンセル対応） |
| `DeleteTodoIntent` | `UndoableIntent` + `requestConfirmation` | `.background` | ✅ | 削除（確認あり。Siri / Shortcuts 用） |
| `DeleteTodoImmediatelyIntent` | `UndoableIntent`（内部用） | `.background` | ✅ | 削除（確認なし。UI は `.confirmationDialog` で確認してから呼ぶ） |
| `DeleteTodosIntent` | `DeleteIntent` + `UndoableIntent` | `.background` | ✅ | バルク削除 |
| `ToggleFavoriteIntent` | — | `.background` | ✅ | お気に入り切替 |
| `SnoozeTodoIntent` | `requestChoice` | `.background` | ✅ | スヌーズ（期間を選ばせる） |
| `QuickSnoozeTodoIntent` | `LiveActivityIntent`（内部用） | `.background` | ✅ | スヌーズ 30 分即実行（Live Activity のボタン用） |
| `ToggleUrgentTodoIntent` | — | `.background` | ✅ | 最緊急 Todo の完了切替（Control 用） |
| `ReorderTodosIntent` | 内部用 | `.background` | ✅ | 並び替え（UI 専用） |
| `ShowTodosIntent` | `IntentDialog(full:supporting:)` + `OpensIntent` | `.foreground` | — | Todo 表示（filter で絞り込み） |
| `ShowTodoCountIntent` | — | `.background` | — | 未完了数を通知で表示（Control 用） |
| `GetTodoSummaryIntent` | `TransientAppEntity` を返す | `.background` | — | 統計サマリ（Shortcuts の条件分岐に使える） |
| `SearchEverythingIntent` | `@UnionValue` | `.background` | — | Todo + Category 横断検索 |
| `ShowTodoSearchResultsIntent` | `@AppIntent(schema: .system.searchInApp)`（watchOS 除外） | — | — | Siri からアプリ内検索 UI へ |
| `TodoSemanticContentSearchIntent` | `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` | — | — | Visual Intelligence の「もっと見る」 |
| `OpenTodoIntent` | `OpenIntent` + `URLRepresentableIntent` + `UISceneAppIntent` | `.foreground(.immediate)` | — | Todo 詳細を開く（Spotlight / ウィジェットのタップ先） |
| `OpenCategoryIntent` | `OpenIntent` | `.foreground(.immediate)` | — | カテゴリを開く（Mac の visual search 要件） |
| `LaunchAppIntent` | `TargetContentProvidingIntent`(iOS/visionOS) + `UISceneAppIntent` | `.foreground(.immediate)` | — | 画面指定でアプリ起動 |
| `TodoFocusFilterIntent` | `SetFocusFilterIntent` | `.background` | — | 集中モード連携 |
| `TodoSnippetIntent` / `TodoSummarySnippetIntent` | `SnippetIntent`（内部用） | — | — | Siri 応答のインタラクティブ表示 |

### Entity / Query

| 型 | 種別 | 備考 |
|:--|:--|:--|
| `TodoAppEntity` | `AppEntity` + `IndexedEntity` + `SyncableEntity` + `Transferable` + `URLRepresentableEntity` | `@ComputedProperty` / `@DeferredProperty` / `@Property(indexingKey:)` / `IntentPerson`・`PlaceDescriptor` への `ValueRepresentation` |
| `CategoryAppEntity` | `AppEntity` | `@AppEntity(schema: .reminders.list)`（watchOS は素の `AppEntity` にフォールバック） |
| `SubTaskAppEntity` | `AppEntity` | — |
| `TodoListSummaryEntity` | `TransientAppEntity` | `GetTodoSummaryIntent` の戻り値 |
| `TodoOrCategory` | `@UnionValue` | 横断検索 / Visual Intelligence の結果型 |
| `TodoEntityQuery` | `EntityQuery` + `EntityStringQuery` + `EnumerableEntityQuery` + `IndexedEntityQuery` | Shortcuts の Find は `EnumerableEntityQuery` で自動生成される |
| `CategoryEntityQuery` / `SubTaskEntityQuery` | `EntityQuery` + `EntityStringQuery` | — |
| `TodoVisualIntelligenceQuery` | `IntentValueQuery` | `SemanticContentDescriptor` → `[TodoOrCategory]` |

## アーキテクチャ

```
IntentTodo/
├── IntentTodo/                  # アプリターゲット (App.init で AppDependencyManager 登録)
│   ├── TodoAppShortcuts.swift   # ★AppShortcutsProvider はここ必須（パッケージ不可）
│   └── SceneDelegate.swift      # AppIntentSceneDelegate（cold start のナビゲーション）
├── IntentTodoWidget/            # Widget + Control Center (WidgetBundle.init でも登録)
├── IntentTodoLiveActivity/      # Live Activity
├── IntentTodoWatchApp/          # watchOS アプリ + Complication
├── IntentTodoUITest/            # XCUITest + AppIntentsTesting（Intent の実経路テスト）
└── Packages/
    ├── Domain/                  # データモデル（SwiftData @Model）, ActivityAttributes
    ├── Repository/              # データアクセス層
    ├── TodoAppIntents/          # ★コア：全 Intent + TodoService + Entity / Query + ヘルパー
    ├── UI/                      # iOS/iPadOS/macOS/visionOS の Views, ViewModels
    ├── LiveActivity/            # ActivityKit 管理 + ロック画面 View（iOS 限定）
    ├── WidgetUI/                # ホームウィジェットの View
    └── WatchUI/                 # watchOS の View + Complication View（watchOS 限定）
```

### 依存関係

```
Domain ← Repository ← TodoAppIntents ← UI / LiveActivity / WidgetUI / WatchUI ← App / Extensions
```

### DI パターン

`@Dependency var todoService: TodoService` / `@Dependency var navigationModel: NavigationModel` で Intent から共有状態にアクセス。`AppDependencyManager.shared.add(dependency:)` を **`App.init()` と `WidgetBundle.init()` で同期登録**することで、各プロセスで `@Dependency` が解決される。

| 呼出元 / モード | 実行プロセス | 登録場所 |
|----------------|------------|---------|
| Siri / Shortcuts / UI | メインアプリ | `App.init()` |
| Widget `Button(intent:)` + `.foreground(.immediate)` | メインアプリ | `App.init()` |
| 書き込み系（`allowedExecutionTargets = [.main]`） | メインアプリに固定 | `App.init()` |
| 読み取り系 + Widget / Control 起点 | ヒューリスティクスで決定（アプリ起動中は本体優先、未起動なら Extension） | **両方**（`WidgetBundle.init()` も必要） |

> **登録漏れはクラッシュせず「無音の失敗」になる**（stderr に `Failed to retrieve dependency of type X` が出るだけで、`Button(intent:)` 経由では画面が何も変わらない）。そのプロセスで走る Intent が触る依存は全部登録する。

### 設計思想

従来の MVVM では ViewModel や UseCase にビジネスロジックを配置しますが、本プロジェクトでは **App Intent がアプリ機能の唯一の入口** です。UseCase 層をパッケージとして持たない代わりに、ユースケースの**宣言**（名前・引数・戻り値）を App Intent が、**実装**（手続き・不変条件・副作用）を `TodoService` が受け持ちます。

> Layered / Clean Architecture との対比（対応表・砂時計図・コードの置き場を決める判定ルール）は [docs/APP_INTENT_DRIVEN_DESIGN.md](docs/APP_INTENT_DRIVEN_DESIGN.md#layered--clean-architecture-との対比) にまとめています。

#### 役割分担

| 責務 | 担当 |
|:--|:--|
| ユースケースの宣言（名前・パラメータ・システムへの公開） | App Intents |
| ビジネスロジック（CRUD、バリデーション、変更後の後処理） | `TodoService` |
| 永続化（1 レコードの CRUD） | `TodoRepositoryProtocol` |
| UI状態管理（フィルター、ソート、検索テキスト） | ViewModel |

#### Button(intent:) による宣言的なIntent実行

```swift
import AppIntents  // ← 必須

// ✅ 推奨: Button(intent:) を直接使用
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Image(systemName: "checkmark.circle")
}

// フォーム入力が必要な場合は Computed Property で動的生成
private var addTodoIntent: AddTodoIntent {
    AddTodoIntent(title: title, dueDate: dueDate)
}

Button(intent: addTodoIntent) {
    Text("Add")
}
```

- Siri/ショートカットと同じ実行経路
- Task/async のボイラープレートが不要
- SwiftData の `@Query` と組み合わせてリアクティブな更新

## セットアップ

1. リポジトリをクローン
```bash
git clone https://github.com/touyou/IntentTodo.git
cd IntentTodo
```

2. Xcode でプロジェクトを開く
```bash
open IntentTodo.xcodeproj
```

3. ビルド & 実行

## テスト

3 層で分担している（詳細は [docs/TESTING.md](docs/TESTING.md)）。

| 層 | 場所 | 実行方法 |
|:--|:--|:--|
| ユニット（Repository / `TodoService` / Intent の静的メタデータ） | `Packages/*/Tests/` | `cd Packages/<name> && swift test` |
| **AppIntentsTesting**（Intent を実経路で実行 / Query / Spotlight / onscreen annotation） | `IntentTodoUITest/AppIntents/` | Xcode の `IntentTodoUITest` スキーム（**UI テストバンドル必須**） |
| XCUITest（UI 経路だけで壊れるもの） | `IntentTodoUITest/` | 同上 |

```bash
cd Packages/Domain && swift test
cd Packages/Repository && swift test
cd Packages/TodoAppIntents && swift test
cd Packages/UI && swift test
```

## App Shortcuts

8 件を `IntentTodo/TodoAppShortcuts.swift`（アプリターゲット直下）で定義。
フレーズにはできるだけパラメータ（`AppEntity` / `AppEnum`）を埋め込んでいる。

| フレーズ（代表） | 機能 |
|---------|------|
| `Add a todo in IntentTodo` | Todo 追加 |
| `Show my <filter> todos in IntentTodo` | Todo 一覧表示（フィルタ付き） |
| `Complete <todo> in IntentTodo` | 完了切替 |
| `Star <todo> in IntentTodo` | お気に入り切替 |
| `Delete <todo> in IntentTodo` | 削除 |
| `Snooze <todo> in IntentTodo` | スヌーズ |
| `Toggle urgent todo in IntentTodo` | 最緊急 Todo の完了切替 |
| `Show todo count in IntentTodo` | 未完了数 |

## Claude Code skill として配布

このリポジトリは、本プロジェクトで蓄積した App Intent 中心設計の知見を **Claude Code plugin** として再利用できる形で同梱しています。

- 配布物: [`skills/`](skills/) 配下の 8 skill + [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)
- **場面ごとに分割**されていて、「ウィジェットにボタンを付けたい」「押しても何も起きない」「訳が反映されない」のように**やりたいこと / 症状で発火**する
- 各 skill の分担・スクリプト・インストール手順は [`skills/README.md`](skills/README.md) を参照

| skill | 場面 |
|---|---|
| `app-intents-centric-design` | 入口。11 の非交渉ルール・導入レベル・症状の振り分け |
| `app-intents-system-surfaces` | どのシステムサーフェスに出すか（ウィジェット / コントロール / Watch / カメラ / 集中モード） |
| `app-intents-execution-and-processes` | 実行プロセス・`@Dependency` 登録・パッケージ配置・プラットフォーム可用性 |
| `app-intents-ui-and-feedback` | `Button(intent:)`・ナビゲーション・dialog / snippet / 通知 |
| `app-intents-parameters-and-prompts` | パラメータと `parameterSummary`・確認 / 選択・部分更新 |
| `app-intents-entities-and-search` | Entity 設計・Spotlight・App Schema・大量データ |
| `app-intents-testing` | AppIntentsTesting・メタデータ検査・緑になる嘘テスト |
| `app-intents-localization` | Intent コピーと Siri フレーズのローカライズ |

## ドキュメント

**現在のルール**

- [AGENTS.md](AGENTS.md) - エージェント / 開発者向けの入口（環境・非交渉ルール・全ドキュメントの目次）
- [docs/AGENTS.md](docs/AGENTS.md) - App Intents 中心設計ガイド（思想・核心原則・実装時に確認すること）
- [docs/APP_INTENT_DRIVEN_DESIGN.md](docs/APP_INTENT_DRIVEN_DESIGN.md) - 関連概念の整理と比較（Layered / Clean Architecture との対比）
- [docs/CODING_GUIDELINES.md](docs/CODING_GUIDELINES.md) - Swift / SwiftUI / ローカライズ / コメントの規約
- [docs/TESTING.md](docs/TESTING.md) - テストの 3 層と「緑になる嘘テスト」を避けるルール
- [docs/INSIGHTS.md](docs/INSIGHTS.md) - 開発中に得られた技術的インサイト（目次→7トピック別ファイル）

**API の地図**

- [docs/APP_INTENTS_API_COVERAGE.md](docs/APP_INTENTS_API_COVERAGE.md) - **App Intents API の採用状況マップ**（採用済み / 意図的不使用 / 対象外 / 未採用候補）
- [docs/WWDC_APP_INTENTS_SESSIONS.md](docs/WWDC_APP_INTENTS_SESSIONS.md) - WWDC 2022〜2026 のセッション別 API 一覧と非推奨タイムライン
- [docs/APP_INTENTS_CENTRIC_PLAN.md](docs/APP_INTENTS_CENTRIC_PLAN.md) - WWDC 2026 要素の検証結果（何をどこまで検証したか）
- [docs/PLAN.md](docs/PLAN.md) - 開発計画（要件・マルチプラットフォーム展開マトリクス）

**経緯と残タスク**

- [docs/devlog/](docs/devlog/README.md) - 各ルールがどういう調査・失敗・再検証を経て今の形になったか
- [GitHub issues](https://github.com/touyou/IntentTodo/issues) - **これからやること**（実機検証 #30 / GM SDK 棚卸し #57 / 未採用 API の消化 #68）
- [docs/presentation/](docs/presentation/README.md) - 登壇用のスライド骨子と想定スクリプト

> ドキュメントは「現在のルール（docs）/ 経緯（devlog）/ 残タスク（issue）」の三分割で運用している。
> 詳細は [AGENTS.md の「ドキュメント運用」](AGENTS.md#ドキュメント運用)。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。
