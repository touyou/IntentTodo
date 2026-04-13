# App Intents 中心設計ガイド

このドキュメントは、App Intents を中心としたアプリ設計パターンをまとめたものです。IntentTodo プロジェクトの実装経験に基づいています。

---

## 設計思想の背景

本設計は以下の概念を統合しています：

| 概念 | 出典 | 本設計での活用 |
|------|------|--------------|
| **App Intent Driven Development** | SwiftLee | コード再利用とシステム統合の基盤 |
| **Action-Centered Design** | Vidit Bhargava | マルチプラットフォーム展開指針 |
| **モデルベースUIデザイン** | usagimaru理論 | ユースケースとIntentの写像 |

### アプリ = アクションのクラスター

> アプリはプラットフォームに縛られない「アクションと情報の集合体」である。

- **Intent（動詞）** = ユースケースの「行動できる」
- **Entity（名詞）** = ユースケースの「誰が」「何を」

この考え方により、デザイン（ユースケース定義）と実装（Intent定義）の間に**自然な写像**が生まれます。

### Liquid Glass時代の設計観

UIクローム（装飾）が透明化し背景に溶け込む時代：
- **コンテンツとアクションが本質** - 標準UIで十分
- **Intent定義に注力** - Apple Intelligenceとの統合が自然に実現
- **UI、アプリ、デバイスの境界が曖昧化** - アクション/情報へのアクセスが本質

---

## 従来設計との比較

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
   (Siri/Shortcuts/Widget/Apple Intelligence からも実行可能)
```

### 核心原則

1. **すべてのアクションはIntentとして定義**
2. **IntentがビジネスロジックのSingle Source of Truth**
3. **UIはIntent実行のトリガーと結果表示のみ**
4. **ロジックの二重実装を排除**
5. **アクションと情報が設計の原子単位** - UIやプラットフォームは二次的

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

    // MARK: - Dependencies
    @Dependency
    var modelContainer: ModelContainer

    // MARK: - 実行
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        // 1. バリデーション
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }

        // 2. Repository 生成（@Dependency で取得した ModelContainer から）
        let repository = SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))

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

## DI パターン（@Dependency + AppDependencyManager）

### 基本方針

`ModelContainer` や `@Observable @MainActor` クラスは `Sendable` 要件を満たすため、`AppDependencyManager` 経由で Intent と共有できる。アプリ起動時に `AppDependencyManager.shared.add(dependency:)` で**同期登録**し、Intent 側で `@Dependency` で取得する。

```swift
// ProjectNameApp.swift
@main
struct IntentTodoApp: App {
    let modelContainer: ModelContainer
    @State private var navigation: NavigationModel

    init() {
        // ModelContainer を同期登録
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        // NavigationModel を同期登録（同じインスタンスを @State にも保持）
        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }

    var body: some Scene {
        WindowGroup {
            TodoListView()
                .environment(navigation)
        }
        .modelContainer(modelContainer)
    }
}
```

### Intent 側

```swift
struct AddTodoIntent: AppIntent {
    @Dependency var modelContainer: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let repository = SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))
        // ...
    }
}

struct LaunchAppIntent: AppIntent {
    @Dependency var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showAddTodo()
        return .result()
    }
}
```

### 注意点

- **`AppDependencyManager` 用の `AppIntentsPackage` を主ターゲットに重複宣言しないこと**。SPM 側で `AppIntentsPackage` を宣言している場合、main target に `includedPackages: [TodoIntentsPackage.self]` を含む `AppIntentsPackage` を追加するとシステム上で二重扱いになり、Shortcuts のルーティングが壊れる。main target には `AppIntentsPackage` を一切宣言しなくてよい。
- 登録は `App.init()` で同期的に行うこと（`Task { ... }` にすると Intent の `perform()` 実行時にまだ登録されていない可能性がある）。

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
    @Dependency
    var modelContainer: ModelContainer

    @MainActor
    private func makeRepository() -> SwiftDataTodoRepository {
        SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))
    }

    @MainActor
    public func entities(for identifiers: [String]) async throws -> [TodoAppEntity] {
        let repository = makeRepository()
        return try identifiers.compactMap { id in
            guard let uuid = UUID(uuidString: id),
                  let todo = try repository.fetch(by: uuid) else { return nil }
            return TodoAppEntity(from: todo)
        }
    }

    @MainActor
    public func suggestedEntities() async throws -> [TodoAppEntity] {
        try makeRepository().fetchIncomplete().map { TodoAppEntity(from: $0) }
    }

    @MainActor
    public func entities(matching string: String) async throws -> [TodoAppEntity] {
        try makeRepository().fetchAll()
            .filter { $0.title.localizedCaseInsensitiveContains(string) }
            .map { TodoAppEntity(from: $0) }
    }
}
```

---

## App Shortcuts

### 配置場所

**AppShortcutsProvider はパッケージ内で定義可能**ですが、メインアプリターゲットから `@_exported import` で再エクスポートする必要があります。

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/Shortcuts/TodoAppShortcuts.swift
public struct TodoAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: ["Add a todo in \(.applicationName)"],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )
        // ... other shortcuts
    }
}

// IntentTodo/TodoAppShortcuts.swift（メインアプリターゲット）
import AppIntents
@_exported import TodoAppIntents  // パッケージのShortcutsも公開される
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
import AppIntents  // ← Button(intent:) を使用するために必須

// ✅ 推奨: Button(intent:) を直接使用
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark")
}

// 削除ボタン
Button(intent: DeleteTodoIntent(todo: entity)) {
    Label("Delete", systemImage: "trash")
}
.tint(.red)
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
| **ビジネスロジック** | App Intents | CRUD操作、バリデーション、データ取得 |
| **UI状態管理** | ViewModel | フィルター状態、ソート順、検索テキスト |
| **表示** | View | レイアウト、アニメーション |

### なぜ分けるのか？

```
【App Intents】
- Siri/Shortcuts からも実行される
- UIに依存しない純粋なロジック
- 例: Todo作成、完了切り替え、削除、検索クエリ実行

【ViewModel】
- アプリUI固有のロジック
- Siri/Shortcuts からは使われない
- 例: フィルター状態、ソート順、検索テキスト（入力値）
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

### フォーム入力 + Button(intent:)

Computed Propertyを使えば、フォーム入力が必要なケースでも `Button(intent:)` が使えます。

```swift
import AppIntents  // ← 必須

struct AddTodoView: View {
    @State private var title = ""
    @State private var dueDate: Date?

    // ✅ Computed Propertyで動的にIntent生成
    private var addTodoIntent: AddTodoIntent {
        AddTodoIntent(title: title, dueDate: dueDate)
    }

    var body: some View {
        Form {
            TextField("Title", text: $title)
            DatePicker("Due Date", selection: ...)
        }
        .toolbar {
            Button(intent: addTodoIntent) {
                Text("Add")
            }
            .disabled(title.isEmpty)
        }
    }
}
```

**注意点**:
- 完了通知がないため、dismissは `onChange(of:)` でデータ変更を検知して行う
- エラーはシステムがアラートで表示（カスタムエラーUI不可）

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

### メタデータと Repository 層のテスト

`@Dependency` は `AppDependencyManager` 経由で解決されるため、SPM テスト（ホストアプリなし）では `perform()` の実行テストは難しい。以下の方針でカバーする：

- **Repository 層**: 通常のモック注入 + ユニットテストで網羅
- **Intent メタデータ**: `title` / `supportedModes` / `parameterSummary` 等の静的プロパティをテスト
- **ビジネスロジック**: 可能な限り `perform()` から分離し、静的メソッド/Repository 側でテスト
- **E2E**: 実機 Shortcuts / Siri での動作確認で補完

```swift
import Testing
@testable import TodoAppIntents

@Suite("AddTodoIntent Metadata Tests")
struct AddTodoIntentTests {
    @Test("supportedModes includes background")
    func supportedModes() {
        #expect(AddTodoIntent.supportedModes.contains(.background))
    }

    @Test("Init assigns parameters correctly")
    func initialization() {
        let intent = AddTodoIntent(title: "Buy groceries")
        #expect(intent.title == "Buy groceries")
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

- [ ] パッケージで定義可能だが、メインアプリから `@_exported import` で再エクスポート
- [ ] String型パラメータはフレーズに埋め込まない
- [ ] `shortTitle` と `systemImageName` を設定
- [ ] 複数のAppShortcutsProviderを作らない

---

---

## マルチプラットフォーム展開指針

Action-Centered Designの考え方に基づき、アクション/情報の特性に応じて適切なプラットフォームに展開します。

### 展開の判断基準

| コンテンツ/アクションの特性 | 展開先 | 理由 |
|---------------------------|--------|------|
| 毎日確認する情報 | **ウィジェット** | グランスで確認可能 |
| 頻繁に変わる情報 | **watchOSコンプリケーション** | 常時表示、即時確認 |
| 繰り返しのアクション | **Shortcuts / Siri** | 音声/自動化で効率化 |
| 常時追跡が必要な情報 | **ライブアクティビティ** | ロック画面で継続表示 |
| 素早いアクセスが必要 | **コントロールセンター** | ワンタップでアクセス |
| 物理的なトリガーが自然 | **Action Button** | 即座に実行 |

### 設計プロセス

1. **最小のスクリーンから設計開始**
   - Apple Watch等、最も制約の厳しい環境で本質的なアクションを特定
   - 「本当に必要なアクションは何か？」を問う

2. **アクションをIntent化**
   - 特定したアクションをApp Intentとして定義
   - EntityとIntentの関係を明確化

3. **プラットフォーム固有の実装へ拡張**
   - 上記の表に従って各プラットフォームに展開
   - 同一のIntentを複数のプラットフォームで再利用

4. **メインアプリUIは最後**
   - 複数のアクションをクラスター化
   - ナビゲーション階層を決定してスクリーン設計

---

## エクステンションターゲットでの注意点

### WidgetBundle への明示的登録

ウィジェット・コントロールは `WidgetBundle` に**明示的に登録**しないと利用できません。

```swift
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        // ホーム画面ウィジェット
        IntentTodoWidget()

        // コントロールセンター（iOS 18+）
        if #available(iOS 18.0, *) {
            QuickAddTodoControl()
            TodoCountControl()
            ToggleUrgentTodoControl()  // 忘れがち！
        }
    }
}
```

### ControlConfigurationIntent の配置

`ControlConfigurationIntent` を準拠するIntentは**エクステンションターゲット内**に配置する必要があります。Swift Package内では動作しません。

```swift
// ❌ Swift Package内では動作しない
// Packages/TodoAppIntents/Sources/.../ToggleUrgentTodoIntent.swift

// ✅ Widgetエクステンションターゲット内に配置
// IntentTodoWidget/Controls/ToggleUrgentTodoControl.swift
struct ToggleUrgentTodoIntent: AppIntent, ControlConfigurationIntent {
    // ...
}
```

### LiveActivityIntent の違い

ライブアクティビティからのボタン操作には `LiveActivityIntent` プロトコルが必要（[Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Start-and-stop-Live-Activities-from-App-Intents) より "make sure it inherits from `LiveActivityIntent`"）。さらに [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) によれば `LiveActivityIntent` の `perform()` は**アプリプロセス**で実行される（"the system runs the app intent in the app's process"）。

```swift
// ❌ 通常のAppIntentはLiveActivityで動作しない
struct CompleteTodoIntent: AppIntent { ... }

// ✅ LiveActivityIntentを準拠
struct CompleteTodoFromActivityIntent: AppIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Todo"

    @Parameter(title: "Todo ID")
    var todoId: String

    init() {}

    init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Live Activity終了処理も含める
        return .result()
    }
}
```

### Extension 内 Intent の ModelContainer アクセス

Extension ターゲット側で独自に Intent を定義している場合（例: `ToggleUrgentTodoIntent` を Widget Extension に配置）、安全策として `SharedModelContainer.createContainer()` から直接 ModelContainer を取得する。これは App Group 経由で共有 DB にアクセスでき、どのプロセスで実行されても動作する。

```swift
// IntentTodoWidget/Intents/ControlIntents.swift
struct ToggleUrgentTodoIntent: AppIntent {
    @MainActor
    func perform() async throws -> some IntentResult {
        let container = try SharedModelContainer.createContainer()
        let context = container.mainContext
        // ...
    }
}
```

SPM パッケージに配置した Intent（`AddTodoIntent` 等）は `@Dependency var modelContainer` で解決できる。

### watchOS での Button(intent:) 制約

watchOS では `Button(intent:label:)` のシグネチャが iOS と異なります。複数のAPIオーバーロードが存在し、型推論がうまく働かないことがあります。

```swift
// ❌ watchOSで曖昧な場合あり
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Image(systemName: "checkmark")
}

// ✅ 明示的なButtonインスタンス生成で対処
// または onTapGesture + Task で直接実行
VStack {
    // 表示コンテンツ
}
.onTapGesture {
    Task {
        _ = try? await ToggleTodoCompletionIntent(todo: entity).perform()
    }
}
```

---

## 参考資料

### Apple公式

- [Apple: App Intents](https://developer.apple.com/documentation/appintents)
- [Apple: Making your app's functionality available to Siri](https://developer.apple.com/documentation/appintents/making-your-app-s-functionality-available-to-siri)
- [WWDC22: Dive into App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/)
- [WWDC23: Explore enhancements to App Intents](https://developer.apple.com/videos/play/wwdc2023/10103/)
- [WWDC24: Bring your app's core features to users with App Intents](https://developer.apple.com/videos/play/wwdc2024/10210/)
- [WWDC25: Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)

### 設計思想

- [Action-Centered Design - Vidit Bhargava](https://blog.viditb.com/action-centered-design/)
- [App Intent Driven Development - SwiftLee](https://www.avanderlee.com/swift/app-intent-driven-development/)
- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - モデルベースUIデザインとの関係
