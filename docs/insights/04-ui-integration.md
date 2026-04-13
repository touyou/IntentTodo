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
| 削除ボタン | `Button(intent:)` | パラメータが既知 |
| 作成フォーム | `Button(intent:)` + Computed Property | 動的にIntent生成、dismissは`onChange`で |

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

### 実行順序

公式ドキュメントによると:
> "If the app intent implements a perform() method, it will be called after the action closure."

つまり `onAppIntentExecution` のクロージャが**先**に実行され、その後に Intent の `perform()` が呼ばれる。両方でナビゲーションを行うと二重実行になるため、どちらか一方に統一することを推奨。

### ⚠️ iOS バージョンによる動作差

アプリが kill されている状態（cold start）での動作は iOS バージョンによって異なる：

- **初期 iOS 26（〜26.3）**: cold start 時、Intentのシステムタイムアウト内にViewが準備できずナビゲーションが失敗する場合がある
- **iOS 26.4 以降**: "works as before"（ワークショップPDF記載）—— cold start でも正常に動作する模様

iOS 26.4 未満をサポートする場合や、安定性を優先する場合は `@Dependency` + `perform()` パターンを検討する（詳細は本ドキュメントの「AppDependencyManager + perform()」セクション参照）。

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

`UISceneAppIntent` はSwift Package内で定義されたIntentには利用できない（`UISceneAppIntent`はUIKit依存のため、Packageスコープで参照不可）。マルチウィンドウでのシーン固有ルーティングが必要な場合は、メインアプリターゲット内でIntentを定義するか、`SceneDelegate`で`connectionOptions`を活用する。

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
