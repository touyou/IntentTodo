# IntentTodo 開発インサイト集

このドキュメントは、IntentTodoアプリの開発中に得られた技術的なインサイトをまとめたものです。

---

## 目次

1. [SwiftLint と CLAUDE.md 規約](#swiftlint-と-claudemd-規約)
2. [Swift Package 依存関係設計](#swift-package-依存関係設計)
3. [TDD (テスト駆動開発)](#tdd-テスト駆動開発)
4. [SwiftData と CloudKit 対応](#swiftdata-と-cloudkit-対応)
5. [SwiftData と @Model マクロ](#swiftdata-と-model-マクロ)
6. [SwiftData と Strict Concurrency](#swiftdata-と-strict-concurrency)
7. [Repository Protocol 設計](#repository-protocol-設計)
8. [App Intents 設計思想](#app-intents-設計思想)
9. [App Intents DI の制約と解決策](#app-intents-di-の制約と解決策)
10. [AppEntity と IndexedEntity](#appentity-と-indexedentity)

---

## SwiftLint と CLAUDE.md 規約

SwiftLint設定では、プロジェクト固有のコーディング規約を強制できます。

### 禁止ルールの設定例

```yaml
custom_rules:
  # ObservableObject使用禁止 → @Observableを使用
  no_observable_object:
    name: "No ObservableObject"
    regex: "ObservableObject"
    message: "ObservableObjectは使用禁止です。@Observableを使用してください。"
    severity: error

  # NavigationView使用禁止 → NavigationStackを使用
  no_navigation_view:
    name: "No NavigationView"
    regex: "NavigationView"
    message: "NavigationViewは使用禁止です。NavigationStackを使用してください。"
    severity: error
```

### ポイント

- `severity: error` で強制力を持たせる
- 正規表現で柔軟にパターンマッチング
- メッセージで代替手段を明示

---

## Swift Package 依存関係設計

```
Packages/
├── Domain/       # 最も基底（依存なし）
├── Repository/   # Domain に依存
├── AppIntents/   # Repository に依存（コア）
└── UI/           # AppIntents に依存
```

### 依存関係の原則

1. **単方向依存**: 下位層は上位層を知らない
2. **Domain は独立**: 他のモジュールに依存しない
3. **AppIntents がコア**: ビジネスロジックの唯一の場所
4. **UI は薄く**: Intent実行トリガーと結果表示のみ

### @_exported import の活用

```swift
// Repository.swift
@_exported import Domain
```

これにより、Repositoryをimportするだけで自動的にDomainの型も使用可能になります。

---

## TDD (テスト駆動開発)

### Red-Green-Refactor サイクル

1. **Red**: 失敗するテストを先に書く
2. **Green**: テストが通る最小限の実装を行う
3. **Refactor**: コード品質を改善する

### Swift Testing フレームワークの活用

```swift
import Testing

@Suite("TodoItem Tests")
struct TodoItemTests {
    @Test("TodoItem initializes with required title")
    func initWithTitle() {
        let todo = TodoItem(title: "Buy groceries")
        #expect(todo.title == "Buy groceries")
        #expect(todo.isCompleted == false)
    }
}
```

### ポイント

- `@Suite` でテストをグループ化
- `@Test` でテスト名を明確に記述
- `#expect` で期待値をアサート

---

## SwiftData と CloudKit 対応

### 設計時の制約

CloudKitを将来的に使用する場合、以下の制約を最初から意識する必要があります。

1. **`@Attribute(.unique)` は使用禁止**: CloudKitは一意制約をサポートしない
2. **プロパティにデフォルト値**: 同期時のコンフリクト対策
3. **リレーションシップはすべてoptional**: カスケード削除の問題を回避

### 推奨パターン

```swift
@Model
public final class TodoItem {
    public var id: UUID              // デフォルト値をinitで設定
    public var title: String         // 必須プロパティ
    public var dueDate: Date?        // optional

    @Relationship(deleteRule: .nullify, inverse: \Category.todos)
    public var category: Category?   // optional リレーション

    public init(title: String, ...) {
        self.id = UUID()             // デフォルト値
        self.title = title
        // ...
    }
}
```

---

## SwiftData と @Model マクロ

### Sendable との競合

`@Model` マクロは自動的に `Sendable` 準拠を追加します。

```swift
// ❌ エラー: redundant conformance
@Model
public final class TodoItem: Sendable { }

// ✅ 正解: Sendable は書かない
@Model
public final class TodoItem { }
```

### 理由

`@Model` マクロが展開時に以下を生成します:

```swift
@available(*, unavailable, message: "PersistentModels are not Sendable...")
extension TodoItem: Sendable { }
```

明示的に `Sendable` を宣言すると競合エラーになります。

---

## SwiftData と Strict Concurrency

### 問題

SwiftData の `@Model` クラスは **Sendable ではない** ため、actor境界を越えられません。

```swift
// ❌ エラー: non-Sendable type cannot cross actor boundary
public actor MockTodoRepository: TodoRepositoryProtocol {
    public func fetchAll() async throws -> [TodoItem] { ... }
}
```

### 解決策

Repository層を `@MainActor` で実行することを前提とします。

```swift
// ✅ @MainActor でUIスレッドでの操作を保証
@MainActor
public protocol TodoRepositoryProtocol {
    func fetchAll() throws -> [TodoItem]  // async不要
}

@MainActor
public final class MockTodoRepository: TodoRepositoryProtocol {
    func fetchAll() throws -> [TodoItem] { ... }
}
```

これはUIアプリケーションとして自然で、SwiftDataの設計意図にも合致します。

---

## Repository Protocol 設計

### 設計のポイント

1. **Protocol定義で実装を抽象化**: MockRepositoryで単体テスト可能
2. **CRUD操作を明確に定義**: Create, Read, Update, Delete
3. **`@MainActor`**: SwiftData制約に対応

### Protocol定義例

```swift
@MainActor
public protocol TodoRepositoryProtocol {
    func create(_ todo: TodoItem) throws
    func fetchAll() throws -> [TodoItem]
    func fetch(by id: UUID) throws -> TodoItem?
    func fetch(where predicate: (TodoItem) -> Bool) throws -> [TodoItem]
    func update(_ todo: TodoItem) throws
    func delete(_ todo: TodoItem) throws
    func delete(by id: UUID) throws
}
```

### デフォルト実装の活用

```swift
public extension TodoRepositoryProtocol {
    func fetchIncomplete() throws -> [TodoItem] {
        try fetch { !$0.isCompleted }
    }

    func fetchFavorites() throws -> [TodoItem] {
        try fetch { $0.isFavorite }
    }
}
```

---

## App Intents 設計思想

### 「アプリの動詞」としてのIntent

App Intentsは、アプリでできる「アクション」を定義します。

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

### UIからの呼び出し

```swift
// SwiftUIでの使用
Button(intent: AddTodoIntent(title: "新しいTodo"))

// または
Button(intent: ToggleTodoCompletionIntent(todo: entity))
```

---

## App Intents DI の制約と解決策

### 問題

App Intentsの `@Dependency` は `Sendable` 型のみをサポートします。
SwiftDataを扱うRepositoryは `Sendable` にできません。

```swift
// ❌ エラー: type does not conform to Sendable
@Dependency
private var repository: any TodoRepositoryProtocol
```

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

### アプリ起動時の設定

```swift
@main
struct IntentTodoApp: App {
    let modelContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: TodoItem.self)
        modelContainer = container
        IntentDependencies.shared.configure(modelContainer: container)
    }
}
```

---

## AppEntity と IndexedEntity

### AppEntity

Siri/Shortcutsでエンティティを参照するためのプロトコルです。

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

### EntityQuery

エンティティの検索ロジックを実装します。

```swift
public struct TodoEntityQuery: EntityQuery {
    @MainActor
    public func entities(for identifiers: [String]) async throws -> [TodoAppEntity] {
        let repository = try IntentDependencies.shared.createRepository()
        // ID で検索...
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        // 未完了のTodoを提案として返す
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchIncomplete()
        return todos.map { TodoAppEntity(from: $0) }
    }
}
```

### EntityStringQuery（テキスト検索）

```swift
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

## まとめ

このプロジェクトでは、以下の技術的なチャレンジと解決策を経験しました:

1. **SwiftData + Strict Concurrency**: `@MainActor` パターンで解決
2. **App Intents + SwiftData DI**: 共有ModelContainerパターンで解決
3. **App Intents中心設計**: ロジックの二重実装を排除
4. **TDD**: Red-Green-Refactorで品質を確保

これらのインサイトは、今後のSwift/SwiftUI/App Intents開発に活用できます。
