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

### 削除確認の現状（2026-08-12〜）

`requestConfirmation` を含む Intent はアプリ内 `Button(intent:)` から呼べない（提示する面が無く `LNPerformActionErrorCodeUnsupportedValueType` で失敗し、**エラー表示も出ずに何も起きない**）。そのため確認は **SwiftUI 側で取り、実行は確認なし版の Intent** に渡す形へ移行済み。

| 経路 | 確認の取り方 | 実行する Intent |
|------|------------|----------------|
| 詳細画面の削除ボタン（`TodoDetailView` / `VisionOSTodoView`） | `.confirmationDialog` + `@State var isConfirmingDelete` | `DeleteTodoImmediatelyIntent` |
| リストのスワイプ削除（`DeleteButton`） | スワイプして Delete を押す操作自体が確認 | `DeleteTodoImmediatelyIntent` |
| Siri / Shortcuts | Intent 内の `requestConfirmation` | `DeleteTodoIntent` |

`DeleteTodoIntent`（確認付き）は Siri / Shortcuts 専用と考える。**AppIntentsTesting では検出できない**（Siri/Shortcuts 経路では成功するため）ので、UI 経路は UI テストで押さえる。経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)、詳細: [03-app-intents-core.md](03-app-intents-core.md)。

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

watchOS でも同じ規則が適用される（`role:` を外した `Button(intent:)` を使えば watchOS でも動く）。

経緯: [docs/devlog/04-ui-integration.md](../devlog/04-ui-integration.md)

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

macOS で使えない理由は**フレームワークの有無ではなく API の availability**（Xcode 27 beta 5 / macOS 27 SDK で実測）:

- `_AppIntents_SwiftUI.framework` は **ネイティブ macOS SDK にも存在する**。`My Mac` destination で `#if canImport(_AppIntents_SwiftUI)` は `true` になる。
- ただし macOS スライスの `.swiftinterface` に `onAppIntentExecution` の宣言は**無い**（iOS スライスにはある）。
- 前提となる `TargetContentProvidingIntent` 自体が `@available(macOS, unavailable)` / `@available(watchOS, unavailable)` で、iOS / tvOS / visionOS / macCatalyst 26.0+ のみ。macOS 向けに準拠を書くと `'TargetContentProvidingIntent' is unavailable in macOS` でコンパイルエラーになる。

つまり `canImport` を根拠にしてはいけないケースで、正しい判定軸は `os(...)`。準拠のガードも `#if os(iOS) || os(visionOS)`（macOS と watchOS を外す）が正となる。

経緯: [docs/devlog/04-ui-integration.md](../devlog/04-ui-integration.md)

### 実行順序

[onAppIntentExecution 公式ドキュメント](https://developer.apple.com/documentation/SwiftUI/View/onAppIntentExecution(_:perform:)) の挙動記述によると:
> "If the app intent implements a perform() method, it will be called after the action closure."

つまり `onAppIntentExecution` のクロージャが**先**に実行され、その後に Intent の `perform()` が呼ばれる。両方でナビゲーションを行うと二重実行になるため、どちらか一方に統一することを推奨。

### ⚠️ cold start ナビゲーションは iOS 26.4 でも不安定な場合がある

アプリが kill されている状態（cold start）での `onAppIntentExecution` 経由ナビゲーションは、Workshop PDF が "In iOS 26.4 and above this works as before" と書いていても、実機では 26.4 でも安定して完走しないケースが残る。

そのため本プロジェクトでは **`@Dependency var navigationModel` + `perform()` 内で NavigationModel に書き込む**パターンを基本とし、`onAppIntentExecution` 経路は補助的にしか使わない（詳細は本ドキュメントの「AppDependencyManager + perform()」セクション参照）。現状コードベース上で `.onAppIntentExecution` は実際にはどこにも使われておらず（`LaunchAppIntent` が `TargetContentProvidingIntent` に準拠しているのみ）、`@Dependency` + `perform()` パターンへ完全移行済みのためこの cold start 問題は現在アクティブなコードパスではない。

経緯: [docs/devlog/04-ui-integration.md](../devlog/04-ui-integration.md)

### 関連API

- **`AppIntentSceneDelegate`**: シーンレベルで Intent をハンドリングするプロトコル。`scene(_:willPerformAppIntent:)` メソッドで受信。
- **`UISceneAppIntent`**: `TargetContentProvidingIntent` を継承し、特定のシーンをターゲットにする Intent。

### TargetContentProvidingIntent

`onAppIntentExecution` を使用するためには、対象Intentが `TargetContentProvidingIntent` に準拠している必要がある。

**重要**: `TargetContentProvidingIntent` は **macOS / watchOS では利用不可**（SDK 側で `@available(macOS, unavailable)` / `@available(watchOS, unavailable)`）。Swift Packageで定義する場合は条件付きextensionで準拠する:

```swift
// Intent本体は全プラットフォーム共通（AppIntent として定義）
public struct OpenAddTodoIntent: AppIntent { ... }

// TargetContentProvidingIntent は macOS / watchOS では unavailable なので除外
// ※ TargetContentProvidingIntent は AppIntent を継承しているため、
//    単独で宣言する場合は AppIntent を並べる必要はないが、
//    後から extension で追加する場合はこのパターンが必要
#if os(iOS) || os(visionOS)
extension OpenAddTodoIntent: TargetContentProvidingIntent {}
extension OpenTodoListIntent: TargetContentProvidingIntent {}
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif
```

同様に、View側の `onAppIntentExecution` も同じ条件で囲む必要がある。

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

### 遷移先の「状態」は pending 値で受け渡す

「開く」だけでなく「**どういう状態で**開くか」を Intent が指定する場合、`NavigationModel` に `pending〜` を置き、View が `.onChange` / `.onAppear` で自分の state に転写してから nil に戻す、というハンドシェイクに統一している。`.onAppear` 側があることで cold start（Intent が先に走り、View が後から現れる）でも取りこぼさない。

| pending 値 | 書き込む Intent | 転写先 |
|-----------|----------------|--------|
| `pendingSearchText: String?` | `ShowTodoSearchResultsIntent`（`.system.searchInApp`）| `viewModel.searchText` |
| `pendingFilter: TodoFilterType?` | `LaunchAppIntent`（`.incompleteTodos` / `.favoriteTodos` / `.todoList`）| `viewModel.filter` |

```swift
// View 側 (TodoListView / VisionOSTodoListView に同じ形で実装)
.onChange(of: navigationModel.pendingFilter) { _, newValue in applyPendingFilter(newValue) }
.onAppear { applyPendingFilter(navigationModel.pendingFilter) }

private func applyPendingFilter(_ filterType: TodoFilterType?) {
    guard let filterType else { return }
    viewModel.filter = TodoFilter(filterType)
    navigationModel.pendingFilter = nil   // 再適用されないよう必ず nil に戻す
}
```

> **注意**: 画面ターゲットの `AppEnum`（`AppScreenTarget`）に case を足しただけでは何も起きない。`perform()` の `switch` で対応する状態を書き込むところまでやって初めて意味を持つ。実際 `.incompleteTodos` / `.favoriteTodos` は長い間 `switch` の `break` に落ちており、Todo Count コントロールや Siri の「お気に入りの Todo を見せて」が**絞り込まれずにアプリを開くだけ**になっていた（経緯: [docs/devlog/04-ui-integration.md](../devlog/04-ui-integration.md)）。列挙が約束した遷移先は、必ず対応する状態書き込みとセットで実装する。

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

### UISceneAppIntent は Swift Package 内でも定義できる（ガードは `canImport` だけでは足りない）

`UISceneAppIntent` は独立した `_AppIntents_UIKit` フレームワークに属する。**Swift Package スコープであることは障壁ではない** — `TodoAppIntents` パッケージ内に `UISceneAppIntent` 準拠の Intent を置いて iOS シミュレータ / My Mac / visionOS シミュレータの 3 destination すべてでビルド成功することを実測で確認済み（Xcode 27 beta 5）。

ただし**ガードの書き方を間違えると watchOS で落ちる**:

| プラットフォーム | `_AppIntents_UIKit.framework` | `UISceneAppIntent` |
|---|---|---|
| iOS / visionOS | あり | 使える |
| watchOS | **あり**（= `canImport` は true） | **無い**（`UIScene` も unavailable） |
| macOS | 無し | — |

`UISceneAppIntent` は `TargetContentProvidingIntent` を継承するため、その `@available(macOS, unavailable)` / `@available(watchOS, unavailable)` をそのまま引き継ぐ。watchOS は「フレームワークは import できるが型が無い」という組み合わせなので、`#if canImport(_AppIntents_UIKit)` 単独では watchOS ターゲットのビルドが `Cannot find type 'UISceneAppIntent' in scope` / `'UIScene' is unavailable in watchOS` で落ちる（実測）。これは本プロジェクトの「[`#if canImport(X)` だけに頼らない](07-platform-specific.md)」と同じ罠。

```swift
// ✅ watchOS を明示的に外す
#if canImport(_AppIntents_UIKit) && !os(watchOS)
```

本プロジェクトは `#if os(iOS) || os(visionOS)` でガードして採用している（`canImport` を使わないので watchOS の罠を踏まない）。適用先は `LaunchAppIntent` と `OpenTodoIntent`。

**採用の理由はマルチウィンドウではなく cold start**。`SceneDelegate` を `AppIntentSceneDelegate` に準拠させ、2 経路をシーンに向ける:

```swift
// 起動済みのシーンに対する実行
func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent) {
    appIntent.performNavigation(forScene: scene)
}

// cold start: Intent がきっかけでシーンが作られた場合はここに渡ってくる
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    connectionOptions.appIntent?.performNavigation(forScene: scene)
}
```

`connectionOptions.appIntent` は `willPerformAppIntent` では来ない。**この 1 行を落とすと「アプリは開くが目的の画面に行かない」**が cold start だけで起きる（上の「cold start ナビゲーションは不安定」と同じ症状の別経路）。

**遷移の実装は 1 か所に集約する**。`perform()` と `performNavigation(forScene:)` の両方から同じ `applyNavigation()` を呼ぶ（冪等）。別々に書くと片方だけ直す事故になり、しかも cold start しか壊れないので気づけない。ソースを真とした検出は `NavigationIntentsTests` の `SceneNavigationWiringTests`。

`performNavigation(forScene:)` はプロトコル要件が nonisolated なので、`@MainActor` を付けずに実装して中で `MainActor.assumeIsolated` する。呼び出し元をシーンデリゲート（＝メインスレッド）に限っているから成立する形。

SwiftUI 側の代替は `contentIdentifier` + `handlesExternalEvents` で「どのシーンが処理するか」を宣言する形（wwdc2025-275 23:12–23:26）。本アプリは `WindowGroup` が 1 つで宛先の選択が要らないため、cold start を確定させられる delegate 側を採った。`OpenIntent` と `UISceneAppIntent` を両方満たす Intent は `contentIdentifier` が自動で得られるので、将来ウィンドウを選ばせたくなったらそのまま活性化条件に使える。

経緯: [docs/devlog/04-ui-integration.md](../devlog/04-ui-integration.md)

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
- **`confirmationDialog`/`alert` の `item:` オーバーロード**: 調査時点では使用箇所ゼロだったが、
  **2026-08-12 に削除確認が SwiftUI 側へ移った**ため現状は当て先がある（下記「削除確認の現状」）。
  ただし現在の 2 箇所はいずれも「詳細画面が対象 entity を 1 つだけ持つ」形で `isPresented:` +
  `@State var isConfirmingDelete` で足りている。`item:` が効くのは「リストのどの行か」を
  ダイアログ側に運ぶ必要があるケースなので、スワイプ削除に確認を足す等の変更が入ったら再検討する。
- **`swipeActionsContainer()`**: メインリストは既に `List` で `.swipeActions` が動作済み。新 API は
  `List` 以外（`LazyVStack` 等）向けなので不要。

### 落とし穴

- **`@State` のマクロ化（SDK 27）**: 今回の変更では未遭遇だが、`@State` 絡みで
  "used before being initialized" 等が出たら **init 代入順の入れ替えは誤り**。`swiftui-whats-new-27`
  skill の `state-macro.md` を参照。
- **`TodoSortOrder` に case 追加 → allCases 前提のテストが赤**: `TodoSortOrderTests.allCases()` の
  期待値（6→7）と displayName テストを更新。enum の網羅 switch（ViewModel の `sortTodos`）も要追随。
