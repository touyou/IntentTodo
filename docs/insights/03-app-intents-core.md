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

`AppDependencyManager.shared` は**プロセスごとに独立したインスタンス**。`supportedModes` は「フォアグラウンド遷移するか」を決めるだけで、実行プロセスそのものを固定しない。共有パッケージの Intent は複数ターゲットにリンクされていると、システムが**ヒューリスティクス**（アプリ起動中ならアプリを優先、等）でプロセスを選ぶ（[WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) 15:59–16:55）。固定したい場合は `allowedExecutionTargets`（後述 L611 付近）で明示する。

| モード/呼出元 | 実行プロセス | 登録が必要な場所 |
|--------------|-------------|----------------|
| `.foreground(.immediate)` | メインアプリ（開かれる） | `App.init()` |
| `.foreground` | メインアプリ | `App.init()` |
| `.background` / Siri / Shortcuts | メインアプリ | `App.init()` |
| `.background` / Widget ControlWidgetButton（`allowedExecutionTargets` 未指定） | **ヒューリスティクスで決定**（アプリ起動中はメインアプリ優先、未起動なら Widget Extension） | **両方**（保険として `App.init()` と `WidgetBundle.init()`） |
| 同上（`allowedExecutionTargets` で明示指定） | 指定したプロセスに固定 | 指定先のみ |
| `LiveActivityIntent` | **メインアプリプロセス**（`perform()` のみ。公式保証） | `App.init()` |

> **2026-08-11 追記**: 上記「ヒューリスティクスで決定」の行は再検証で判明した内容。以前は「`.background` / Widget ControlWidgetButton は固定的に Widget Extension で実行」と記録していたが、`IntentExecutionTargets`（`.default`/`.main`/`.appIntentsExtension`/`.widgetKitExtension`）が `OptionSet` として存在し `.default` が「システムに委ねる」を表す独立ケースであること自体が、既定はヒューリスティクスであることの SDK 上の裏付け。`CompleteTodosIntent` は `allowedExecutionTargets = [.main]` を既に指定済み（詳細は下記「大量データ処理」節）。二重登録（`App.init()` + `WidgetBundle.init()`）は他の未指定 Intent がある限り撤廃できない。
>
> `LiveActivityIntent` については Apple 公式 [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) が "the system runs the app intent in the app's process" と明言しているが、これは `perform()` の実行プロセスについての保証であり、`@Parameter var todo: TodoAppEntity` のような entity パラメータの**事前解決フェーズ**（`entities(for:)`）がどこで走るかは別問題（下記「Primary / FromExtension 分離パターン」参照）。つまりメインアプリ側の `AppDependencyManager` に登録してあれば `perform()` 内の `@Dependency` は解決される（Extension 側の登録は不要）。

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

Intent / AppEntity / EntityQuery / AppEnum は Swift Package 内に置ける。パッケージ側に `AppIntentsPackage` を1つ宣言するだけで、そこに含まれるこれらの型がアプリ全体で認識される。

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/TodoAppIntents.swift
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

現在の運用は、メインアプリターゲットに `includedPackages` を持つ `AppIntentsPackage` を重複宣言しない形。2026-04-13 の実機検証で、SPM 側の `AppIntentsPackage` 自動発見とメインアプリターゲットでの二重登録が重なった際に Shortcuts のルーティングが壊れる現象（エラーは `LNContextErrorDomain Code=2001`）を確認したのが根拠だった。

> **2026-08-11 追記（再検証、Xcode 27 beta 5）**: この制約を「重複宣言は絶対禁止」と断定するのは過剰だったと判明。アプリターゲット・Widget/LiveActivity/watchOS の全 Extension ターゲットに `AppIntentsPackage { includedPackages: [TodoIntentsPackage.self] }` を追加してビルドしても、`Metadata.appintents/extract.actionsdata` の `actions`/`entities`/`queries` 件数は無宣言時と完全に同一（11/1/1、重複なし）だった。しかも Apple 公式 `AppIntentsPackage` ドキュメント（[developer.apple.com](https://developer.apple.com/documentation/appintents/appintentspackage)）や wwdc2025-244（23:29-24:00）・wwdc2025-275（25:50）は、まさにこの「利用側にも `includedPackages` 付き `AppIntentsPackage` を宣言する」パターンを標準手順として示している。
>
> `3f6d835`（2026-04-13 の当該コミット）を読み直すと、これは Intent routing 問題の解決・`@Dependency` パターンへの統一・重複 Intent の削除・プロパティリネームなどを一括で行った大きな PR で、「`AppIntentsPackage` 重複宣言そのもの」を単独で切り出して再現実験した記録は残っていなかった。デバッグログが示す当時の疑いは「Widget Extension が `TodoAppIntents` を import しているため Shortcuts が Widget Extension を intent provider として誤選択した」というもので、これは `AppIntentsPackage` の宣言方法とは別の話（実行プロセス選択の問題、「実行プロセスと登録先」節参照）である可能性が高い。
>
> **今回の検証はビルド/メタデータレベルに限られ、Siri/Shortcuts の実機ルーティング（`LNContextErrorDomain` 系エラー）の再現実験は行っていない。** 現状のドキュメント運用（重複宣言しない）自体は安全なので変更していないが、「絶対に壊れる」という断定は取り下げ、複数ターゲットでの型共有が本当に必要になった場面では実機で Siri 経由の呼び出しを確認してから採用する、という位置づけに改める。

### ⚠️ `AppShortcutsProvider` は SPM パッケージに置いてはいけない（アプリターゲット必須）

**`AppShortcutsProvider` を Swift Package 内に置くと、App Shortcuts はアプリに登録されない。** メインアプリターゲット直下（本プロジェクトでは `IntentTodo/IntentTodo/TodoAppShortcuts.swift`）に置くこと。

**症状**: Siri / Shortcuts アプリ / Spotlight に App Shortcut が一切出てこない（ビルド・実行はエラー無しで成功するため気付きにくい）。

**根拠（2026-07-08 検証、Xcode 27 beta 3 / toolchain 27A5218g）**: App Intents の実体はビルド時に生成される `Metadata.appintents` バンドル。DerivedData の `.appintents/extract.actionsdata`（JSON）を比較すると:

| キー | パッケージ `TodoAppIntents.appintents` | アプリ `IntentTodo.app/Metadata.appintents` |
|------|--------------------------------------|--------------------------------------------|
| `actions`（Intent） | 20 | 20 ✅ 集約される |
| `entities` | 3 | 3 ✅ 集約される |
| `queries` | 3 | 3 ✅ 集約される |
| **`autoShortcuts`（AppShortcut）** | **8** | **0 ❌ 集約されない** |

`actions` / `entities` / `queries` は依存パッケージからアプリの統合メタデータへ集約されるが、**`autoShortcuts`（`AppShortcutsProvider.appShortcuts`）だけは集約されない**。システムが実際に読むのはアプリバンドル内の統合 `Metadata.appintents` 一つなので、そこで `autoShortcuts: 0` だと App Shortcut は存在しないのと同じ。

`AppShortcutsProvider` をアプリターゲットへ移すと、同じ検証で `IntentTodo.app` 側の `autoShortcuts` が **0 → 8** になることを確認した。Intent 本体はパッケージ (`public`) のままでよく、`AppShortcutsProvider` から `import TodoAppIntents` で参照する。

**検証手順（再確認したいとき）**:
```bash
# アプリバンドルの統合メタデータで AppShortcut 件数を見る
python3 -c "import json; d=json.load(open('<DerivedData>/.../IntentTodo.app/Metadata.appintents/extract.actionsdata')); print('autoShortcuts:', len(d['autoShortcuts']))"
```
`XcodeRefreshCodeIssuesInFile` や通常ビルドの成否では**一切露見しない**（メタデータ抽出は成功扱いのまま件数だけ 0 になる）タイプの問題。App Shortcuts を触ったら統合メタデータの件数を直接見るのが唯一確実。

> **補足（過去の誤記録の訂正）**: 以前この節には「`AppShortcutsProvider` も Swift Package 内に配置可能」と書いていたが、上記検証により誤りと判明。実行・ビルドが通り Intent 自体は動く（UI / Widget / Siri 直接呼び出しは Intent 集約経由で機能する）ため、App Shortcut フレーズだけが黙って欠落しており長く気付かれていなかった。

> **一次ソース未確認**: Apple 公式 API リファレンスで「アプリあたり 1 つまで」と明文化されている記述は 2026-04-15 時点で確認できていない。`AppIntentsPackage` / `includedPackages` のドキュメントには duplicate registration に関する注意書きが見つからないため、実機観測ベースの知見として扱う。

> **2026-08-11 追記（再検証）**: 本制約は上記「パッケージ内での定義」節の `AppIntentsPackage` 重複宣言問題とは**独立**であることを確認済み。アプリ/Extension ターゲットに `includedPackages` 付き `AppIntentsPackage` を追加した状態でも `AppShortcutsProvider` がパッケージ内にある限り `autoShortcuts` は 0 のままで、パッケージ→アプリターゲットへ移動した時点でのみ 0→8 に変化した。よってこの節のルール（アプリターゲット直下必須）自体は変更不要。

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

App Intents が `TodoAppEntity` のような `AppEntity` をパラメータに取る Intent を実行すると、`perform()` 前に `TodoEntityQuery.entities(for:)` を呼んで ID から entity を再解決する。この解決処理中に SwiftData の内部 assertion を踏んで `EXC_BREAKPOINT` で crash することが実機で確認された（2026-04-14、コミット `c37ee97`/`a234842`）。

> **2026-08-11 追記（再検証）**: 「Live Activity Extension プロセスで」という当時の原因記述は要注意。Apple 公式ドキュメント（[Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action)）は「`LiveActivityIntent` の `perform()` はアプリプロセスで実行される」と明言しており、これは `TodoAppEntity`（Primary 版）が実際に `LiveActivityIntent` に準拠していれば `perform()` 自体はアプリプロセスで動くはずということを意味する。一方で `entities(for:)` のような**事前解決フェーズ**がどのプロセスで走るかは Apple 文書に明記が無く、上記スタックトレースは解決フェーズで発生している。加えて `IntentTodoLiveActivityBundle.init()` は現在も過去も `AppDependencyManager` への登録を一切行っていないため、解決フェーズが Extension 側で走った場合は `TodoEntityQuery` の `@Dependency var modelContainer` が解決できないはずだが、捕捉されたスタックトレースは `ModelContext.fetch` の内部まで進んでおり、「未登録 dependency」の `fatalError` 文言ではない。したがって真因を「Extension プロセスで解決されたから」と確定させることはできず、「事前解決フェーズのプロセスが未文書化かつ実際に crash 歴がある」という表現に留めるのが正確。FromExtension 分離は結果的に安全なワークアラウンドとして機能しているため、コード側の変更は不要。

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
- **落とし穴（watchOS 非対応 / Xcode 27 beta 2、beta 3 でも継続）**: beta 2 で `reminders` ドメインの assistant schema が
  **watchOS で unavailable** になった（`'reminders' is unavailable in watchOS` / `'list' is unavailable in watchOS`）。
  **2026-07-08 に Xcode 27 beta 3 で再検証済み**: `TodoListType` の `#if os(watchOS)` フォールバックを一時無効化して watchOS
  スキームをビルドしたところ `'reminders'/'listType' is unavailable in watchOS` が再現。**beta 3 でも制約は解消されておらず、
  フォールバックは維持が必要**（[[verify-platform-limits-on-sdk-updates]] の方針で実ビルド確認）。
  `TodoAppIntents` は watchOS でもコンパイルされるため、`CategoryAppEntity`（`.reminders.list`）と
  `TodoListType`（`.reminders.listType`）を `#if os(watchOS)` で素の `AppEntity` / `AppEnum` にフォールバックした。
  **マクロ付き宣言は `#if` で頭（属性＋宣言行）と本体を分割できない**（`Expected '}' in struct` になる）ため、
  型を2系統まるごと書き分ける必要がある。watchOS では Siri / Apple Intelligence のスキーマルーティングを
  使わないので機能損失はない。**iOS destination のビルドや `XcodeRefreshCodeIssuesInFile` では露見せず、
  watchOS を含むフルビルドで初めて出る**（`indexingKey:` の #43 と同じ「複数 destination を回せ」教訓）。
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

- 提供される context は `.audio(.nowPlaying)`（`AudioContext`、Xcode 27 beta 5 SDK の swiftinterface で確認済み）と、
  framework overlay（HealthKit 等）が定義する domain context のみ。**汎用 / reminders / todo 向けの context 値が
  存在しない**。**2026-08-11 訂正**: wwdc2026-345 (3:57 前後) の実例は `.audio(.workout(activityType: .running))`
  （ワークアウト開始時にプレイリストを提案する例）で、`.nowPlaying` ではない。ただし beta 5 SDK の
  `AppIntents.swiftinterface` には `AudioContext.nowPlaying` のみが確認でき、`.workout(activityType:)` は
  HealthKit 等のオーバーレイ側にもまだ見当たらない（beta 未実装の可能性、要再確認）。
- どちらの context 例でも todo を寄付するのは意味的に誤り（再生中メディア/ワークアウト扱いになる）という結論は変わらない。
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
選べるのは **`.main`（アプリ本体）/ `.appIntentsExtension`（App Intents Extension）/ `.widgetKitExtension`
（WidgetKit Extension）** の 3 種（`IntentExecutionTargets` の公式 discussion が "the main app, an App Intents
extension, or a WidgetKit extension" と明記。型名は `AppIntent.ExecutionTargets = IntentExecutionTargets`）。
> **記録訂正（#42）**: 以前ここを「`.main` / `.appIntentsExtension` のみ」と記録していたが誤り。WWDC 2026
> セッション 345 のとおり **`.widgetKitExtension` も存在**する（Widget ボタンからの更新を本体に寄せて
> データ競合を避ける用途）。

- 本アプリは App Intents Extension を持たず、バルク SwiftData 変更はアプリ本体が最も確実なので、新設の
  バルク Intent は `[.main]` に固定した。
- **⚠️ FromExtension 分離を `allowedExecutionTargets` で統合することはできない**（検証結論。`.widgetKitExtension`
  の存在を踏まえても結論は不変）:
  - FromExtension（`todoId: String`）と Primary（`todo: TodoAppEntity`）の分離は、**entity 解決フェーズでの
    crash 回避が目的**（パラメータの「型」を変えて解決自体を避ける。解決フェーズがどのプロセスで走るかは
    Apple 未文書化、2026-08-11 再検証で「Live Activity Extension プロセスで」という原因断定は取り下げ済み。
    「Primary / FromExtension 分離パターン」節参照）。
  - `allowedExecutionTargets` が制御するのは**どのプロセスが perform するか**であって、entity 解決の有無では
    ない。`.widgetKitExtension` を加えても Widget は対象になり得るだけで、**Live Activity Extension は依然
    対象外**であり、何より「entity を解決するか否か」は target 指定では変えられない。
  - LA ボタン用変種は `LiveActivityIntent`（Apple 保証でアプリプロセス実行）だが、クラッシュは
    パラメータ解決段で起きるため、解決を経由しない String 版が依然必要。→ **FromExtension は維持**。
  - **未検証（R 深度・要実機 #42）**: `[.main]` ピン（または `.widgetKitExtension` 指定）で **パラメータ解決
    (entity resolution) の実行プロセスまで本体側に寄るか** は実機未確認。もし寄るなら LA/Widget からの解決
    クラッシュを target 指定で回避できる可能性が残るが、現状はコードで型分離（String 版）する方が確実。

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
- **未記録だった制約（2026-08-11 追記）**: wwdc2026-297 (11:39) は「`SemanticContentDescriptor` を受ける
  `IntentValueQuery` はアプリに **1 つだけ**」と明言している。本アプリは `TodoVisualIntelligenceQuery` の
  1 つのみなので現状は問題ないが、将来 2 つ目を追加しようとした場合は不可（`@UnionValue` で戻り値の型を
  混在させて 1 つの query に集約する、が正しい対処）。

### `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`（もっと見る）

visual search の「More results」に対応する intent。`@Parameter var semanticContent: SemanticContentDescriptor`
だけを持つ形をスキーママクロが要求し、`reminders` スキーマのような `EntityProperty` init 地雷は踏まない
（entity プロパティが無いため）。perform でアプリを開きリスト表示。

### canImport ガードと既存要素の再利用

- `VisualIntelligence` 関連ファイルは **`#if canImport(VisualIntelligence)`** で丸ごとガードする。当初は
  `VisualIntelligence` が **iOS 専用**だったための措置だが、**Xcode 27 beta 2 で Mac にも import 可能**になった
  （下記「beta 2 で macOS 対応」参照）。`canImport` のみのガードなので、フレームワークが存在するプラットフォーム
  （iOS + Mac）で自動的にビルドされる。
- **結果タップ → 詳細表示**は Phase 3 の `OpenTodoIntent`（`OpenIntent`）が、**複数結果型**は Phase 4 の
  `@UnionValue`（`TodoOrCategory`）がそのまま流用できる。Visual Intelligence のために新規 entity/型を増やさない。

### beta 2 で macOS 対応（`OpenCategoryIntent` 追加で「iOS 専用」を解消）

「VisualIntelligence は iOS 専用」は SDK にフレームワークが無かった時点の制約で、**恒久的な不可能ではなかった**。
Xcode 27 beta 2 で Mac に import 可能になったため、macOS でも成立させた。

- **openable 要件は全プラットフォーム共通、Mac 固有なのは「コンパイル時に強制される」点のみ**: visual search の
  `IntentValueQuery` が返す entity は**すべて openable（`OpenIntent` を持つ）**必要があるが、これは
  wwdc2025-275 (9:19) が "This `OpenIntent` must exist, otherwise your app won't show up" と明言する通り
  全プラットフォーム共通のルール（openable でない entity はそもそも Visual Intelligence の結果に出てこない、
  という仕様）。**2026-08-11 表現訂正**: 以前この節を「Mac 固有の追加バリデーション」と書いていたが、正確には
  「ルールは共通だが、macOS destination のビルドだけがコンパイル時エラーとして enforce する」という**enforce
  のされ方の違い**であり、ルール自体が Mac 限定というわけではない。`TodoVisualIntelligenceQuery` は
  `TodoOrCategory` union を返すため、`TodoAppEntity`（`OpenTodoIntent`）に加え **`CategoryAppEntity` にも
  `OpenIntent` が必要**。Mac ビルドで `result type 'CategoryAppEntity' that is not openable ... must be
  associated with an OpenIntent` エラーになる（**iOS シミュレータ / iPhone ビルドではコンパイルエラーとして
  出ず、macOS destination でのみ発火**。本プロジェクトの Mac は Catalyst ではなく native macOS
  （`SUPPORTS_MACCATALYST` 無し・`macosx` SDK）で、そのビルドで確認）。
- **解決**: `OpenCategoryIntent`（`OpenIntent`、`target: CategoryAppEntity`）を新設。カテゴリ専用画面は無いので
  `perform()` は `navigateToRoot()`（アプリを開く）だけ。**openable にすること自体が目的**で、これで union が
  全メンバ openable になり Mac ビルドが通る（AppShortcut 未登録なので 10 件枠に影響なし）。
- **教訓**: 「プラットフォーム限定」は当時の SDK 制約に過ぎない場合がある。SDK 更新時は `#if canImport` ガードを
  外して**本当に不可能か**を実ビルドで確かめる。iOS だけでなく **macOS(My Mac) / visionOS の複数
  destination をフルビルド**して初めて分かる差異がある（`indexingKey` #43 と同じ教訓）。

### EventKit / Contacts 連携は別軸（記録のみ）

「期限→カレンダー / 担当者→連絡先」は EventKit / Contacts という**別フレームワーク連携**で、App Intents
中心設計の検証主眼からは外れる。本ブランチでは未実装とし、必要になった時点で独立タスクとして扱う。

## Phase 6: テスト基盤（#295 AppIntentsTesting）

### UI テストバンドル必須（unit test 不可）

[Apple 公式](https://developer.apple.com/documentation/AppIntentsTesting/testing-your-app-intents-code)が明記:
**「App Intents Testing は intent を**ライブのアプリプロセスで**実行するため、テストは unit test ではなく
UI テスティングバンドルに置く」**。本プロジェクトは既存の `IntentTodoUITest`（UIテストターゲット）に
追加した（新規ターゲット不要）。SPM の Testing パッケージでは動かない（アプリプロセス + 登録済み
`AppDependencyManager` が要るため）。

> **未記録だった要件（2026-08-11 追記）**: wwdc2026-295 (2:54) は "AppIntentsTesting requires the test runner
> and the app to use the same development team for code signing" と明言している。テストランナー（UI テスト
> ターゲット）とアプリ本体で**同じ development team** の code signing でなければ動かない。CI 環境や複数
> Apple ID を切り替える環境でこの設定がずれると原因不明の失敗になりやすいので、テスト追加時は署名チームの
> 一致を最初に確認する。

```swift
import AppIntentsTesting

@MainActor override func setUp() async throws {
    app = XCUIApplication(); app.launch()           // ← ライブ起動
    definitions = IntentDefinitions(bundleIdentifier: "dev.touyou.IntentTodo")
}
```

### 型消去 API（文字列キー）

- `IntentDefinitions(bundleIdentifier:)` がアプリの intents / entities / enums / queries を発見。
- サブスクリプトは **型名**でキーする: `definitions.intents["AddTodoIntent"]` /
  `definitions.entities["TodoAppEntity"]` / `definitions.valueQueries["TodoVisualIntelligenceQuery"]`。
- `makeIntent(<パラメータラベル>: 値)` → `try await intent.run()` で実経路実行。`entities["..."].entities(matching:)`
  で entity query、`valueQueries["..."].values(for:)` で value query。戻り値は `AnyAppEntity` 等の型消去型で、
  **動的プロパティアクセス**（`try match.title` を `String` に代入）で値を取り出す。
- アプリターゲットを import せず文字列で参照するため、**多くの誤りはコンパイルではなく実行時**に出る。
  本ブランチは **buildForTesting + live diagnostics 0 件**まで（B 深度）。実 run はシミュレータ起動 +
  実 SwiftData 変更を伴うため、テストは一意タイトルで作成 → 操作 → 削除の**自己クリーンアップ設計**にし、
  実行自体は手動 / CI に委ねる。

### 落とし穴: ファイルのターゲット所属

UIテストターゲットは synchronized folder ではないため、**ファイルを置くだけでは target に入らない**
（ビルドは通るが当該ファイルは無視される）。Xcode プロジェクトに登録する必要がある（本作業では
`XcodeWrite` で追加 → `project.pbxproj` に反映）。`@MainActor override func setUp() async` にしないと
`XCUIApplication` の MainActor 隔離で Swift 6 エラーになる。

## Phase 7: WWDC 2026 追加検証（#43–#48）

> issue #42–#48（WWDC 2026 セッション 240 / 343 / 344 / 345 起票）を `xcode27` で実装。すべて B 深度
> （iOS / visionOS / watchOS の 3 スキームで `BuildProject` グリーン）。R 深度（実機 Siri / Spotlight）は手動。

### `@Property(indexingKey:)`（セマンティック Spotlight、#240 / #43）

`@Property(title:indexingKey:)` の `indexingKey` は `PartialKeyPath<CSSearchableItemAttributeSet>`。プロパティ値を
Spotlight のセマンティックインデックスのキーへ宣言的にマップし、意味ベース検索 / Q&A の対象にできる。

- `TodoAppEntity.title` → `\.title`、新設 `todoDescription` → `\.contentDescription`。
- **訂正（2026-08-11 再検証）**: 「`textContent` は SDK に露出していない」は誤り。`CSSearchableItemAttributeSet_Messaging.h`
  に `NSString *textContent`（macOS 10.11 / iOS 9〜、tvOS・watchOS 対象外）として存在する（wwdc2026-240 のコード例、
  wwdc2024-10131 2:41 が言及する通り）。さらに `EntityProperty.init(indexingKey:)` は `PartialKeyPath<CSSearchableItemAttributeSet>`
  を取るだけでローカルプロパティの型とキーパスの値型を静的に対応付けないため、`String?` でも `AttributedString?` でも同一の
  `indexingKey:` オーバーロードが使える（SDK の `swiftinterface` 上、`Value.ValueType == String` と
  `Value.ValueType == AttributedString` の両方に同シグネチャの `indexingKey:` init 群があることを実ビルドで確認済み）。
  「`textContent` は `AttributedString?` 専用」という仮説も誤り。
  それでも `todoDescription` は `contentDescription`（`CSDocuments` カテゴリ、「アイテムの説明文」の意味）にマップし続けるのが
  妥当という結論は変わらない。`textContent`（`CSMessaging` カテゴリ、メール/メッセージ本文全文を想定した意味）よりも
  Todo の詳細説明というユースケースに近いため——これは型の制約ではなく意味の制約による選択。
- **落とし穴（プラットフォーム）**: `indexingKey:` オーバーロードは **iOS / macOS でしか vend されない**。
  visionOS / watchOS では `Extra argument 'indexingKey'` + `Cannot infer key path type` でビルド失敗するため、
  既存の `IndexedEntity` 拡張と同じ `#if os(iOS) || os(macOS)` で分岐し、他プラットフォームは素の `@Property`
  にフォールバックする。**`XcodeRefreshCodeIssuesInFile`（iOS コンテキスト）は通っても、別プラットフォーム
  destination の `BuildProject` で初めて露見する**ので、entity 系の変更は必ずフルビルドで複数 destination を回す。
- 既存の手書き `attributeSet`（キーワード index）とは併存可。indexingKey はセマンティック経路を足すもの。

### `Transferable` + `ValueRepresentation`（構造化値エクスポート、#240/#345 / #44）

`TodoAppEntity: Transferable` の `transferRepresentation` に複数表現を並べる:

- `ProxyRepresentation(exporting: \.title)`: タイトルを plain text で（どのテキスト先にも貼れる）。
- **`ValueRepresentation`**（`AppEntity.ValueRepresentation` = `IntentValueRepresentation<Item, IntentValue>`,
  `Item: Transferable`）: エンティティを **システム intent value 型**へ橋渡し。`init(exporting:)` /
  `init(exporting:importing:)`。本アプリは担当者を **`IntentPerson`**、場所を **`PlaceDescriptor`** へ export。
  - `IntentPerson(identifier:name:handle:)` は **全引数必須**（`identifier` / `handle` を省くと
    `Missing arguments for parameters 'identifier', 'handle'`）。`identifier: .applicationDefined(todo.id)`,
    `name: .displayName(name)`, `handle: nil`。
  - export closure は `async throws`。値が無い todo は `throw` してその表現を出さない（空値を返さない）。
  - これが計画 doc の「ValueRepresentation(→IntentPerson)」を兼ねる。`IntentPerson` 自体も `Transferable`。

### `IntentParameter.valueState`（部分更新、#344 / #45）

更新系 intent の optional パラメータで「新値 / 明示クリア / 据え置き」を区別する。

- `$param.valueState` は `IntentParameter<Value>.ValueState`。`case set(Value)` / `case unset`。
  optional パラメータでは `.set(nil)` が **明示クリア**、`.unset` が **未指定（据え置き）**。素の `nil` チェックでは
  この 2 つが潰れる。
- `TodoService` 側に `enum FieldUpdate<Value> { case unchanged; case set(Value) }`（`ValueState` の写像）を置き、
  `update(todoId:title:...)` が各フィールドを `.unchanged` / `.set` で受ける。`UpdateTodoIntent` は
  `$param.valueState` → `FieldUpdate` を generic ヘルパー 2 種でマップ:
  - optional モデル列: `if case .set(let v) = state { .set(v) } else { .unchanged }`（`.set(nil)` 透過）
  - required モデル列（title 等、Intent では optional 公開）: `if case .set(let v?) = state { .set(v) } else { .unchanged }`
    （`.set(nil)` は据え置き = 必須列は空にできない）
- `Duration?` → モデルの `TimeInterval?` は perform 内で `duration.map { TimeInterval($0.components.seconds) }` と変換。

### コレクション Onscreen + 通知へのエンティティ付与（#343 / #46）

- **コレクション onscreen**: `List` に `.appEntityIdentifier(forSelectionType: TodoAppEntity.self) { EntityIdentifier(for: TodoAppEntity.self, identifier: $0.id) }`。
  「3 番目のやつ」のような onscreen 参照に対応。`forSelectionType:` 版は大きなリストで id を遅延マップしオーバーヘッドを抑える
  （単一 entity 版 `.appEntityIdentifier(_:)` は既に詳細画面で使用済み）。
- **通知へのエンティティ付与**: `UNMutableNotificationContent.appEntityIdentifiers = [EntityIdentifier(for:identifier:)]`
  （iOS 27、`import AppIntents`）。画面外でも Siri が通知の文脈を理解する。**永続 AppEntity 必須**（TransientAppEntity 不可）。
  `ControlNotificationHelper.sendToggledNotification` に `todoId` を足し、`UrgentTodoToggleResult` に `id` を持たせて配線。

### `.system.searchInApp`（in-app 検索スキーマ、#343 / #47）

`@AppIntent(schema: .system.searchInApp)` + `ShowInAppSearchResultsIntent` で、Siri / Apple Intelligence が検索語を
**アプリ自身の検索 UI** に流して結果を出せる（`ShowInAppSearchResultsIntent` 自体は iOS 16 からの型で、スキーママクロ形が新）。
**スキーマ名の変遷**: beta 2 では `.system.search` が正式名だったが、**Xcode 27 beta 3 で `.system.search` は deprecated となり `.system.searchInApp` にリネーム**された（`'search' is deprecated: Use .system.searchInApp instead`）。issue #47 当初の `.system.searchInApp` 表記が結果的に正しかった。2026-07-08 に追従。

- 形: `static let searchScopes: [StringSearchScope] = [.general]` + `var criteria: StringSearchCriteria`（マクロが
  `@Parameter` を注入、`criteria.term` で検索語）。`title` / `supportedModes` はスキーマが供給。
- **ナビゲーション**: `@Dependency var navigationModel` に検索語を書く設計。`NavigationModel.pendingSearchText` を新設し、
  `TodoListView` が `.onChange` / `.onAppear` で `viewModel.searchText` に転写してから nil に戻す（cold-start 安全な
  `@Dependency` ナビ方式と同系統）。
- **`SearchEverythingIntent` とは別物**: あちらは `@UnionValue` の `[TodoOrCategory]` を **返す** value 検索。
  こちらは検索 UI へ **遷移** する。スキーマの意味（"take the person to search results"）が異なるため統合せず別 Intent にした。
- 低優先項目（#47）: `OwnershipProvidingEntity`（shared/public/private の出し分け）/ `$param.requestValue`（perform 途中の聞き返し）
  は個人利用主体では優先度低として **未採用**（必要時に追加）。
- **落とし穴（watchOS 非対応 / Xcode 27 beta 2、beta 3 でも継続 — 2026-07-08 実ビルド確認）**: `.system` ドメインのスキーマも beta 2 で **watchOS で unavailable**
  （`'system' is unavailable in watchOS` / `'search' is unavailable in watchOS`）。watch アプリには検索遷移先の UI が
  無いため、`ShowTodoSearchResultsIntent` は `#if !os(watchOS)` で丸ごと除外した（`NavigationModel` / `TodoListView`
  からの参照はコメントのみで実害なし）。`.visualIntelligence.*`（#297）は `#if canImport(VisualIntelligence)` ガード
  なので watchOS（フレームワーク非存在）には来ない。※ beta 2 で **Mac には import 可能**になり macOS でも成立
  させた（`OpenCategoryIntent` 追加）。詳細は上記「beta 2 で macOS 対応」。

### reminder 本体スキーマ適合の優先度再考（#240 Group Lab / #48）

「新 Siri 連携は App Schema 採用が前提」だが、コア `TodoAppEntity` の `@AppEntity(schema: .reminders.reminder)` 適合は
**引き続き保留**と判断（再評価結果）。

- **確認した具体的前提**（DocumentationSearch）: reminder 本体は入れ子サブエンティティとして
  `@AppEntity(schema: .reminders.section)`（`name` + `list`）と `@AppEntity(schema: .reminders.locationTrigger)`
  （`place: GeoToolbox.PlaceDescriptor` + `event`）、後者の `event` に `@AppEnum(schema: .reminders.locationTriggerEvent)`
  （`arrive` / `depart`）を要求。`locationTrigger.place` が `PlaceDescriptor` な点は本アプリの `TodoPlace` 橋渡しと相性が良い。
- **コアブロッカーは不変**: サブエンティティを揃えても、reminder スキーママクロの **生成 init が `EntityProperty<T>` 引数 +
  入れ子再帰**を要求し、モデルから組み立てる自前 init と衝突（`self.images used before being initialized`、SDK 27 の
  `@State` マクロ化と同根の初期化規約問題）。サブエンティティ追加では解消しない。
- **新 Siri 連携は本体適合なしでも成立**（#48 のフォールバック検証）: `CategoryAppEntity` の `.reminders.list` 適合 +
  discoverable な自前 Intent 群（Add / Update(#45) / Toggle / Show / `.system.searchInApp`(#47)）+ `OpenIntent` / `DeleteIntent` +
  `IndexedEntity` セマンティック index(#43) で、意味理解・検索・遷移は機能する。**本体適合は SDK のスキーママクロ init 規約が
  扱いやすくなるのを待つ独立タスク**として据え置く。

## Phase 8: TransientAppEntity（Xcode 27 beta 4 / #344）

### TransientAppEntity とは

`TransientAppEntity` は WWDC 2026 #344 で紹介されたエンティティの派生型で、**永続化・クエリが不要な一時的なデータ**を App Intents の型システムで表現する。

```
AppEntity                       TransientAppEntity
─────────────────────────────   ─────────────────────────────
defaultQuery 必須（EntityQuery） defaultQuery 不要
SwiftData/永続化と対応              計算済みスナップショット
ID で Siri/Shortcuts が参照       Intent の戻り値としてのみ使う
@Property で公開可能              @Property で公開可能
```

### 実装パターン

```swift
public struct TodoListSummaryEntity: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo List Summary"

    @Property(title: "Pending Todos")
    public var pendingCount: Int

    @Property(title: "Overdue Todos")
    public var overdueCount: Int

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(pendingCount) pending, \(overdueCount) overdue"
        )
    }

    public init() {}

    public init(pendingCount: Int, overdueCount: Int, ...) {
        self.pendingCount = pendingCount
        self.overdueCount = overdueCount
    }
}
```

**ポイント**:
- `static let typeDisplayRepresentation` を `let`（非 `nonisolated(unsafe) var`）で宣言できる。
- `@Property` は `AppEntity` と同じマクロが使える。`Int` 等の非 Optional もそのまま利用可能。
- `init()` と値初期化 `init(...)` の 2 種を用意するのが定石（システムが `init()` を必要とする場合がある）。
- `defaultQuery` は宣言不要（`TransientAppEntity` プロトコル要件には含まれない）。
- `IndexedEntity` は適用不可（クエリ不可な型を Spotlight に載せる意味がない）。

### 利用パターン（Shortcuts の条件分岐）

```swift
public struct GetTodoSummaryIntent: AppIntent {
    public static var supportedModes: IntentModes { .background }

    @Dependency var todoService: TodoService

    @MainActor
    public func perform() async throws -> some IntentResult
        & ReturnsValue<TodoListSummaryEntity>
        & ProvidesDialog {
        let summary = try todoService.summarize()
        return .result(
            value: summary,
            dialog: IntentDialog(
                full: "You have \(summary.pendingCount) pending todos.",
                supporting: "\(summary.pendingCount) pending."
            )
        )
    }
}
```

Shortcuts ユーザーは「If Get Todo Summary → Overdue Todos > 0 → 通知」のような条件分岐が書ける。
個別の `TodoAppEntity` リストを `ShowTodosIntent` で取得する必要がなく、集計値だけほしい場面に最適。

### beta 4 での動作確認

Xcode 27 beta 4 で `RunCodeSnippet` + `BuildProject` の両方で成立を確認（B 深度）。
