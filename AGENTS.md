# IntentTodo - Agent Guide

このプロジェクトはApp Intents中心設計に基づいたマルチプラットフォームTodoアプリです。

## プロジェクト概要

### 設計思想

本プロジェクトは**App Intents中心設計**を採用しています。これは以下の概念を統合した独自のアプローチです：

- **App Intent Driven Development** (SwiftLee): コード再利用とシステム統合
- **Action-Centered Design** (Vidit Bhargava): アクション中心のUXデザイン
- **モデルベースUIデザイン**: ユースケース中心設計との写像

#### 核心原則

1. **全てのアクションはApp Intentとして定義**されること
2. App Intentsで定義したアクションは`Button(intent:)`で直接実行
3. ロジックの二重実装を避け、App Intentsを唯一の実行経路とする
4. **アクションと情報（Entity）が設計の原子単位** - UIやプラットフォームは二次的

#### モデルベースUIデザインとの関係

> 「誰が何を行動できる」というユースケース中心設計は、App IntentsのEntity-Intentモデルに直接写像できる。
> - **Entity（名詞）** = ユースケースの「誰が」「何を」
> - **Intent（動詞）** = ユースケースの「行動できる」

これにより、デザインと実装の間に自然な対応関係が生まれます。

#### Liquid Glass時代の設計

UIクローム（装飾）が透明化し背景に溶け込む時代において、**コンテンツとアクションが本質**となります。
標準UIで十分となり、カスタムスタイリングへの投資は減少。代わりにIntent定義に注力することで、Apple Intelligenceとの統合が自然に実現されます。

### パッケージ構成（App Intents中心設計）
```
Packages/
├── Domain/           # SwiftDataモデル、共通Entity、ActivityAttributes
├── Repository/       # データアクセス層（Protocol + 実装）
├── TodoAppIntents/   # ★コア：Intent定義 + ビジネスロジック + Shortcuts
└── UI/               # SwiftUI Views, ViewModels（表示のみ）
```

### Extension ターゲット構成
```
IntentTodoWidget/           # ホーム画面ウィジェット + コントロールセンター
├── Configuration/          # WidgetConfigurationIntent
├── Views/                  # Small/Medium/Large ウィジェットView
└── IntentTodoWidgetBundle.swift  # 全Widget/Controlをバンドル

IntentTodoLiveActivity/     # ライブアクティビティ
├── Views/                  # ロック画面・Dynamic Island View
├── Intents/                # LiveActivityIntent（完了/スヌーズ）
└── Manager/                # TodoLiveActivityManager

IntentTodoWatchApp/         # watchOS アプリ
├── Views/                  # リスト・詳細・追加View
├── Components/             # 再利用可能コンポーネント
└── TodoComplication.swift  # コンプリケーション定義
```

**ポイント**:
- UseCase層は廃止 → AppIntentsがロジックを担う
- UIはIntent実行トリガーと結果表示のみ
- Repository ProtocolによりMock可能、テスタビリティ確保

### マルチプラットフォーム展開指針（Action-Centered Design）

アクションと情報の特性に応じて、適切なプラットフォームに展開します：

| コンテンツ/アクションの特性 | 展開先 | 例 |
|---------------------------|--------|-----|
| 毎日確認する情報 | **ウィジェット** | 今日のTodo一覧、未完了数 |
| 頻繁に変わる情報 | **watchOSコンプリケーション** | 次の期限、進捗状況 |
| 繰り返しのアクション | **Shortcuts / Siri** | Todo追加、完了切り替え |
| 常時追跡が必要な情報 | **ライブアクティビティ** | 期限1時間以内のTodo |
| 素早いアクセスが必要 | **コントロールセンター** | クイック追加、緊急Todo完了 |
| 物理的なトリガーが自然 | **Action Button** | 新規Todo作成 |
| 没入型・空間的な体験 | **visionOS** | 空間UI、ガラス素材 |

#### 実装済みプラットフォーム

- **iOS/iPadOS**: メインアプリ（リスト、詳細、追加）
- **macOS**: Catalyst対応
- **watchOS**: アプリ + コンプリケーション（Circular/Corner/Rectangular/Inline）
- **visionOS**: 空間UI（NavigationSplitView、Ornament、ホバーエフェクト）
- **ウィジェット**: Small/Medium/Large サイズ対応（Todo一覧表示）
- **ライブアクティビティ**: Dynamic Island + ロック画面（期限1時間以内で自動表示）
- **コントロールセンター**: クイック追加、Todo数表示、緊急Todo切り替え

#### 設計プロセス

1. **最小のスクリーンから設計開始**: Apple Watch等、最も制約の厳しい環境で本質的なアクションを特定
2. **アクションをIntent化**: 特定したアクションをApp Intentとして定義
3. **プラットフォーム固有の実装へ拡張**: 上記の表に従って各プラットフォームに展開
4. **メインアプリUIは最後**: 複数のアクションをクラスター化してスクリーン設計

## 技術要件

### ターゲット
- iOS 18.0+ / iPadOS 18.0+
- macOS 15.0+
- watchOS 11.0+
- visionOS 2.0+
- Swift 6.0+

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
- [x] Todo作成（AddTodoIntent）
- [x] Todo完了/未完了の切り替え（ToggleTodoCompletionIntent）
- [x] Todo削除（DeleteTodoIntent）
- [x] お気に入り機能（ToggleFavoriteIntent）

### 拡張機能
- [x] 検索（TodoListView + .searchable）
- [x] 期限設定（TodoItem.dueDate）
- [x] ソート（TodoSortOrder）
- [x] カテゴリ分類（Category model）
- [x] 詳細説明（TodoItem.todoDescription）
- [x] サブタスク（SubTask model）

### マルチプラットフォーム
- [x] iOS/iPadOS メインアプリ
- [x] macOS（Catalyst対応）
- [x] watchOS アプリ + コンプリケーション
- [x] visionOS 空間UI
- [x] ホーム画面ウィジェット（Small/Medium/Large）
- [x] ライブアクティビティ（Dynamic Island + ロック画面）
- [x] コントロールセンター（クイック追加/Todo数/緊急Todo）
- [x] Siri/Shortcuts（TodoAppShortcuts）

### 拡張ロードマップ（Next Phase）

Action-Centered DesignとApp Intents中心設計をさらに深化させる次のフェーズ：

| フェーズ | 機能 | 概要 |
|---------|------|------|
| **Apple Intelligence** | FoundationModels統合 | Todo自動生成、サマリー、Tool Calling |
| **Visual Intelligence** | IntentValueQuery | カメラからTodo認識、Onscreen Entities |
| **Intent Modes** | 高度な実行制御 | .background/.foreground(.dynamic) |
| **Interactive Snippets** | Siri応答強化 | インタラクティブボタン付きスニペット |
| **Entity強化** | プロパティマクロ | @ComputedProperty, @DeferredProperty |
| **Liquid Glass** | UI適応 | widgetAccentable, glassEffect() |
| **visionOS強化** | 空間体験 | mountingStyles, levelOfDetail, ExtraLarge |

> 詳細は `docs/PLAN.md` の「拡張可能性」セクションを参照

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
- `docs/AGENTS.md` - App Intents中心設計の詳細ガイド
- `docs/APP_INTENT_DRIVEN_DESIGN.md` - 関連概念の整理と比較
- `docs/INSIGHTS.md` - 開発中に得られた技術的インサイト
- `docs/references/` - 最新の技術参照（gitignore対象、ローカル参照用）

## 設計思想の背景

本プロジェクトの設計思想については以下を参照：
- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - モデルベースUIデザインとの関係
