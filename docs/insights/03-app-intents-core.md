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

`ModelContainer` は `Sendable` を満たすため、`@Dependency` でそのまま共有できる。`App.init()` で `AppDependencyManager.shared.add(dependency:)` に**同期登録**し、Intent 側で `@Dependency` で取得、`perform()` 内で `modelContainer.mainContext` を使って Repository を生成する（毎回新しい `ModelContext(modelContainer)` を作ると保存されていない状態が共有されないので注意）。

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
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
        // ...
    }
}
```

### 実行プロセスごとに登録が必要

`AppDependencyManager.shared` は**プロセスごとに独立したインスタンス**。`supportedModes` によって `perform()` がどのプロセスで実行されるかが決まる。

| モード/呼出元 | 実行プロセス | 登録が必要な場所 |
|--------------|-------------|----------------|
| `.foreground(.immediate)` | メインアプリ（開かれる） | `App.init()` |
| `.foreground` | メインアプリ | `App.init()` |
| `.background` / Siri / Shortcuts | メインアプリ | `App.init()` |
| `.background` / Widget ControlWidgetButton | Widget Extension | `WidgetBundle.init()` |
| `LiveActivityIntent` | **メインアプリプロセス** (公式保証) | `App.init()` |

> `LiveActivityIntent` は Apple 公式 [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) が "the system runs the app intent in the app's process" と明言している。つまりメインアプリ側の `AppDependencyManager` に登録してあれば解決される（Extension 側の登録は不要）。

Widget Extension 側での登録例:

```swift
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
    }
    var body: some Widget { /* ... */ }
}
```

### 登録のタイミング

`App.init()` / `WidgetBundle.init()` で**同期**的に。`Task { @MainActor in ... }` に入れると `perform()` が Task 完了を待たずに走る可能性があり、`@Dependency` 解決失敗になる。

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
        SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
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

### 10 件上限と設計指針

Apple は `AppShortcutsProvider.appShortcuts` の登録数を **10 件** に制限している（iOS 26 時点）。本プロジェクトは現在 8 件で運用しており、枠 2 件分の余裕を意識的に確保する設計判断をしている。

- 同じ Intent のパラメータ違いは、可能な限り 1 件にまとめて「フレーズを複数登録」する。例えば `ShowTodosIntent` は `filter` パラメータを 1 つの AppShortcut で受け、`Show my todos / Show incomplete todos / Show favorite todos` のフレーズ群にまとめている（以前は 3 件登録していたが、10 件枠を食い潰さないよう統合）。
- アプリを「開くだけ」の用途（例: `LaunchAppIntent`）は Widget/ControlWidget 経由で呼べば足りるので、AppShortcut 登録を省いて枠を節約する。

### パッケージ内での定義

`AppShortcutsProvider` も Swift Package 内に配置可能。パッケージ側に `AppIntentsPackage` を1つ宣言するだけで、そこに含まれる Intent と AppShortcutsProvider がアプリ全体で認識される。

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/TodoAppIntents.swift
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

**重要**: メインアプリターゲットに `includedPackages` を持つ `AppIntentsPackage` を**重複宣言しない**こと。2026-04-13 の実機検証で、SPM 側の `AppIntentsPackage` 自動発見とメインアプリターゲットでの二重登録が重なると Shortcuts のルーティングが壊れる現象を確認した（エラーは `LNContextErrorDomain Code=2001`）。

> **一次ソース未確認**: Apple 公式 API リファレンスで「アプリあたり 1 つまで」と明文化されている記述は 2026-04-15 時点で確認できていない。`AppIntentsPackage` / `includedPackages` のドキュメントには duplicate registration に関する注意書きが見つからないため、実機観測ベースの知見として扱う。

**注意**: アプリ内に `AppShortcutsProvider` が複数存在するとビルドエラーになる。

### フレーズのパラメータ型制限

App Shortcut のフレーズに埋め込めるのは **AppEntity** と **AppEnum** 型のみ（2026-04-15 時点のコンパイラ観測）。

```swift
// ❌ String 型パラメータはフレーズに埋め込めない (compiler error)
"Add \(\.$title) to \(.applicationName)"

// ✅ AppEntity / AppEnum のみ使用可能
"Show \(\.$filter) todos in \(.applicationName)"  // filter: TodoFilterType (AppEnum)
```

String 型パラメータを使いたい場合は、Siri がユーザーに後から入力を求めるフローを利用する。

> **一次ソース未確認**: Apple 公式 API リファレンスではこの制約を明示的に書いた箇所を 2026-04-15 時点で発見できていない。コンパイラエラー挙動から観測した制約として扱う。将来的に緩和される可能性もあるため iOS / Xcode の major バージョン更新時には再確認が望ましい。

---

## supportedModes

[Apple 公式 `supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) より:

### 基本モード

| モード | 動作 | 旧 API との対応 |
|--------|------|----------------|
| `.background` | バックグラウンド実行 | `openAppWhenRun = false` と同じ挙動 |
| `.foreground` / `.foreground(.immediate)` | 即座にフォアグラウンド | `openAppWhenRun = true` と同じ挙動 |
| `.foreground(.dynamic)` | 実行中に動的判断 | **`ForegroundContinuableIntent` の後継**（下記注参照）|
| `.foreground(.deferred)` | 初期バックグラウンド → `perform()` 内か返却時に自動 foreground 化 | 新 API |

> **`ForegroundContinuableIntent` は deprecated**: [公式ドキュメント](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent) が明記 — "This protocol is deprecated, please include `.foreground(.dynamic)` in the `supportedModes` of your app intent instead."

> **`.foreground(.deferred)` の正確な挙動**: Apple 公式 [supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) には enum case としての存在は記載されるが、詳細な semantics（`perform()` 終了時に system が自動で foreground 化するタイミング）までは明記されていない (2026-04-15 時点)。上記の動作は実機検証ベース。

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

> **Note**: Control Widget からの `continueInForeground()` 呼び出しは現時点で未検証（かつて動作しないと記録していたが、当時の失敗は `IntentTodoAppIntentsPackage` 重複 Bug によるもので、fix 後は未検証）。

---

## Primary / FromExtension 分離パターン

同じ行動でも「**ユーザーがパラメータを直接選ぶか**」で実装を分ける。

### 背景

App Intents が `TodoAppEntity` のような `AppEntity` をパラメータに取る Intent を実行すると、`perform()` 前に `TodoEntityQuery.entities(for:)` を呼んで ID から entity を再解決する。この解決処理が Live Activity Extension プロセスで SwiftData の内部 assertion を踏んで `EXC_BREAKPOINT` で crash することが実機で確認された（2026-04-14）。

スタック:
```
SwiftData`___lldb_unnamed_symbol_9d14c + 356
SwiftData`dispatch thunk of ModelContext.fetch(_:) + 20
SwiftDataTodoRepository.fetch(id:)   ← TodoEntityQuery から呼ばれる
TodoEntityQuery.entities(for:)       ← parameter resolution 段階
```

### 解決策: 2 系統に分ける

| 区分 | パラメータ | `isDiscoverable` | AppShortcuts | 用途 |
|------|----------|------------------|--------------|------|
| **Primary** | `todo: TodoAppEntity` | `true` | ✅ 登録 | Siri / Shortcuts / UI — ユーザーが todo を picker で選ぶ |
| **FromExtension** | `todoId: String` | `false` | ❌ | Live Activity / Widget — 呼出元が todoId を既知 |

String パラメータなら entity 解決を経由せず `perform()` に直行できる。

```swift
// Primary
public struct ToggleTodoCompletionIntent: AppIntent {
    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var todoService: TodoService
    // ...
}

// FromExtension
public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static let isDiscoverable = false
    @Parameter(title: "Todo ID") public var todoId: String
    @Dependency var todoService: TodoService
    // ...
}
#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
```

### 共通ロジックは TodoService に集約

重複を避けるため `Services/TodoService.swift` (`@MainActor final class`) にビジネスロジックを集約し、Primary / FromExtension 両方の Intent が `@Dependency var todoService: TodoService` で参照する。`WidgetReloader.reloadAllWidgets()` は各メソッドの `defer` で自動呼び出しされるため、Intent 側で呼び忘れる心配がない。

```swift
@MainActor
public final class TodoService {
    private let repository: any TodoRepositoryProtocol
    public init(repository: any TodoRepositoryProtocol) { ... }

    public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
        defer { WidgetReloader.reloadAllWidgets() }
        // ...
    }
}
```

### DI は両者共通で @Dependency

`@Dependency var todoService: TodoService` は Primary / FromExtension 両方で使える。`TodoService.swiftDataBacked(container:)` ファクトリ経由で、メインアプリ / Widget Extension / watch App の各プロセスで `AppDependencyManager.shared` に登録する。登録先の詳細は `04-ui-integration.md` の実行プロセス表を参照。

> **補足**: 旧 `TodoActions` (enum + static func) は TodoService に昇格済み。Repository を都度生成する負荷と呼び忘れ脆弱性を同時に解消。

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

## Xcode 27 / WWDC 2026 で採用した API

> `xcode27` ブランチ（26.x ベータ SDK 検証用、main 未マージ）で採用。ベータ仕様のため変更の可能性あり。

### @ComputedProperty / @DeferredProperty（Entity プロパティマクロ）

`AppEntity` のプロパティをスナップショット以外の源から導出/取得して Shortcuts・Siri に公開できる。

- `@ComputedProperty`: 同期 getter。`TodoAppEntity.isOverdue` はスナップショットの `dueDate` / `isCompleted` から導出（外部アクセスなし）。
- `@DeferredProperty`: 非同期 getter (`get async throws`)。要求時のみ取得され、**Spotlight index には含まれず、Siri / Shortcuts にも自動送出されない**。`TodoAppEntity.subtaskProgress` はサブタスク（SwiftData リレーション）を必要時だけ取得する。

**落とし穴**:
- **Entity は `@Dependency` を使えない**。Apple 公式: 「dependency injection は main app から *intent* へデータを渡すためだけに使える」。`EntityQuery` では使えるが `AppEntity` では `Unknown attribute 'Dependency'` になる。→ 共有 `ModelContainer` を App 起動時に `TodoEntityStore`（`@MainActor enum` の static）へ登録し、deferred getter から参照する（Apple サンプルの ambient `modelData` パターン相当）。
- **プロパティマクロは非 `Hashable` な `EntityProperty` backing を生成する**ため `Hashable` / `Equatable` の自動合成が壊れる。→ `==` / `hash(into:)` を明示実装（id ベースの hash + スナップショット比較の等価）。

### Intent Modes: `.foreground(.dynamic)` + `continueInForeground`

`ShowTodosIntent` を `[.background, .foreground(.dynamic)]` にし、background 優先で実行。

```swift
public static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog {
    let entities = try todoService.listTodos(filter: filter)
    if systemContext.currentMode.canContinueInForeground {
        do {
            try await continueInForeground(alwaysConfirm: false)
            navigationModel.navigateToRoot()
        } catch { /* foreground 拒否 → background のまま */ }
    }
    return .result(value: entities, dialog: dialog(for: entities))
}
```

- `.foreground(.dynamic)` は deprecated な `ForegroundContinuableIntent` の後継。
- **`OpensIntent` 返却は dynamic background と矛盾する**（常にアプリを開いてしまう）。foreground 遷移は `continueInForeground()` 成功後に `NavigationModel` で直接行い、`OpensIntent` は使わない。
- 「アプリを開く」専用 Intent（`LaunchAppIntent`）は `.foreground(.immediate)` を維持する。dynamic にしない。

### Onscreen Entities（画面コンテンツを Siri / Apple Intelligence に提供）

詳細 View に `.userActivity` を付与し、表示中エンティティを関連付ける。

```swift
.userActivity("dev.touyou.IntentTodo.ViewingTodo") { activity in
    activity.title = String(localized: "Viewing \(todo.title)")
    activity.appEntityIdentifier = EntityIdentifier(for: entity)   // AppIntents
}
```

- `appEntityIdentifier`（`NSUserActivity` の AppIntents 拡張）/ `EntityIdentifier(for:)` は `import AppIntents` が必要。
- アクティビティタイプ文字列は **Info.plist の `NSUserActivityTypes` に登録**し、コード側の定数と一致させる。

### Interactive Snippet（`SnippetIntent`）

`SnippetIntent.perform()` は `some IntentResult & ShowsSnippetView` を返し、`.result(view:)` で SwiftUI を提示。ホスト Intent は `.result(value:dialog:snippetIntent:)` で `ShowsSnippetIntent` を返す。

- スニペットの Button は **ウィジェット同様に `Button(intent:)` で App Intent を直接実行**する。
- ボタン押下のたびに **システムが `SnippetIntent` を再実行**するため、`perform()` は毎回最新状態を取得する（本プロジェクトは `TodoEntityStore` から再フェッチしてラベルを更新）。
- 本プロジェクトの `AddTodoIntent` 経由スニペットは **app プロセスで提示**されるため、entity 解決クラッシュ（Live Activity Extension 限定の Issue #30 A-3）は該当せず Primary な entity ベース Intent を使う。**新規 `FromExtension` 変種は追加しない**（FromExtension は LA/Widget 専用ワークアラウンドのため）。
- `SnippetIntent` は `isDiscoverable = false`（`snippetIntent:` 経由でのみ提示、Shortcuts 非露出）。

### App Schema（`@AppEntity(schema:)` / `@AppEnum(schema:)`）— reminders ドメイン

assistant schema に適合させると、Siri / Apple Intelligence がコンテンツを意味的に理解する。

- **`.reminders` ドメインは iOS 27+ 限定**（`'reminders' is only available in iOS 27.0 or newer`）。
  採用には deployment を 27 世代へ上げる（`.v27` は PackageDescription 6.4 = `swift-tools-version: 6.4`）。
- **小スキーマは素直**: `CategoryAppEntity` を `@AppEntity(schema: .reminders.list)` に適合（`id` / `name` /
  `type: TodoListType`）、`TodoListType` を `@AppEnum(schema: .reminders.listType)` に。マクロが
  `typeDisplayRepresentation` を生成するので手書きは削除、`Hashable` はマクロ backing が非 Hashable のため明示実装。
- **大スキーマ（`.reminders.reminder`）の落とし穴**: スキーマが `dueDate: DateComponents?`（`Date?` と衝突）、
  非 optional `list`、再帰 `subtasks: [Self]`、`images`/`tags`/`urls`/`recurrence`/`section`/`locationTrigger`
  等を要求。さらに **マクロ生成 init は `EntityProperty<T>` 引数**を取り、`section`/`locationTrigger` 等の
  **入れ子サブエンティティを再帰的に要求**する。モデルから組み立てる自前 `init(from:)`（プロパティ順次代入）は
  `self.images used before being initialized` で弾かれ、代入順 / デフォルト / 他マクロ除去では解消しない
  （SDK 27 の「`@State` がマクロ化」初期化規約と同根。`swiftui-whats-new-27` skill 参照）。
  → リッチな共有 entity を reminder 本体スキーマに適合させるのは深掘りが必要。list 適合で App Schema の
  仕組み自体は検証できるため、本体適合は独立タスクとして切り出すのが現実的。

### 対話的な質問（`requestChoice`）

`AppIntent.requestChoice(between:dialog:)` は perform() を中断し、ユーザーに選択肢を提示する（WWDC 2026 #343）。
`requestConfirmation`（yes/no）の多分岐版。

```swift
let choice = try await requestChoice(
    between: [IntentChoiceOption(title: "30 minutes"), IntentChoiceOption(title: "1 hour"), .cancel],
    dialog: IntentDialog("Snooze “\(todo.title)” for how long?")
)
```

- 返り値は選ばれた `IntentChoiceOption`。**`IntentChoiceOption` は `Equatable`**（`==` / `switch case` で照合可）。
  ただし安定した識別子は持たないため、本プロジェクトでは選択肢と逆引きを `SnoozeDuration` enum に
  一元化し、`IntentChoiceOption(title:) == choice` で突き合わせる（option list と mapping のドリフト防止）。
- `.cancel` を含めると、それが選ばれたとき `requestChoice` が cancellation error を throw して intent を中断。
- `IntentChoiceOption(title:style:)` の `style` は `.default` / `.destructive` / `.cancel`。
- **`.background` モードの intent からも呼べる**（`requestConfirmation` と同様、Siri / Shortcuts の UI に surface する）。
  `SnoozeTodoIntent`（Primary）は UI Button から呼ばれず Siri/Shortcuts 専用なので、ここに置くのが安全。
  LA/Widget 用の `*FromExtensionIntent` 変種は固定間隔のまま据え置く（対話を求めない）。
- view 付きの `requestChoice(between:dialog:view:)` / `requestChoice(between:dialog:content:)` も存在。

### system intents（`OpenIntent` / `DeleteIntent`）

App Intents は「開く」「削除する」等の共通アクションに **system intent プロトコル**を用意している（#344）。
適合すると、システムがそのアクションを意味的に理解する（Spotlight 結果タップ → 開く 等）。スキーママクロ
（`@AppIntent(schema: .system.open)` など）を使わず、**プロトコルに直接適合**するだけでよい。

- **`OpenIntent`**: `var target: Target`（`Target: AppEntity`、関連型は `target` から推論）を要求。
  `OpenTodoIntent` は `@Parameter var target: TodoAppEntity` を持ち、perform() で `NavigationModel.showDetail`
  へ遷移（`LaunchAppIntent` と同じ cold-start 安全な `@Dependency` ナビ方式）。`supportedModes` は
  `.foreground(.immediate)`。
- **`DeleteIntent`**（`: SystemIntent`）: `var entities: [Entity]`（**複数 entity の配列**、関連型 `Entity` は
  推論）を要求。単数の `todo: TodoAppEntity` 形では適合できないため、UI 駆動の単体 `DeleteTodoIntent` とは
  分離して `DeleteTodosIntent`（バルク削除）を新設した。requestConfirmation で一括確認 → 各 todo 削除 +
  donation 削除。
- いずれも **AppShortcuts には未登録**（10 件枠の温存。system intent は AppShortcut 無しでも意味解釈される）。

### 会話ダイアログ（`IntentDialog(full:supporting:)`）

`IntentDialog` には単一文字列の `init(_:)` の他に **`init(full:supporting:)`** がある（#343）。

- `full`: 画面が無い文脈（音声のみ）で読み上げる、それ単体で完結するメッセージ。
- `supporting`: 返却した値（一覧など）が視覚表示される文脈で、その表示に添える短い一言。
- `init(full:systemImageName:)` / `init(full:supporting:systemImageName:)` もある。
- `ShowTodosIntent` は `ReturnsValue<[TodoAppEntity]>` を返すので、音声単独（full: 件数を完全文で）と
  視覚併用（supporting: 「Here are your incomplete todos.」）を出し分けるのに適合する。

### `RelevantEntities` は Todo ドメインに不適合（ブロッカー記録）

「次の期限/緊急 Todo」を文脈寄付する目的で `RelevantEntities.shared.updateEntities(_:for:)` を検討したが、
**第二引数 `AppEntityContext` がドメイン固有のファクトリしか持たない**ことが判明（DocumentationSearch 確認）。

- 提供される context は `.audio(.nowPlaying)`（`AudioContext`）と、framework overlay（HealthKit 等）が
  定義する domain context のみ。**汎用 / reminders / todo 向けの context 値が存在しない**。
- `.audio(.nowPlaying)` で todo を寄付するのは意味的に誤り（再生中メディア扱いになる）。
- → **本アプリ（reminders ドメイン）では `RelevantEntities` は現状適合不能**。Apple が todo / reminders 向け
  `AppEntityContext` を追加するまで保留。`RelevantIntent` / `RelevantIntentManager`（WidgetConfigurationIntent
  ベースのウィジェット提案）は別軸の API なので、文脈提案が必要なら将来そちらを検討する。

## Phase 4: 大量・実行制御（#345）

### `EntityCollection` + `LongRunningIntent` + `CancellableIntent`（バルク処理）

`CompleteTodosIntent`（バルク完了）で3つを同時に検証。

- **`EntityCollection<TodoAppEntity>`**: `@Parameter` の型にすると、**パラメータ解決時に各 id を
  full entity へ解決しない**（数百件でメモリ/時間を節約）。`.identifiers`（`[Entity.ID]` = `[String]`）で
  id だけ取り出せる。完全な entity が要るときだけ `resolvedEntities()`。完了処理は id しか要らないので
  解決を完全に回避できる。
- **`LongRunningIntent`**（`: ProgressReportingIntent`）: `performBackgroundTask { ... }` で囲むと
  バックグラウンド30秒制限を延長。**`progress`（`Progress`）を定期更新しないとシステムが延長を打ち切る**。
  `progress.totalUnitCount` / `completedUnitCount` を逐次更新する。
- **`CancellableIntent`**: `performBackgroundTask(operation:onCancel:)`（`Self: CancellableIntent` 必須）で
  `onCancel: (IntentCancellationReason) -> Void` を渡せる。ループ内で `try Task.checkCancellation()`。
- **並行性の注意**: `perform()` を `@MainActor` にしなくても、`operation` クロージャ（nonisolated async）から
  `try await todoService.markCompleted(...)` とすれば MainActor へホップして SwiftData 変更が安全に動く。

### `allowedExecutionTargets`（実行プロセス指定）

`static var allowedExecutionTargets: IntentExecutionTargets { [.main] }` で intent の実行先を限定できる。
選べるのは **`.main`（アプリ本体）/ `.appIntentsExtension`（App Intents Extension）**。

- 本アプリは App Intents Extension を持たず、バルク SwiftData 変更はアプリ本体が最も確実なので、新設の
  バルク Intent は `[.main]` に固定した。
- **⚠️ FromExtension 分離を `allowedExecutionTargets` で統合することはできない**（検証結論）:
  - FromExtension（`todoId: String`）と Primary（`todo: TodoAppEntity`）の分離は、**Live Activity
    Extension プロセスでの entity 解決クラッシュ回避が目的**（パラメータの「型」を変えて解決自体を避ける）。
  - `allowedExecutionTargets` が制御するのは**どのプロセスが perform するか**であって、entity 解決の有無では
    ない。しかも選択肢は `.main` / `.appIntentsExtension` のみで、**Widget/Live Activity Extension は対象外**。
  - LA ボタン用変種は `LiveActivityIntent`（Apple 保証でアプリプロセス実行）だが、クラッシュは
    パラメータ解決段で起きるため、解決を経由しない String 版が依然必要。→ **FromExtension は維持**。

### `SyncableEntity`（デバイス間 ID 一貫）

`struct TodoAppEntity: AppEntity, SyncableEntity` を追加するだけ。`id` がデバイス間で一貫していれば
（本アプリは UUID 文字列 = SwiftData/CloudKit が同一レコード id を複製）**追加変更不要**で適合できる
（`String` id でも OK と確認。`var id: UUID` 直なら尚良し）。local/stable が別なら `id` を
`SyncableEntityIdentifier<Local, Stable>` 型にする。Siri 会話のデバイス間転送などでシステムが entity を
一貫参照できるようになる。

### `@UnionValue`（複数 entity 型を1つの値で）

`@UnionValue` を enum に付けると、`AppUnionValue` / `_IntentValueRepresentable` 適合と nested `Cases` enum を
マクロ生成する。`@Parameter` / `ReturnsValue` の型として使え、`ParameterSummary` の `Switch`/`When` で
ケース分岐もできる。

```swift
@UnionValue
public enum TodoOrCategory: Sendable {   // ← public enum は Sendable 自動推論されないため明示必須
    case todo(TodoAppEntity)
    case category(CategoryAppEntity)
}
```

- **落とし穴**: `public enum` に `@UnionValue` を付けると、マクロ生成コードが `Sendable` を要求する。
  Swift は public 型の `Sendable` を自動推論しないので **`: Sendable` を明示**しないと
  「Type '...' does not conform to the 'Sendable' protocol」（生成ソース内）でビルド失敗する。
- 各ケースの associated value は単一の値型（AppEntity 等）にする。`SearchEverythingIntent` は
  `ReturnsValue<[TodoOrCategory]>` で todo とカテゴリの混在結果を返す。

## Phase 5: Visual Intelligence（#297）

### `IntentValueQuery` + `SemanticContentDescriptor`

カメラ / スクショの visual search に対して、アプリのコンテンツを entity として返す入口。

```swift
#if canImport(VisualIntelligence)
import VisualIntelligence

public struct TodoVisualIntelligenceQuery: IntentValueQuery {
    @Dependency var todoService: TodoService   // ← IntentValueQuery は @Dependency 可
    public func values(for input: SemanticContentDescriptor) async throws -> [TodoOrCategory] { ... }
}
#endif
```

- **`IntentValueQuery: PersistentlyIdentifiable, _SupportsAppDependencies, Sendable`** — `AppEntity` と違い
  **`@Dependency` が使える**ので `TodoService` を直接注入できる（entity の `TodoEntityStore` 迂回は不要）。
- `values(for:)` の `Input` は `SemanticContentDescriptor`、戻り値は entity 配列または **`@UnionValue` 配列**
  （`[TodoOrCategory]` で todo / category 混在結果）。`EntityQuery` と違い**単一 entity 型に縛られない**のが
  value query の利点。
- **`SemanticContentDescriptor`（`VisualIntelligence`）**: `labels: [String]`（一般的な英語ラベル。建物の固有名は
  来ない、`en_US`、同義語/翻訳なし）と `pixelBuffer: CVReadOnlyPixelBuffer?`。本アプリは labels を todo タイトル /
  カテゴリ名に部分一致させた（画像一致は ML が要るため見送り）。
- **並行性**: `values(for:)` は nonisolated。MainActor の `TodoService` は
  `try await MainActor.run { try todoService.listTodos(...) }` でホップして取得し、以降は Sendable な
  `TodoAppEntity` 値で off-actor フィルタする。
- **登録不要**: 他の query 同様、システムが自動発見（AppShortcut 不要）。

### `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`（もっと見る）

visual search の「More results」に対応する intent。`@Parameter var semanticContent: SemanticContentDescriptor`
だけを持つ形をスキーママクロが要求し、`reminders` スキーマのような `EntityProperty` init 地雷は踏まない
（entity プロパティが無いため）。perform でアプリを開きリスト表示。

### iOS 専用ガードと既存要素の再利用

- `VisualIntelligence` は **iOS 専用**。本パッケージは macOS/watchOS/visionOS/Widget でもビルドするため、
  Visual Intelligence 関連ファイルは **`#if canImport(VisualIntelligence)`** で丸ごとガードする。
- **結果タップ → 詳細表示**は Phase 3 の `OpenTodoIntent`（`OpenIntent`）が、**複数結果型**は Phase 4 の
  `@UnionValue`（`TodoOrCategory`）がそのまま流用できる。Visual Intelligence のために新規 entity/型を増やさない。

### EventKit / Contacts 連携は別軸（記録のみ）

「期限→カレンダー / 担当者→連絡先」は EventKit / Contacts という**別フレームワーク連携**で、App Intents
中心設計の検証主眼からは外れる。本ブランチでは未実装とし、必要になった時点で独立タスクとして扱う。
