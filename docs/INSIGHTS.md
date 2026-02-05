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
13. [Extension ターゲットの制約と設計](#extension-ターゲットの制約と設計)
14. [App Groups によるデータ共有](#app-groups-によるデータ共有)
15. [Intent から UI へのコミュニケーション](#intent-から-ui-へのコミュニケーション)
16. [openAppWhenRun から supportedModes/OpenIntent への移行](#openappwhenrun-から-supportedmodesopenintent-への移行)
17. [Control Widget 用シンプルIntent パターン](#control-widget-用シンプルintent-パターン)

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

### iOS 26+: パッケージ内でも定義可能

iOS 26以降では、`AppShortcutsProvider`をSwift Package内で定義し、`AppIntentsPackage`経由で統合できます。

```swift
// ✅ iOS 26+: パッケージ内で定義可能
// Packages/TodoAppIntents/Sources/TodoAppIntents/Shortcuts/TodoAppShortcuts.swift
public struct TodoAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [ ... ],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )
    }
}

// メインアプリでAppIntentsPackageとして統合
// IntentTodo/AppIntentsExtension.swift
struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]  // パッケージ内のAppShortcutsProviderも含まれる
    }
}
```

### iOS 18以前の制約（参考）

iOS 18以前では、`AppShortcutsProvider`はメインアプリターゲットに配置する必要がありました。
パッケージ内で定義すると認識されない問題がありました。

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

---

## Control Widget の制約

### ControlConfigurationIntent と SetValueIntent の非互換性

iOS 18のControl Widget APIでは、`ControlConfigurationIntent`と`SetValueIntent`を同時に準拠させることができません：

```swift
// ❌ コンパイルエラー: ControlConfigurationIntentは全パラメータoptional必須
// SetValueIntentはvalue: Bool (non-optional) を要求
struct ToggleControlIntent: ControlConfigurationIntent, SetValueIntent {
    @Parameter(title: "Value")
    var value: Bool  // ← ControlConfigurationIntentではoptionalが必須
}
```

### 解決策: ControlWidgetButton でトグル実装

```swift
// ✅ ボタンでトグル操作を実装
@available(iOS 18.0, *)
struct ToggleUrgentTodoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ToggleUrgentTodoControlIntent.self
        ) { configuration in
            ControlWidgetButton(action: ToggleUrgentTodoControlIntent()) {
                Label {
                    Text(configuration.todoTitle ?? "No urgent todo")
                } icon: {
                    Image(systemName: configuration.isCompleted
                        ? "checkmark.circle.fill"
                        : "clock.badge.exclamationmark")
                }
            }
        }
    }
}

// perform()でトグル
func perform() async throws -> some IntentResult {
    guard let todo = fetchUrgentTodo() else { return .result() }
    todo.isCompleted.toggle()
    try? context.save()
    return .result()
}
```

---

## Live Activity の自動管理

### View Modifier パターン

Live Activityの自動開始/終了は、View modifierとして実装することで既存UIに非侵入的に追加できます：

```swift
#if os(iOS)
@available(iOS 16.1, *)
struct LiveActivityMonitorModifier: ViewModifier {
    let todos: [TodoItem]

    func body(content: Content) -> some View {
        content
            .task { await checkAndStartActivities() }
            .onChange(of: todos.map(\.id)) { _, _ in
                Task { await checkAndStartActivities() }
            }
    }

    @MainActor
    private func checkAndStartActivities() async {
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)

        // 期限1時間以内の未完了Todoを自動でLive Activity表示
        let urgentTodos = todos.filter { todo in
            guard let dueDate = todo.dueDate, !todo.isCompleted else { return false }
            return dueDate > now && dueDate <= oneHourFromNow
        }

        for todo in urgentTodos where !existingActivityIds.contains(todo.id) {
            await startActivity(for: todo)
        }

        // 完了時または期限15分経過後に自動終了
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            if shouldEndActivity(activity) {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
```

### 使用方法

```swift
public var body: some View {
    NavigationStack { /* ... */ }
    #if os(iOS)
    .monitorLiveActivities(for: todoItems)
    #endif
}
```

---

## Widget への Button(intent:) 統合

### iOS 17+ での直接Intent実行

Widget内でボタンをタップして直接Intentを実行できます：

```swift
// ✅ Widget Large にクイック追加ボタン
Button(intent: OpenAddTodoIntent()) {
    HStack {
        Image(systemName: "plus.circle.fill")
        Text("Add Todo")
    }
    .font(.subheadline.weight(.medium))
    .foregroundStyle(.orange)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
}
.buttonStyle(.plain)
```

### 注意点

- `AppIntents`モジュールのimportが必要
- `Intent`は`openAppWhenRun = true`でアプリを開くか、バックグラウンド実行
- Widget Extensionでは`@main`バンドルにIntentが含まれている必要あり（パッケージからのre-export対応）

---

## App Groups によるデータ共有

### 問題: Extension とメインアプリのデータ分離

ウィジェット、コントロールセンター、Live Activityなどの**Extension**は、メインアプリとは**別プロセス**で動作します。そのため、各ターゲットで個別に`ModelContainer`を作成すると、**データが共有されません**。

```swift
// ❌ 各ターゲットで別々にModelContainerを作成
// → データベースファイルが異なり、データが共有されない

// Widget
private let widgetModelContainer = try! ModelContainer(for: schema, configurations: [config])

// Main App
let appModelContainer = try! ModelContainer(for: schema, configurations: [config])

// 結果: Widget は常に空のデータを表示（All done!）
```

### 解決策: App Groups と SharedModelContainer

App Groupsを使用して共有コンテナにデータベースを配置することで、全ターゲット間でデータを共有できます。

```swift
// Packages/Domain/Sources/Domain/SharedModelContainer.swift
public enum SharedModelContainer {
    /// App Group identifier（全ターゲットで同じ値を使用）
    public static let appGroupIdentifier = "group.com.example.MyApp"

    /// 共有コンテナURL
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    /// 共有ModelConfigurationを作成
    public static var configuration: ModelConfiguration? {
        if let containerURL = sharedContainerURL {
            let storeURL = containerURL.appendingPathComponent("MyApp.store")
            return ModelConfiguration(schema: schema, url: storeURL)
        }
        return nil  // フォールバック
    }

    /// 共有ModelContainerを作成
    public static func createContainer() throws -> ModelContainer {
        if let config = configuration {
            return try ModelContainer(for: schema, configurations: [config])
        }
        return try ModelContainer(for: schema)
    }
}
```

### 使用方法

全ターゲットで`SharedModelContainer`を使用:

```swift
// Main App
let container = try SharedModelContainer.createContainer()

// Widget
private let widgetModelContainer = try! SharedModelContainer.createContainer()

// Live Activity
let liveActivityModelContainer = try! SharedModelContainer.createContainer()

// Control Center
private let controlWidgetModelContainer = try! SharedModelContainer.createContainer()
```

### Xcodeでの App Groups 設定手順

1. **メインアプリターゲット**: Signing & Capabilities → + Capability → App Groups
2. **各Extensionターゲット**: 同様に App Groups を追加
3. **全ターゲットで同じ識別子を使用**: `group.com.example.MyApp`

**重要**: この設定はXcodeで手動で行う必要があり、コードだけでは完結しません。

### watchOS の注意点

watchOS と iOS は別デバイスのため、App Groups では直接データ共有できません。Watch Connectivityを使用するか、CloudKitで同期する必要があります。

---

## コントロールセンターのタップが動作しない問題

### 原因

Control Widgetはメインアプリとは別プロセスで動作するため、以下が起きます:

1. **独自のModelContainer**: メインアプリのデータにアクセスできない
2. **IntentDependenciesが未設定**: `IntentDependencies.shared.modelContainer`が`nil`
3. **結果**: `perform()`が空のデータで動作、または失敗

### 解決策

1. **SharedModelContainer**を使用してデータ共有
2. **App Groups**をXcodeで設定
3. **Intent内で直接ModelContainerにアクセス**（IntentDependenciesに依存しない）

```swift
@MainActor
func perform() async throws -> some IntentResult {
    // SharedModelContainerから直接取得
    let container = try SharedModelContainer.createContainer()
    let context = container.mainContext

    // データ操作
    guard let todo = fetchUrgentTodo(from: context) else {
        return .result()
    }
    todo.isCompleted.toggle()
    try context.save()

    return .result()
}
```

---

## Intent から UI へのコミュニケーション

### 問題: Intent からアプリUIを操作したい

`OpenAddTodoIntent`のようにアプリを開いて特定のUI状態（モーダル表示など）を設定したい場合、IntentからSwiftUIのViewに直接アクセスできません。

### 解決策: SharedState + UserDefaults

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/AppState/IntentAppState.swift
@MainActor
public final class IntentAppState {
    public static let shared = IntentAppState()

    private enum Keys {
        static let shouldShowAddTodo = "IntentAppState.shouldShowAddTodo"
    }

    /// Add Todo画面を表示すべきかどうか
    public var shouldShowAddTodo: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.shouldShowAddTodo) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.shouldShowAddTodo) }
    }

    /// Intent側: 表示をリクエスト
    public func requestShowAddTodo() {
        shouldShowAddTodo = true
    }

    /// UI側: リクエストを消費（一度だけ処理）
    public func consumeShowAddTodoRequest() -> Bool {
        guard shouldShowAddTodo else { return false }
        shouldShowAddTodo = false
        return true
    }
}
```

### Intent での使用

```swift
public struct OpenAddTodoIntent: AppIntent {
    public static var openAppWhenRun: Bool { true }

    @MainActor
    public func perform() async throws -> some IntentResult {
        // UI にリクエストを送信
        IntentAppState.shared.requestShowAddTodo()
        return .result()
    }
}
```

### View での使用

```swift
public var body: some View {
    NavigationStack { /* ... */ }
        .onAppear {
            // アプリ起動時にチェック
            if IntentAppState.shared.consumeShowAddTodoRequest() {
                navigationViewModel.showAddTodo()
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // バックグラウンドから復帰時にもチェック
            if IntentAppState.shared.consumeShowAddTodoRequest() {
                navigationViewModel.showAddTodo()
            }
        }
        #endif
}
```

### ポイント

- **UserDefaults**を使用することでExtensionからもアクセス可能
- **consume パターン**でリクエストを一度だけ処理
- **複数のタイミングでチェック**: `onAppear`と`didBecomeActiveNotification`

---

## WidgetKit 更新パターン

### 問題: データ変更後にウィジェットが更新されない

Intentでデータを変更しても、ウィジェットは自動的に更新されません。明示的にタイムラインの再読み込みが必要です。

### 解決策: WidgetReloader ヘルパー

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/Helpers/WidgetReloader.swift
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum WidgetReloader {
    /// 全ウィジェットのタイムラインを再読み込み
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// 特定のウィジェット種別のみ再読み込み
    public static func reloadWidget(kind: String) {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        #endif
    }
}
```

### 使用箇所（全データ変更Intent）

```swift
// AddTodoIntent
try repository.create(todoItem)
WidgetReloader.reloadAllWidgets()  // ← 追加

// ToggleTodoCompletionIntent
todoItem.isCompleted.toggle()
try repository.update(todoItem)
WidgetReloader.reloadAllWidgets()  // ← 追加

// DeleteTodoIntent
try repository.delete(by: uuid)
WidgetReloader.reloadAllWidgets()  // ← 追加

// ToggleFavoriteIntent
todoItem.isFavorite.toggle()
try repository.update(todoItem)
WidgetReloader.reloadAllWidgets()  // ← 追加
```

### Extension内での直接呼び出し

Extension内（LiveActivity, Control Widget）では`WidgetReloader`をimportできない場合があるため、直接呼び出します:

```swift
// IntentTodoWidget/TodoControlWidget.swift
import WidgetKit

func perform() async throws -> some IntentResult {
    // データ変更
    todo.isCompleted.toggle()
    try? context.save()

    // ウィジェット更新（直接呼び出し）
    WidgetCenter.shared.reloadAllTimelines()

    return .result()
}
```

---

## ControlConfigurationIntent のフィードバック制限

### 問題: Control Center で完了時のフィードバックがない

`ControlConfigurationIntent`は通常の`AppIntent`と異なり、`.result(dialog:)`をサポートしていません。

### 利用可能なフィードバック手段

| 手段 | サポート状況 | 備考 |
|------|------------|------|
| dialog パラメータ | ❌ | ControlConfigurationIntentでは不可 |
| 視覚的状態変化 | ✅ | アイコン/テキストの変更 |
| システムハプティック | ✅ | 自動提供 |
| ローカル通知 | ✅ | 実装可能だが侵入的 |

### 現在の設計

Control Centerのフィードバックは**視覚的な状態変化**で提供:

1. **タップ前**: `clock.badge.exclamationmark` アイコン + Todo タイトル
2. **タップ後**: `checkmark.circle.fill` アイコン + 次のUrgent Todo タイトル

```swift
ControlWidgetButton(action: ToggleUrgentTodoControlIntent()) {
    Label {
        Text(configuration.todoTitle ?? "No urgent todo")
    } icon: {
        Image(systemName: configuration.isCompleted
            ? "checkmark.circle.fill"    // 完了後
            : "clock.badge.exclamationmark")  // 未完了
    }
}
```

### 実装: ローカル通知によるフィードバック

Control Center操作の結果をローカル通知で伝えることで、明示的なフィードバックを実現：

```swift
// IntentTodoWidget/Helpers/ControlNotificationHelper.swift
enum ControlNotificationHelper {
    /// Todo完了時の通知
    static func sendCompletedNotification(todoTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Completed"
        content.body = "✅ \(todoTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-completed-\(UUID().uuidString)",
            content: content,
            trigger: nil  // 即座に配信
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Todo数の通知
    static func sendTodoCountNotification(incompleteCount: Int, totalCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Status"
        content.body = incompleteCount == 0
            ? "🎉 All done! No pending todos."
            : "📋 \(incompleteCount) of \(totalCount) todos remaining"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-count-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

### 通知権限のリクエスト

アプリ起動時に通知権限をリクエスト：

```swift
// IntentTodoApp.swift
var body: some Scene {
    WindowGroup {
        TodoListView()
            .task {
                await requestNotificationPermission()
            }
    }
}

private func requestNotificationPermission() async {
    let center = UNUserNotificationCenter.current()
    _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
}
```

---

## OpensIntent の制約

### 問題: Control Widget から OpensIntent が機能しない

`ControlConfigurationIntent`で`OpensIntent`を使ってIntentをチェインしても、期待通りに動作しないことがあります。

```swift
// ❌ 機能しない場合がある
struct QuickAddTodoControlIntent: ControlConfigurationIntent {
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenAddTodoIntent())
    }
}
```

### 解決策: 直接状態を設定

`OpensIntent`を使わず、直接共有状態を設定してアプリを開く：

```swift
// ✅ 直接状態を設定
struct QuickAddTodoControlIntent: ControlConfigurationIntent {
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // 共有状態を直接設定
        IntentAppState.shared.requestShowAddTodo()

        // 通知でフィードバック
        ControlNotificationHelper.sendQuickAddNotification()

        return .result()
    }
}
```

### ポイント

- `openAppWhenRun = true`でアプリは開く（はずだが不安定な場合あり）
- `IntentAppState`で必要な状態を伝達
- 通知でユーザーに操作結果を伝える

---

## Extension間データ共有のベストプラクティス

### UserDefaults の App Group 対応

Widget、Control Center、Live Activity などの Extension は別プロセスで動作するため、`UserDefaults.standard` ではデータを共有できません。

```swift
// ❌ 共有されない
UserDefaults.standard.bool(forKey: "someKey")

// ✅ App Group で共有
let sharedDefaults = UserDefaults(suiteName: "group.com.example.MyApp") ?? .standard
sharedDefaults.bool(forKey: "someKey")
```

### IntentAppState の実装例

```swift
@MainActor
public final class IntentAppState {
    public static let shared = IntentAppState()

    /// App Group 経由の共有 UserDefaults
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
    }

    public var shouldShowAddTodo: Bool {
        get { sharedDefaults.bool(forKey: Keys.shouldShowAddTodo) }
        set { sharedDefaults.set(newValue, forKey: Keys.shouldShowAddTodo) }
    }
}
```

### 重要なポイント

- **ModelContainer** と **UserDefaults** の両方で App Group を使用
- フォールバックとして `.standard` を用意（App Group 未設定時のデバッグ用）
- Xcode で全ターゲットに同じ App Group を設定することが必須

---

## openAppWhenRun から supportedModes/OpenIntent への移行

### 背景: openAppWhenRun の問題 (iOS 18以前)

iOS 18以前では、Widget および Control Center Widget において、`openAppWhenRun = true` を設定すると **`perform()` メソッドが呼ばれない**という問題がありました。これは通知経由やURLスキームでの回避策が必要でした。

### iOS 26+ での解決: OpenIntent と supportedModes

iOS 26（Xcode 26）では、以下の新しいAPIが導入されました：

1. **`OpenIntent`プロトコル**: アプリを開くIntentの専用プロトコル
2. **`supportedModes`**: `openAppWhenRun`を置き換える新しいプロパティ
3. **`IntentModes`**: `.foreground(.dynamic)`（動的フォアグラウンド）、`.foreground`（アプリを開く）、`.background`（バックグラウンド実行）

### supportedModes: .foreground(.dynamic) の重要性

iOS 26では、**`ForegroundContinuableIntent`は非推奨**になりました。代わりに `supportedModes: .foreground(.dynamic)` を使用します。

`.foreground(.dynamic)` を使用することで、IntentがWidget Extensionのプロセスではなく、**メインアプリのプロセスで実行される**ようになります。これにより、メインアプリのコンテキスト（共有状態など）にアクセスできます。

### OpenIntent の実装

`OpenIntent`プロトコルには`target`パラメータ（`AppEnum`型）が必要です。`supportedModes: .foreground(.dynamic)`も追加してControl Widgetから確実にアプリを開けるようにします：

```swift
// 画面を表す AppEnum
public enum AppScreenTarget: String, AppEnum {
    case addTodo
    case todoList
    case incompleteTodos
    case favoriteTodos

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "App Screen")
    }

    public static var caseDisplayRepresentations: [AppScreenTarget: DisplayRepresentation] {
        [
            .addTodo: DisplayRepresentation(title: "Add Todo"),
            .todoList: DisplayRepresentation(title: "Todo List"),
            // ...
        ]
    }
}

// 統一された LaunchAppIntent
// OpenIntent に準拠 + supportedModes で動的フォアグラウンド実行
public struct LaunchAppIntent: OpenIntent {
    public static var title: LocalizedStringResource = "Open Todo App"

    /// 動的フォアグラウンド: メインアプリプロセスで実行
    /// iOS 26+ で ForegroundContinuableIntent を置き換える
    public static var supportedModes: IntentModes { .foreground(.dynamic) }

    @Parameter(title: "Target")
    public var target: AppScreenTarget

    public init() {
        self.target = .todoList
    }

    public init(target: AppScreenTarget) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        switch target {
        case .addTodo:
            IntentAppState.shared.requestShowAddTodo()
        case .todoList, .incompleteTodos, .favoriteTodos:
            // アプリが適切な画面を表示
            break
        }
        return .result()
    }
}
```

### 重要: OpenIntent の target は一意である必要

**同じ`AppEnum`型を複数の`OpenIntent`で使用することはできません。** 以下のようなエラーになります：

```
error: OpenIntent targets should be unique, but these all have 'AppScreenTarget' as their target: OpenAddTodoIntent, OpenTodoListIntent
```

**解決策**: 単一の`LaunchAppIntent`で全ての画面を管理し、`target`パラメータで分岐します。

### supportedModes の使用

バックグラウンドで実行するIntent（アプリを開かない）には`supportedModes: .background`を使用：

```swift
public struct AddTodoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Add Todo"

    /// バックグラウンドで実行（アプリを開かない）
    public static var supportedModes: IntentModes { .background }

    // ...
}
```

### Control Center Widget での使用

`StaticControlConfiguration`を使用してConfigurationIntentの問題を回避：

```swift
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        // StaticControlConfiguration を使用（ConfigurationIntent不要）
        StaticControlConfiguration(kind: Self.kind) {
            // OpenIntent を使用してアプリを開く
            ControlWidgetButton(action: LaunchAppIntent(target: .addTodo)) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}
```

### ConfigurationIntent のモジュール境界問題

Widget Extension内で定義した`ControlConfigurationIntent`は、アプリ本体から参照できません。これはSwiftのモジュール名mangling（例: `25IntentTodoWidgetExtension0bc13ConfigurationA0V`）が原因です。

**解決策**: `StaticControlConfiguration`を使用し、ConfigurationIntentを必要としない設計にします。動的な設定が必要な場合は、TodoAppIntentsパッケージ内でIntentを定義し、両方のターゲットから参照できるようにします。

### まとめ

| 項目 | iOS 18以前 | iOS 26+ |
|------|-----------|---------|
| アプリを開く | `openAppWhenRun = true`（不安定） | `OpenIntent` + `supportedModes: .foreground(.dynamic)` |
| バックグラウンド実行 | `openAppWhenRun = false` | `supportedModes: .background` |
| フォアグラウンド実行 | URLスキーム/通知回避策 | `supportedModes: .foreground` |
| 動的フォアグラウンド | `ForegroundContinuableIntent` | `supportedModes: .foreground(.dynamic)` |
| 画面指定 | `IntentAppState`で間接的に | `target`パラメータで明示的に |
| Control Widget設定 | `AppIntentControlConfiguration` | `StaticControlConfiguration`推奨 |

**iOS 26+では、`OpenIntent` + `supportedModes: .foreground(.dynamic)`と`StaticControlConfiguration`を使用することで、Widget/Control Widget からアプリを確実に開くことができます。**

**注意**: `ForegroundContinuableIntent`はiOS 26で非推奨になりました。代わりに`supportedModes`に`.foreground(.dynamic)`を含めてください。

---

## Control Widget 用シンプルIntent パターン

### 問題: パラメータ付きIntentが機能しない

Control Widgetで`@Parameter`付きのIntentを使用すると、アプリが開かない場合があります。これはControl Widgetの実行コンテキストの制約によるものと考えられます。

```swift
// ⚠️ 動作が不安定な場合がある
public struct LaunchAppIntent: AppIntent {
    public static var supportedModes: IntentModes { .foreground }

    @Parameter(title: "Target")
    public var target: AppScreenTarget  // パラメータ付き

    @MainActor
    public func perform() async throws -> some IntentResult {
        // ...
    }
}

// Control Widget での使用
ControlWidgetButton(action: LaunchAppIntent(target: .addTodo)) { ... }
```

### 解決策: パラメータなしの専用Intent

Control Widget用に**パラメータなし**のシンプルなIntentを作成します：

```swift
// ✅ Control Widget で確実に動作
public struct OpenAddTodoIntent: AppIntent {
    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Add Todo")
    }

    /// フォアグラウンドモードでアプリを開く
    public static var supportedModes: IntentModes { .foreground }

    public init() {}  // パラメータなし

    @MainActor
    public func perform() async throws -> some IntentResult {
        // 共有状態を設定
        IntentAppState.shared.requestShowAddTodo()
        return .result()
    }
}

public struct OpenTodoListIntent: AppIntent {
    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Todo List")
    }

    public static var supportedModes: IntentModes { .foreground }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // アプリを開くだけ（デフォルト画面）
        return .result()
    }
}
```

### Control Widget での使用

```swift
struct QuickAddTodoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            // シンプルなパラメータなしIntentを使用
            ControlWidgetButton(action: OpenAddTodoIntent()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
    }
}

struct TodoCountControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenTodoListIntent()) {
                Label { Text("\(fetchIncompleteCount())") }
                icon: { Image(systemName: "checklist") }
            }
        }
        .displayName("Todo Count")
    }
}
```

### 使い分けの指針

| Intent種別 | 用途 | 特徴 |
|-----------|------|------|
| **パラメータなしIntent** | Control Widget, Action Button | シンプル、確実に動作 |
| **パラメータ付きIntent** | Shortcuts, Siri, 通常のUI | 柔軟性が高い |
| **OpenIntent + target** | アプリ内ナビゲーション | 汎用的だがControl Widgetでは不安定 |

### ポイント

1. **Control Widget専用Intentを作成**: 各画面ごとに専用のIntentを定義
2. **パラメータを排除**: `@Parameter`を使わず、固定動作のみ
3. **`supportedModes: .foreground`**: アプリを開くために必須
4. **IntentAppState経由の状態共有**: アプリにどの画面を表示すべきか伝達
5. **StaticControlConfiguration使用**: ConfigurationIntentの複雑さを回避

---
