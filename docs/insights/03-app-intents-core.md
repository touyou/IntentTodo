# App Intents コア設計

## 「アプリの動詞」としてのIntent

App Intentsは、アプリでできる「アクション」を定義する。

- **AddTodoIntent**: Todoを作成する
- **ToggleTodoCompletionIntent**: 完了状態を切り替える
- **DeleteTodoIntent**: Todoを削除する
- **ToggleFavoriteIntent**: お気に入り状態を切り替える

### ビジネスロジックは `TodoService`、Intent は接続点

Intent は「ユースケースの宣言」（名前・パラメータ・戻り値）と、`TodoService` を呼ぶ接続点だけを持つ。
SwiftData を直接触らないので、同じ操作を UI / Siri / ウィジェットのどこから呼んでも手続きが 1 本になる。

```swift
public struct AddTodoIntent: AppIntent {
    @Dependency var todoService: TodoService

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let entity = try todoService.create(title: title, dueDate: dueDate, ...)
        return .result(value: entity)
    }
}
```

`TodoService`（`@MainActor final class`）が持つのは Repository 呼び出し・不変条件・副作用で、
変更メソッドの `defer` が後処理をまとめて行う（後述「データ更新の後処理」）。
バリデーションのように「そのユースケース固有で、他から呼ばれない」判断は Intent 側に置いてよい。

---

## DI パターン（@Dependency + AppDependencyManager）

### 基本

`TodoService` / `ModelContainer` / `@Observable @MainActor` クラス（`NavigationModel` 等）はいずれも
`Sendable` 要件を満たすので `@Dependency` で共有できる。`App.init()` で
`AppDependencyManager.shared.add(dependency:)` に**同期登録**する。

**Intent が受け取るのは `TodoService`**（Repository を内包している）。`ModelContainer` を直接受けるのは
**Query 側**（`TodoEntityQuery` など、`mainContext` から Repository を組む）だけにする。
毎回新しい `ModelContext(modelContainer)` を作ると保存されていない状態が共有されないので注意。

```swift
@main
struct IntentTodoApp: App {
    let modelContainer: ModelContainer

    init() {
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)
        AppDependencyManager.shared.add(dependency: TodoService.swiftDataBacked(container: container))
    }
}

// Intent 側は Service を受け取る
public struct AddTodoIntent: AppIntent {
    @Dependency var todoService: TodoService
}

// Query 側だけコンテナを受け取る
public struct TodoEntityQuery: EntityQuery {
    @Dependency var modelContainer: ModelContainer
}
```

現在の内訳は `todoService` 18 / `navigationModel` 7 / `modelContainer` 4（Query と snippet Intent）。

### 実行プロセスごとに登録が必要

`AppDependencyManager.shared` は**プロセスごとに独立したインスタンス**。`supportedModes` は「フォアグラウンド遷移するか」を決めるだけで、実行プロセスそのものを固定しない。共有パッケージの Intent は複数ターゲットにリンクされていると、システムが**ヒューリスティクス**（アプリ起動中ならアプリを優先、等）でプロセスを選ぶ（[WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) 15:59–16:55）。固定したい場合は `allowedExecutionTargets`（後述 L611 付近）で明示する。

| モード/呼出元 | 実行プロセス | 登録が必要な場所 |
|--------------|-------------|----------------|
| `.foreground(.immediate)` | メインアプリ（開かれる） | `App.init()` |
| `.foreground` | メインアプリ | `App.init()` |
| `.background` / Siri / Shortcuts | メインアプリ | `App.init()` |
| `.background` / Widget ControlWidgetButton（`allowedExecutionTargets` 未指定 = 読み取り系のみ） | **ヒューリスティクスで決定**（アプリ起動中はメインアプリ優先、未起動なら Widget Extension） | **両方**（`App.init()` と `WidgetBundle.init()`） |
| 同上（`allowedExecutionTargets = [.main]` = 書き込み系すべて） | メインアプリに固定 | `App.init()` のみ |
| Live Activity ボタン | **メインアプリプロセス**（`perform()` は公式保証。entity 事前解決も実測でメインアプリ） | `App.init()` |

> `LiveActivityIntent` については Apple 公式 [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) が "the system runs the app intent in the app's process" と明言している。これは `perform()` についての保証だが、`@Parameter var todo: TodoAppEntity` の**事前解決フェーズ**（`entities(for:)`）についても、iOS 27 / Xcode 27 beta 5 の実測ではメインアプリプロセスで走ることを確認済み（アプリ kill 済みの cold start でも、`LiveActivityIntent` 非準拠の素の `AppIntent` でも同じ。下記「1 アクション 1 Intent」参照）。よってメインアプリ側の `AppDependencyManager` に登録してあれば両フェーズとも解決される（LA Extension 側の登録は不要）。
>
> ただしこれは **Live Activity ボタン経由に限った話**。Widget のタイムライン描画では `entities(for:)` が Widget Extension プロセスで走ることを同じ実測で確認しているため、Widget Extension 側の登録は必要。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

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

    // システムに見せる属性は @Property。素の var は Shortcuts / Siri / Spotlight から見えない
    @Property(title: "Title") public var title: String
    @Property(title: "Completed") public var isCompleted: Bool

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"

    public var displayRepresentation: DisplayRepresentation {
        // 実行時の値は "\(value)" の補間形式（後述「実行時の文字列は…」）
        DisplayRepresentation(
            title: "\(title)",
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }

    public static var defaultQuery: TodoEntityQuery {
        TodoEntityQuery()
    }
}
```

### Spotlight: 名前付き index と `IndexedEntityQuery`（donate 側と受け側はセット）

`IndexedEntity` 準拠 + `indexAppEntities` での donate だけでは片手落ちで、Apple 公式
（Making app entities available in Spotlight）は受け側の実装も要求している:

> If you donate app entities to a `CSSearchableIndex` using its `indexAppEntities(_:priority:)`
> method, **implement the `IndexedEntityQuery` protocol** in your entity's query object to
> handle reindexing.

これが無いと、Spotlight 側が index を作り直したいときに応答先が無く、次にアプリが起動して
全件 index するまで検索に出てこない。本アプリは `TodoEntityQuery` に
`reindexEntities(for:indexDescription:)` / `reindexAllEntities(indexDescription:)` を実装した。

落とし穴が 2 つ:

1. **`@MainActor` を付けられない**。`CSSearchableIndexDescription` が non-Sendable なので、
   MainActor 隔離した実装に渡せず `Non-Sendable parameter type 'CSSearchableIndexDescription'
   cannot be sent from caller of protocol requirement` でコンパイルエラーになる。同じファイルの
   `entities(for:)` などは `@MainActor` で問題ないので、ここだけ nonisolated にして内側で await する
2. **単体テストで直接呼びにくい**。`CSSearchableIndexDescription` の public な init は `init(coder:)`
   だけで、素直にインスタンスを作れない

**index は名前付きにする**。同ドキュメントの Note:

> When indexing your app's content, use a **named** `CSSearchableIndex` type and not the default
> index. Use the default index only for prototyping and testing your code during development.

`CSSearchableIndex.default()` から `CSSearchableIndex(name: "dev.touyou.IntentTodo.Todos")`
（`TodoSpotlightIndex`）に移行済み。移行時は**旧 default index に残ったアイテムが二重に出る**ので、
初回起動で 1 度だけ `CSSearchableIndex.default().deleteAllSearchableItems()` を実行して掃除する
（default index にはこのアプリの todo しか入れていないので全消しで安全）。移行後も AppIntentsTesting の
Spotlight テスト（`testNewTodoIsIndexedInSpotlight` / `testDeletedTodoIsRemovedFromSpotlight`）は
グリーンなので、名前付き index でも検索からは見える。

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
        // システムは絞り込んでくれない。比較は必ず localizedStandardContains
        // （後述「文字列の突き合わせは**すべて** localizedStandardContains」）
        try makeRepository().fetchAll()
            .filter { $0.title.localizedStandardContains(string) }
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

Apple は `AppShortcutsProvider.appShortcuts` の登録数を **10 件** に制限している（SDK 27 時点）。本プロジェクトは現在 8 件で運用しており、枠 2 件分の余裕を意識的に確保する設計判断をしている。

- 同じ Intent のパラメータ違いは、可能な限り 1 件にまとめて「フレーズを複数登録」する。例えば `ShowTodosIntent` は `filter` パラメータを 1 つの AppShortcut で受け、`Show my todos / Show incomplete todos / Show favorite todos` のフレーズ群にまとめ、10 件枠を食い潰さないようにしている。
- アプリを「開くだけ」の用途（例: `LaunchAppIntent`）は Widget/ControlWidget 経由で呼べば足りるので、AppShortcut 登録を省いて枠を節約する。

### パッケージ内での定義

Intent / AppEntity / EntityQuery / AppEnum は Swift Package 内に置ける。パッケージ側に `AppIntentsPackage` を1つ宣言するだけで、そこに含まれるこれらの型がアプリ全体で認識される。

```swift
// Packages/TodoAppIntents/Sources/TodoAppIntents/TodoAppIntents.swift
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

さらに、**そのパッケージを使う各ターゲットでも `includedPackages` 付きで宣言する**（Apple 公式手順。wwdc2025-244 23:29–24:00 "You must register each target as an App Intents Package to ensure proper indexing and validation."）。

```swift
// IntentTodo / IntentTodoWidget / IntentTodoLiveActivity / IntentTodoWatchApp に 1 つずつ
struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
```

宣言先は `IntentTodo` / `IntentTodoWidget` / `IntentTodoLiveActivity` / `IntentTodoWatchApp` の 4 ターゲット。
メタデータの重複が起きないこと・AppIntentsTesting が全緑になることは確認済みで、**未確認なのは
App Shortcut の「フレーズ」ルーティング（Siri）だけ**（AppIntentsTesting は型名で引くので構造上通らない。
追跡は #30）。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

### ⚠️ `AppShortcutsProvider` は SPM パッケージに置いてはいけない（アプリターゲット必須）

**`AppShortcutsProvider` を Swift Package 内に置くと、App Shortcuts はアプリに登録されない。** メインアプリターゲット直下（本プロジェクトでは `IntentTodo/IntentTodo/TodoAppShortcuts.swift`）に置くこと。

**症状**: Siri / Shortcuts アプリ / Spotlight に App Shortcut が一切出てこない（ビルド・実行はエラー無しで成功するため気付きにくい）。

**根拠**: App Intents の実体はビルド時に生成される `Metadata.appintents` バンドル。DerivedData の `.appintents/extract.actionsdata`（JSON）を比較すると:

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

> **一次ソース未確認**: Apple 公式 API リファレンスで「アプリあたり 1 つまで」と明文化されている記述は 2026-04-15 時点で確認できていない。`AppIntentsPackage` / `includedPackages` のドキュメントには duplicate registration に関する注意書きが見つからないため、実機観測ベースの知見として扱う。

> 本制約は上記「パッケージ内での定義」節の `AppIntentsPackage` 重複宣言問題とは**独立**。アプリ/Extension ターゲットに `includedPackages` 付き `AppIntentsPackage` を追加した状態でも `AppShortcutsProvider` がパッケージ内にある限り `autoShortcuts` は 0 のままで、パッケージ→アプリターゲットへ移動した時点でのみ 0→8 に変化する。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

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

### パラメータ入りフレーズと `updateAppShortcutParameters()`（セット）

**パラメータをフレーズに埋めるだけでは動かない。** wwdc2023-10102 9:24–9:52:

> Calling this method signals to the system that your App Shortcut parameters have changed
> and will cause the system to call `suggestedEntities` on any relevant queries to re-fetch
> them. [...] It's important to remember to also call this upon your app's **first launch**.
> App Shortcut phrases referencing entity parameters **won't work until the system has
> successfully fetched entities for the first time**.

呼ぶタイミングは「entity の追加 / 削除 / `displayRepresentation` の変化（リネーム等）」＋初回起動。

**⚠️ `suggestedEntities()` の件数がそのまま App Shortcut の件数になる。** wwdc2025-244 9:46:
"Phrases can include up to one intent parameter. **If provided, an App Shortcut for each value of that
type will be created.**" パラメータ入りフレーズを入れるなら、`suggestedEntities()` は「候補として妥当な
少数」に絞ること（本アプリは直近の未完了 10 件。HIG の "not more than ten" に合わせた）。全件返す実装のまま
フレーズだけパラメータ化すると、Shortcuts / Spotlight がそのアプリの自動生成 shortcut で埋まる。
全件が要る用途は `allEntities()`（`EnumerableEntityQuery`）が担う。

本アプリの配線（2026-08-21 採用）:

| 場所 | 役割 |
|---|---|
| `TodoAppShortcuts.swift` | `"Complete \(\.$todo) in \(.applicationName)"` 等。**パラメータ無しのフレーズも各 shortcut に 1 つ残す**（同 8:14。Siri 側で聞き返せるようにするため） |
| `AppShortcutParameterUpdater`（パッケージ） | アプリ側のクロージャを受け取る間接層。`updateAppShortcutParameters()` は provider の**具体型**に対する static なので、アプリターゲットにしか置けない型をパッケージから呼ぶにはこれが要る |
| `TodoService.dataDidChange()` | 変更系メソッドの `defer` が通る唯一の後処理。ウィジェット/コントロールのリロードと並べて通知する |
| `IntentTodoApp.init()` | ハンドラ登録 + 初回 1 回の通知 |

守り方: `AppShortcutParameterUpdaterTests`（create / toggle / delete で通知が飛ぶことを数える）。通知を外すと落ちることを確認済み。

### アプリ内の導線: `SiriTipView` / `ShortcutsLink`

App Shortcut は Spotlight / Siri / Shortcuts から自動で見つかるが、ユーザーが「言えること」を知らなければ使われない。アプリ内の導線は 2 つあり、**役割が違うので置き場も違う**（`SiriTipView` はその場のフレーズを教えるので文脈のある瞬間に、`ShortcutsLink` は一覧を探索させるので設定画面に）。

置き場の判断根拠・プラットフォーム可用性・実装は UI 側の話なので **`docs/insights/04-ui-integration.md`「App Shortcut をアプリ内で知らせる 2 つの面」に一元化**した。

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
// バックグラウンドで始めて、返却時にシステムが前面化を保証する（AddTodoIntent が採用）
public static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }
```

`.foreground(.dynamic)` + `continueInForeground()` / `systemContext.currentMode` は
**本アプリでは使っていない**（理由は後述「Intent Modes: `.foreground(.dynamic)` は使っていない」）。

---

## 1 アクション 1 Intent（呼出元ごとに複製しない）

同じアクションは呼出元が違っても同じ Intent を使う。Live Activity のボタンも Siri も `ToggleTodoCompletionIntent(todo:)` を呼ぶ。Live Activity が持っているのが id と title だけでも `TodoAppEntity(id:title:)` で組んで渡せばよい（システムが `perform()` 前に id から再解決する）。

**呼出元プロセスの都合で Intent を複製する必要はない。** Live Activity ボタン経由では
`entities(for:)`（entity の事前解決）も `perform()` もメインアプリプロセスで走る（iOS 27 実測。
cold start でも `LiveActivityIntent` 非準拠でも同じ）。ただし **Widget のタイムライン描画では
`entities(for:)` が Widget Extension プロセスで走る**ので、「entity 解決は必ずアプリ」ではない点に注意。

> かつて呼出元ごとに Primary / FromExtension を分けていたが、その根拠だった crash が iOS 27 で
> 再現しないと実測して撤去した。経緯と実測表: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

### 別 Intent に分けるのは「振る舞いが違う」ときだけ

呼出元プロセスの都合で複製しない。現存する分岐は次の 3 つで、どれも理由は**対話できるかどうか**（または値の渡し方）であってプロセスではない。

| Intent | 分けている理由 |
|--------|--------------|
| `SnoozeTodoIntent` / `QuickSnoozeTodoIntent` | 前者は `requestChoice` で期間を選ばせる。Live Activity のボタンは背景実行で問い合わせ先の UI が無いため、後者が既定 30 分で即実行する |
| `DeleteTodoIntent` / `DeleteTodoImmediatelyIntent` | 前者は `requestConfirmation` で確認を取る。アプリ内の `Button(intent:)` には確認を提示する面が無く**失敗して何も起きない**ため、UI は SwiftUI の `.confirmationDialog` で確認してから後者を実行する |
| `ToggleTodoCompletionIntent` / `SetTodoCompletionIntent` | 前者はトグル、後者は絶対値セット（`SetValueIntent`）。Control の `ControlWidgetToggle` は on/off を渡してくるのでトグルでは表現できない |

> **⚠️ `requestConfirmation` / `requestChoice` を含む Intent はアプリ内 `Button(intent:)` から呼べない**。応答する面が無いため `LNPerformActionErrorCodeUnsupportedValueType` で失敗し、**エラー表示も出ずに何も起きない**（2026-08-12 実測。詳細画面の削除ボタンが全く動いていなかった）。対話を伴う Intent は Siri / Shortcuts 専用と考え、UI からは対話なし版を用意して確認は SwiftUI 側で取る。Siri / Shortcuts / AppIntentsTesting 経由なら成功するので、AppIntentsTesting だけではこの不具合を検出できない — **UI テストが必要**。

内部用は `isDiscoverable = false` にして AppShortcuts に登録しない。Live Activity の状態を触る Intent（`activity.end` / `activity.update`）は `#if os(iOS)` で `LiveActivityIntent` に準拠させる。

```swift
public struct ToggleTodoCompletionIntent: AppIntent {
    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var todoService: TodoService

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let result = try todoService.toggleCompletion(todoId: todo.id)
        #if os(iOS)
        if result.isNowCompleted { await endMatchingLiveActivity(for: todo.id) }
        #endif
        return .result(value: result.entity)
    }
}

#if os(iOS)
extension ToggleTodoCompletionIntent: LiveActivityIntent {}
#endif
```

Live Activity 側は Activity が持つ id / title から entity を組んで渡す:

```swift
let todoEntity = TodoAppEntity(id: context.attributes.todoId, title: context.state.title)
Button(intent: ToggleTodoCompletionIntent(todo: todoEntity)) { ... }
```

### 共通ロジックは TodoService に集約

`Services/TodoService.swift` (`@MainActor final class`) にビジネスロジックを集約し、各 Intent が
`@Dependency var todoService: TodoService` で参照する。`TodoService.swiftDataBacked(container:)`
ファクトリ経由で、メインアプリ / Widget Extension / watch App の各プロセスで `AppDependencyManager.shared`
に登録する。

### データ更新の後処理は `TodoService.dataDidChange()` に集約する

データを変える経路は必ず `TodoService` の変更メソッドを通り、そこの `defer` が後処理をまとめて行う。
**Intent 側には書かない**（経路が 25 本あるので、1 か所忘れると「その呼出元からだけ更新されない」形で壊れる）。

```swift
public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
    defer { Self.dataDidChange() }
    // ...
}
```

`dataDidChange()` が呼ぶのは 2 つ:

1. `WidgetReloader.reloadAllWidgets()` — `WidgetCenter.shared.reloadAllTimelines()` と
   `ControlCenter.shared.reloadAllControls()` の**両方**（前者だけではコントロールは更新されない。
   実測: [05-extensions-and-data-sharing.md](05-extensions-and-data-sharing.md)）
2. `AppShortcutParameterUpdater.notifyEntitiesChanged()` — パラメータ入り App Shortcut フレーズの
   候補をシステムに取り直させる（wwdc2023-10102 `9:24`）

Widget 起点の `Button(intent:)` はシステムが自動でタイムラインをリロードするので厳密には重複するが、
**判定を省いて全変更で無条件に呼ぶ**のが現在のルール（重複のコストは無視できる）。
守り方は `AppShortcutParameterUpdaterTests`（create / toggle / delete で通知が飛ぶことを数える）。

### `parameterSummary` は Shortcuts 編集画面の allowlist（飾りではない）

Apple のガイダンスが明言している: "`ParameterSummary` is not cosmetic — it is the allowlist for which
parameters the Shortcuts editor surfaces. […] every other `@Parameter` is **silently omitted** from the
editor UI, even though it still exists and still resolves."

編集行になるのは **`Summary("...")` の補間に出てくるもの**と **trailing `@ParameterKeyPathsBuilder`
ブロックに列挙したもの**だけ。載せ忘れたパラメータは **Shortcuts から設定できない**（ビルドは緑、
Siri から名指しすれば動くので気づけない）。

```swift
public static var parameterSummary: some ParameterSummary {
    Summary("Add todo titled \(\.$title)") {
        \.$dueDate          // ← この列挙が無いと、どれも Shortcuts で設定できない
        \.$isFavorite
        \.$estimatedDuration
    }
}
```

- **Intent が変えられるものは全部載せる**。文に入らないものは trailing ブロックへ
- 表示順は宣言順ではなく **summary の順**（補間 → trailing ブロック）
- 出し分けは `When(\.$p, .equalTo, v) { } otherwise: { }` / `Switch(\.$p) { Case(v) { } }`
- 判定は `Metadata.appintents` の
  `actionConfiguration.actionSummary.wrapper.otherParameterIdentifiers` と突き合わせる

経緯: [docs/devlog/2026-08-29-attribute-write-paths.md](../devlog/2026-08-29-attribute-write-paths.md)
（`AddTodoIntent` / `UpdateTodoIntent` の 11 パラメータが編集画面に出ていなかった件）

---

## Intent のコピーはどこから引かれるか

Intent が共有パッケージ（`TodoAppIntents`）にあるとき、**文言の抽出と解決は別の話**で、
どちらも直感と違う。ここを取り違えると「ビルドは緑、ソース言語では正常、訳した言語だけ
英語のまま」という形で壊れる。

### 解決先はリンク先ターゲットの main bundle。これは強制されている

メタデータ（`Metadata.appintents/extract.actionsdata`）は文言を `{"key": "Add Todo"}` の形で
**キーだけ**持ち、bundle も table も記録しない。実際にコンパイラが非 main bundle を弾く:

```swift
// ❌ コンパイルエラー: AppIntents requires 'LocalizedStringResource' to use the main bundle
public static var title: LocalizedStringResource {
    LocalizedStringResource("Complete Todos", bundle: .atURL(Bundle.module.bundleURL))
}
```

つまり **UI パッケージの `.copy(_:)` パターンは Intent には使えない**。`title` /
`IntentDescription` / `@Parameter` / `DisplayRepresentation` の訳は、リンク先ターゲット
（アプリ / 各 Extension / watch アプリ）の `Localizable.xcstrings` に置く。

### 自動で抽出されるのは `parameterSummary` だけ

`TodoAppIntents` は `defaultLocalization` も resources も持たないので、**このモジュールでは
文字列抽出そのものが走っていない**（`TodoAppIntents.build/**/Objects-normal/*.stringsdata` が
1 つも出ない）。catalog に載っている Intent 系のキーの出どころは 2 つだけ:

| 出どころ | 中身 |
|---|---|
| `appshortcutstringsprocessor` | 全 Intent の `parameterSummary` フォーマット文字列（+ `AppShortcuts` テーブルのフレーズ） |
| アプリターゲットの Swift 抽出 | `TodoAppShortcuts.swift` に直書きした `shortTitle` |

`title` が ja になっている Intent があるのは、**同じ文字列を `shortTitle` にも書いていた偶然**。
`title` / `IntentDescription` / `@Parameter(title:/description:)` / `categoryName` /
`searchKeywords` / entity・enum の `DisplayRepresentation` / `IntentDialog` はどこにも載らない。

### だから手動キーで持ち、スクリプトで漏れを見る

各ターゲットの catalog に `extractionState: "manual"` で入れる。コンパイラの後ろ盾が無いので、
**メタデータと catalog の突き合わせをスクリプトでやる**:

```
python3 skills/app-intents-localization/scripts/check_intent_copy_localization.py
```

Intent コピーを持つ 4 ターゲット（アプリ / watch アプリ / LiveActivity / Widget）を一度に見る。
Widget は自前の catalog を持たず watch アプリのものを共有している点に注意。

副作用: 大文字小文字だけ違うキー（`todo` と `Todo`、`category` と `Category`）が同じ catalog に
同居するため、シンボル生成が衝突する。4 ターゲットとも
`STRING_CATALOG_GENERATE_SYMBOLS = NO`（生成シンボルはどこからも使っていない）。

### `IntentDialog` の中で英語の屈折を Swift で組み立てない

```swift
// ❌ "s" / "is" / "are" は catalog に載らないまま %@ に差し込まれ、訳文に英語が残る
let noun = count == 1 ? "todo" : "todos"
IntentDialog(full: "You have no \(categoryLabel)s.")

// ✅ 単複は訳文側に持たせる / inflect に任せる
let noun = String(localized: count == 1 ? "todo" : "todos")
IntentDialog(full: "You have ^[\(pending) pending todo](inflect: true).")
```

`IntentDialog` は `perform()` の中で作るのでメタデータには現れず、上のスクリプトでも
見えない。棚卸しが必要なときは `TodoAppIntents` に一時的に `defaultLocalization` +
`Resources/Localizable.xcstrings` を足してビルドし、Xcode が抽出したキーを読む（読んだら戻す）。

経緯: [docs/devlog/2026-08-28-intent-copy-localization.md](../devlog/2026-08-28-intent-copy-localization.md)

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

統合しない基準は**振る舞いの違い**だけ（上の 3 分岐と同じ）。「呼出元が違う」は理由にならない。

| Intent組み合わせ | 統合しない理由 |
|-----------------|---------------|
| `SetTodoCompletionIntent` / `ToggleTodoCompletionIntent` | Control の Toggle は `SetValueIntent`（システムが遷移先の状態を `value` に埋める絶対値）で、flip する Toggle 系 Intent とは意味論が違う。パラメータも `todoId: String`（呼出元が id を知っているので事前 entity 解決が不要）|
| `SearchEverythingIntent` / `ShowTodoSearchResultsIntent` | 前者は値（`[TodoOrCategory]`）を**返す**、後者はアプリの検索 UI へ**遷移する**（`.system.searchInApp` の意味） |

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

> `xcode27` ブランチ（27 世代ベータ SDK 検証用）で採用し、2026-08-27 に `main` へマージ済み。
> ベータ SDK 時点の仕様に基づくため、GM SDK で変更されている可能性がある。

### @ComputedProperty / @DeferredProperty（Entity プロパティマクロ）

`AppEntity` のプロパティをスナップショット以外の源から導出/取得して Shortcuts・Siri に公開できる。

- `@ComputedProperty`: 同期 getter。`TodoAppEntity.isOverdue` はスナップショットの `dueDate` / `isCompleted` から導出（外部アクセスなし）。
- `@DeferredProperty`: 非同期 getter (`get async throws`)。要求時のみ取得され、**Spotlight index には含まれず、Siri / Shortcuts にも自動送出されない**。`TodoAppEntity.subtaskProgress` はサブタスク（SwiftData リレーション）を必要時だけ取得する。

**落とし穴**:
- **Entity は `@Dependency` を使えない**。Apple 公式: 「dependency injection は main app から *intent* へデータを渡すためだけに使える」。`EntityQuery` では使えるが `AppEntity` では `Unknown attribute 'Dependency'` になる。→ 共有 `ModelContainer` を App 起動時に `TodoEntityStore`（`@MainActor enum` の static）へ登録し、deferred getter から参照する（Apple サンプルの ambient `modelData` パターン相当）。
- **プロパティマクロは非 `Hashable` な `EntityProperty` backing を生成する**ため `Hashable` / `Equatable` の自動合成が壊れる。→ `==` / `hash(into:)` を明示実装（id ベースの hash + スナップショット比較の等価）。

### Intent Modes: `.foreground(.dynamic)` は使っていない（適所なし）

`.foreground(.dynamic)` + `continueInForeground` は「背景で走らせ、必要になったら前面に
引き上げる」ための API（deprecated な `ForegroundContinuableIntent` の後継）。**本アプリでは
採用していない**。API を把握した上での不採用なので、理由を残す。

```swift
// 採用していない形
public static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog {
    let entities = try todoService.listTodos(filter: filter)
    if systemContext.currentMode.canContinueInForeground {
        try? await continueInForeground(alwaysConfirm: false)
        navigationModel.navigateToRoot()
    }
    return .result(value: entities, dialog: dialog(for: entities))
}
```

**`OpensIntent` と両立しない**のが判断の中心。`OpensIntent` は返り値の型に現れるので
「条件によっては開かない」を表現できず、dynamic を使うなら Intent 合成
（`ShowTodosIntent` → `LaunchAppIntent`）を外して `NavigationModel` 直叩きに替える必要がある。
一度その形を入れて revert した（`93d0230` → `cab8e67`）。

**代わりに埋まっている手段**（2026-08-27 に全 21 intent を見直して確認）:

| やりたいこと | 使っている手段 |
|------------|--------------|
| アプリの該当画面へ送る | `OpensIntent` + `LaunchAppIntent`（`.foreground(.immediate)`）の Intent 合成 |
| 実行中に選ばせる / 確認を取る | `requestChoice`（`SnoozeTodoIntent`）/ `requestConfirmation`（`DeleteTodoIntent`） |
| 結果を読ませる / 見せる | `IntentDialog(full:supporting:)` + `snippetIntent:` |
| 時間のかかる一括処理 | `LongRunningIntent` + `CancellableIntent`（`CompleteTodosIntent`） |

残るのは「背景で始めて、途中で前面が必要になる」形だが、**このアプリの 21 intent にその形の
操作が無い**（todo の CRUD はパラメータが揃っていれば背景で完結し、揃わないケースは
パラメータ解決 / `requestChoice` が拾う）。`.foreground(.dynamic)` に当て先ができるのは、
たとえば「途中でカメラや地図のような別 UI を出さないと完了できない操作」が生えたとき。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)（2026-08-27 の #55）

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
- スニペットからは entity ベースの Intent をそのまま使う。かつての entity 解決クラッシュ（Issue #30 / A-3）は iOS 27 で再現せず、呼出元ごとの `String` パラメータ変種はすべて撤去済み。
- `SnippetIntent` は `isDiscoverable = false`（`snippetIntent:` 経由でのみ提示、Shortcuts 非露出）。

### App Schema（`@AppEntity(schema:)` / `@AppEnum(schema:)`）— reminders ドメイン

assistant schema に適合させると、Siri / Apple Intelligence がコンテンツを意味的に理解する。

- **`.reminders` ドメインは iOS 27+ 限定**（`'reminders' is only available in iOS 27.0 or newer`）。
  採用には deployment を 27 世代へ上げる（`.v27` は PackageDescription 6.4 = `swift-tools-version: 6.4`）。
- **小スキーマは素直**: `CategoryAppEntity` を `@AppEntity(schema: .reminders.list)` に適合（`id` / `name` /
  `type: TodoListType`）、`TodoListType` を `@AppEnum(schema: .reminders.listType)` に。マクロが
  `typeDisplayRepresentation` を生成するので手書きは削除、`Hashable` はマクロ backing が非 Hashable のため明示実装。
- **落とし穴（watchOS / tvOS 非対応）**: **`AppSchema` の全 23 ドメインが watchOS / tvOS で
  `@available(..., unavailable)`**（Xcode 27 beta 6 の SDK swiftinterface を全数確認）。`reminders`
  固有ではないので**ドメインを変えても回避できない**。App Schema は新しい Siri に語彙を渡す仕組みで、
  その Siri が iPhone / iPad / Mac / visionOS にしか無いため（WWDC 2026 Apple Intelligence Group Lab
  `35:34`）。
  `TodoAppIntents` は watchOS でもコンパイルされるため、`CategoryAppEntity`（`.reminders.list`）と
  `TodoListType`（`.reminders.listType`）を `#if os(watchOS)` で素の `AppEntity` / `AppEnum` にフォールバックした。
  **マクロ付き宣言は `#if` で頭（属性＋宣言行）と本体を分割できない**（`Expected '}' in struct` になる）ため、
  型を2系統まるごと書き分ける必要がある。watchOS では Siri / Apple Intelligence のスキーマルーティングを
  使わないので機能損失はない。**iOS destination のビルドや `XcodeRefreshCodeIssuesInFile` では露見せず、
  watchOS を含むフルビルドで初めて出る**（`indexingKey:` の #43 と同じ「複数 destination を回せ」教訓）。

  経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)
- **フォールバック側の型名は本体と変える（`WatchCategoryAppEntity` / `WatchTodoListType`）**。同じ
  型名のエントリが 2 つあると、**アプリの統合 `Metadata.appintents` へのマージで
  「ファイルリストの後ろにある方」が前を丸ごと置き換える**（キーはモジュール名を含まない型名。
  優劣はスキーマの有無ではなく入力順で、Xcode の生成順では watchOS が必ず最後）。iOS アプリは watchOS アプリを
  `IntentTodo.app/Watch/` に埋め込むため、iOS の出荷メタデータから `reminders.ListEntity` /
  `reminders.ListType` が消え、`properties` も 0 件になる。型名を分ければ 2 エントリが共存し、
  スキーマは残る（代償は iOS 側メタデータに `WatchCategoryAppEntity` が 1 件増えること）。
  呼出側は `public typealias CategoryAppEntity = WatchCategoryAppEntity` で共通名のまま。
- **フォールバック側にも `@Property(title:)` を明示する**。スキーマ変種はマクロが `name` / `type` の
  `@Property` を生成してくれるが、素の `AppEntity` は自分で書かないと **プロパティ 0 件の entity**
  になる（渡せるが何も読めない・絞り込めない）。
- 上 2 点はいずれも**コンパイラにもビルド緑にも一切現れない**。パッケージ単体の `.appintents` は
  正常なので、**アプリバンドルの統合メタデータを直接見るまで分からない**:

  ```bash
  python3 skills/app-intents-testing/scripts/inspect_appintents_metadata.py --find IntentTodo
  ```

  「linked package にはあるのにアプリバンドルに無いスキーマ」を error として検出する。**nested な
  バンドル（`IntentTodo.app/Watch/…`）は比較対象から外す**必要がある — iOS の products ディレクトリに
  居ても中身は watchOS ビルドなので、隣の iOS パッケージと比べても意味がない。

  経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)（2026-08-25 の #49）
- **大スキーマ（`.reminders.reminder`）の落とし穴**: スキーマが `dueDate: DateComponents?`（`Date?` と衝突）、
  非 optional `list`、再帰 `subtasks: [Self]`、`images`/`tags`/`urls`/`recurrence`/`section`/`locationTrigger`
  等を要求。さらに **マクロ生成 init は `EntityProperty<T>` 引数**を取り、`section`/`locationTrigger` 等の
  **入れ子サブエンティティを再帰的に要求**する。モデルから組み立てる自前 `init(from:)`（プロパティ順次代入）は
  `self.images used before being initialized` で弾かれ、代入順 / デフォルト / 他マクロ除去では解消しない
  （SDK 27 の「`@State` がマクロ化」初期化規約と同根。`swiftui-whats-new-27` skill 参照）。
  → **自前 `init(from:)` を書かず、マクロ生成 init に値を渡す形にする**。適合の実際の手順と
  守るべきルールは下記「reminder 本体スキーマ適合」。

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
  問い合わせ先の UI が無い呼出元（Live Activity のボタン）には固定間隔の `QuickSnoozeTodoIntent` を使う。
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

- 提供される context は `.audio(.nowPlaying)` / `.audio(.workout(activityType:))`（`AudioContext`。Xcode 27 beta 6 SDK の
  swiftinterface でも `.nowPlaying` のみで、`.workout(activityType:)` は HealthKit 等のオーバーレイ側にも
  まだ見当たらない。`AppEntityContext` のファクトリも `.audio(_:)` 1 つだけ）と、framework overlay（HealthKit 等）が定義する domain context のみ。
  **汎用 / reminders / todo 向けの context 値が存在しない**。
- どちらの context 例でも todo を寄付するのは意味的に誤り（再生中メディア/ワークアウト扱いになる）という結論は変わらない。
- → **本アプリ（reminders ドメイン）では `RelevantEntities` は現状適合不能**。Apple が todo / reminders 向け
  `AppEntityContext` を追加するまで保留。`RelevantIntent` / `RelevantIntentManager`（WidgetConfigurationIntent
  ベースのウィジェット提案）は別軸の API なので、文脈提案が必要なら将来そちらを検討する。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

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
未指定時の値は `.default`（= どのターゲットでも可）で、`IntentExecutionTargets` は `OptionSet, Hashable,
Equatable`（Xcode 27 beta 5 の swiftinterface で確認）なのでテストで等値比較できる。
**`ExecutionTargets` は `EntityQuery` 側にも生えている**（公式: "ExecutionTargets is available on both
`AppIntent` and `EntityQuery`"）。本アプリの entity 解決は読み取りのみなので `TodoEntityQuery` は未指定のまま。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

**方針: SwiftData を書き換える Intent はすべて `[.main]`、読み取り系は未指定（`.default`）。**

セッションが挙げる動機がこのアプリの構成そのものだった（wwdc2026-345 16:30 "My widget shares the data
model with the app — but having two processes write to the same data store can cause conflicts. So I
gave the widget read-only access and the main app handles all the writes."）。共有パッケージが Widget
Extension にもリンクされているため、未指定だと**アプリ未起動時に Extension プロセスが同じストアの書き手に
なり得る**。`docs/insights/05-extensions-and-data-sharing.md` の「アプリ更新直後は Extension が先に起動し
得る」話と同じ危険。

- 固定対象は 13 intent（`TodoService` の変更メソッドを呼ぶもの全部）。`ToggleTodoCompletionIntent` /
  `QuickSnoozeTodoIntent` は iOS では `LiveActivityIntent` 準拠で実質アプリ実行だが、macOS / watchOS には
  その保証が無いので同じく明示する。
- 読み取り系（`ShowTodoCountIntent` / `GetTodoSummaryIntent` / `SearchEverythingIntent` 等）は**あえて固定
  しない**。Extension で応答できたほうがアプリを起こさずに済んで速い。よって `WidgetBundle.init()` の
  `TodoService` 登録は残す（読み取り専用の利用に用途が変わった）。二重登録は撤廃ではなく**役割の分離**。
- 守り方: `Packages/TodoAppIntents/Tests/.../IntentExecutionTargetsTests.swift`。①13 intent の
  `allowedExecutionTargets == [.main]` を個別に assert ②読み取り系が `.default` のままか ③`Intents/` の
  ソースを走査して「`todoService` の変更メソッドを呼ぶのに `allowedExecutionTargets` を宣言していない
  ファイル」を検出（新規 intent の宣言漏れ対策）。③ は probe intent を置いて**実際に落ちることを確認済み**。
- **`allowedExecutionTargets` が制御するのは「どのプロセスが perform するか」だけ**で、entity 解決の有無は
  変えられない。かつて「だから FromExtension 分離は `allowedExecutionTargets` では統合できない」と結論して
  いたが、そもそもの前提（LA からの entity 解決が crash する）が iOS 27 で成立しなくなったため、この論点は
  失効した。FromExtension 分離自体を撤去済み（上記「1 アクション 1 Intent」節）。

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
#if canImport(VisualIntelligence) && !os(visionOS)
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
- **制約**: wwdc2026-297 (11:39) は「`SemanticContentDescriptor` を受ける `IntentValueQuery` はアプリに
  **1 つだけ**」と明言している。本アプリは `TodoVisualIntelligenceQuery` の 1 つのみなので現状は問題ないが、
  将来 2 つ目を追加しようとした場合は不可（`@UnionValue` で戻り値の型を混在させて 1 つの query に集約する、
  が正しい対処）。

### `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`（もっと見る）

visual search の「More results」に対応する intent。`@Parameter var semanticContent: SemanticContentDescriptor`
だけを持つ形をスキーママクロが要求し、`reminders` スキーマのような `EntityProperty` init 地雷は踏まない
（entity プロパティが無いため）。perform でアプリを開きリスト表示。

### canImport ガードと既存要素の再利用

- `VisualIntelligence` 関連ファイルは **`#if canImport(VisualIntelligence) && !os(visionOS)`** で丸ごと
  ガードする。`canImport` だけだと、visionOS **実機** SDK でフレームワークが import 可能になった時点で
  visionOS 非対応の API までコンパイルされて落ちる（シミュレータでは false なので通ってしまう）。
  詳細: [07-platform-specific.md](07-platform-specific.md)「`#if canImport(X)` だけに頼らない」
- **結果タップ → 詳細表示**は Phase 3 の `OpenTodoIntent`（`OpenIntent`）が、**複数結果型**は Phase 4 の
  `@UnionValue`（`TodoOrCategory`）がそのまま流用できる。Visual Intelligence のために新規 entity/型を増やさない。

### macOS 対応（`OpenCategoryIntent`）

- **openable 要件は全プラットフォーム共通**: visual search の `IntentValueQuery` が返す entity は**すべて
  openable（`OpenIntent` を持つ）**必要がある（wwdc2025-275 (9:19) "This `OpenIntent` must exist, otherwise
  your app won't show up"。openable でない entity はそもそも Visual Intelligence の結果に出てこない）。
  ただしコンパイル時エラーとして enforce されるのは **macOS destination のビルドのみ**（iOS シミュレータ /
  iPhone ビルドでは出ない）。`TodoVisualIntelligenceQuery` は `TodoOrCategory` union を返すため、
  `TodoAppEntity`（`OpenTodoIntent`）に加え **`CategoryAppEntity` にも `OpenIntent` が必要**で、無いと Mac
  ビルドで `result type 'CategoryAppEntity' that is not openable ... must be associated with an OpenIntent`
  エラーになる。本プロジェクトの Mac は Catalyst ではなく native macOS（`SUPPORTS_MACCATALYST` 無し・`macosx`
  SDK）。
- **解決**: `OpenCategoryIntent`（`OpenIntent`、`target: CategoryAppEntity`）を新設。カテゴリ専用画面は無いので
  `perform()` は `navigateToRoot()`（アプリを開く）だけ。**openable にすること自体が目的**で、これで union が
  全メンバ openable になり Mac ビルドが通る（AppShortcut 未登録なので 10 件枠に影響なし）。
- **教訓**: 「プラットフォーム限定」は当時の SDK 制約に過ぎない場合がある。SDK 更新時は `#if canImport` ガードを
  外して**本当に不可能か**を実ビルドで確かめる。iOS だけでなく **macOS(My Mac) / visionOS の複数
  destination をフルビルド**して初めて分かる差異がある（`indexingKey` #43 と同じ教訓）。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

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

> **要件**: wwdc2026-295 (2:54) は "AppIntentsTesting requires the test runner and the app to use the same
> development team for code signing" と明言している。テストランナー（UI テストターゲット）とアプリ本体で
> **同じ development team** の code signing でなければ動かない。CI 環境や複数 Apple ID を切り替える環境で
> この設定がずれると原因不明の失敗になりやすいので、テスト追加時は署名チームの一致を最初に確認する。

```swift
import AppIntentsTesting

@MainActor override func setUp() async throws {
    app = XCUIApplication()
    // 起動済みなら activate。毎回 launch() すると再起動が挟まりシミュレータが散発的に落ちる。
    if app.state == .runningForeground || app.state == .runningBackground {
        app.activate()
    } else {
        app.launch()
    }
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
  テストは一意タイトルで作成 → 操作 → 削除の**自己クリーンアップ設計**にしておく。

### 実行して分かった落とし穴（2026-08-12、22 テストを実 run）

- **dynamic member lookup で見えるのは `@Property` だけ**。`AnyAppEntity` の `entity.id` は
  `castingFailed(elementType: "NSNull", targetType: "String")` になる（`TodoAppEntity.id` は
  `@Property` ではないため）。id が要るときは **`entity.identifier.instanceIdentifier`**（型消去側が
  別に持っている）を使う。
- **`setUp` で `app.launch()` を使わない。`app.activate()` にする**。`launch()` は起動中のアプリを
  terminate して再起動するため、テスト数が増えるとシミュレータが `Simulator device failed to launch ...
  did not return a process handle nor launch error` で散発的に落ちる。`activate()` は未起動なら起動、
  起動済みなら前面化するだけ（3 テスト時は顕在化せず、10 テストに増やして毎回どれかが落ちるようになった）。
- **アプリを入れ直した直後は待つ**。クリーンビルド後の最初のテストだけが
  `AppIntentsServicesMetadataErrorDomain Code=400 "<bundle id> is not present"` で落ちる。App Intents の
  メタデータサービスがまだ新しいアプリを認識していないため。`setUp` で軽いクエリ（`suggestedEntities()`）が
  通るまでポーリングしてから本体に入ると解消する。
- **`makeIntent(x: nil)` は `.set(nil)` ではなく `.unset`**（= パラメータを渡さなかった扱い）。
  `IntentParameter.valueState` の「明示クリア」を表現したいときは、`Optional` 自身が
  `IntentValueExpressing` に適合していることを使って**型付きの nil** を渡す:
  ```swift
  let explicitNull: any IntentValueExpressing = String?.none
  try await intent("UpdateTodoIntent").makeIntent(todo: entity, todoDescription: explicitNull).run()
  ```
  これを知らないと「`.set(nil)` が効かない」というアプリ側のバグに見えてしまう（実際に一度そう誤診した）。
- **`IntentValueQuery`（Visual Intelligence）は iOS シミュレータでテストできない**。
  `VisualIntelligence.framework` は iOS 実機 SDK と macOS SDK にはあるが **iOS Simulator SDK には無い**
  （Xcode 27 beta 5 で確認）。`#if canImport(VisualIntelligence)` がシミュレータでは false になり、
  `TodoVisualIntelligenceQuery` 自体がビルドに含まれないため `definitions.valueQueries[...]` で参照できない。
  この観点は実機テストか macOS destination に回すしかない。
- **Spotlight の index は Intent の完了と非同期**。`spotlightQuery()` は `run()` 直後だと空を返しうるので、
  タイムアウト付きでポーリングする。
- **`requestChoice` / `requestConfirmation` を使う Intent は run できない**（応答する相手が居ない）。
  対話しない固定版を別 Intent として持っておくと、そちらはテストできる
  （本プロジェクトの `SnoozeTodoIntent` / `QuickSnoozeTodoIntent`）。

### 検証の梯子（Apple が示す順序）

wwdc2026-240 (24:13–25:57) が「progressive validation」として順序を明示している:

1. **AppIntentsTesting** — ビジネスロジックを分離して検証。"entirely in isolation. **No Siri involved.**"
2. **Shortcuts アプリ** — intent の形（パラメータ / parameter summary）
3. **Spotlight** — コンテンツの index
4. **Siri** — 自然言語・entity 解決・onscreen・cross-app を通した end-to-end

**4 は自動化できない**。wwdc2026-295 (24:46) も "be sure to test your intents **manually** with Siri and
the Shortcuts app" と手動を明示しており、`AppIntentsTesting` の公開 API にも `shortcut` / `phrase` /
`siri` / `utterance` に相当するシンボルは 1 つも無い（swiftinterface 全文検索で 0 件）。
`definitions.intents["..."]` と**型名**で引く設計なので、`AppShortcutsProvider` のフレーズ経路は
構造上通らない。App Shortcut のフレーズが Siri / Spotlight に出るかは手で確かめるしかない。

### AppIntentsTesting に寄せられる検証観点

「ビルドが通る」までしか見ていなかった項目のうち、次はテストで実測できる。手で Siri / Shortcuts を触る
必要があるのは、**App Shortcut のフレーズ routing** と、最終的に**システム UI の見え方**
（dialog の読み上げ、snippet の描画、Control の表示）だけ。

| 観点 | API | 落ちたときの症状（他のテストでは捕まらない） |
|------|-----|------------------------------|
| entity の id 解決 | `entities(identifiers:)` | Live Activity / Widget のボタンが無反応になる |
| `EnumerableEntityQuery` | `allEntities()` | Shortcuts の一覧が空になる |
| 候補提示 | `suggestedEntities()` | パラメータ picker に何も出ない |
| Spotlight index | `spotlightQuery(_:)` | 検索・Siri から消えるだけで他は正常に見える |
| `TransientAppEntity` | `intents["..."].run()` の `result.value.<prop>` | Shortcuts の条件分岐が壊れる |
| ValueRepresentation | `AnyAppEntity.exported(as:)` | 他アプリへの受け渡しが壊れる |
| Onscreen entity | `viewAnnotations()` | Siri が画面上の対象を認識しなくなる |
| 部分更新の三状態 | `valueState`（型付き nil で `.set(nil)`） | Shortcuts で項目を消せなくなる |
| ナビゲーション | Intent 実行 → `XCUIApplication` で画面を確認 | 「アプリが開くだけ」になる |
| `IntentValueQuery` | `valueQueries["..."].values(for:)` | Visual Intelligence の結果が出なくなる（**iOS シミュレータ不可**、下記参照） |

### ファイル追加とテストの分割

`IntentTodoUITest` は現在 `PBXFileSystemSynchronizedRootGroup`（synchronized folder）なので、
**ファイルを置けばそのままターゲットに入る**。サブフォルダも同様（本プロジェクトは
`IntentTodoUITest/AppIntents/` 配下に分割: 共通基底 `AppIntentsTestCase` + 実行 / query /
システム統合の 3 ファイル）。`@MainActor override func setUp() async` にしないと
`XCUIApplication` の MainActor 隔離で Swift 6 エラーになる。

> 以前ここには「synchronized folder ではないのでファイルを置くだけでは target に入らない」と
> 書いていたが、現在の `project.pbxproj` では synchronized になっている（2026-08-12 に確認）。

## Phase 7: WWDC 2026 追加検証（#43–#48）

> issue #42–#48（WWDC 2026 セッション 240 / 343 / 344 / 345 起票）を `xcode27` で実装。すべて B 深度
> （iOS / visionOS / watchOS の 3 スキームで `BuildProject` グリーン）。R 深度（実機 Siri / Spotlight）は手動。

### `@Property(indexingKey:)`（セマンティック Spotlight、#240 / #43）

`@Property(title:indexingKey:)` の `indexingKey` は `PartialKeyPath<CSSearchableItemAttributeSet>`。プロパティ値を
Spotlight のセマンティックインデックスのキーへ宣言的にマップし、意味ベース検索 / Q&A の対象にできる。

- `TodoAppEntity.title` → `\.title`、新設 `todoDescription` → `\.contentDescription`。
- `textContent` は `CSSearchableItemAttributeSet_Messaging.h` に `NSString *textContent`（macOS 10.11 / iOS 9〜、
  tvOS・watchOS 対象外）として存在する（wwdc2026-240 のコード例、wwdc2024-10131 2:41 が言及）。`EntityProperty.init(indexingKey:)`
  は `PartialKeyPath<CSSearchableItemAttributeSet>` を取るだけでローカルプロパティの型とキーパスの値型を静的に対応付けない
  ため、`String?` でも `AttributedString?` でも同一の `indexingKey:` オーバーロードが使える（SDK の `swiftinterface` 上、
  `Value.ValueType == String` と `Value.ValueType == AttributedString` の両方に同シグネチャの `indexingKey:` init 群がある
  ことを実ビルドで確認済み）。
  それでも `todoDescription` は `contentDescription`（`CSDocuments` カテゴリ、「アイテムの説明文」の意味）にマップするのが
  妥当。`textContent`（`CSMessaging` カテゴリ、メール/メッセージ本文全文を想定した意味）よりも Todo の詳細説明という
  ユースケースに近いため——これは型の制約ではなく意味の制約による選択。
- **落とし穴（プラットフォーム）**: `indexingKey:` オーバーロードは **watchOS / tvOS で unavailable**
  （Xcode 27 beta 6 の SDK は `@available(watchOS, unavailable)` / `@available(tvOS, unavailable)`。
  `IndexedEntity` は `macOS 15 / iOS 18 / visionOS 2`、`IndexedEntityQuery` は 27 世代の 3 OS）。
  watchOS では `Extra argument 'indexingKey'` + `Cannot infer key path type` でビルド失敗するため、
  `IndexedEntity` 拡張と同じ `#if os(iOS) || os(macOS) || os(visionOS)` で分岐し、watchOS は素の `@Property`
  にフォールバックする。**`XcodeRefreshCodeIssuesInFile`（iOS コンテキスト）は通っても、別プラットフォーム
  destination の `BuildProject` で初めて露見する**ので、entity 系の変更は必ずフルビルドで複数 destination を回す。
  経緯: [docs/devlog/2026-08-28-xcode27-beta6-recheck.md](../devlog/2026-08-28-xcode27-beta6-recheck.md)（visionOS を
  除外していた記述をビルドで確かめ直した件）
- 既存の手書き `attributeSet`（キーワード index）とは併存可。indexingKey はセマンティック経路を足すもの。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

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
  - **`ValueRepresentation` も entity の `@Property` も SSU バグを踏まない**。踏むのは system value 型を
    **App Shortcut に登録した Intent の `@Parameter`** に置いたときだけ（`PlaceDescriptor` / `LinkMetadata` /
    `AudioSearch` / `PHAsset` の 4 型で実測）。SSU アセットが丸ごと出なくなり、ローカルは
    `BUILD SUCCEEDED` のまま。`TodoAppEntity.location` は `PlaceDescriptor?` で持つ（出荷メタデータには
    `GeoToolbox.PlaceDescriptorEntity` が入るが SSU は通る）。`AddTodoIntent.location` だけ `String` 退避。
    ルールは [AGENTS.md](../../AGENTS.md#触る前に知っておくルール) の 8 番、
    実測値は [devlog 2026-08-28](../devlog/2026-08-28-ssu-system-value-type-bug.md) /
    [2026-08-29](../devlog/2026-08-29-entity-placedescriptor-restore.md)。Apple 報告済み（FB24548956 / #57）。

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
  `ControlNotificationHelper.sendErrorNotification` の `todoId` に配線（当初は Control の成功通知に付けていたが、成功通知自体を
  廃止したためエラー通知へ移動。経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)）。

### `.system.searchInApp`（in-app 検索スキーマ、#343 / #47）

`@AppIntent(schema: .system.searchInApp)` + `ShowInAppSearchResultsIntent` で、Siri / Apple Intelligence が検索語を
**アプリ自身の検索 UI** に流して結果を出せる（`ShowInAppSearchResultsIntent` 自体は iOS 16 からの型で、スキーママクロ形が新）。
`.system.search` は deprecated（`'search' is deprecated: Use .system.searchInApp instead`）のため、常に
`.system.searchInApp` を使う。

経緯: [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

- 形: `static let searchScopes: [StringSearchScope] = [.general]` + `var criteria: StringSearchCriteria`（マクロが
  `@Parameter` を注入、`criteria.term` で検索語）。`title` / `supportedModes` はスキーマが供給。
- **ナビゲーション**: `@Dependency var navigationModel` に検索語を書く設計。`NavigationModel.pendingSearchText` を新設し、
  `TodoListView` が `.onChange` / `.onAppear` で `viewModel.searchText` に転写してから nil に戻す（cold-start 安全な
  `@Dependency` ナビ方式と同系統）。
- **`SearchEverythingIntent` とは別物**: あちらは `@UnionValue` の `[TodoOrCategory]` を **返す** value 検索。
  こちらは検索 UI へ **遷移** する。スキーマの意味（"take the person to search results"）が異なるため統合せず別 Intent にした。
- 低優先項目（#47）: `OwnershipProvidingEntity`（shared/public/private の出し分け）/ `$param.requestValue`（perform 途中の聞き返し）
  は個人利用主体では優先度低として **未採用**（必要時に追加）。
- **落とし穴（watchOS 非対応）**: `.system` ドメインも他の 22 ドメインと同様 **watchOS で unavailable**
  （`'system' is unavailable in watchOS` / `'search' is unavailable in watchOS`）。watch アプリには検索遷移先の UI が
  無いため、`ShowTodoSearchResultsIntent` は `#if !os(watchOS)` で丸ごと除外した（`NavigationModel` / `TodoListView`
  からの参照はコメントのみで実害なし）。`.visualIntelligence.*`（#297）は
  `#if canImport(VisualIntelligence) && !os(visionOS)` ガードなので watchOS（フレームワーク非存在）には来ない。macOS には import 可能（`OpenCategoryIntent` 追加、上記
  「macOS 対応」節参照）。

### reminder 本体スキーマ適合（#56、2026-08-29 に適合済み）

`TodoAppEntity` は `@AppEntity(schema: .reminders.reminder)` マクロで適合し、**watchOS には
スキーマ無しの別型 `WatchTodoAppEntity` を置く**（`typealias` で呼出名は共通）。

守るべきルール:

- **親のスキーマ適合はサブエンティティの適合も要求する**。`list` / `locationTrigger` の型が
  スキーマ無しだと `Property 'list' type does not match required AppSchemaEntity property type
  'ListEntity'` で落ちる。つまり適合は `list` / `listType` / `locationTrigger` /
  `locationTriggerEvent` を含む**サブグラフ全体**に及ぶ。**watchOS 側にはこのサブグラフごと
  持たせない**（スキーマが無いので要求も無い）
- **`__appSchemaEntity` / `__appSchemaEnum` を手書きしない**。これは `AssistantSchemaEntity` の
  プロトコル要求ですらなく（プロトコル本体は空）、マクロとメタデータ抽出器の間の**非公開の
  申し合わせ**。Apple のガイダンスもアンダースコア始まりのシンボル使用を禁じている。
  スキーマという機能が無いプラットフォームに `reminders.ReminderEntity` を主張するメタデータを
  出すことにもなる。2026-08-29 に一度採ったが撤去した
- **公開 API での抜け道は無い**。`AppSchema.Entity("ListEntity")` を自前で組めれば済むが、
  `init(_:)` は `@usableFromInline internal`
- **適合を `#if` で切って型名を共有してはいけない**。同じ型名のエントリが 2 つ居ると、iOS アプリの
  統合メタデータへの merge で**後の入力（= 常に watchOS スライス）が前を丸ごと置き換える**。
  スキーマだけでなくプロパティも落ちる（`TodoAppEntity` は 20 → 10）。#49 と同じ衝突を
  2026-08-29 に 2 度実測し、2026-08-30 に処理器を直接叩いて順序依存まで確認した
  （Apple 報告済み: FB24570185 / #57）。**型名を分ける**のが正
- **`Transferable` / `URLRepresentableEntity` は具象型名で宣言する**。const 抽出（swiftconstvalues）で
  読まれるため `typealias` 越しの extension だと watchOS スライスで
  `The property 'transferRepresentation' must be static, have a compile-time constant value, and
  cannot be computed or dynamic` になる
- スキーマ要求名（`note` / `creationDate` / `isFlagged` / `list`）は `@ComputedProperty` の
  別名で満たせるので、アプリ側の既存名はリネームしない。`dueDate` だけは型が衝突するので
  stored を `dueDateValue: Date?` にして `dueDate` を `DateComponents?` の computed にした
- `list` は非 optional 要求。未分類 todo には合成の `CategoryAppEntity.uncategorized` を見せる
- **配列属性（`tags` / `urls`）は `@DeferredProperty` で id から引き直す**。`@Property` にして
  `init(from:)` で読むと、削除直後の再描画で SwiftData が trap する（削除済みオブジェクトの
  配列属性は読めない。scalar は耐える）。`!isDeleted` のガードでは防げない。スキーマ要求は
  deferred でも満たせる
- **同じ理由で `@Model` の配列属性は SwiftUI の `body` からも読まない**。`@Query` の結果は削除直後の
  1 フレームだけ削除済みオブジェクトを含みうるので、`if !todo.tags.isEmpty` と書くだけで詳細画面が
  クラッシュする（entity 側で 1 回直しても、新しく読む場所を作るたびに再発する）。表示は
  `@State` のスナップショットに写し、`.task(id: todo.modifiedAt)`（`modifiedAt` は scalar なので
  削除済みでも読める）で entity の `@DeferredProperty` 経由 = id から引き直して更新する。
  シートに渡すときも値渡し（content クロージャは提示中に再評価されうる）
- **`Calendar.RecurrenceRule` は SwiftData 属性にできない**（コンパイルは通るが schema 初期化で
  trap する）。`TodoRecurrence` で primitive（frequency + interval）から組み立てる
- 判定は `inspect_appintents_metadata.py`。メタデータは `{"domain": "reminders", "name":
  "ReminderEntity"}` の形なので `grep reminders.ReminderEntity` では見つからない

経緯: [docs/devlog/2026-08-29-reminder-schema-conformance.md](../devlog/2026-08-29-reminder-schema-conformance.md)

### 新 Siri 連携は本体スキーマ適合なしでも成立する（適合は上乗せ）

適合済み（上節）だが、**適合が無くても意味理解・検索・遷移は機能する**という切り分けは今も有効。
`CategoryAppEntity` の `.reminders.list` 適合 + discoverable な自前 Intent 群（Add / Update / Toggle /
Show / `.system.searchInApp`）+ `OpenIntent` / `DeleteIntent` + `IndexedEntity` のセマンティック index が
その足場になる。App Schema は**新しい agentic Siri への入場券**で、既存の経路を格下げするものではない
（wwdc2026-8011 `3:09` / `21:47`）。スキーマを持てないプラットフォーム（watchOS）で機能が落ちないのも
この構造のため。

> 適合を「据え置く」と判断していた時期があり、その根拠（生成 init が `EntityProperty<T>` 引数 +
> 入れ子再帰を要求する / `locationTrigger.place` が SSU バグを踏むという誤読）と、それがどう覆ったかは
> [docs/devlog/2026-08-29-reminder-schema-cost-remeasure.md](../devlog/2026-08-29-reminder-schema-cost-remeasure.md) にある。

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

---

## Phase 9: 公式サンプル 4 本との突き合わせ（WWDC26）

WWDC26 の App Intents 系サンプルを取り込んで、本プロジェクトの書き方と 1 項目ずつ突き合わせた結果。
サンプルは `~/Developer/Private/wwdc26-app-intents-samples/`（リポジトリ外）に展開してある。
**`docs/references/` の下に置いてはいけない**: Xcode の同期グループがサンプルの `.xcodeproj` を
拾い、追跡下の `project.pbxproj` に project reference として書き込んでしまう（gitignore は効かない）。
取得元:

| サンプル | アプリ名 | ドキュメント |
|---------|---------|------------|
| calendar | CometCal | `/documentation/appintents/integrating-your-calendar-app-with-apple-intelligence` |
| messaging | UnicornChat | `/documentation/appintents/integrating-your-messaging-app-with-apple-intelligence` |
| music | CosmoTunes | `/documentation/appintents/integrating-your-music-app-with-apple-intelligence` |
| photo | PhotosDomainExample | `/documentation/appintents/integrating-your-photo-app-with-apple-intelligence` |

zip の実 URL は各ページの JSON (`https://developer.apple.com/tutorials/data<path>.json` の
`sampleCodeDownload.action.identifier`) から `https://docs-assets.developer.apple.com/published/<id>` で引ける。

> セッション対応: 240（App Schemas / UnicornChat）、295（AppIntentsTesting / CometCal）、
> 343（CosmoTunes + UnicornChat + CometCal）、344（Code-along / CometCal）。

### 実行時の文字列は `"\(value)"` の補間で渡す（`LocalizedStringResource(stringLiteral:)` は使わない）

`DisplayRepresentation(title:)` などが取るのは `LocalizedStringResource`。ここに
`LocalizedStringResource(stringLiteral: todo.title)` を渡すと、**ランタイム文字列がそのまま
ローカライズキーになる**。翻訳テーブルに存在しないキーの引きが毎回走り、String Catalog の
抽出対象にもならない（キーが実行時に決まるため）。サンプル 4 本はすべて補間形式。

```swift
// ❌ ランタイム値をキーにしている
DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))

// ✅ 補間形式（キーは "%@"、title は引数として渡る）
DisplayRepresentation(title: "\(title)")
```

同じ理由で、**表示すべき subtitle が無いときは空文字ではなく `nil`** を返す
（`subtitle: LocalizedStringResource?`）。空の `LocalizedStringResource("")` は空キーの引きになる。

### Siri は entity の subtitle を読み上げる → 位置指定の書式を避ける

CosmoTunes の `TimerEntity` / `AlarmEntity` が明記している通り、`DisplayRepresentation` の
subtitle は音声で読まれる。`"5:00"` のような位置指定表記は「ご、コロン、ぜろ、ぜろ」と読まれるため、
`Duration.formatted(.units(width: .wide))` や `Date.FormatStyle` の自然文表記を使う。

```swift
// CosmoTunes/AppIntents/Clock/Timers/Entities/TimerEntity.swift より
duration.formatted(.units(allowed: [.minutes, .seconds], width: .wide))  // "5 minutes"
date.formatted(.dateTime.hour().minute())                                 // "7:30 AM"（ロケール依存）
```

本アプリの `TodoAppEntity.subtitle` は `dueDate.formatted(date: .abbreviated, time: .omitted)` で
すでに自然文なので条件は満たしている。**今後 subtitle に時刻を足すときはこの制約を思い出すこと**。

### donation は「アプリ UI 起点の操作」だけ。`perform()` の中では donate しない

公式 (Donations and discovery): *"Restrict your donations to direct interactions with your app's
interface, and **not to interactions started by Siri or the Shortcuts app**."*
CosmoTunes の `DonationManager` も同じことを書いている（*"Avoid issuing donations from inside an
intent's `perform()`, because the framework already donates intents invoked through Siri or
Shortcuts."*）。

`perform()` は呼出元を判別できない（`IntentSystemContext` が持つのは `currentMode` と
`isVoiceOnly` だけ。invocation source の API は無い）。したがって `perform()` 内の donate は
**必ず Siri / Shortcuts 経由でも走る = 規約違反になる**。

サンプルが取っている形は 2 通り:

1. **サービス層に `donateIntent:` フラグ**（CometCal）: `CalendarManager.createEvent(..., donateIntent: true)`
   が既定で donate し、Intent 側は `donateIntent: false` を明示して抜ける。UI が Intent を通らず
   サービスを直接呼ぶ設計でのみ成立する。
2. **UI タップ地点から専用マネージャ経由で donate**（CosmoTunes `DonationManager`）。
   `IntentDonationManager.shared.donate(intent:)` / `donate(intent:result:)` を呼ぶ薄いラッパ。

**本アプリは UI も `Button(intent:)` で同じ Intent を走らせる設計**なので、上のどちらも
そのままでは当てはまらない（サービス層に届く時点で常に Intent 経由）。現状は
「規約違反になる donate を消す」を優先して `perform()` 内の donate を撤去した。UI タップ分を
donate し直したい場合の選択肢は `AppIntent.callAsFunction(donate:)`
（"Runs the intent's action after resolving any parameters, and optionally donates the intent"）で
一部の UI 経路だけ `Button(intent:)` から直接実行へ切り替える形。未着手候補として
`docs/APP_INTENTS_CENTRIC_PLAN.md` に置いてある。

**却下した 3 案目: Intent に「呼出元フラグ」を持たせる形**（`shouldDonate` のような専用プロパティを
UI 側で立てて `perform()` 内の donate を切り替える）は成立しない。理由は 2 つとも機械的:

- **素のプロパティは実行側プロセスに届かない**。Intent のシリアライズ面は `@Parameter` だけで、
  システムは実行プロセスで `init()` してからパラメータを流し込む。Widget / Control のように
  別プロセスで走る経路では必ずデフォルト値に戻る。アプリ内 `Button(intent:)` では運ばれうるため
  **「アプリ内だけ通って他の呼出元で静かに落ちる」**という一番たちの悪い形になる
- **`@Parameter` にすると Siri / Shortcuts から立てられる**。`ParameterSummary` から外せば
  Shortcuts エディタには出ないが（`parameters.md`: 「summary に無いパラメータはエディタに出ないだけで
  存在し解決もされる」）、統合メタデータには残るのでモデルが値を埋められる。**避けたかった
  「Siri 起点の donate」がむしろ起こる**。加えて保存済みショートカットはパラメータ込みで replay
  されるため、後から消せない契約になる

そもそも Apple のガイダンスは「呼出元で分岐せよ」ではなく **「`perform()` の中では donate するな」**
（システムは自分が走らせた Intent を既に donate しているので二重計上になる）。フラグをどこに置くかの
問題ではなく、置き場所が `perform()` ではないという話。donate する層は「呼出元を知っている層」＝UI で、
タイミングは**操作が成功した後**。

もう 1 つのコストとして、donation には観測用の公開 API が無い（`deleteDonations` はあるが列挙は無い）。
**AppIntentsTesting で押さえられない**ので、「効いているか確認できないコードを Intent の公開スキーマに
足す」形になる。これも未着手のまま置いている理由の一部。

### そもそも `Button(intent:)` の実行はシステムが donation として記録している

**アプリ内 UI の操作が全部 `Button(intent:)` である限り、donate すべきものが残らない。**
本アプリは `donate()` をどこからも呼んでいないが、`Button(intent:)` のタップは
`IntelligenceEngine.Interaction.Donation` に記録される（2026-08-30 に iOS 27 シミュレータで実測）。

公式サンプル 4 本が明示 donate を必要とするのは、UI が Manager を直接呼んでいて
（`Button(` 94 件のうち `Button(intent:)` は **0 件**）その実行がシステムに見えないから。
wwdc2026-343 `6:33` の *"Apple Intelligence can't learn from actions people take through your app's
UI without your help"* は **UI の操作が intent の実行になっていない**アプリの話で、前提が違う。

- 別プロセス（Widget / Control）起点が記録されるかは**未確定**（#98）
- 「ストリームに載る」＝「学習に使われる」とまでは公式に書かれていない（ストリーム名と
  wwdc2026-343 `6:22–9:46` の一致からの推定）
- 観測は `skills/app-intents-testing/scripts/inspect_donation_stream.py`。**非公開パスなので
  検証専用**で、出荷コードから依存しない。判定の落とし穴（mtime を信じない / `+0` を見たら待つ）は
  スクリプトの docstring にある

経緯: [docs/devlog/2026-08-30-donation-observability.md](../devlog/2026-08-30-donation-observability.md)

一方 **`deleteDonations(matching:)` は呼出元に関係なく正しい**（消えた entity への提案を残さない
後片付け）。CosmoTunes も `EntityIdentifier(for:identifier:)` を集めて
`deleteDonations(matching: .entityIdentifiers(...))` を呼ぶ形で、削除経路に必ず入れている。
本アプリの delete 系 3 Intent は既にこの形。

### URL 表現は `URLRepresentableEntity` に寄せ、綴りの重複はテストで縛る

`TodoAppEntity: URLRepresentableEntity` を宣言すると `intenttodo://todo/<id>` が entity の
URL 表現になり、`OpenTodoIntent` は `URLRepresentableIntent` を**無償で満たす**
（SDK に `URLRepresentableIntent where Self: OpenIntent, Value: URLRepresentableEntity` の
extension があり `urlRepresentation` を組み立ててくれる）。結果、ウィジェットの `Link` /
Siri / Shortcuts / Spotlight が同じ宛先を指す。

注意点が 2 つ。

- **`urlRepresentation` は DSL リテラル**（`"intenttodo://todo/\(.id)"`）で、関数を呼べない。
  URL を組む / 読む側の実装（`TodoDeepLink`）とは**同じ形を 2 回書く**ことになる。両者の一致は
  `TodoDeepLinkTests` の「entity の URL 表現は TodoDeepLink と同じ URL になる」で縛る
  （インスタンス側の `urlRepresentation` は `async` なので `await` して比較する）
- **URL の綴りをターゲットごとに散らさない**。作る側（ウィジェット、entity）と読む側
  （アプリの `onOpenURL`）が別ターゲットなので、文字列を各所に置くとビルドでは検出できず
  「ウィジェットをタップしても何も起きない」という形でしか出ない。`TodoDeepLink` に集約する

「アプリを開くだけ」の行タップは `Button(intent:)` ではなく `Link(destination:)`
（公式: *"If you want to offer an interaction that opens the app, use `Link`"*）。ウィジェットの
Todo 行はこの形で該当 Todo の詳細に飛ぶ。

### Focus filter（`SetFocusFilterIntent`）は「実行先を選べない Intent」

集中モードごとの絞り込みは `TodoFocusFilterIntent` が受ける。設定 > 集中モード に現れ、
Focus の切り替わりでシステムが `perform()` を呼ぶ。他の Intent と違う点が 4 つある。

- **`allowedExecutionTargets` を宣言しない**。実行先は Focus の仕組みが決める（アプリが動いて
  いればアプリ、そうでなければ AppIntents Extension。wwdc2022-10121 9:29）。本プロジェクトの
  「書き込み系は `[.main]`」ルールはここには適用しない — 固定しても意味がなく、将来 Extension を
  足したときに噛み合わなくなる
- **AppIntents Extension が無い＝アプリ未起動中の遷移は取りこぼす**。埋め合わせは
  `SetFocusFilterIntent.current`（wwdc2022-10121 11:47）で、起動時とフォアグラウンド復帰時に
  `TodoFocusFilterStore.syncFromSystem()` が現在値を取り直す。Focus filter 未設定なら throw
  するので、その場合は `.inactive` に倒す
- **`notificationFilterPredicate` に一致しない通知は黙らされる**（wwdc2022-10121 13:15）。
  照合相手は `UNMutableNotificationContent.filterCriteria`。**criteria を付けていない通知は
  述語を返した瞬間に全部消える**ので、アプリ自身の失敗通知（`ControlNotificationHelper`）には
  `TodoFocusFilter.systemNotificationCriteria` を付け、許可リストに常に含める。コントロールの
  失敗通知が消えると「何も起きなかった」と区別できなくなる
- **絞り込みの判定は 1 か所に集約する**。読み手はリスト UI（アプリプロセス）とウィジェット
  （別プロセス）の 2 つで、後者には App Group の UserDefaults 経由で設定だけを渡し、
  「どの Todo を残すか」は共通の `TodoFocusFilter.apply(to:now:)` を通す。ウィジェットの件数表示も
  絞り込み後の母数で数える（絞った一覧に全体件数を出すと「表示 0 件なのに未完了 5 件」になる）

UI 側では**絞り込み中であることの表示と、その場での解除手段**をセットで出す（標準のカレンダーが
同じ形。wwdc2022-10121 2:04）。表示だけだと、絞られていることに気づいたユーザーが設定アプリまで
行くしかない。解除は永続化しない（次の Focus 遷移で畳む）。

`displayRepresentation` は設定済みの内容を動的に反映する（wwdc2022-10121 8:07）。ここもランタイム
文字列は `"\(value)"` の補間形式で渡す（上の「Entity の表示表現」と同じ理由）。

### `attributeSet` と `@Property(indexingKey:)` で同じ Spotlight キーを二重に埋めない

`indexingKey:` はプロパティを `CSSearchableItemAttributeSet` のキーへマップする。同じキーを
`IndexedEntity.attributeSet` 側でも埋めた場合、どちらが勝つかは公式に定義されていない。
本アプリは `todoDescription → \.contentDescription` をマップしているのに `attributeSet` で
`contentDescription = "Completed" / "Incomplete"` を上書きしていたため、**セマンティック検索に
載せたかった本文が固定文に置き換わりうる**状態だった（2026-08-21 に撤去。完了状態は `keywords` で表現）。

`attributeSet` には **`indexingKey:` で表現できない属性だけ**を書く（`dueDate`、`keywords` など）。
`displayName` は Spotlight 結果セルの表示名で `.title` とは別キーなので衝突しない。

### 文字列の突き合わせは**すべて** `localizedStandardContains(_:)`

`EntityStringQuery.entities(matching:)` は**システムが絞り込んでくれない**（自分でフィルタする）。
その比較に `lowercased().contains()` を使うとロケール非依存になり、かな/カナ、ダイアクリティカル
マーク、トルコ語の I などを別物として扱う。サンプルは `localizedCaseInsensitiveContains`、
本プロジェクトのユーザー全体ルールは `localizedStandardContains` を指定している。

**適用先は `EntityStringQuery` に限らない**。「人が読む文字列同士を突き合わせる」場所はすべて同じ:

| 場所 | 突き合わせるもの |
|---|---|
| `TodoEntityQuery` / `CategoryEntityQuery` | Siri / Shortcuts が渡す文字列 ↔ タイトル・カテゴリ名 |
| `SearchEverythingIntent` | `query` パラメータ ↔ タイトル・カテゴリ名 |
| `TodoVisualIntelligenceQuery` | `SemanticContentDescriptor.labels` ↔ タイトル・カテゴリ名 |
| `TodoListViewModel`（UI の検索フィールド） | 入力文字列 ↔ タイトル |

Visual Intelligence のラベルは英語主体だが、**突き合わせ先の Todo は日本語などになる**ので
例外にしない。`localizedStandardContains` は自前の小文字化を不要にするため、
`labels.map { $0.lowercased() }` のような前処理も消せる。

### `DisplayRepresentation` の `synonyms:` と画像の遅延クロージャ

CosmoTunes は entity ごとに `synonyms:` を付けて Siri のマッチ幅を広げ、画像は**トレーリング
クロージャ形**で渡して「テキストだけ必要な文脈では画像を解決させない」ようにしている。

```swift
DisplayRepresentation(
    title: "\(title)",
    subtitle: "^[\(trackCount) track](inflect: true)",
    synonyms: ["\(title) mix tape", "\(title) playlist"]
) {
    DisplayRepresentation.Image(systemName: "music.note.list")
}
```

複数形は `^[\(n) track](inflect: true)` で inflection を効かせる。

本アプリの適用先: `TodoAppEntity` / `CategoryAppEntity` / `SubTaskAppEntity` の 3 つとも
`synonyms:` + 遅延クロージャ形。`TodoListSummaryEntity` は `^[\(n) todo](inflect: true)`。
組み立ては **`makeDisplayRepresentation(...)` という static 関数**に寄せてある（後述の
`displayRepresentations(for:)` が entity を作らずに同じ表現を返せるようにするため）。

### `EntityQuery.displayRepresentations(for:)`（バッチ）

公式: *"Return full representations; the system materializes only the components it needs (for
example, dropping a deferred image when only text is required)."* 候補一覧の描画で entity 本体を
N 回組み立てるコストを避けるための口。

本アプリは `TodoEntityQuery` / `CategoryEntityQuery` / `SubTaskEntityQuery` の 3 つに実装。いずれも
**SwiftData のモデルから直接 `makeDisplayRepresentation(...)` を呼ぶ**（`TodoAppEntity(from:)` を
通さない）。todo では、表示に使わない `CategoryAppEntity` の生成がまるごと落ちるのが効き目。
`@available(anyAppleOS 27.0, *)` の要件なので、26 世代へ戻すなら `#available` が要る。

### `EnumerableEntityQuery.findIntentDescription`

Shortcuts が自動生成する "Find X" アクションの説明・カテゴリ・`resultValueName` を指定できる。
未指定だと説明なしのアクションとして並ぶ。`TodoEntityQuery` / `CategoryEntityQuery` の両方に指定済み
（`SubTaskEntityQuery` は `EnumerableEntityQuery` 非準拠なので対象外）。

### `UndoableIntent`

CosmoTunes `DeleteAlarmIntent` が実装形を示している。要点は **snapshot を取る順序**と
**同じ id で復元する**こと（Spotlight / AlarmKit の identity を保つため）。

```swift
@AppIntent(schema: .clock.deleteAlarm)
struct DeleteAlarmIntent: UndoableIntent {
    var entities: [AlarmEntity]
    @Dependency var model: ModelManager

    @MainActor
    func perform() async throws -> some IntentResult {
        // 1. 消す前に snapshot（同じ id で戻せるように）
        let snapshots = try entities.compactMap { try model.snapshotAlarm(id: $0.id) }
        for alarm in entities { try model.deleteAlarm(alarm.id) }

        // 2. undo ハンドラ登録
        undoManager?.registerUndo(withTarget: model) { manager in
            Task { @MainActor in snapshots.forEach { try? manager.restoreAlarm($0) } }
        }
        // 3. 取り消しメニューに出る名前（inflection 付き）
        undoManager?.setActionName(String(localized: "Delete ^[\(entities.count) Alarm](inflect: true)"))
        return .result()
    }
}
```

本アプリの形（`TodoUndoRegistrar` に登録処理を集約）と、そこで分かった注意点:

- **`UndoManager.registerUndo(withTarget:handler:)` はハンドラごと `@MainActor`**（Foundation の
  swiftinterface で `handler: @escaping @MainActor (TargetType) -> Void`）。`Task { @MainActor in }` で
  ホップする必要はなく、`TodoService` をそのまま呼べる
- **`undoManager` は呼出元が用意しなければ `nil`**。ウィジェットの `Button(intent:)` などでは登録が
  丸ごと no-op になる。これは失敗ではなく想定どおりの分岐なので、`guard let` で静かに抜ける
- **完了トグルの undo は「逆トグル」ではなく「元の値へ `setCompletion`」**。undo するまでの間に別経路
  （Siri / ウィジェット / 別デバイスの CloudKit マージ）で状態が変わっていると、トグルは意図と逆へ倒れる
- **復元は idempotent にする**。`TodoService.restore(_:)` は同じ id の todo が既にあればそれを返すだけ。
  二重 undo や CloudKit が先に戻したケースで、同じ id の重複を作らない
- 削除は `SubTask` を cascade で連れていくので、snapshot にサブタスクも入れて**サブタスクの id も保つ**。
  カテゴリはリレーションを値で持ち越せないので `categoryID` だけ持ち、復元時に引き直す。カテゴリ自体が
  消えていたら関連を落として復元する（カテゴリの不在で todo が戻らないほうが困る）
- `TodoItem` / `SubTask` に **id を受け取る init を別途生やす**。通常の `init(title:)` に id を足すと、
  普通の作成経路が既存 todo と衝突しうる形になる

### Siri に読ませるエラー文言は `CustomAppIntentErrorConvertible` で決める

CosmoTunes はドメインエラー enum に `CustomLocalizedStringResourceConvertible` を付けて Siri が
読める文言を与え、throw の直前に `AppIntentError(wrapping:)` で包む。

本アプリは 1 段上の `CustomAppIntentErrorConvertible`（`var appIntentError: AppIntentError`）を
`IntentError` に付けている。理由と注意点:

- **throw 側で `AppIntentError(wrapping:)` を呼ぶ必要がない**。公式: *"When you throw a conforming
  error from a method such as `perform()` […] the framework reads the `appIntentError` property and
  uses it directly."* `TodoService` は AppIntents を import せずに `IntentError` を投げるだけでよい
- `errorDescription`（"Validation error: …" のような開発者向けプレフィックス付き）と、Siri が読む文言を
  **別々に決められる**。前者を読み上げさせない
- `.notFound` は `AppIntentError(predefinedError: .Unrecoverable.entityNotFound, description:)` に載せる。
  文言だけでなく「参照先の entity が無い」種別がシステムに伝わる
- **`init(predefinedError:description:)` は受け付けない値を渡すと実行時に `fatalError()`**（公式明記）。
  ビルドでは検出できないので、全ケースを 1 度組み立てるテストを置く（`IntentErrorTests`）
- 両方（`CustomLocalizedStringResourceConvertible` と `CustomAppIntentErrorConvertible`）に準拠した場合、
  システムは後者だけを見る

### `AppShortcutsProvider.shortcutTileColor`

Shortcuts アプリに並ぶタイルの背景色。未指定だと既定色。本アプリは `.teal`。

### Onscreen annotation: `forSelectionType:` は `List` に付けたときだけ効く

CosmoTunes `TimerView` のコメントが明言している:
*"The collection-form `.appEntityIdentifier(forSelectionType:)` is only honored when applied to a
`List`"*。`ScrollView { VStack { ForEach } }` では効かないので、**行ごとの単一 annotation**
（`.appEntityIdentifier(EntityIdentifier(for:identifier:))`）に落とす。

`Canvas` などビュー階層から bounds を推測できない描画は `.appEntityUIElements { context in ... }`
で `AppEntityUIElement(identifier:bounds:state:)` を明示的に返す。

本アプリの `TodoListView`（iOS / macOS）と `VisionOSTodoListView`（visionOS）はどちらも
`List(selection:)` + `.tag(todo)` なので `forSelectionType:` がそのまま効く形。

**watchOS は行ごとの単一 annotation に落とす**（2026-08-27）。`WatchTodoListView` も `List` だが
**selection を持たない**（行が `Button(intent:)` で、タップは完了トグル）。`forSelectionType:` は
selection 値の型を手がかりにする仕組みなので、当て先が無い。`WatchTodoRow` / `WatchTodoDetailView`
に `.appEntityIdentifier(EntityIdentifier(for: entity))` を 1 つずつ付ける形にした
（`.appEntityIdentifier` 自体は watchOS 11.4+ で使える）。

詳細画面側で iOS は `.userActivity` に `appEntityIdentifier` を載せているが、watchOS では
単一 annotation の modifier を使う。こちらは `Info.plist` の `NSUserActivityTypes` 宣言が要らない
（watch アプリは `GENERATE_INFOPLIST_FILE = YES` で plist 実体を持たない）。

### テスト: `viewAnnotations()` と `#if DEBUG` の seed / reset Intent

- `AppEntityDefinition.viewAnnotations()` で「いま画面が publish している entity」を検証できる。
  CosmoTunes は Now Playing / Library の 4 セグメント / Canvas / Timer カードと**画面ごとに**
  テストを持つ。本アプリは詳細画面（単一 annotation）と一覧（コレクション annotation）の 2 本。
  一覧側は「作った 2 件が両方 annotation に出る」を superset で見る（他のテストが残した todo が
  混ざりうるので、件数の完全一致では見ない）。
- **watchOS ではこの手が使えない**（2026-08-27 実測）。`AppIntentsTesting` は watchOS SDK にも
  あり、`IntentDefinitions` / `suggestedEntities()` / `viewAnnotations()` まではリンクも実行も
  通るが、**intent の `run()` が `LNPerformActionPrebuiltErrorCodeActionNotAllowed`（
  `LNPerformIntentPrebuiltErrorDomain` code 4025）で落ちる**。テストの前提データを作る
  `AddTodoIntent` が走らないので、annotation を読むところまで到達できない。
  watchOS 側は実機 / シミュレータでの手動確認（#30）に残す。
- サンプルは `#if DEBUG` + `isDiscoverable = false` の `ResetTestDataIntent` /
  `SeedSampleEventsIntent` / `ClearSpotlightIntent` をアプリターゲットに同梱し、`setUp()` で
  `run()` して既知状態から始める。本アプリは「一意タイトルを作って最後に消す」自己クリーンアップ
  方式で、こちらは出荷バイナリに何も足さない代わりにテスト間の独立性がやや弱い。
- `IndexedEntityQuery` の reindex 経路を手で叩く方法もサンプルのコメントにある:
  macOS は `mdutil -cr <bundle id>`、iOS は Settings → Developer → CoreSpotlight Testing。

### Spotlight の全件再インデックスは client state で省略する

名前付き index の `beginBatch()` / `endBatch(withClientState:)` / `fetchLastClientState()` を使い、
前回コミットしたダイジェストと一致すれば起動時の全件再インデックスを丸ごと飛ばす
（`TodoService.indexAllForSpotlight()` / `TodoSpotlightIndex.clientState(for:)`）。

- client state は 250 バイト上限なので SHA-256 で 32 バイトに畳む。入力は **ソートしてから** hash する
  （fetch 順に依存すると同じ内容でもダイジェストがぶれ、毎回フル再インデックスになる）
- ダイジェストの材料は **id だけでなく `modifiedAt` も混ぜる**。id 集合が同じでも中身が変わることが
  ある（アプリ未起動中に他デバイスの編集が CloudKit で届いた等）。CosmoTunes は id 集合だけなので、
  そこだけ本アプリのほうが強い
- `beginBatch()` は index / delete 呼び出しの**前**に開く。空の no-op バッチで
  `endBatch(withClientState:)` すると state が永続化されず毎回フル再インデックスになるため、
  todo が 0 件のときは batch を開かずに抜ける
- 全ての per-entity 呼び出しが成功したときだけ state をコミットする（`try` が throw した起動は前回の
  state を残し、次回起動でフル再インデックスをやり直す）
- **batching は default index では使えない**（公式ヘッダ: *"Batching is unsupported for the
  CSSearchableIndex returned by the defaultSearchableIndex method"*）。名前付き index への移行が前提

Swift の API 名は ObjC ヘッダと違う（Swift 3 のリネームが効いている）: `beginIndexBatch` → `beginBatch()`、
`endIndexBatchWithClientState:` → `endBatch(withClientState:)`。ヘッダ名のまま書くとビルドエラーになる。

ダイジェストの性質（32 バイト / 順序非依存 / 内容変化を検出）は `TodoSpotlightIndexTests` で押さえる。

### 差分 index の失敗は数える（省略の裏で index が壊れたままになる）

上の省略と組み合わせると、**壊れたまま復旧しない**状態が作れてしまう。差分反映
（`reindexSpotlight` / `deindexSpotlight`）は fire-and-forget で、失敗しても Intent の呼出側には
伝えない（Spotlight の不調で todo の操作自体を失敗させるべきではない）。一方 client state は
差分の成否と無関係に「最新」のままなので、次回起動の全件再インデックスも省略される。結果、
index が壊れた端末は Spotlight / Siri から todo を引けない状態が続く。**アプリ内では正常に見える**。

そこで連続失敗を数える（`TodoSpotlightIndex.recordFailure` / `recordSuccess`）。

- 閾値（3 回）に達したら `UserDefaults` に「次回起動でフル再インデックス」の要求を立て、
  `indexAllForSpotlight()` は client state 一致でも**省略しない**
- 1 回の失敗で倒さないのは、`quotaExceeded` / 一時的な `indexUnavailable` のようなその場限りの
  失敗にフル再インデックスをぶつけても直らないため
- 成功したら連続カウントを畳む。フル再インデックスが通ったら要求を降ろす
- todo が 0 件のときも要求は降ろす（直す対象が無い）

判定は全部 `UserDefaults` の読み書きなので、`TodoSpotlightIndexTests` の
`TodoSpotlightIndexSelfHealingTests` がテスト用 suite を注入して押さえている。

### サンプル側にも古い書き方は残っている（無批判に真似しない）

- UnicornChat `DraftMessageIntent` / PhotosDomainExample の `DeleteAssetsIntent` /
  `DeleteAlbumIntent` は `static let openAppWhenRun = true` を使っている。公式の
  `supportedModes` ドキュメントでは `.foreground(.immediate)` と同等の旧 API 扱い。
- CometCal の `EventEntity.displayRepresentation` は `DateFormatter` をその都度生成している
  （本プロジェクトのユーザー全体ルールは `Date.FormatStyle` 側を優先）。
