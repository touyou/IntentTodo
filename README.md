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
| **Home Widget** | `Link(destination:)` | アプリ起動目的は Apple 公式推奨で `Link` |
| **Control Center** | `ControlWidgetButton(action:)` | `.foreground(.immediate)` / `.background` どちらも使用可能（`kind` は reverse-domain 形式） |
| **Live Activity** | `Button(intent:)` | `LiveActivityIntent` プロトコル準拠 |
| **Siri / Shortcuts** | `AppShortcutsProvider` | Siri フレーズ定義済み |
| **Spotlight** | `IndexedEntity` | iOS / macOS |
| **Complication** (watchOS) | 表示のみ | データ表示用 |

### 定義済み AppIntent 一覧

#### コア Intent（TodoAppIntents パッケージ）

| Intent | 種別 | Mode | 用途 |
|:--|:--|:--|:--|
| `AddTodoIntent` | Action | `[.background, .foreground(.deferred)]` | Todo 追加 |
| `ToggleTodoCompletionIntent` | Action | `.background` | 完了/未完了切替 |
| `DeleteTodoIntent` | Action | `.background` | Todo 削除 |
| `ToggleFavoriteIntent` | Action | `.background` | お気に入り切替 |
| `ShowTodosIntent` | Query | `.foreground` | Todo 表示（filter で絞り込み） |
| `LaunchAppIntent` | Navigation | `.foreground(.immediate)` | 画面指定でアプリ起動（target で遷移先指定） |

#### Widget Extension 専用 Intent

| Intent | Mode | 用途 |
|:--|:--|:--|
| `ToggleUrgentTodoIntent` | `.background` | 緊急 Todo の完了切替 |
| `ShowTodoCountIntent` | `.background` | 未完了数を通知で表示 |

#### Live Activity専用Intent

| Intent | 用途 |
|:--|:--|
| `CompleteTodoFromActivityIntent` | アクティビティからTodo完了 |
| `SnoozeTodoIntent` | 期限を30分延長 |

## アーキテクチャ

```
IntentTodo/
├── IntentTodo/                  # アプリターゲット
├── IntentTodoWidget/            # Widget + Control Center
├── IntentTodoLiveActivity/      # Live Activity
├── IntentTodoWatchApp/          # watchOS
└── Packages/
    ├── Domain/                  # データモデル（SwiftData @Model）
    ├── Repository/              # データアクセス層
    ├── TodoAppIntents/          # ★コア：Intent + ビジネスロジック
    └── UI/                      # Views, ViewModels
```

### 依存関係

```
Domain ← Repository ← TodoAppIntents ← UI ← App
```

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
