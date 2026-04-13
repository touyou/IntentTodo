# IntentTodo

App Intents 中心設計に基づいたマルチプラットフォーム Todo アプリです。

## 特徴

- **App Intents 中心設計**: すべてのアクションを App Intent として定義し、`Button(intent:)` で統一的に実行
- **SwiftData**: モダンなデータ永続化（CloudKit対応）
- **マルチプラットフォーム**: iOS / macOS / watchOS / visionOS 対応
- **Extension対応**: Widget / Live Activity / Control Center / Siri Shortcuts
- **TDD**: テスト駆動開発で実装

## 要件

- iOS 26.0+ / macOS 26.0+ / watchOS 26.0+ / visionOS 26.0+
- Xcode 26.0+
- Swift 6.0+

## App Intents 中心設計の適応状況

### プラットフォーム別

| プラットフォーム | 実行パターン | AppIntent活用 | 公式Doc | 検証状況 |
|:--|:--|:--|:--|:--|
| **iOS / iPadOS** | `Button(intent:)` | ✅ 全アクション | ✅ 記載あり | ✅ 検証済み |
| **macOS** | `Button(intent:)` | ✅ 全アクション | ✅ 記載あり | 🔲 未検証 |
| **watchOS** | `Button(intent:)` | ✅ 全アクション | ✅ 記載あり | 🔲 未検証 |
| **visionOS** | `Button(intent:)` + Spatial UI | ✅ 全アクション | ✅ 記載あり | 🔲 未検証 |

### Extension別

| Extension | 実行パターン | 備考 |
|:--|:--|:--|
| **Home Widget** | `Button(intent:)` / `Link(destination:)` | Large Widget の Add Todo は `Button(intent: LaunchAppIntent.addTodo())` で動作確認済み。Apple 公式は単純なアプリ起動なら `Link` を推奨 |
| **Control Center** | `ControlWidgetButton(action:)` | `.foreground(.immediate)` で `LaunchAppIntent`、`.background` で `ToggleUrgentTodoIntent` / `ShowTodoCountIntent` を呼出（`kind` は reverse-domain 形式必須） |
| **Live Activity** | `Button(intent:)` | `ToggleTodoCompletionIntent` / `SnoozeTodoIntent` が `LiveActivityIntent` 条件付き準拠 |
| **Siri / Shortcuts** | `AppShortcutsProvider` | Siri フレーズ定義済み |
| **Spotlight** | `IndexedEntity` | iOS / macOS |
| **Complication** (watchOS) | 表示のみ | データ表示用 |

### 定義済み AppIntent 一覧

すべての Intent を `TodoAppIntents` SPM パッケージに集約。Extension からも `import TodoAppIntents` で参照する。

| Intent | プロトコル | Mode | 用途 |
|:--|:--|:--|:--|
| `AddTodoIntent` | `AppIntent` | `[.background, .foreground(.deferred)]` | Todo 追加 |
| `ToggleTodoCompletionIntent` | `AppIntent` + `LiveActivityIntent` (iOS) | `.background` | 完了/未完了切替（完了時に対応する Live Activity を終了） |
| `DeleteTodoIntent` | `AppIntent` | `.background` | Todo 削除 |
| `ToggleFavoriteIntent` | `AppIntent` | `.background` | お気に入り切替 |
| `ShowTodosIntent` | `AppIntent` | `.foreground` | Todo 表示（filter で絞り込み） |
| `LaunchAppIntent` | `AppIntent` + `TargetContentProvidingIntent` (iOS/visionOS) | `.foreground(.immediate)` | 画面指定でアプリ起動（target で遷移先指定） |
| `SnoozeTodoIntent` | `AppIntent` + `LiveActivityIntent` (iOS) | `.background` | 期限を 30 分延長（Live Activity も更新） |
| `ToggleUrgentTodoIntent` | `AppIntent` | `.background` | 最緊急 Todo の完了切替 + 通知（Control Center 用） |
| `ShowTodoCountIntent` | `AppIntent` | `.background` | 未完了数を通知で表示（Control Center 用） |

## アーキテクチャ

```
IntentTodo/
├── IntentTodo/                  # アプリターゲット (App.init で AppDependencyManager 登録)
├── IntentTodoWidget/            # Widget + Control Center (WidgetBundle.init でも登録)
├── IntentTodoLiveActivity/      # Live Activity
├── IntentTodoWatchApp/          # watchOS
└── Packages/
    ├── Domain/                  # データモデル（SwiftData @Model）, ActivityAttributes
    ├── Repository/              # データアクセス層
    ├── TodoAppIntents/          # ★コア：全 Intent + AppShortcuts + 通知ヘルパー
    └── UI/                      # Views, ViewModels, LiveActivityMonitor
```

### 依存関係

```
Domain ← Repository ← TodoAppIntents ← UI ← App
                              ↑
              Extensions (Widget / LiveActivity / WatchApp)
```

### DI パターン

`@Dependency var modelContainer: ModelContainer` / `@Dependency var navigationModel: NavigationModel` で Intent から共有状態にアクセス。`AppDependencyManager.shared.add(dependency:)` を **`App.init()` と `WidgetBundle.init()` で同期登録**することで、各プロセスで `@Dependency` が解決される。

| 呼出元 / モード | 実行プロセス | 登録場所 |
|----------------|------------|---------|
| Siri / Shortcuts / UI | メインアプリ | `App.init()` |
| Widget `Button(intent:)` + `.foreground(.immediate)` | メインアプリ | `App.init()` |
| Widget `ControlWidgetButton` + `.background` | Widget Extension | `WidgetBundle.init()` |

### 設計思想

従来の MVVM では ViewModel や UseCase にビジネスロジックを配置しますが、本プロジェクトでは **App Intent がビジネスロジックの唯一の場所** です。

#### App Intents vs ViewModel の役割分担

| 責務 | 担当 |
|:--|:--|
| ビジネスロジック（CRUD、バリデーション） | App Intents |
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

各パッケージで個別にテスト実行可能：

```bash
# 全テスト
cd Packages/UI && swift test

# 個別パッケージ
cd Packages/Domain && swift test
cd Packages/Repository && swift test
cd Packages/TodoAppIntents && swift test
```

## App Shortcuts

以下の Siri フレーズで操作可能：

| フレーズ | 機能 |
|---------|------|
| "Add a todo in IntentTodo" | Todo 追加 |
| "Show my todos in IntentTodo" | Todo 一覧表示 |
| "Show incomplete todos in IntentTodo" | 未完了 Todo 表示 |
| "Show favorite todos in IntentTodo" | お気に入り Todo 表示 |

## ドキュメント

- [docs/AGENTS.md](docs/AGENTS.md) - App Intents 中心設計ガイド
- [docs/INSIGHTS.md](docs/INSIGHTS.md) - 開発中に得られた技術的インサイト（目次→7トピック別ファイル）
- [docs/PLAN.md](docs/PLAN.md) - 開発計画
- [docs/APP_INTENT_DRIVEN_DESIGN.md](docs/APP_INTENT_DRIVEN_DESIGN.md) - 関連概念の整理と比較

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。
