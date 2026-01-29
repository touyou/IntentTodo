# IntentTodo - Agent Guide

このプロジェクトはApp Intents中心設計に基づいたマルチプラットフォームTodoアプリです。

## プロジェクト概要

### 設計思想
- **全てのアクションはApp Intentとして定義**されること
- App Intentsで定義したアクションは`Button(intent:)`で直接実行
- ロジックの二重実装を避け、App Intentsを唯一の実行経路とする

### パッケージ構成（App Intents中心設計）
```
Packages/
├── Domain/       # SwiftDataモデル、共通Entity
├── Repository/   # データアクセス層（Protocol + 実装）
├── AppIntents/   # ★コア：Intent定義 + ビジネスロジック
└── UI/           # SwiftUI Views, ViewModels（表示のみ）
```

**ポイント**:
- UseCase層は廃止 → AppIntentsがロジックを担う
- UIはIntent実行トリガーと結果表示のみ
- Repository ProtocolによりMock可能、テスタビリティ確保

## 技術要件

### ターゲット
- iOS 26.0以上
- Swift 6.2以上

### コーディング規約

#### SwiftLint
- **必須**: SwiftLintを導入し、スタイルの一貫性を保つ
- プロジェクトルートに`.swiftlint.yml`を配置
- CI/ビルド時に自動チェックを実行

#### Swift API Design Guidelines準拠
- [Swift.org API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)に従う
- 命名規則: 明確で曖昧さのない名前を使用
- メソッド名は副作用に基づいて命名（mutatingは動詞、non-mutatingは名詞）
- パラメータ名は文書化の役割を果たすように命名

#### Human Interface Guidelines (HIG)準拠
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)に従う
- 標準コンポーネントを適切に使用
- アクセシビリティを考慮した設計
- プラットフォーム慣習に沿ったUX

### テスト方針

#### TDD（テスト駆動開発）
- **Red → Green → Refactor** サイクルを遵守
- 機能実装前にテストを先に書く
- テストが通る最小限の実装を行い、その後リファクタリング

#### テスト構成
- **Unit Tests**: Testingフレームワーク使用（`@Test`構文）
- **UI Tests**: XCTest使用
- App Intents、UseCase、Repositoryは必ずユニットテストを作成

### Swift/SwiftUI ガイドライン

#### 必須ルール
- `@Observable`クラスには必ず`@MainActor`を付与
- Strict Swift Concurrencyを適用
- `ObservableObject`は使用禁止 → `@Observable`を使用
- `NavigationView`は使用禁止 → `NavigationStack`を使用
- `foregroundColor()`は使用禁止 → `foregroundStyle()`を使用
- GCDは使用禁止 → Swift Concurrencyを使用

#### SwiftUIベストプラクティス
- Viewにロジックを書かず、ViewModelに記述
- コンポーネントはデータ単位で分割（再レンダリング範囲の最適化）
- computed propertyでViewを分割しない → 新しいView structを作成
- `GeometryReader`より`containerRelativeFrame()`や`visualEffect()`を優先
- `AnyView`は必要最小限に

#### SwiftData（CloudKit使用時）
- `@Attribute(.unique)`は使用禁止
- プロパティはデフォルト値を持つかoptionalにする
- リレーションシップは全てoptional

## App Intents実装ガイド

### 基本パターン
```swift
struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Todo"

    @Parameter(title: "Title")
    var title: String

    func perform() async throws -> some IntentResult {
        // 実装
        return .result()
    }
}
```

### Swift Package内でのAppIntents
```swift
// パッケージ内で定義
public struct TodoIntentsPackage: AppIntentsPackage { }

// アプリターゲットで統合
struct AppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
```

### IndexedEntity（Spotlight連携）
```swift
struct TodoEntity: AppEntity, IndexedEntity {
    var id: String

    @Property(title: "Title")
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

## Todoアプリ機能要件

### 基本機能
- [ ] Todo作成
- [ ] Todo完了/未完了の切り替え
- [ ] Todo削除
- [ ] お気に入り機能

### 拡張機能
- [ ] 検索
- [ ] 期限設定
- [ ] ソート
- [ ] カテゴリ分類
- [ ] 詳細説明
- [ ] サブタスク

## 開発フロー（TDD）

1. **テスト作成（Red）**: 機能のテストを先に書く
2. **Entity定義**: SwiftData Model（Domain）
3. **Repository実装**: Protocol + SwiftData実装
4. **App Intent実装（Green）**: ビジネスロジック込みでIntent定義
5. **リファクタ**: コード品質改善
6. **UI実装**: Button(intent:)で統合

## Git運用

### コミット粒度
- 機能単位で適切な粒度でコミット
- Phase完了時、重要なマイルストーン時にコミット
- テストが通る状態でのみコミット

### gitignore
- `docs/references/` はgitignoreに追加（参照ドキュメントは各自で用意）

### コミットメッセージ形式
```
<type>: <subject>

<body>
```

Types: feat, fix, refactor, test, docs, chore

## 参照ドキュメント

- `docs/PLAN.md` - 開発計画
- `docs/references/` - 最新の技術参照（gitignore対象、ローカル参照用）
