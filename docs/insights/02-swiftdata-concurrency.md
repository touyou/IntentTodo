# SwiftData と Concurrency

## SwiftData と CloudKit 対応

CloudKit 同期を有効にする場合、[Apple 公式: Syncing model data across a person's devices / Define a CloudKit compatible schema](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices#Define-a-CloudKit-compatible-schema) が明記する以下の制約を意識する必要がある:

1. **`@Attribute(.unique)` は CloudKit では enforce されない**: Apple 公式より "the framework synchronizes changes concurrently and at opportune times, which means CloudKit is unable to enforce the unique property option." `#Unique<T>` マクロの CloudKit 互換性については Apple 公式 API リファレンスに直接の記述はないが、同じ一意性メカニズムに依拠するため同じ制約が及ぶと考えるのが妥当。
2. **リレーションシップはすべて optional**: Apple 公式より "CloudKit requires all relationships to be optional." また DeleteRule の `.deny` も CloudKit ではサポートされない。
3. **プロパティにデフォルト値 / optional**: 同期時のコンフリクト対策（Apple 公式のスキーマ設計ガイダンス）。

経緯: [docs/devlog/02-swiftdata-concurrency.md](../devlog/02-swiftdata-concurrency.md)

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

## @Model プロパティで `didSet` を使わない

`@Model` マクロはプロパティアクセスを内部で swizzle する。その結果、CloudKit 経由のマージや KVC/KVO 経由の書き込みでは `didSet` オブザーバが**発火しない**ことがある。「変更時刻の自動更新」等の副作用を `didSet` に書いてしまうと、ローカルからの書き込みでは動いても、CloudKit で同じモデルが更新された時に `modifiedAt` が更新されない矛盾が生まれる。

```swift
// ❌ CloudKit マージ経由の更新で発火しない可能性
@Model
public final class TodoItem {
    public var title: String {
        didSet { modifiedAt = Date() }   // 発火タイミングが不安定
    }
    public var modifiedAt: Date
}
```

```swift
// ✅ 呼び出し側（TodoService 等）で明示的に更新
item.title = newTitle
item.modifiedAt = Date()
try repository.update(item)
```

本プロジェクトでは、`TodoItem` の全フィールドから `didSet` を除去し、`TodoService.toggleCompletion` / `toggleFavorite` / `snooze` 各メソッドが変更後に `item.modifiedAt = Date()` を明示的に触る方針に統一している。

---

## 共有ドメイン値としての `DueDateStatus`

期限日の状態判定（`overdue` / `dueSoon` / `normal`）は複数プラットフォームの View（`TodoDetailView` / `VisionOSTodoView` / `WatchDueDateLabel` / `TodoWidgetRow` 等）で必要になる。同じ閾値ロジックが複数箇所に散ると、閾値変更時の漏れやクラッシュ条件が揃わないといった問題が起きやすい。

```swift
// Packages/Domain/Sources/Domain/Models/DueDateStatus.swift
public enum DueDateStatus: Sendable, Equatable {
    case normal, dueSoon, overdue
    public static let dueSoonThreshold: TimeInterval = 3600

    public static func evaluate(
        date: Date,
        isCompleted: Bool,
        now: Date = Date()
    ) -> DueDateStatus {
        guard !isCompleted else { return .normal }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return .overdue }
        if interval <= dueSoonThreshold { return .dueSoon }
        return .normal
    }
}
```

全 View から `DueDateStatus.evaluate(date:isCompleted:)` を呼ぶ形に統一すると、閾値・状態判定が 1 箇所で管理でき、テスト容易性も上がる（注入可能な `now:` を持つので TimelineView との組み合わせで時間進行テストも可）。

### TimeRemainingView の overdue 時 ClosedRange 制約

SwiftUI の `Text(timerInterval:countsDown:)` は `ClosedRange<Date>` を引数に取り、下限 > 上限の場合に `precondition` で trap する。期限を過ぎた Live Activity で `Date()...dueDate` を渡すとクラッシュするため、`DueDateStatus` で `.overdue` を判定したら `Text(timerInterval:)` ではなく静的なラベル（"Overdue" 等）にフォールバックする。

```swift
if isOverdue {
    Text("Overdue").foregroundStyle(.red)
} else {
    Text(timerInterval: Date()...dueDate, countsDown: true)
        .monospacedDigit()
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
