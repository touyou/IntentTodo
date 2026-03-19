# SwiftData と Concurrency

## SwiftData と CloudKit 対応

CloudKitを将来的に使用する場合、以下の制約を最初から意識する必要がある。

1. **`@Attribute(.unique)` は使用禁止**: CloudKitは一意制約をサポートしない（iOS 26+ で追加された `#Unique<T>` マクロも同様にCloudKit環境では使用不可）
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
    }
}
```

---

## @Model マクロと Sendable の競合

`@Model` マクロは自動的に `Sendable` 準拠を追加する。

```swift
// ❌ エラー: redundant conformance
@Model
public final class TodoItem: Sendable { }

// ✅ 正解: Sendable は書かない
@Model
public final class TodoItem { }
```

`@Model` マクロが展開時に以下を生成するため:

```swift
@available(*, unavailable, message: "PersistentModels are not Sendable...")
extension TodoItem: Sendable { }
```

---

## Strict Concurrency との統合

### 問題

SwiftData の `@Model` クラスは **Sendable ではない** ため、actor境界を越えられない。

```swift
// ❌ エラー: non-Sendable type cannot cross actor boundary
public actor MockTodoRepository: TodoRepositoryProtocol {
    public func fetchAll() async throws -> [TodoItem] { ... }
}
```

### 解決策: @MainActor パターン

Repository層を `@MainActor` で実行することを前提とする。

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

UIアプリケーションとして自然で、SwiftDataの設計意図にも合致する。

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
