# UI層とIntent統合

## Button(intent:) の使用

macOS 14 / iOS 17 以降、`Button(intent:)` は両プラットフォームで使用可能。

```swift
import AppIntents  // ← Button(intent:) を使用するために必須

// 推奨: Button(intent:) を直接使用
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

### Button(intent:) の使い分け

| ケース | 方式 | 備考 |
|--------|------|------|
| チェックボックス、お気に入り | `Button(intent:)` | パラメータが既知 |
| 削除ボタン | `Button(role:intent:)` | **`role:` を先に書く**（下記注記参照） |
| 作成フォーム | `Button(intent:)` + Computed Property | 動的にIntent生成、dismissは`onChange`で |

> **引数順の罠**: `Button(role:intent:)` は `role:` を**先に**書く。`Button(intent: X, role: .destructive)` の順だと別 init に解決されて `"extraneous argument label 'intent:'"` エラーになる（visionOS ビルドで実際に発生、詳細は `07-platform-specific.md` の「Button(intent:role:) の引数順」）。

### 直接 `perform()` を呼ばない

Intent の `@Dependency` はシステムが `Button(intent:)` 経由で dispatch した時にのみ `AppDependencyManager` から解決される。`Task { try? await intent.perform() }` のように手動で呼ぶと `@Dependency` がゼロ初期化状態になり、ModelContainer 利用時点でクラッシュする。

```swift
// ❌ watchOS などで @Dependency 未解決のまま実行→クラッシュ
Button {
    Task { try? await AddTodoIntent(title: title).perform() }
} label: { Label("Add", systemImage: "plus") }

// ✅ Button(intent:) でシステム dispatch 経由にする
Button(intent: AddTodoIntent(title: title)) {
    Label("Add", systemImage: "plus.circle.fill")
}
```

アプリを開くだけの導線は **`Link(destination:)` を優先**する（Apple 公式推奨、詳細は「Widget への Button(intent:) 統合」節参照）。

> watchOS でも同じ規則が適用される。以前 `07-platform-specific.md` には watchOS 向けに手動 `Task { try? await intent.perform() }` を推奨する誤った記述があったが、2026-08-11 に訂正済み（`role:` を外した `Button(intent:)` を使えば watchOS でも動く）。

---

## onAppIntentExecution（iOS 26+ / Intent → UI 連携）

iOS 26 で追加された `onAppIntentExecution(_:perform:)` View modifier により、特定の AppIntent が実行された際にシーン側で直接 UI を更新できる。

### 仕組み

`TargetContentProvidingIntent` を実装した Intent が実行されると、`onAppIntentExecution` を設定した View のクロージャが呼ばれる。

```swift
// TargetContentProvidingIntent は AppIntent を継承しているため、AppIntent の明示は不要
struct ShowTodoDetailIntent: TargetContentProvidingIntent {
    @Parameter(title: "Todo")
    var todo: TodoAppEntity

    // perform() は省略可能。ナビゲーションは onAppIntentExecution 側で完結させることが多い
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// View側
NavigationStack {
    TodoListView()
}
.onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
    navigationPath.append(intent.todo)
}
```

### 「知識の方向」—— どちらのパターンを選ぶか

| パターン | 知識の向き | 特徴 |
|---------|-----------|------|
| `@Dependency` + `perform()` | Intent がアプリ状態を知っている | Intent 側にナビゲーションロジックが集約 |
| `onAppIntentExecution` | App（View）が Intent を知っている | ナビゲーションロジックが View 側に集約、宣言的 |

どちらも正しい。プロジェクトの規模や好みで選択する。macOS では `onAppIntentExecution` が使えないため `@Dependency` パターンが必須。

> **2026-08-11 再検証（確認・変更不要）**: 「macOS では使えない」という記述自体は正しいと確認した。Xcode 27 beta 5 SDK の `.swiftinterface` を直接調べると、`onAppIntentExecution` は `_AppIntents_SwiftUI` フレームワークに実装されており、この配布は **iOS / macCatalyst / visionOS / watchOS には存在するが、ネイティブ macOS 向けには存在しない**（`MacOSX.sdk` 内では `System/iOSSupport`＝Mac Catalyst 配下にしか同フレームワークが無い）。一方 `TargetContentProvidingIntent`（プロトコル本体、`AppIntents.framework` 側）は macOS でも利用可能で、本プロジェクトの `#if os(iOS) || os(macOS) || os(visionOS)` による準拠は妥当（プロトコル準拠自体はできるが、SwiftUI 側のフック用モディファイアだけが無い、という切り分け）。よって半矛盾を疑ったが、コード側の `#if` 条件と実際の SDK 制約は整合しており修正不要。

### 実行順序

[onAppIntentExecution 公式ドキュメント](https://developer.apple.com/documentation/SwiftUI/View/onAppIntentExecution(_:perform:)) の挙動記述によると:
> "If the app intent implements a perform() method, it will be called after the action closure."

つまり `onAppIntentExecution` のクロージャが**先**に実行され、その後に Intent の `perform()` が呼ばれる。両方でナビゲーションを行うと二重実行になるため、どちらか一方に統一することを推奨。

### ⚠️ cold start ナビゲーションは iOS 26.4 でも不安定 (実体験ベース)

アプリが kill されている状態（cold start）での `onAppIntentExecution` 経由ナビゲーションは、Workshop PDF が "In iOS 26.4 and above this works as before" と書いていても、**実体験では 26.4 でも安定して完走しないケースが残る** (2026-04-12 の App Intents ワークショップで確認)。

そのため本プロジェクトでは **`@Dependency var navigationModel` + `perform()` 内で NavigationModel に書き込む**パターンを基本とし、`onAppIntentExecution` 経路は補助的にしか使わない（詳細は本ドキュメントの「AppDependencyManager + perform()」セクション参照）。

> **過去の理解**: 初期 iOS 26 (〜26.3) で cold start 失敗が確認され、Workshop PDF では 26.4 で修正と謳われたが、実機では完全には解消していない印象。Apple Feedback に提出するには再現性をさらに詰める必要あり。

> **2026-08-11 追記（未解決の仮説、要再検証）**: 「OS バグ」と断定する前に切り分けるべき候補が3つ残っている: ①`.onAppIntentExecution` を付けた View の `@State path` がクロージャ実行時点でまだ構築されていない、②シーンの activation conditions（wwdc2025-275 23:52-24:09「どのシーンが intent をハンドルするかは activation conditions で決まる」）が未設定、③対象 Intent の `supportedModes` に foreground が無くタイムアウトする。ただし現状のコードベースを grep した限り `.onAppIntentExecution` は実際には**どこにも使われていない**（`LaunchAppIntent` が `TargetContentProvidingIntent` に準拠しているのみ）。本プロジェクトは既に `@Dependency var navigationModel` + `perform()` パターンへ完全移行済みで、この cold start 問題は現在アクティブなコードパスではない。上記3仮説の検証は、`.onAppIntentExecution` を実際に再導入する場面が来たときに行う。

### 関連API

- **`AppIntentSceneDelegate`**: シーンレベルで Intent をハンドリングするプロトコル。`scene(_:willPerformAppIntent:)` メソッドで受信。
- **`UISceneAppIntent`**: `TargetContentProvidingIntent` を継承し、特定のシーンをターゲットにする Intent。

### TargetContentProvidingIntent

`onAppIntentExecution` を使用するためには、対象Intentが `TargetContentProvidingIntent` に準拠している必要がある。

**重要**: `TargetContentProvidingIntent` はwatchOSでは利用不可。Swift Packageで定義する場合は条件付きextensionで準拠する:

```swift
// Intent本体は全プラットフォーム共通（AppIntent として定義）
public struct OpenAddTodoIntent: AppIntent { ... }

// TargetContentProvidingIntent は watchOS 以外のみ追加準拠
// ※ TargetContentProvidingIntent は AppIntent を継承しているため、
//    単独で宣言する場合は AppIntent を並べる必要はないが、
//    後から extension で追加する場合はこのパターンが必要
#if os(iOS) || os(macOS) || os(visionOS)
extension OpenAddTodoIntent: TargetContentProvidingIntent {}
extension OpenTodoListIntent: TargetContentProvidingIntent {}
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif
```

同様に、View側の `onAppIntentExecution` も `#if !os(watchOS)` で囲む必要がある。

---

## AppDependencyManager + perform() による安定したナビゲーション

ナビゲーション状態を `AppDependencyManager` に同期登録し、Intent の `perform()` で書き込む。`perform()` は Intent 実行コンテキストで呼ばれるため、SwiftUI シーンの準備完了を待たずに書き込める。シーンが表示されたときに `@Observable` の変化を受けて自動反映される。

```swift
// ナビゲーション状態
@MainActor
@Observable
public final class NavigationModel {
    public var showingAddTodo: Bool = false
    public init() {}
}

// App.init で同期登録
@main
struct IntentTodoApp: App {
    @State private var navigation: NavigationModel

    init() {
        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }

    var body: some Scene {
        WindowGroup {
            TodoListView().environment(navigation)
        }
    }
}

// Intent は @Dependency で取得
struct LaunchAppIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Dependency
    var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showingAddTodo = true
        return .result()
    }
}
```

### supportedModes の選択

ナビゲーション目的の Intent には `.foreground(.immediate)` が適切。アプリを即座にフォアグラウンドに持ってきてから `perform()` が実行される。

```swift
static let supportedModes: IntentModes = [.foreground(.immediate)]
```

### `onAppIntentExecution` との使い分け

| 方式 | 特徴 |
|------|------|
| `onAppIntentExecution` | 宣言的・View modifier に集約。`TargetContentProvidingIntent` 準拠 Intent が対象。初期 iOS 26 では cold start 時に失敗する可能性 |
| `AppDependencyManager` + `@Dependency` + `perform()` | Intent 側に集約。cold start でも安定。実行プロセスごとに依存登録が必要（`App.init()` だけでなく、Widget 経由の `.background` Intent を使うなら `WidgetBundle.init()` にも登録が必要）|

---

### UISceneAppIntent の制限

**2026-08-11 因果訂正**: 「Package スコープで参照不可」という理由付けは誤り。SPM パッケージは `#if canImport(UIKit)` で UIKit そのものを普通に import できる。実際の障壁は `UISceneAppIntent` が独立した `_AppIntents_UIKit` フレームワークに属し、**このフレームワークが SDK レベルで iOS / watchOS / visionOS には存在するが、ネイティブ macOS には存在しない**こと（Xcode 27 beta 5 SDK で確認: `_AppIntents_UIKit.framework` が macOS SDK 直下には無い）。`TodoAppIntents` は macOS 向けにもコンパイルされるプラットフォームマトリクスのため、`#if canImport(_AppIntents_UIKit)`（または `#if os(iOS) || os(watchOS) || os(visionOS)`）でガードすれば Package 内でも利用できる可能性が高い（未検証・優先度低、必要になったら試す）。マルチウィンドウでのシーン固有ルーティングが必要な場合の代替は変わらず、メインアプリターゲット内でIntentを定義するか、`SceneDelegate`で`connectionOptions`を活用する。

---

## View は struct 抽出、computed-property View は避ける

CLAUDE.md で規約化しているが、実装では崩れやすい。本プロジェクトでは `TodoListView` / `TodoDetailView` / `VisionOSTodoListView` / `VisionOSTodoDetailView` の各セクションを以下のような粒度で `private struct: View` に分割している。computed-property や method-returning `some View` は差分追跡単位にならず、親 `body` 全体が再評価されるため、メンテナンス時の体感パフォーマンスが落ちやすい。

```swift
// ✅ 実例: TodoDetailView の分割
TodoDetailContent(todo: item)      // 全体
  TodoDetailHeaderSection(todo:)   // チェックボックス + タイトル + ステータスバッジ
  TodoDetailDueDateSection(...)    // 期限
  TodoDetailTimeRemainingLabel(...) // TimelineView でライブ更新
  TodoDetailSubtasksSection(...)
  TodoDetailMetadataSection(...)
  TodoDetailActionsSection(...)
```

ポイント:

- **DueDateStatus を切り出し直す**: 複数セクションで "overdue / dueSoon" 判定が必要なら、`Domain.DueDateStatus.evaluate(date:isCompleted:)` を共通で呼ぶ。
- **`TimelineView(.periodic(from:by:))`** で時間経過を受ける View は struct 化しておくと `context.date` を閉じ込められてテストもしやすい。
- **Formatter は `static let` で共有**: `DateComponentsFormatter` などはインスタンス化コストが高いので、struct 内に `static let` で 1 度だけ生成する。

---

## @Observable + @MainActor

Observation frameworkを使用する際は、必ず `@MainActor` を付与する。

```swift
@MainActor
@Observable
public final class TodoListViewModel {
    public private(set) var todos: [TodoAppEntity] = []
    public private(set) var isLoading = false
    public var errorMessage: String?
}
```

### App Intents vs ViewModel の役割分担

- **App Intents** = ビジネスロジック（CRUD、Siri/Shortcutsからも使用、検索クエリ実行含む）
- **ViewModel** = UI状態管理（フィルター状態、ソート順、検索テキスト）

---

## プラットフォーム条件分岐

iOS専用APIは `#if os(iOS)` で分岐する。

```swift
TextField("Title", text: $title)
#if os(iOS)
    .textInputAutocapitalization(.sentences)
#endif
```

---

## コード簡素化のパターン

### Dictionary初期化

```swift
// Before
for item in items { dict[item.id] = item }

// After
dict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
```

### 重複するswitch文の統合

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

### ネストした三項演算子の排除

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

## WWDC 2026 / SDK 27 SwiftUI 新 API 採用（`xcode27` ブランチ）

> deployment target は 26.0 のまま。27+ 限定 API は **`#available` ガード**で導入し、
> 26 では従来動作にフォールバックする（この「新 OS だけ強化・旧 OS は据え置き」の
> ガード方式自体の検証も兼ねる）。ビルドは複数 destination で green（B 深度）、実機
> ジェスチャ確認は R 深度で手動。

### ドラッグ並べ替え（`reorderable()` / `reorderContainer(for:itemID:)`）

`List`（や任意コンテナ）の `ForEach` に `.reorderable()`、コンテナに
`.reorderContainer(for:itemID:)` を付けるとドラッグ並べ替えになる（iOS/macOS/visionOS/
watchOS 27+、tvOS 不可）。本アプリは **手動ソート時のみ**有効化する。

- **永続化**: `TodoItem.sortIndex: Int = 0`（デフォルト値付き＝CloudKit 安全 + SwiftData
  軽量マイグレーション、`VersionedSchema` 不要）を追加。`TodoAppEntity.sortIndex` に写像し、
  `TodoSortOrder.manual`（新規 case）が `sortIndex` 昇順で並べる（同値は createdAt 新しい順で tie-break）。
- **アクションは Intent**: 並べ替えは `ReorderTodosIntent`（`.background` / `isDiscoverable=false`）
  として定義し、ロジックは `TodoService.reorderTodos(orderedIDs:)` に集約。ただし**ドラッグ確定は
  `Button(intent:)` に載せられない**ため、View 側は同じ `TodoService` を直接呼ぶ（`modelContext.container`
  から生成 → `@Query` と同一 context に書く）。Intent と UI がロジックを共有するので二重実装にならない。
- **`ReorderDifference` の適用**: 単一コレクションは
  `ReorderDifference<String, ReorderableSingleCollectionIdentifier>` を受け、`sources` を抜いて
  `destination.position`（`.before(id)` / `.end`）へ差し込む拡張（`@available(iOS 27,…)` で
  ガード）で新 id 順を算出 → 上記 Intent 経路へ。
- **`#available` の当て方**: `.reorderable()` は `ForEach` の型を変えるので、`List` builder 内で
  `if #available(iOS 27, macOS 27, visionOS 27, *), isReorderable { ForEach…​.reorderable() } else { ForEach… }`
  と条件分岐（availability + bool を 1 つの `if` で結合可）。`.reorderContainer` は `ViewModifier`
  に切り出して同じガードを 1 箇所に閉じ込め、`body` を読みやすく保つ。

### ツールバー最小化（`toolbarMinimizeBehavior(_:for:)`）

スクロールでナビゲーションバーを最小化。`.onScrollDown` は **iOS 限定**なので `#if os(iOS)` +
`if #available(iOS 27, *)` の二重ガードを `ViewModifier` に閉じ込めて適用。macOS/visionOS は
`.automatic` しか無いため、本アプリでは iOS のみ採用。

### 該当なしだった新 API（調査記録）

- **`AsyncImage(request:)` / `asyncImageURLSession`**: プロジェクトに `AsyncImage` 使用箇所ゼロ
  （リモート画像を扱わない）→ 採用対象なし。
- **`confirmationDialog`/`alert` の `item:` オーバーロード**: `confirmationDialog` / `.alert(` の
  使用箇所ゼロ。削除確認は SwiftUI ダイアログではなく **App Intent の `requestConfirmation`** 経由
  （Siri/Shortcuts でも一貫）なので、この新オーバーロードの当て先が無い → 採用対象なし。
- **`swipeActionsContainer()`**: メインリストは既に `List` で `.swipeActions` が動作済み。新 API は
  `List` 以外（`LazyVStack` 等）向けなので不要。

### 落とし穴

- **`@State` のマクロ化（SDK 27）**: 今回の変更では未遭遇だが、`@State` 絡みで
  "used before being initialized" 等が出たら **init 代入順の入れ替えは誤り**。`swiftui-whats-new-27`
  skill の `state-macro.md` を参照。
- **`TodoSortOrder` に case 追加 → allCases 前提のテストが赤**: `TodoSortOrderTests.allCases()` の
  期待値（6→7）と displayName テストを更新。enum の網羅 switch（ViewModel の `sortTodos`）も要追随。
