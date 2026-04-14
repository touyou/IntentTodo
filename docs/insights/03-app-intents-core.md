# App Intents コア設計

## 「アプリの動詞」としてのIntent

App Intentsは、アプリでできる「アクション」を定義する。

- **AddTodoIntent**: Todoを作成する
- **ToggleTodoCompletionIntent**: 完了状態を切り替える
- **DeleteTodoIntent**: Todoを削除する
- **ToggleFavoriteIntent**: お気に入り状態を切り替える

### ビジネスロジックはIntent内に

```swift
public struct AddTodoIntent: AppIntent {
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        // バリデーション（ビジネスロジック）
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }

        // 作成と保存
        let todoItem = TodoItem(title: trimmedTitle, ...)
        try repository.create(todoItem)

        return .result(value: TodoAppEntity(from: todoItem))
    }
}
```

---

## DI パターン（@Dependency + AppDependencyManager）

### 基本

`ModelContainer` は `Sendable` を満たすため、`@Dependency` でそのまま共有できる。`App.init()` で `AppDependencyManager.shared.add(dependency:)` に**同期登録**し、Intent 側で `@Dependency` で取得、`perform()` 内で `modelContainer.mainContext` を使って Repository を生成する（毎回新しい `ModelContext(modelContainer)` を作ると保存されていない状態が共有されないので注意）。

`@Observable @MainActor` クラス（`NavigationModel` 等）も同様に共有可能。

### アプリ側の同期登録

```swift
@main
struct IntentTodoApp: App {
    let modelContainer: ModelContainer

    init() {
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)
    }
}
```

### Intent 側

```swift
public struct AddTodoIntent: AppIntent {
    @Dependency
    var modelContainer: ModelContainer

    @MainActor
    public func perform() async throws -> some IntentResult {
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
        // ...
    }
}
```

### 実行プロセスごとに登録が必要

`AppDependencyManager.shared` は**プロセスごとに独立したインスタンス**。`supportedModes` によって `perform()` がどのプロセスで実行されるかが決まる。

| モード/呼出元 | 実行プロセス | 登録が必要な場所 |
|--------------|-------------|----------------|
| `.foreground(.immediate)` | メインアプリ（開かれる） | `App.init()` |
| `.foreground` | メインアプリ | `App.init()` |
| `.background` / Siri / Shortcuts | メインアプリ | `App.init()` |
| `.background` / Widget ControlWidgetButton | Widget Extension | `WidgetBundle.init()` |
| `LiveActivityIntent` | **メインアプリプロセス** (公式保証) | `App.init()` |

> `LiveActivityIntent` は Apple 公式 [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) が "the system runs the app intent in the app's process" と明言している。つまりメインアプリ側の `AppDependencyManager` に登録してあれば解決される（Extension 側の登録は不要）。

Widget Extension 側での登録例:

```swift
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
    }
    var body: some Widget { /* ... */ }
}
```

### 登録のタイミング

`App.init()` / `WidgetBundle.init()` で**同期**的に。`Task { @MainActor in ... }` に入れると `perform()` が Task 完了を待たずに走る可能性があり、`@Dependency` 解決失敗になる。

---

## AppEntity と IndexedEntity

### AppEntity

Siri/Shortcutsでエンティティを参照するためのプロトコル。

```swift
public struct TodoAppEntity: AppEntity {
    public var id: String
    public var title: String
    public var isCompleted: Bool

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Todo")
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }

    public static var defaultQuery: TodoEntityQuery {
        TodoEntityQuery()
    }
}
```

### EntityQuery と EntityStringQuery

```swift
public struct TodoEntityQuery: EntityQuery {
    @Dependency
    var modelContainer: ModelContainer

    @MainActor
    private func makeRepository() -> SwiftDataTodoRepository {
        SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
    }

    @MainActor
    public func entities(for identifiers: [String]) async throws -> [TodoAppEntity] {
        // ID で検索（makeRepository() を使用）
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        try makeRepository().fetchIncomplete().map { TodoAppEntity(from: $0) }
    }
}

extension TodoEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        try makeRepository().fetchAll()
            .filter { $0.title.lowercased().contains(string.lowercased()) }
            .map { TodoAppEntity(from: $0) }
    }
}
```

---

## App Shortcuts

### AppShortcutsProvider

```swift
public struct TodoAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a new todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )
    }
}
```

### 10 件上限と設計指針

Apple は `AppShortcutsProvider.appShortcuts` の登録数を **10 件** に制限している（iOS 26 時点）。本プロジェクトは現在 8 件で運用しており、枠 2 件分の余裕を意識的に確保する設計判断をしている。

- 同じ Intent のパラメータ違いは、可能な限り 1 件にまとめて「フレーズを複数登録」する。例えば `ShowTodosIntent` は `filter` パラメータを 1 つの AppShortcut で受け、`Show my todos / Show incomplete todos / Show favorite todos` のフレーズ群にまとめている（以前は 3 件登録していたが、10 件枠を食い潰さないよう統合）。
- アプリを「開くだけ」の用途（例: `LaunchAppIntent`）は Widget/ControlWidget 経由で呼べば足りるので、AppShortcut 登録を省いて枠を節約する。

### パッケージ内での定義

`AppShortcutsProvider` も Swift Package 内に配置可能。パッケージ側に `AppIntentsPackage` を1つ宣言するだけで、そこに含まれる Intent と AppShortcutsProvider がアプリ全体で認識される。

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/TodoAppIntents.swift
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

**重要**: メインアプリターゲットに `includedPackages` を持つ `AppIntentsPackage` を**重複宣言しない**こと。システム上 `AppIntentsPackage` はアプリあたり1つまでで、SPM 側の自動発見と二重登録になると Shortcuts のルーティングが壊れる。

**注意**: アプリ内に `AppShortcutsProvider` が複数存在するとビルドエラーになる。

### フレーズのパラメータ型制限

App Shortcutのフレーズに埋め込めるのは **AppEntity** と **AppEnum** 型のみ。

```swift
// ❌ String型パラメータはフレーズに埋め込めない
"Add \(\.$title) to \(.applicationName)"  // エラー: Invalid parameter type

// ✅ AppEntity/AppEnumのみ使用可能
"Show \(\.$filter) todos in \(.applicationName)"  // filter: TodoFilterType (AppEnum)
```

String型パラメータを使いたい場合は、Siriがユーザーに後から入力を求めるフローを利用する。

---

## supportedModes

[Apple 公式 `supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) より:

### 基本モード

| モード | 動作 | 旧 API との対応 |
|--------|------|----------------|
| `.background` | バックグラウンド実行 | `openAppWhenRun = false` と同じ挙動 |
| `.foreground` / `.foreground(.immediate)` | 即座にフォアグラウンド | `openAppWhenRun = true` と同じ挙動 |
| `.foreground(.dynamic)` | 実行中に動的判断 | **`ForegroundContinuableIntent` の後継**（下記注参照）|
| `.foreground(.deferred)` | 初期バックグラウンド → `perform()` 内か返却時に自動 foreground 化 | 新 API |

> **`ForegroundContinuableIntent` は deprecated**: [公式ドキュメント](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent) が明記 — "This protocol is deprecated, please include `.foreground(.dynamic)` in the `supportedModes` of your app intent instead."

### 複合モード

```swift
// バックグラウンド + 条件付きフォアグラウンド
public static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }
```

`[.background, .foreground(.deferred)]` の動作:
- デフォルトはバックグラウンド実行
- `perform()` 内で `continueInForeground()` を呼ぶとアプリがフォアグラウンドに遷移
- `continueInForeground()` を呼ばなくても、`perform()` 終了前にシステムがフォアグラウンド化を保証

### continueInForeground()

```swift
// AppIntentのインスタンスメソッドとして利用可能
func perform() async throws -> some IntentResult {
    // バックグラウンドでTodo作成
    try repository.create(todoItem)

    // 必要な場合のみアプリを開く
    if openInApp {
        try await continueInForeground()
    }

    return .result(value: entity)
}
```

### systemContext.currentMode

実行時のモードを確認する:

```swift
func perform() async throws -> some IntentResult {
    if systemContext.currentMode.canContinueInForeground {
        try await continueInForeground()
    }
    return .result()
}
```

> **Note**: Control Widget からの `continueInForeground()` 呼び出しは現時点で未検証（かつて動作しないと記録していたが、当時の失敗は `IntentTodoAppIntentsPackage` 重複 Bug によるもので、fix 後は未検証）。

---

## Primary / FromExtension 分離パターン

同じ行動でも「**ユーザーがパラメータを直接選ぶか**」で実装を分ける。

### 背景

App Intents が `TodoAppEntity` のような `AppEntity` をパラメータに取る Intent を実行すると、`perform()` 前に `TodoEntityQuery.entities(for:)` を呼んで ID から entity を再解決する。この解決処理が Live Activity Extension プロセスで SwiftData の内部 assertion を踏んで `EXC_BREAKPOINT` で crash することが実機で確認された（2026-04-14）。

スタック:
```
SwiftData`___lldb_unnamed_symbol_9d14c + 356
SwiftData`dispatch thunk of ModelContext.fetch(_:) + 20
SwiftDataTodoRepository.fetch(id:)   ← TodoEntityQuery から呼ばれる
TodoEntityQuery.entities(for:)       ← parameter resolution 段階
```

### 解決策: 2 系統に分ける

| 区分 | パラメータ | `isDiscoverable` | AppShortcuts | 用途 |
|------|----------|------------------|--------------|------|
| **Primary** | `todo: TodoAppEntity` | `true` | ✅ 登録 | Siri / Shortcuts / UI — ユーザーが todo を picker で選ぶ |
| **FromExtension** | `todoId: String` | `false` | ❌ | Live Activity / Widget — 呼出元が todoId を既知 |

String パラメータなら entity 解決を経由せず `perform()` に直行できる。

```swift
// Primary
public struct ToggleTodoCompletionIntent: AppIntent {
    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var modelContainer: ModelContainer
    // ...
}

// FromExtension
public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static let isDiscoverable = false
    @Parameter(title: "Todo ID") public var todoId: String
    @Dependency var modelContainer: ModelContainer
    // ...
}
#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
```

### 共通ロジックの切り出し

重複を避けるため `Actions/TodoActions.swift` に `@MainActor` 関数群として切り出し、両系統から呼ぶ。

```swift
public enum TodoActions {
    @MainActor
    public static func toggleCompletion(
        todoId: String,
        using repository: any TodoRepositoryProtocol
    ) throws -> TodoToggleResult { /* ... */ }
}
```

### DI は両者共通で @Dependency

`@Dependency var modelContainer: ModelContainer` は Primary / FromExtension 両方で使える。`AppDependencyManager` への登録を `App.init()` と `WidgetBundle.init()` で済ませてあれば、どのプロセスで実行されても解決される（詳細は `04-ui-integration.md` の実行プロセス表）。

> **補足**: かつて FromExtension では `SharedModelContainer.createContainer()` を直接呼ぶ方針にしたが、crash の真因は DI ではなく entity 解決だったと判明したので統一。

---

## Intent 統合のベストプラクティス

### 重複Intentの検出と統合

「同じアクションは同じ Intent」を原則として、似た機能を持つ Intent は統合を検討する。パラメータ（`AppEnum` や `AppEntity`）で分岐させれば1つの Intent で複数バリエーションをカバーできる。

```swift
// ✅ filter: TodoFilterType で統合
public struct ShowTodosIntent: AppIntent {
    @Parameter(title: "Filter", default: .all)
    public var filter: TodoFilterType
    // ...
}

// ✅ target: AppScreenTarget で統合
public struct LaunchAppIntent: AppIntent {
    @Parameter(title: "Target")
    public var target: AppScreenTarget
    // ...
}
```

### 統合すべきでないケース

| Intent組み合わせ | 統合しない理由 |
|-----------------|---------------|
| `CompleteTodoFromActivityIntent` / `ToggleTodoCompletionIntent` | LiveActivity固有の終了処理が必要（`LiveActivityIntent` プロトコル準拠が別） |
| Widget Extension 内の独自 Intent（`ToggleUrgentTodoIntent` 等） | Extension プロセスで動作するため SPM の Intent と分離する必要がある |

### AppEnum

IntentパラメータでEnumを使用する場合は `AppEnum` に準拠する。

```swift
public enum TodoFilterType: String, AppEnum {
    case all, incomplete, completed, favorites

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Filter")
    }

    public static var caseDisplayRepresentations: [TodoFilterType: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "All", image: .init(systemName: "list.bullet")),
            .incomplete: DisplayRepresentation(title: "Incomplete", image: .init(systemName: "circle")),
            // ...
        ]
    }
}
```
