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

`ModelContainer` は `Sendable` を満たすため、`@Dependency` でそのまま共有できる。`App.init()` で `AppDependencyManager.shared.add(dependency:)` に**同期登録**し、Intent 側で `@Dependency` で取得、`perform()` 内で `ModelContext(modelContainer)` から Repository を生成する。

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
        let repository = SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))
        // ...
    }
}
```

### 注意

- 登録は `App.init()` で**同期**的に。`Task { @MainActor in ... }` に入れると `perform()` より後になる可能性がある。
- Extension ターゲット内に定義した Intent（例: Widget Extension 内の `ControlIntents.swift`）について、`AppDependencyManager` 経由で共有できるか未検証。実行プロセスによっては `SharedModelContainer.createContainer()` を直接呼ぶ必要があるかもしれない。

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
        SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))
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

## supportedModes（iOS 26+ / openAppWhenRun 後継）

### 基本モード

| モード | 動作 | 旧API相当 |
|--------|------|-----------|
| `.background` | バックグラウンド実行 | `openAppWhenRun = false` |
| `.foreground` / `.foreground(.immediate)` | 即座にフォアグラウンド | `openAppWhenRun = true` |
| `.foreground(.dynamic)` | 実行中に動的判断 | `ForegroundContinuableIntent` |
| `.foreground(.deferred)` | perform()内で明示的にフォアグラウンド遷移 | - |

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

> **Note**: `continueInForeground()` はControl Widgetコンテキストでは動作しない。Shortcuts/Siri経由での使用を想定。

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
