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
├── Domain/           # SwiftData モデル、共通 Entity、DueDateStatus、ActivityAttributes
├── Repository/       # データアクセス層（Protocol + 実装）
├── TodoAppIntents/   # ★コア：Intent 定義 + ビジネスロジック + Shortcuts
├── UI/               # メインアプリ SwiftUI Views/ViewModels（iOS/iPadOS/macOS/visionOS）
├── LiveActivity/     # ActivityKit 管理 + ロック画面 View（iOS 限定）
├── WidgetUI/         # ホームウィジェット View（TodoWidgetEntryView / TodoWidgetRow）
└── WatchUI/          # watchOS View + Components + Complication（watchOS 限定）
```

### Extension ターゲット構成

各 Extension は「App/Bundle/Widget 宣言 + Info.plist + entitlements」のみに薄く保ち、View・状態管理・データ取得ロジックはすべて SPM パッケージに置く方針。

```
IntentTodoWidget/                   # ホーム画面ウィジェット + コントロールセンター
├── IntentTodoWidget.swift          # Provider + Widget 宣言（WidgetUI を import）
├── IntentTodoWidgetBundle.swift    # 全 Widget / Control をバンドル
├── Configuration/                  # WidgetConfigurationIntent
├── Controls/                       # ControlWidget 3 種（#if !os(visionOS)）
└── Helpers/WidgetModelContainer.swift

IntentTodoLiveActivity/             # ライブアクティビティ
├── IntentTodoLiveActivityBundle.swift
└── TodoLiveActivity.swift          # ActivityConfiguration（LiveActivity を import）

IntentTodoWatchApp/                 # watchOS アプリ
├── IntentTodoWatchApp.swift        # @main（WatchUI を import）
└── TodoComplication.swift          # コンプリケーション Widget 宣言
```

**ポイント**:
- UseCase 層は廃止 → AppIntents がロジックを担う
- UI は Intent 実行トリガーと結果表示のみ
- Extension はターゲット固有のスキャフォルドのみ、View は SPM に移送してプレビュー再利用・テスト可能化
- Repository Protocol により Mock 可能、テスタビリティ確保

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
- **macOS**: ネイティブビルド対応（`AppDelegate` (iOS/visionOS) と `MacAppDelegate` (macOS) を `#if os(...)` で分離、`NotificationHandler` を cross-platform 実体として共通化）
- **watchOS**: アプリ + コンプリケーション（Circular/Corner/Rectangular/Inline）
- **visionOS**: 空間UI（NavigationSplitView、Ornament、ホバーエフェクト）
- **ウィジェット**: Small/Medium/Large サイズ対応（Todo一覧表示、アプリ起動は `Link(destination:)` を使用）

> **Widget でのアプリ起動**: [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) に "An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use `Link` and `widgetURL(_:)`" と明記。アプリを開くだけの用途には `Button(intent:)` より `Link` が公式推奨。
- **ライブアクティビティ**: Dynamic Island + ロック画面（期限1時間以内で自動表示、`LiveActivityIntent` 使用）
- **コントロールセンター**: `ControlWidgetButton(action:)` で `LaunchAppIntent` / `.background` Intent を直接呼ぶ

#### 設計プロセス

1. **最小のスクリーンから設計開始**: Apple Watch等、最も制約の厳しい環境で本質的なアクションを特定
2. **アクションをIntent化**: 特定したアクションをApp Intentとして定義
3. **プラットフォーム固有の実装へ拡張**: 上記の表に従って各プラットフォームに展開
4. **メインアプリUIは最後**: 複数のアクションをクラスター化してスクリーン設計

## 技術要件

### ターゲット
- iOS 26.0+ / iPadOS 26.0+
- macOS 26.0+
- watchOS 26.0+
- visionOS 26.0+
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

[Apple 公式: Define a CloudKit compatible schema](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices#Define-a-CloudKit-compatible-schema) より:

- `@Attribute(.unique)` は CloudKit では enforce されない（"CloudKit is unable to enforce the unique property option"）。`#Unique<T>` マクロも同じメカニズムのため同様
- リレーションシップはすべて optional（"CloudKit requires all relationships to be optional"）。DeleteRule の `.deny` もサポート外
- プロパティはデフォルト値を持つか optional にする（同期時のコンフリクト対策）

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

Swift Package 内で Intent を定義する場合は、パッケージに `AppIntentsPackage` を1つ宣言するだけで良い。**メインアプリターゲットに `includedPackages` を含む `AppIntentsPackage` を重複宣言してはいけない**（システム上ではアプリ全体で1つまでに制限されており、SPM 側の宣言が二重扱いになると Shortcuts のルーティングが壊れる）。

```swift
// パッケージ内でのみ宣言
public struct TodoIntentsPackage: AppIntentsPackage { }
```

メインアプリ側には何も宣言しなくてよい。パッケージの Intent は自動的にアプリの Intent として登録される。

### Primary / FromExtension 分離パターン

同じアクションでも「**ユーザーがパラメータを直接選ぶか**」で Intent を 2 系統に分ける。

| 区分 | 呼出元 | パラメータ型 | `isDiscoverable` | AppShortcuts 登録 |
|------|-------|------------|------------------|--------------------|
| **Primary** | Siri / Shortcuts / UI | `TodoAppEntity`（`@Parameter`） | `true` (default) | ✅ |
| **FromExtension** | Live Activity / Widget（todoId を既に持っている） | `String`（UUID 文字列） | `false` | ❌ |

**なぜ分けるか**: App Intents は `@Parameter var todo: TodoAppEntity` を持つ Intent を実行する前に `TodoEntityQuery.entities(for:)` を呼んで entity を解決する。Live Activity Extension プロセスで解決されると SwiftData が内部 assertion で trap することがあるため、呼出元が todoId を既に持っているケースでは entity 解決を経由しない `String` パラメータ版を用意する。

```swift
// Primary
public struct ToggleTodoCompletionIntent: AppIntent {
    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var modelContainer: ModelContainer
    // ...
}

// FromExtension (LA ボタン用)
public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static let isDiscoverable = false
    @Parameter(title: "Todo ID") public var todoId: String
    @Dependency var todoService: TodoService
    // ...
}
#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
```

ビジネスロジックは両者で共通のため `Services/TodoService.swift` (`@MainActor final class`) に集約し、両 Intent が `@Dependency var todoService: TodoService` で参照する。

### Dialog vs 通知の使い分け

Intent の実行結果をユーザーに伝える方法は呼出元で見え方が異なる:

| 呼出元 | `.result(dialog:)` | ローカル通知 |
|-------|------------------|------------|
| Siri | 読み上げ ✅ | 表示 ✅ |
| Shortcuts | 結果欄に表示 ✅ | 表示 ✅ |
| UI (`Button(intent:)`) | 表示なし | 表示 ✅ |
| Widget `Button(intent:)` | 表示なし | 表示 ✅ |
| **Control Widget (`ControlWidgetButton`)** | **表示なし** (2026-04-14 実機検証) | 表示 ✅ |

使い分けルール:
- **Control Center から呼ばれる Intent** (`ToggleUrgentTodoIntent`, `ShowTodoCountIntent`): **ローカル通知**でフィードバック (Dialog が表示されないため)
- **Siri / Shortcuts 前提の Intent** (`ShowTodosIntent` 等): **Dialog** で結果を音声読み上げ / テキスト表示
- **UI Button 経由が中心の Intent** (Add/Toggle/Delete 等): Dialog も通知も不要 (UI が即座に反映するため)

### データ更新 Intent は必ず `WidgetReloader.reloadAllWidgets()` を呼ぶ

データ変更があった Intent は、UI / Widget 反映のため末尾で `WidgetReloader.reloadAllWidgets()` を呼ぶ。

```swift
try repository.update(item)
WidgetReloader.reloadAllWidgets()
```

対象: `AddTodoIntent`, `DeleteTodoIntent`, `ToggleTodoCompletionIntent`, `ToggleFavoriteIntent`, `SnoozeTodoIntent`, `ToggleUrgentTodoIntent` と FromExtension 系。

### @Dependency + AppDependencyManager パターン

Intent がアプリの共有状態（`TodoService`、`NavigationModel`、`ModelContainer` 等）にアクセスする場合、`AppDependencyManager` に同期登録し Intent 側で `@Dependency` で取得する。Intent がビジネスロジックを触るときは **`TodoService` を直接受け取る**のが基本（Repository は内包済み）。

```swift
// App.init() で同期登録
@main
struct MyApp: App {
    let modelContainer: ModelContainer
    @State private var navigation: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }
}

// Intent で @Dependency から取得
struct AddTodoIntent: AppIntent {
    @Dependency var todoService: TodoService
    @Parameter(title: "Title") var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let entity = try todoService.create(title: title, ...)
        // WidgetReloader.reloadAllWidgets() は TodoService 内の defer で自動呼出
        return .result(value: entity)
    }
}
```

`TodoService` / `ModelContainer` / `@Observable @MainActor` クラスはいずれも `Sendable` 要件を満たすため `@Dependency` で問題なく共有できる。ビジネスロジックを直接扱わない Intent (例: `ToggleUrgentTodoIntent` のように fetch + mutate を 1 つの操作としてまとめたい場合) は `TodoService` にメソッドを足す方針で、Intent 側に SwiftData 呼び出しを書かない。

### 実行プロセスと登録先

`supportedModes` によって `perform()` がどのプロセスで実行されるかが決まり、`@Dependency` はそのプロセス内の `AppDependencyManager` からのみ解決される。

| 呼出元 | モード | 実行プロセス | 必要な登録 |
|-------|------|------------|-----------|
| Siri / Shortcuts | 全モード | メインアプリ | `App.init()` |
| UI の `Button(intent:)` | 全モード | メインアプリ | `App.init()` |
| Widget `Button(intent:)` | `.foreground(.immediate)` | **メインアプリ** | `App.init()` |
| Widget `Button(intent:)` / ControlWidget | `.background` | **Widget Extension** | `WidgetBundle.init()` |
| Live Activity ボタン | `LiveActivityIntent` | Live Activity Extension | Extension 側 |

```swift
// Widget Extension 側でも同様に同期登録
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: sharedWidgetModelContainer)
            AppDependencyManager.shared.add(dependency: todoService)
        }
    }

    var body: some Widget { /* ... */ }
}
```

プロセスごとに `AppDependencyManager.shared` は独立インスタンスなので、そのプロセスで `@Dependency` を使う Intent がある場合は、そのプロセスの起点（`App.init()` / `WidgetBundle.init()` 等）で登録する必要がある。

### Intent Modes

[Apple 公式 `supportedModes` ドキュメント](https://developer.apple.com/documentation/appintents/appintent/supportedmodes)より:

| モード | 動作 | 旧 API との対応 |
|--------|------|----------------|
| `.background` | アプリを開かずにバックグラウンド実行 | `openAppWhenRun = false` と同じ挙動 |
| `.foreground` / `.foreground(.immediate)` | パラメータ解決後すぐフォアグラウンド | `openAppWhenRun = true` と同じ挙動 |
| `.foreground(.dynamic)` | `perform()` 内で動的にフォアグラウンド化を決定 | **`ForegroundContinuableIntent` の後継**（下記注参照）|
| `.foreground(.deferred)` | 初期バックグラウンド → `perform()` 内 or 返却時に自動フォアグラウンド化 | 新 API |

> **`ForegroundContinuableIntent` は deprecated**: [Apple 公式ドキュメント](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent)が明記: "This protocol is deprecated, please include `.foreground(.dynamic)` in the `supportedModes` of your app intent instead."

```swift
struct MyIntent: AppIntent {
    // バックグラウンドで実行
    static var supportedModes: IntentModes { .background }

    // フォアグラウンドで実行（アプリを開く）
    // static var supportedModes: IntentModes { .foreground(.immediate) }

    // 動的切り替え（初期バックグラウンド + 必要時 foreground へ）
    // static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }
}
```

### onAppIntentExecution（iOS 26+ / Intent → UI連携）

`onAppIntentExecution(_:perform:)` は iOS 26 で追加された View modifier で、特定のシーンに対して AppIntent の実行をハンドリングする。`TargetContentProvidingIntent` を実装した Intent が実行されたとき、対応するシーンでクロージャが呼ばれる。

```swift
// Intentの定義（TargetContentProvidingIntent は AppIntent を継承するため AppIntent の明示は不要）
struct ShowTodoDetailIntent: TargetContentProvidingIntent {
    @Parameter(title: "Todo")
    var todo: TodoAppEntity

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// Viewでのハンドリング
NavigationStack {
    TodoListView()
}
.onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
    // Intent実行時にUIを更新（例: 該当Todoの詳細画面へ遷移）
    navigationPath.append(intent.todo)
}
```

**ポイント**:
- `perform()` が定義されている場合、アクションクロージャの**後に** `perform()` が呼ばれる（二重実行に注意、どちらか一方にナビゲーションを集約する）
- `supportedModes` の `.background` と組み合わせることで、UIハンドリングと`.background`処理を両立可能
- `AppIntentSceneDelegate` プロトコルでシーンレベルのハンドリングも可能

**iOS バージョンによる動作差**
- **iOS 26.4 以降**: cold start でも正常動作（ワークショップPDF "In iOS 26.4 and above this works as before"）
- **初期 iOS 26（〜26.3）**: cold start 時タイムアウトでナビゲーション失敗の可能性あり。その場合は `AppDependencyManager` + `@Dependency var navigationModel` + `perform()` でナビゲーション状態を書き込むパターンに切り替える（詳細は `docs/insights/04-ui-integration.md` 参照）

### LiveActivityIntent（Live Activity専用）

Live Activity からアクションを実行する場合は `LiveActivityIntent` を使用する（[Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Start-and-stop-Live-Activities-from-App-Intents) より "make sure it inherits from `LiveActivityIntent`"）。通常の `AppIntent` ではなく `LiveActivityIntent` を使うことで、Activity の状態操作が可能になる。

```swift
struct CompleteTodoFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Todo"

    @Parameter(title: "Todo ID")
    var todoId: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Todo完了処理 + Live Activity を終了
        return .result()
    }
}
```

[ActivityKit / Activity](https://developer.apple.com/documentation/activitykit/activity) より: "You can update or end a Live Activity while your app is in the background, but you can only start a Live Activity while the app is in the foreground, unless you adopt App Intents and start the Live Activity using a `LiveActivityIntent`."

さらに [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) が明記する実行プロセスの差：
> "If you adopt the `LiveActivityIntent` or `AudioPlaybackIntent` protocol, the system runs the app intent in the app's process. [...] If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target."

つまり `LiveActivityIntent` はアプリプロセスで実行、通常の `AppIntent` を Widget 経由で呼ぶ場合は Widget Extension プロセスで実行される。

| Intent種別 | 用途 | 特徴 |
|-----------|------|------|
| `AppIntent` | Siri/Shortcuts/UI | 汎用的なアクション |
| `LiveActivityIntent` | Dynamic Island/ロック画面 | Activity状態の操作が可能 |
| `ControlConfigurationIntent` | コントロールセンター | Extension配置必須 |

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

### 拡張ロードマップ（WWDC 2026 要素の検証）

Action-Centered DesignとApp Intents中心設計を深化させる WWDC 2026 要素を `xcode27` ブランチで検証済み（指定6セッション網羅。深度 **B**=ビルド/型成立まで。R=実機 Siri/Visual Intelligence、U=実 run は手動/CI）：

| フェーズ | 機能 | 概要 | 状態 |
|---------|------|------|------|
| **Entity強化** | プロパティマクロ | @ComputedProperty, @DeferredProperty | ✅ |
| **Onscreen Entities** | 画面コンテンツ提供 | userActivity + appEntityIdentifier | ✅ |
| **Interactive Snippets** | Siri応答強化 | インタラクティブボタン付きスニペット | ✅ |
| **App Schema** | reminders ドメイン適合 | @AppEntity(schema: .reminders.list) | ✅ list適合 / reminder本体は保留 |
| **高度な Intent** | 対話/寄付/system intent | requestConfirmation, requestChoice, IntentDonationManager, OpenIntent, DeleteIntent, IntentDialog(full:supporting:) | ✅（RelevantEntities は不適合） |
| **大量・実行制御** | スケール/プロセス制御 | EntityCollection, LongRunningIntent, CancellableIntent, allowedExecutionTargets, @UnionValue, SyncableEntity | ✅ |
| **Visual Intelligence** | カメラ/スクショ連携 | IntentValueQuery, SemanticContentDescriptor, semanticContentSearch | ✅ |
| **テスト基盤** | Intent 実経路テスト | AppIntentsTesting (makeIntent/run, UIテストバンドル) | ✅ |
| **Intent Modes** | 動的実行制御 | .foreground(.dynamic)（適所を再選定中） | 保留（#2 revert 済） |

> 検証は `xcode27` ブランチ（26.x ベータ SDK 用、**main 未マージ**）。状態・コミット・残タスクは `docs/HANDOFF.md` と `docs/APP_INTENTS_CENTRIC_PLAN.md`、実装パターンと落とし穴は `docs/insights/03-app-intents-core.md` を参照。
> **不適合/保留**: `RelevantEntities`（todo/reminders 向け `AppEntityContext` が無い）、コア `TodoAppEntity` の `.reminders.reminder` スキーマ適合（マクロ生成 init + 入れ子サブエンティティの再設計が必要）、EventKit/Contacts 連携（別フレームワーク軸）。

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
- `docs/APP_INTENTS_CENTRIC_PLAN.md` - WWDC 2026 セッション要素の検証計画（セッション別チェックリスト + 根拠URL）
- `docs/HANDOFF.md` - 上記検証作業の引き継ぎメモ（進捗・残作業・再開手順、xcode27 ブランチ）
- `docs/AGENTS.md` - App Intents中心設計の詳細ガイド
- `docs/APP_INTENT_DRIVEN_DESIGN.md` - 関連概念の整理と比較
- `docs/INSIGHTS.md` - 開発中に得られた技術的インサイト（目次）
- `docs/insights/` - インサイト個別ファイル（7トピック）
- `docs/references/` - 最新の技術参照（gitignore対象、ローカル参照用）

## 設計思想の背景

本プロジェクトの設計思想については以下を参照：
- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - モデルベースUIデザインとの関係
