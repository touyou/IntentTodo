# IntentTodo

App Intents 中心設計に基づいたマルチプラットフォーム Todo アプリです。

## 特徴

- **App Intents 中心設計**: すべてのアクションを App Intent として定義し、Siri/ショートカットからも実行可能
- **SwiftData**: モダンなデータ永続化
- **マルチプラットフォーム**: iOS / macOS 対応
- **TDD**: テスト駆動開発で実装

## 要件

- iOS 18.0+
- macOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## アーキテクチャ

```
IntentTodo/
├── IntentTodo/              # アプリターゲット
├── IntentTodo.xcodeproj
└── Packages/
    ├── Domain/              # データモデル（SwiftData @Model）
    ├── Repository/          # データアクセス層
    ├── TodoAppIntents/      # ★コア：Intent + ビジネスロジック
    └── UI/                  # Views, ViewModels
```

### 依存関係

```
Domain ← Repository ← TodoAppIntents ← UI ← App
```

### 設計思想

従来の MVVM では ViewModel や UseCase にビジネスロジックを配置しますが、本プロジェクトでは **App Intent がビジネスロジックの唯一の場所** です。

#### App Intents vs ViewModel の役割分担

| 責務 | 担当 |
|------|------|
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
