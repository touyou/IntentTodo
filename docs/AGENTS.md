# App Intents 中心設計ガイド

このドキュメントは、App Intents を中心としたアプリ設計パターンをまとめたものです。IntentTodo プロジェクトの実装経験に基づいています。

---

## 設計思想

### 従来のMVVM設計 vs App Intents中心設計

```
【従来のMVVM】
View → ViewModel → UseCase → Repository → Domain
                    ↑
              ビジネスロジック

【App Intents中心】
View → Intent → Repository → Domain
         ↑
   ビジネスロジック
   (Siri/Shortcuts からも実行可能)
```

### 核心原則

1. **すべてのアクションはIntentとして定義**
2. **IntentがビジネスロジックのSingle Source of Truth**
3. **UIはIntent実行のトリガーと結果表示のみ**
4. **ロジックの二重実装を排除**

---

## パッケージ構成

```
ProjectRoot/
├── ProjectName/              # アプリターゲット
│   ├── ProjectNameApp.swift  # エントリーポイント
│   └── AppShortcuts.swift    # AppShortcutsProvider（必ずここに配置）
├── ProjectName.xcodeproj
└── Packages/
    ├── Domain/               # データモデル（SwiftData @Model）
    │   └── Package.swift
    ├── Repository/           # データアクセス層
    │   └── Package.swift     # → Domain に依存
    ├── TodoAppIntents/       # ★コア：Intent + ビジネスロジック
    │   └── Package.swift     # → Repository に依存
    └── UI/                   # Views, ViewModels
        └── Package.swift     # → TodoAppIntents に依存
```

### 依存関係の方向

```
Domain ← Repository ← AppIntents ← UI ← App
  ↑                       ↑
 最も基底              コア層
```

---

## Intent 実装パターン

### 基本構造

```swift
import AppIntents
import Repository

public struct AddTodoIntent: AppIntent {
    // MARK: - メタデータ
    public static var title: LocalizedStringResource = "Add Todo"
    public static var description: IntentDescription = "Creates a new todo item"

    // MARK: - パラメータ
    @Parameter(title: "Title")
    public var title: String

    @Parameter(title: "Due Date", default: nil)
    public var dueDate: Date?

    // MARK: - 初期化
    public init() {}

    public init(title: String, dueDate: Date? = nil) {
        self.title = title
        self.dueDate = dueDate
    }

    // MARK: - 実行
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        // 1. Repository取得
        let repository = try IntentDependencies.shared.createRepository()

        // 2. バリデーション（ビジネスロジック）
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }

        // 3. 実行
        let todoItem = TodoItem(title: trimmedTitle, dueDate: dueDate)
        try repository.create(todoItem)

        // 4. 結果返却
        return .result(value: TodoAppEntity(from: todoItem))
    }
}
```

### エラーハンドリング

```swift
public enum IntentError: LocalizedError {
    case validation(String)
    case notFound(String)
    case repositoryNotConfigured

    public var errorDescription: String? {
        switch self {
        case .validation(let message): return message
        case .notFound(let message): return message
        case .repositoryNotConfigured: return "Repository is not configured"
        }
    }
}
```

---

## DI パターン（SwiftData対応）

### 課題

App Intents の `@Dependency` は `Sendable` 型のみサポート。SwiftData Repository は `Sendable` にできない。

### 解決策: 共有 ModelContainer パターン

```swift
// IntentDependencies.swift
@MainActor
public final class IntentDependencies {
    public static let shared = IntentDependencies()
    public private(set) var modelContainer: ModelContainer?

    private init() {}

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

### アプリ起動時の設定

```swift
// ProjectNameApp.swift
@main
struct IntentTodoApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([TodoItem.self, SubTask.self, Category.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [config])
        modelContainer = container

        // Intent用に設定
        Task { @MainActor in
            IntentDependencies.shared.configure(modelContainer: container)
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
        .modelContainer(modelContainer)
    }
}
```

---

## AppEntity と EntityQuery

### AppEntity 定義

```swift
public struct TodoAppEntity: AppEntity, IndexedEntity {
    public var id: String

    @Property(title: "Title")
    public var title: String

    @Property(title: "Completed")
    public var isCompleted: Bool

    @Property(title: "Favorite")
    public var isFavorite: Bool

    // 型の表示名
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Todo")
    }

    // インスタンスの表示
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: isCompleted ? "Completed" : nil,
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }

    // デフォルトクエリ
    public static var defaultQuery: TodoEntityQuery { TodoEntityQuery() }
}
```

### EntityQuery 実装

```swift
public struct TodoEntityQuery: EntityQuery, EntityStringQuery {
    // ID検索
    @MainActor
    public func entities(for identifiers: [String]) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        return try identifiers.compactMap { id in
            guard let uuid = UUID(uuidString: id),
                  let todo = try repository.fetch(by: uuid) else { return nil }
            return TodoAppEntity(from: todo)
        }
    }

    // 候補提案
    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        return try repository.fetchIncomplete().map { TodoAppEntity(from: $0) }
    }

    // テキスト検索
    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        return try repository.fetchAll()
            .filter { $0.title.localizedCaseInsensitiveContains(string) }
            .map { TodoAppEntity(from: $0) }
    }
}
```

---

## App Shortcuts

### 配置場所（重要）

**AppShortcutsProvider は必ずメインアプリターゲットに配置**（パッケージ内は不可）

```swift
// IntentTodo/TodoAppShortcuts.swift
import AppIntents
import TodoAppIntents

struct TodoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Todo追加
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a new todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )

        // Todo一覧表示
        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: [
                "Show my todos in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Show Todos"),
            systemImageName: "list.bullet"
        )
    }
}
```

### フレーズの制限

- `\(.applicationName)`: アプリ名（常に使用可能）
- `\(\.$parameter)`: **AppEntity/AppEnum型のみ**（String型は不可）

```swift
// ❌ String型パラメータはフレーズに埋め込めない
phrases: ["Add \(\.$title) to \(.applicationName)"]  // エラー

// ✅ AppEnum型は埋め込み可能
phrases: ["Show \(\.$filter) todos in \(.applicationName)"]  // OK
```

---

## UI からの Intent 実行

### iOS専用: Button(intent:)

```swift
// iOSのみで使用可能
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark")
}
```

### クロスプラットフォーム: 手動実行

```swift
// iOS/macOS両対応
Button {
    Task { await toggleCompletion() }
} label: {
    Label("Complete", systemImage: "checkmark")
}

private func toggleCompletion() async {
    let intent = ToggleTodoCompletionIntent(todo: entity)
    _ = try? await intent.perform()
}
```

---

## ViewModel パターン

### Intent実行をViewModelに委譲

```swift
@MainActor
@Observable
public final class TodoListViewModel {
    public private(set) var todos: [TodoAppEntity] = []
    public private(set) var isLoading = false
    public var errorMessage: String?

    // Intent経由でデータ取得
    public func loadTodos() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let intent = ShowTodosIntent()
            let result = try await intent.perform()
            todos = result.value ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Intent経由で更新
    public func toggleCompletion(for entity: TodoAppEntity) async {
        do {
            let intent = ToggleTodoCompletionIntent(todo: entity)
            let result = try await intent.perform()
            if let updated = result.value {
                updateTodo(updated)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## テスト戦略

### MockRepository でIntent単体テスト

```swift
import Testing
@testable import TodoAppIntents

@Suite("AddTodoIntent Tests")
struct AddTodoIntentTests {
    @Test("Valid title creates todo")
    @MainActor
    func validTitle() async throws {
        // Arrange
        let mockRepo = MockTodoRepository()
        IntentDependencies.shared.configureForTesting(repository: mockRepo)

        var intent = AddTodoIntent()
        intent.title = "Buy groceries"

        // Act
        let result = try await intent.perform()

        // Assert
        #expect(result.value?.title == "Buy groceries")
        #expect(mockRepo.todos.count == 1)
    }

    @Test("Empty title throws validation error")
    @MainActor
    func emptyTitle() async throws {
        var intent = AddTodoIntent()
        intent.title = "   "

        await #expect(throws: IntentError.self) {
            _ = try await intent.perform()
        }
    }
}
```

---

## チェックリスト

### Intent実装時

- [ ] `@MainActor` を `perform()` に付与
- [ ] バリデーションロジックを `perform()` 内に実装
- [ ] 適切な `IntentResult` 型を返却
- [ ] エラーは `LocalizedError` 準拠の型でthrow

### AppEntity実装時

- [ ] `id` プロパティを定義
- [ ] `typeDisplayRepresentation` を実装
- [ ] `displayRepresentation` を実装
- [ ] `defaultQuery` を実装
- [ ] Spotlight対応なら `IndexedEntity` 準拠

### App Shortcuts実装時

- [ ] メインアプリターゲットに配置
- [ ] String型パラメータはフレーズに埋め込まない
- [ ] `shortTitle` と `systemImageName` を設定
- [ ] 複数のAppShortcutsProviderを作らない

---

## 参考資料

- [Apple: App Intents](https://developer.apple.com/documentation/appintents)
- [Apple: Making your app's functionality available to Siri](https://developer.apple.com/documentation/appintents/making-your-app-s-functionality-available-to-siri)
- [WWDC22: Dive into App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/)
- [WWDC23: Explore enhancements to App Intents](https://developer.apple.com/videos/play/wwdc2023/10103/)
