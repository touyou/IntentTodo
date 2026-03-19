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

## DI の制約と解決策

### 問題

App Intentsの `@Dependency` は `Sendable` 型のみをサポートする。SwiftDataを扱うRepositoryは `Sendable` にできない。

### 解決策: 共有ModelContainerパターン

```swift
@MainActor
public final class IntentDependencies {
    public static let shared = IntentDependencies()
    public private(set) var modelContainer: ModelContainer?

    public func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public func createRepository() throws -> SwiftDataTodoRepository {
        guard let container = modelContainer else {
            throw IntentDependenciesError.notConfigured
        }
        return SwiftDataTodoRepository(modelContext: container.mainContext)
    }
}
```

### Intent内での使用

```swift
public struct AddTodoIntent: AppIntent {
    @MainActor
    public func perform() async throws -> some IntentResult {
        let repository = try IntentDependencies.shared.createRepository()
        // repositoryを使用...
    }
}
```

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
    @MainActor
    public func entities(for identifiers: [String]) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        // ID で検索...
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchIncomplete()
        return todos.map { TodoAppEntity(from: $0) }
    }
}

extension TodoEntityQuery: EntityStringQuery {
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        let allTodos = try repository.fetchAll()
        return allTodos
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

### iOS 26+: パッケージ内でも定義可能

iOS 26以降では、`AppShortcutsProvider`をSwift Package内で定義し、`AppIntentsPackage`経由で統合できる。

```swift
// メインアプリでAppIntentsPackageとして統合
struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]  // パッケージ内のAppShortcutsProviderも含まれる
    }
}
```

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

似た機能を持つIntentは統合を検討する。

```swift
// ❌ 重複: 両方とも「アプリを開いてTodo追加画面を表示」
struct OpenAddTodoIntent: AppIntent { ... }
struct ActionButtonAddTodoIntent: AppIntent { ... }

// ✅ 統合: searchKeywordsでユースケースをカバー
public struct OpenAddTodoIntent: AppIntent {
    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource("Opens the app to add a new todo"),
            categoryName: "Todos",
            searchKeywords: ["add", "create", "new", "quick", "action button"]
        )
    }
}
```

### 統合すべきでないケース

| Intent組み合わせ | 統合しない理由 |
|-----------------|---------------|
| `ShowTodosIntent` / `ShowIncompleteTodosIntent` | Siriフレーズが異なりUX的に別 |
| `CompleteTodoFromActivityIntent` / `ToggleTodoCompletionIntent` | LiveActivity固有の終了処理が必要 |

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
