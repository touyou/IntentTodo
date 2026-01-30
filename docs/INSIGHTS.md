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
11. [UI層とIntent統合](#ui層とintent統合)
12. [App Shortcuts](#app-shortcuts)

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

## UI層とIntent統合

### Button(intent:) の使用

macOS 14 / iOS 17 以降、`Button(intent:)` は両プラットフォームで使用可能です。

```swift
import AppIntents  // ← Button(intent:) を使用するために必須

// ✅ 推奨: Button(intent:) を直接使用
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Text("Complete")
}

// カスタムラベル付き
Button(intent: DeleteTodoIntent(todo: entity)) {
    Label("Delete", systemImage: "trash")
}
.tint(.red)
.buttonStyle(.plain)
```

**メリット**:
- 宣言的でシンプル
- Siri/Shortcuts と同じ実行経路
- ボイラープレートが不要
```

### @Observable + @MainActor

Observation frameworkを使用する際は、必ず `@MainActor` を付与します。

```swift
@MainActor
@Observable
public final class TodoListViewModel {
    public private(set) var todos: [TodoAppEntity] = []
    public private(set) var isLoading = false
    public var errorMessage: String?
    // ...
}
```

### プラットフォーム条件分岐

iOS専用APIは `#if os(iOS)` で分岐します。

```swift
TextField("Title", text: $title)
#if os(iOS)
    .textInputAutocapitalization(.sentences)
#endif
```

---

## App Shortcuts

### AppShortcutsProvider

`AppShortcutsProvider` でSiri/ショートカットの初期フレーズを定義します。

```swift
public struct TodoAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a new todo in \(.applicationName)",
                "Add \(\.$title) to \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )
    }
}
```

### プレースホルダー

- `\(.applicationName)`: アプリ名を動的に挿入
- `\(\.$parameterName)`: Intentパラメータをフレーズに埋め込み

### AppEnum

IntentパラメータでEnumを使用する場合は `AppEnum` に準拠します。

```swift
public enum TodoFilterType: String, AppEnum {
    case all
    case incomplete
    case completed
    case favorites

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

### OpensIntent

Intentの結果として別のIntentを開くことができます。

```swift
public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
    // ...
    return .result(
        value: entities,
        opensIntent: OpenTodoListIntent(filter: .incomplete)
    )
}
```

---

## まとめ

このプロジェクトでは、以下の技術的なチャレンジと解決策を経験しました:

1. **SwiftData + Strict Concurrency**: `@MainActor` パターンで解決
2. **App Intents + SwiftData DI**: 共有ModelContainerパターンで解決
3. **App Intents中心設計**: ビジネスロジック（CRUD）の二重実装を排除
4. **App Intents vs ViewModel の役割分担**:
   - App Intents = ビジネスロジック（Siri/Shortcutsからも使用、検索クエリ実行含む）
   - ViewModel = UI状態管理（フィルター状態、ソート順、検索テキスト）
5. **Button(intent:)**: Computed Propertyで動的生成すればフォーム入力にも対応可能
6. **App Shortcuts**: `AppShortcutsProvider` でSiri/ショートカット対応

### Button(intent:) の使い分け

| ケース | 方式 | 備考 |
|--------|------|------|
| チェックボックス、お気に入り | `Button(intent:)` | パラメータが既知 |
| 削除ボタン | `Button(intent:)` | パラメータが既知 |
| 作成フォーム | `Button(intent:)` + Computed Property | 動的にIntent生成、dismissは`onChange`で |

これらのインサイトは、今後のSwift/SwiftUI/App Intents開発に活用できます。

---

## Swift Package 構成のベストプラクティス

### DevDock式パッケージ構成

各パッケージが独立した `Package.swift` を持ち、相対パスで依存関係を参照する構成です。

```
ProjectRoot/
├── ProjectName/              # アプリソース
├── ProjectName.xcodeproj     # Xcodeプロジェクト
└── Packages/                 # 独立したパッケージ群
    ├── Domain/
    │   ├── Package.swift     # 独立したマニフェスト
    │   ├── Sources/Domain/
    │   └── Tests/DomainTests/
    ├── Repository/
    │   ├── Package.swift     # path: "../Domain" で依存
    │   └── ...
    └── UI/
        ├── Package.swift     # path: "../Repository" で依存
        └── ...
```

### 相対パス依存の記述

```swift
// Packages/Repository/Package.swift
let package = Package(
    name: "Repository",
    dependencies: [
        .package(path: "../Domain"),  // 相対パスで参照
    ],
    targets: [
        .target(
            name: "Repository",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
            ]
        ),
    ]
)
```

### メリット

1. **xcworkspace不要**: xcodeprojにPackagesフォルダをドラッグするだけ
2. **各パッケージが独立**: 個別にビルド・テスト可能
3. **明確な依存関係**: 各Package.swiftで依存が明示される
4. **Xcodeとの親和性**: パッケージ内のソースが直接編集可能

### ルート Package.swift 方式との比較

| 観点 | DevDock式（独立Package.swift） | ルートPackage.swift方式 |
|-----|-------------------------------|----------------------|
| Xcodeでの編集 | ✅ 直接編集可能 | ⚠️ 設定次第 |
| 個別ビルド | ✅ 各パッケージで可能 | ❌ 全体のみ |
| 依存の明確さ | ✅ 各ファイルで明示 | ⚠️ 1ファイルに集約 |
| xcworkspace | ✅ 不要 | ⚠️ 必要な場合あり |

---

## AppShortcutsProvider の制約

### メインアプリターゲットに配置する必要がある

`AppShortcutsProvider` はSwift Packageから公開できません。必ずメインアプリターゲットに配置する必要があります。

```swift
// ❌ パッケージ内で定義するとエラー
// Packages/TodoAppIntents/Sources/TodoAppIntents/Shortcuts/TodoAppShortcuts.swift
public struct TodoAppShortcuts: AppShortcutsProvider { ... }

// ✅ メインアプリターゲットに配置
// IntentTodo/TodoAppShortcuts.swift
import TodoAppIntents

struct TodoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),  // パッケージからimport
            phrases: [ ... ],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )
    }
}
```

### 複数のAppShortcutsProviderは不可

アプリ内に `AppShortcutsProvider` が複数存在するとビルドエラーになります。

---

## App Shortcuts フレーズの制限

### パラメータの型制限

App Shortcutのフレーズに埋め込めるのは **AppEntity** と **AppEnum** 型のみです。

```swift
// ❌ String型パラメータはフレーズに埋め込めない
AppShortcut(
    intent: AddTodoIntent(),
    phrases: [
        "Add \(\.$title) to \(.applicationName)"  // エラー: Invalid parameter type
    ],
    ...
)

// ✅ AppEntity/AppEnumのみ使用可能
AppShortcut(
    intent: ShowTodosIntent(),
    phrases: [
        "Show \(\.$filter) todos in \(.applicationName)"  // filter: TodoFilterType (AppEnum)
    ],
    ...
)

// ✅ パラメータなしのフレーズは問題なし
AppShortcut(
    intent: AddTodoIntent(),
    phrases: [
        "Add a todo in \(.applicationName)",
        "Create a new todo in \(.applicationName)"
    ],
    ...
)
```

### 回避策

String型パラメータを使いたい場合は、Siriがユーザーに後から入力を求めるフローを利用します（フレーズには埋め込まない）。

---

## コード簡素化のパターン

### 1. 不要なモジュールマーカーの削除

使われていない `enum ModuleName { static let version = "1.0.0" }` は削除し、コメントのみに変更。

### 2. Dictionary初期化の簡潔化

```swift
// Before
for item in items {
    dict[item.id] = item
}

// After
dict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
```

### 3. 重複するswitch文の統合

複数のcomputed propertyで同じswitch文を繰り返す場合、タプルを返す単一のプロパティに統合。

```swift
// Before: 3つのプロパティで同じswitch文を繰り返し
var emptyViewTitle: String { switch filter { ... } }
var emptyViewIcon: String { switch filter { ... } }
var emptyViewDescription: String { switch filter { ... } }

// After: タプルを返す単一のプロパティ
var emptyViewContent: (title: String, icon: String, description: String) {
    switch filter {
    case .all: return ("No Todos", "tray", "Add your first todo")
    // ...
    }
}
```

### 4. ネストした三項演算子の排除

複雑なネスト三項演算子は、ヘルパープロパティに分離して可読性を向上。

```swift
// Before
image: isCompleted ? .init(...) : (isFavorite ? .init(...) : .init(...))

// After
private var displayImage: DisplayRepresentation.Image {
    if isCompleted {
        return .init(systemName: "checkmark.circle.fill")
    } else if isFavorite {
        return .init(systemName: "star.fill")
    } else {
        return .init(systemName: "circle")
    }
}
```

---

## Extension ターゲットの制約と設計

### WidgetBundle の明示的登録

WidgetやControlWidgetは、定義しただけでは動作しません。必ず `WidgetBundle` に登録する必要があります。

```swift
// ❌ 定義だけでは不十分
struct ToggleUrgentTodoControl: ControlWidget { ... }

// ✅ WidgetBundleに明示的に登録
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        IntentTodoWidget()           // ホーム画面ウィジェット

        if #available(iOS 18.0, *) {
            QuickAddTodoControl()     // コントロールセンター
            TodoCountControl()
            ToggleUrgentTodoControl() // ← 忘れがち！
        }
    }
}
```

### ControlConfigurationIntent の配置制約

`ControlConfigurationIntent` はSwift Package内で定義できません。Extension ターゲットに直接配置する必要があります。

```swift
// ❌ パッケージ内では不可
// Packages/TodoAppIntents/Sources/.../QuickAddTodoControlIntent.swift

// ✅ Extension ターゲットに配置
// IntentTodoWidget/TodoControlWidget.swift
@available(iOS 18.0, *)
struct QuickAddTodoControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Add Todo"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        // パッケージのIntentを利用
        return .result(opensIntent: OpenAddTodoIntent())
    }
}
```

### Extension ターゲットごとの ModelContainer

各Extension（Widget、LiveActivity）は独立したプロセスで動作するため、ModelContainerを個別に作成する必要があります。

```swift
// IntentTodoWidget/IntentTodoWidget.swift
private let widgetModelContainer: ModelContainer = {
    let schema = Schema([TodoItem.self, SubTask.self, Category.self])
    let config = ModelConfiguration(schema: schema)
    return try! ModelContainer(for: schema, configurations: [config])
}()

// IntentTodoLiveActivity/Intents/LiveActivityIntents.swift
let liveActivityModelContainer: ModelContainer = {
    // 同じスキーマでも別インスタンスが必要
    let schema = Schema([TodoItem.self, SubTask.self, Category.self])
    let config = ModelConfiguration(schema: schema)
    return try! ModelContainer(for: schema, configurations: [config])
}()
```

**重要**: App Group を設定していれば、同じデータベースファイルを共有できます。

---

## watchOS 固有の制約

### Button(intent:) の API 差異

watchOS では iOS と同じ `Button(intent:role:)` シグネチャが利用できません。代わりに async パターンを使用します。

```swift
// ❌ watchOS ではエラー
Button(intent: ToggleTodoCompletionIntent(todo: entity), role: .none) {
    Text("Complete")
}

// ✅ watchOS 対応パターン
Button {
    Task {
        try? await ToggleTodoCompletionIntent(todo: entity).perform()
    }
} label: {
    Text("Complete")
}
```

### watchOS向けファイル分割

watchOSアプリは単一ファイルが肥大化しやすいため、早期に分割することを推奨。

```
IntentTodoWatchApp/
├── IntentTodoWatchApp.swift      # Appエントリーのみ
├── Views/
│   ├── WatchTodoListView.swift   # メインリスト
│   ├── WatchAddTodoView.swift    # 追加画面
│   └── WatchTodoDetailView.swift # 詳細画面
├── Components/
│   ├── WatchTodoRow.swift        # 行コンポーネント
│   └── WatchDueDateLabel.swift   # 期限ラベル
└── TodoComplication.swift        # コンプリケーション
```

---

## LiveActivity の Intent 設計

### LiveActivityIntent vs AppIntent

Live Activity からアクションを実行する場合は `LiveActivityIntent` を使用します。

```swift
// LiveActivityIntent: Live Activity専用
struct CompleteTodoFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Todo"

    @Parameter(title: "Todo ID")
    var todoId: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Todo完了処理
        // ...

        // Live Activity を終了（LiveActivityIntent固有の処理）
        await endLiveActivity(for: todoId)

        return .result()
    }
}
```

### 通常の AppIntent との使い分け

| Intent種別 | 用途 | 特徴 |
|-----------|------|------|
| `AppIntent` | Siri/Shortcuts/UI | 汎用的なアクション |
| `LiveActivityIntent` | Dynamic Island/ロック画面 | Activity状態の操作が可能 |
| `ControlConfigurationIntent` | コントロールセンター | Extension配置必須 |

---

## Intent 統合のベストプラクティス

### 重複Intentの検出と統合

似た機能を持つIntentは統合を検討します。

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
| `ShowTodosIntent` / `ShowIncompleteTodosIntent` | Siriフレーズが異なり、UX的に別ショートカットとして意味がある |
| `CompleteTodoFromActivityIntent` / `ToggleTodoCompletionIntent` | Live Activity固有の終了処理が必要 |
| `QuickAddTodoControlIntent` / `OpenAddTodoIntent` | ControlConfigurationIntentはExtension配置必須 |

---

## ファイル分割のパターン

### 肥大化したファイルの分割指針

1ファイルが200行を超えたら分割を検討。以下のパターンで整理：

```
Target/
├── TargetMain.swift              # エントリーポイント・Widget定義のみ
├── Configuration/                # Intent/Configuration定義
│   └── TargetConfigurationIntent.swift
├── Views/                        # UI View
│   ├── MainView.swift
│   └── DetailView.swift
├── Components/                   # 再利用可能な小さいView
│   ├── RowComponent.swift
│   └── BadgeComponent.swift
├── Intents/                      # ターゲット固有のIntent
│   └── TargetSpecificIntent.swift
└── Manager/                      # ビジネスロジック管理
    └── TargetManager.swift
```

### 分割時の注意点

- **internal型の共有**: 同じターゲット内なら `import` 不要
- **Preview**: 分割後も各ファイルでPreviewが動作するよう依存を整理
- **ビルドエラー**: 循環参照に注意（型の定義順序）
