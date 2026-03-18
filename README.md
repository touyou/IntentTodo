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

| Extension | 実行パターン | AppIntent活用 | 公式Doc | 検証状況 | 備考 |
|:--|:--|:--|:--|:--|:--|
| **Home Widget** | `Link(destination:)` | ⚠️ 非使用 | ✅ 両方記載 | ⚠️ 一部検証 | `Button(intent:)` はアプリを開く用途には非推奨（公式Doc: Linkを使え）※1 |
| **Control Center** (ToggleUrgent) | `ControlWidgetButton(action:)` | ✅ `.background` | ✅ 記載あり | ✅ 検証済み | 通知フィードバック |
| **Control Center** (QuickAdd) | `ControlWidgetButton(action:)` | ✅ `.background` | ✅ 記載あり | 🔲 未検証 | 通知で案内→アプリで操作 |
| **Control Center** (TodoCount) | `ControlWidgetButton(action:)` | ✅ `.background` | ✅ 記載あり | 🔲 未検証 | 通知でカウント表示 |
| **Control Center → アプリ起動** | `OpenIntent` | ❌ 未動作 | ✅ 記載あり | ❌ iOS 26で不具合 | 公式Docには `OpenIntent` 用init が存在するが動作しない ※2 |
| **Live Activity** | `Button(intent:)` | ✅ `LiveActivityIntent` | ✅ 記載あり | 🔲 未検証 | 完了/スヌーズ |
| **Siri / Shortcuts** | `AppShortcutsProvider` | ✅ 4ショートカット | ✅ 記載あり | 🔲 未検証 | Siriフレーズ定義済み |
| **Spotlight** | `IndexedEntity` | ✅ 検索/列挙 | ✅ 記載あり | 🔲 未検証 | iOS/macOSのみ |
| **Complication** (watchOS) | 表示のみ | ─ | ✅ 記載あり | 🔲 未検証 | データ表示用 |

### 凡例

- ✅ 検証済み / 記載あり: 実機で動作確認完了 / Apple公式ドキュメントに記載
- ⚠️ 一部検証: 動作するが制限あり（ワークアラウンド使用中）
- 🔲 未検証: 実装済みだが実機検証が未完了
- ❌ 未動作: 公式ドキュメントに記載があるが iOS 26 で動作しない

### 既知の制限事項

1. **Home Widget** ※1: 公式ドキュメント「Adding interactivity to widgets and Live Activities」に「An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use Link」と明記されており、アプリ起動目的の `Button(intent:)` は意図的に非サポート。`Link(destination:)` + URLスキームが正規の方法
2. **Control Center → アプリ起動** ※2: `ControlWidgetButton` に `OpenIntent` 専用イニシャライザ（"Creates a button template for a control that launches an app"）が公式ドキュメントに存在するが、iOS 26 で実際に動作しない。10種類のアプローチを試行済み。`.background` Intent + 通知フィードバックで代替中（詳細は [docs/INSIGHTS.md](docs/INSIGHTS.md) Section 18）

### 定義済み AppIntent 一覧

#### コアIntent（TodoAppIntents パッケージ）

| Intent | 種別 | Mode | 用途 |
|:--|:--|:--|:--|
| `AddTodoIntent` | Action | `.background` | Todo追加 |
| `ToggleTodoCompletionIntent` | Action | `.background` | 完了/未完了切替 |
| `DeleteTodoIntent` | Action | `.background` | Todo削除 |
| `ToggleFavoriteIntent` | Action | `.background` | お気に入り切替 |
| `ShowTodosIntent` | Query | `.foreground` | 全Todo表示 |
| `ShowIncompleteTodosIntent` | Query | `.foreground` | 未完了Todo表示 |
| `ShowFavoriteTodosIntent` | Query | `.foreground` | お気に入りTodo表示 |
| `LaunchAppIntent` | Navigation | `.foreground` | 画面指定でアプリ起動 |
| `OpenAddTodoIntent` | Navigation | `.foreground` | 追加画面を開く |
| `OpenTodoListIntent` | Navigation | `.foreground` | 一覧画面を開く |

#### Widget Extension専用Intent

| Intent | Mode | 用途 |
|:--|:--|:--|
| `ToggleUrgentTodoIntent` | `.background` | 緊急Todoの完了切替 |
| `QuickAddTodoNotifyIntent` | `.background` | Todo追加を通知で案内 |
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
- [docs/INSIGHTS.md](docs/INSIGHTS.md) - 開発中に得られた技術的インサイト
- [docs/PLAN.md](docs/PLAN.md) - 開発計画

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。
