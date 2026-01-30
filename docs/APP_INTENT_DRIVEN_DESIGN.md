# App Intent Driven Design - 概念整理

このドキュメントでは、App Intents中心の設計思想に関連する外部の概念を整理し、本リポジトリの思想との比較を行います。

## 目次

1. [概念の概要](#概念の概要)
2. [App Intent Driven Development (SwiftLee)](#app-intent-driven-development-swiftlee)
3. [Action-Centered Design Framework (Vidit Bhargava)](#action-centered-design-framework-vidit-bhargava)
4. [MVI (Model-View-Intent) Architecture](#mvi-model-view-intent-architecture)
5. [本リポジトリの思想との比較](#本リポジトリの思想との比較)
6. [参考リンク](#参考リンク)

---

## 概念の概要

App Intentsを中心とした設計アプローチには、いくつかの異なる視点からの概念が存在します。

| 概念名 | 提唱者/出典 | 主な焦点 |
|--------|-------------|----------|
| App Intent Driven Development | Antoine van der Lee (SwiftLee) | コード再利用とシステム統合 |
| Action-Centered Design | Vidit Bhargava | UXデザインとマルチプラットフォーム |
| MVI Architecture | Hannes Dorfmann (Android) | 状態管理と単方向データフロー |

---

## App Intent Driven Development (SwiftLee)

### 定義

Antoine van der Leeによって提唱されたアプローチで、**アクションやデータを最初からAppIntentプロトコルで定義する**開発手法です。

### 核心的な考え方

> "By defining actions as app intents by default, you allow them to be connected to any system-service in the future."

- **デフォルトでApp Intentとして定義**: 将来的なシステムサービス接続を見据えた設計
- **再利用性の強制**: AppIntentプロトコルとAppEntityプロトコルを使用
- **柔軟な拡張性**: 現時点でシステム連携が不要でも、将来に備えた構造化

### 技術的アプローチ

```swift
// EntityQuery実装による再利用
struct WidgetFavoritesGroupQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetFavoritesGroup] { ... }
    func suggestedEntities() async throws -> [WidgetFavoritesGroup] { ... }
    func defaultResult() async -> WidgetFavoritesGroup? { ... }
}
```

- ウィジェット設定用のIntentを定義
- メインアプリケーションで同じクエリロジックを活用
- ViewModelで`suggestedEntities()`を呼び出して一覧を生成

### 統合対象

- Shortcuts
- Siri
- Spotlight
- Action Button
- ウィジェット

### メリット

- コード重複の排除
- システムサービス対応の将来性確保
- テストと保守性の向上
- 一度定義したIntentを複数の文脈で活用

### デメリット

- 初期設計の複雑性増加
- 小規模アプリではオーバーエンジニアリングの可能性
- AppEntity・EntityQuery実装の追加作業

---

## Action-Centered Design Framework (Vidit Bhargava)

### 定義

デザイナー・開発者のVidit Bhargavaが提唱するフレームワークで、**アクションと情報を中心にアプリを設計する**アプローチです。

### 核心的な考え方

> "アプリは情報へのアクセスとプロセス実行を支援する**アクションのクラスター**"

従来のプラットフォーム中心の考え方から脱却し、アクションを原子単位として捉えます。

### 設計プロセス

1. **4つの基本質問から開始**:
   - 対象ユーザーは誰か
   - どの問題を解決するか
   - 目的は何か
   - どのコンテンツを含むか

2. **最小単位から設計**:
   - ウォッチなど最も小さなスクリーンから開始
   - 必須要素に焦点を当てる

3. **プラットフォーム固有へ拡張**:
   - 毎日確認する情報 → ウィジェット
   - 頻繁に変わる情報 → watchOSコンプリケーション
   - 繰り返しのアクション → ショートカット/Siri
   - 常時追跡情報 → ライブアクティビティ

### App Intentsとの関係

> "AppIntents allow developers to break down their app's actions into small chunks that can run independently but are also flexible enough to interface with other applications, much like lego bricks."

- **AppIntents** = アクション（レゴブロックのような独立した実行単位）
- **AppEntities** = 情報（検索可能なデータ）

### Apple Intelligenceとの関連

Apple Intelligenceは「アクションと情報を個別化された体験に統合する」概念を体現しており、Action-Centered Designの実装例と位置づけられています。

### 特徴

- UX/デザイン視点からのアプローチ
- マルチプラットフォーム対応を前提
- Apple Intelligenceとの親和性を重視

---

## MVI (Model-View-Intent) Architecture

### 定義

Hannes Dorfmannによって提唱された（主にAndroid向けの）アーキテクチャパターンで、**単方向データフロー**を特徴とします。

### 核心的な考え方

```
User Action → Intent → Model → View → User sees change
```

> "No shortcuts. No backdoors. Completely predictable."

### コンポーネント

| コンポーネント | 役割 |
|---------------|------|
| Model | アプリケーションの状態を表現 |
| View | 状態を表示し、ユーザー入力を受け取る |
| Intent | 状態を変更するイベント（ユーザー操作など） |

### SwiftUIでの実装

```swift
// MVI Store
class Store<State, Intent> {
    @Published private(set) var state: State

    func send(_ intent: Intent) {
        // IntentをModelに反映
    }
}
```

### 注意点

**MVI の "Intent" と Apple の "AppIntent" は別概念です。**

- MVI Intent: 状態変更を表すイベント/アクション
- AppIntent: Appleのシステムサービスと連携するためのプロトコル

### メリット

- 予測可能な状態遷移
- デバッグの容易さ
- テスト性の向上

### デメリット

- シンプルなCRUD操作には過剰
- 学習コストが高い

---

## 本リポジトリの思想との比較

### IntentTodoの設計思想（再掲）

```
Packages/
├── Domain/       # SwiftDataモデル、共通Entity
├── Repository/   # データアクセス層（Protocol + 実装）
├── AppIntents/   # ★コア：Intent定義 + ビジネスロジック
└── UI/           # SwiftUI Views, ViewModels（表示のみ）
```

- **全てのアクションはApp Intentとして定義**
- **UseCase層を廃止** → AppIntentsがロジックを担う
- **Button(intent:)で直接実行** → ロジックの二重実装を避ける

### 比較表

| 観点 | IntentTodo | App Intent Driven Dev | Action-Centered Design | MVI |
|------|------------|----------------------|------------------------|-----|
| **主目的** | ロジック一元化 | コード再利用・システム統合 | UXデザイン・マルチプラットフォーム | 状態管理 |
| **App Intentsの役割** | ビジネスロジック層 | 再利用可能なアクション定義 | アクションの原子単位 | 関係なし |
| **UseCase層** | 廃止 | 言及なし | 言及なし | 別途必要 |
| **Button(intent:)** | 必須 | 推奨 | 言及なし | 関係なし |
| **対象** | アーキテクチャ全体 | Intent定義のベストプラクティス | 設計プロセス全体 | 状態管理のみ |

### 共通点

#### IntentTodo と App Intent Driven Development

1. **App Intentsをデフォルトの実装手段とする**
   - 両者ともApp Intentsをオプションではなく、基本的な実装方法として位置づけ

2. **再利用性の重視**
   - システムサービス連携を見据えた設計
   - コード重複の排除

3. **EntityQueryの活用**
   - データ取得ロジックの一元化
   - ウィジェット・メインアプリでの共有

#### IntentTodo と Action-Centered Design

1. **アクション中心の設計思想**
   - アプリを「アクションのクラスター」として捉える点で一致

2. **マルチプラットフォーム対応**
   - ウィジェット、Shortcuts、Siriなど複数の接点を想定

3. **Apple Intelligenceへの対応**
   - 将来的なAI統合を見据えた設計

### 差分・独自性

#### IntentTodo独自の特徴

1. **UseCase層の明示的な廃止**
   - 他の概念では言及されていない
   - App IntentsがUseCase層を完全に代替

2. **Button(intent:)の必須化**
   - UIからのアクション実行は必ずIntent経由
   - ロジックの二重実装を構造的に防止

3. **ViewModelの役割限定**
   - ViewModelは「表示のみ」に限定
   - ビジネスロジックはApp Intentsに集約

4. **明確なパッケージ構成**
   - Domain / Repository / AppIntents / UIの4層構造
   - 各層の責務が明確

#### 他の概念にあってIntentTodoにないもの

1. **デザインプロセスの指針**（Action-Centered Design）
   - 「4つの質問から始める」などのデザイン方法論
   - IntentTodoは技術的なアーキテクチャに焦点

2. **状態管理パターン**（MVI）
   - 単方向データフローの詳細な規定
   - IntentTodoは@Observableベースで、特定のパターンを強制しない

### 結論

IntentTodoの「App Intents中心設計」は、以下の点で独自の立場を取っています：

1. **より徹底したIntent中心主義**: UseCase層を廃止し、App Intentsをビジネスロジック層として位置づける
2. **実装レベルの具体性**: Button(intent:)の必須化など、実装方法を明確に規定
3. **アーキテクチャ全体の再構成**: 従来のClean Architectureを、App Intents前提で再設計

これは、App Intent Driven DevelopmentやAction-Centered Designの考え方を参考にしつつ、より実装に踏み込んだ独自のアーキテクチャと言えます。

---

## 参考リンク

### 主要リソース

- [App Intent Driven Development in Swift and SwiftUI - SwiftLee](https://www.avanderlee.com/swift/app-intent-driven-development/)
- [Action-Centered Design - Vidit Bhargava](https://blog.viditb.com/action-centered-design/)
- [Apple Intelligence: Action Centered Design Framework - Matthew Cassinelli](https://matthewcassinelli.com/apple-intelligence-action-centered-design-framework-feat-vidit-bhargava/)

### Apple公式ドキュメント

- [App Intents | Apple Developer Documentation](https://developer.apple.com/documentation/appintents)
- [Integrating actions with Siri and Apple Intelligence](https://developer.apple.com/documentation/appintents/integrating-actions-with-siri-and-apple-intelligence)
- [Making actions and content discoverable and widely available](https://developer.apple.com/documentation/appintents/making-actions-and-content-discoverable-and-widely-available)
- [Get to know App Intents - WWDC25](https://developer.apple.com/videos/play/wwdc2025/244/)
- [Bring your app's core features to users with App Intents - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10210/)

### 関連記事

- [How to Future-Proof Your iOS App With App Intents - Heady](https://www.heady.io/blog/app-intents-apple-intelligence)
- [MVI Architecture in SwiftUI - DEV Community](https://dev.to/swift_pal/mvi-architecture-in-swiftui-a-complete-guide-to-model-view-intent-pattern-2025-4c8)
- [MVI Architecture for SwiftUI - Better Programming](https://betterprogramming.pub/mvi-architecture-for-swiftui-apps-cff44428394)
