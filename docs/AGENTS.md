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

### Button(intent:) を使用（推奨）

macOS 14 / iOS 17 以降、`Button(intent:)` は両プラットフォームで使用可能です。

```swift
// ✅ 推奨: Button(intent:) を直接使用
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark")
}

// 削除ボタン（role: .destructive 付き）
Button(role: .destructive, intent: DeleteTodoIntent(todo: entity)) {
    Image(systemName: "trash")
        .foregroundStyle(.red)
}
```

**メリット**:
- 宣言的でシンプル
- Siri/Shortcuts と同じ実行経路
- Task/async のボイラープレートが不要
- システムがIntent実行を管理

---

## App Intents と ViewModel の役割分担

### 基本原則

| 責務 | 担当 | 例 |
|------|------|-----|
| **ビジネスロジック** | App Intents | CRUD操作、バリデーション、データ変換 |
| **UI状態管理** | ViewModel | フィルター、ソート、検索、ローディング状態 |
| **表示** | View | レイアウト、アニメーション |

### なぜ分けるのか？

```
【App Intents】
- Siri/Shortcuts からも実行される
- UIに依存しない純粋なロジック
- 例: Todo作成、完了切り替え、削除

【ViewModel】
- アプリUI固有のロジック
- Siri/Shortcuts からは使われない
- 例: フィルター状態、ソート順、検索テキスト
```

### Button(intent:) が使えるケース

```swift
// ✅ 即座に実行できるアクション
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Image(systemName: "checkmark.circle")
}

Button(intent: DeleteTodoIntent(todo: entity)) {
    Label("Delete", systemImage: "trash")
}
```

### Button(intent:) が使えないケース

```swift
// ❌ フォーム入力が必要なアクション
// → パラメータを収集してから実行する必要がある
struct AddTodoView: View {
    @State private var title = ""
    @State private var dueDate: Date?

    var body: some View {
        Form {
            TextField("Title", text: $title)
            DatePicker("Due Date", selection: ...)
        }
        .toolbar {
            Button("Add") {
                Task {
                    // フォームの値を使ってIntent実行
                    let intent = AddTodoIntent(title: title, dueDate: dueDate)
                    try await intent.perform()
                }
            }
        }
    }
}
```

---

## ViewModel パターン

### UI状態管理に特化

```swift
@MainActor
@Observable
public final class TodoListViewModel {
    // MARK: - UI State（アプリ固有）
    public var filter: TodoFilter = .all
    public var sortOrder: TodoSortOrder = .createdAtDescending
    public var searchText = ""

    // MARK: - Computed（フィルタリング・ソート）
    public func filteredTodos(from todos: [TodoAppEntity]) -> [TodoAppEntity] {
        var result = todos

        // フィルター適用
        switch filter {
        case .all: break
        case .incomplete: result = result.filter { !$0.isCompleted }
        case .completed: result = result.filter { $0.isCompleted }
        case .favorites: result = result.filter { $0.isFavorite }
        }

        // 検索適用
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // ソート適用
        return sortTodos(result, by: sortOrder)
    }
}
```

### View との連携

```swift
struct TodoListView: View {
    @Query private var todoItems: [TodoItem]  // SwiftData
    @State private var viewModel = TodoListViewModel()

    var body: some View {
        let entities = todoItems.map { TodoAppEntity(from: $0) }
        let filtered = viewModel.filteredTodos(from: entities)

        List(filtered) { todo in
            TodoRowView(todo: todo)
        }
        .searchable(text: $viewModel.searchText)
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
