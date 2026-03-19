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
struct ShowTodoDetailIntent: AppIntent, TargetContentProvidingIntent {
    @Parameter(title: "Todo")
    var todo: TodoAppEntity

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

### 実行順序

公式ドキュメントによると:
> "If the app intent implements a perform() method, it will be called after the action closure."

つまり `onAppIntentExecution` のクロージャが**先**に実行され、その後に Intent の `perform()` が呼ばれる。

### 関連API

- **`AppIntentSceneDelegate`**: シーンレベルで Intent をハンドリングするプロトコル。`scene(_:willPerformAppIntent:)` メソッドで受信。
- **`UISceneAppIntent`**: `TargetContentProvidingIntent` を継承し、特定のシーンをターゲットにする Intent。

### 実装パターン: デュアルIntent→UI連携

本プロジェクトでは `onAppIntentExecution` と `IntentAppState` を併用する「デュアルパターン」を採用している。

```swift
// 主軸: onAppIntentExecution（アプリ内Intent実行時）
.onAppIntentExecution(LaunchAppIntent.self) { intent in
    switch intent.target {
    case .addTodo: navigationViewModel.showAddTodo()
    default: break
    }
}
.onAppIntentExecution(OpenAddTodoIntent.self) { _ in
    navigationViewModel.showAddTodo()
}

// フォールバック: IntentAppState（Extension→アプリ間通信）
.onAppear {
    if IntentAppState.shared.consumeShowAddTodoRequest() {
        navigationViewModel.showAddTodo()
    }
}
```

### IntentAppState との使い分け

| 方式 | 用途 | 特徴 |
|------|------|------|
| `onAppIntentExecution` | アプリ内のIntent→UI連携（主軸） | 宣言的、View modifier で完結 |
| `IntentAppState` (共有状態) | Extension → アプリ間の通信（フォールバック） | Control Widget 等、Extension からの状態伝達向き |

### TargetContentProvidingIntent

`onAppIntentExecution` を使用するためには、対象Intentが `TargetContentProvidingIntent` に準拠している必要がある。

**重要**: `TargetContentProvidingIntent` はwatchOSでは利用不可。Swift Packageで定義する場合は条件付きextensionで準拠する:

```swift
// Intent本体は全プラットフォーム共通
public struct OpenAddTodoIntent: AppIntent { ... }

// TargetContentProvidingIntent は watchOS 以外のみ
#if os(iOS) || os(macOS) || os(visionOS)
extension OpenAddTodoIntent: TargetContentProvidingIntent {}
extension OpenTodoListIntent: TargetContentProvidingIntent {}
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif
```

同様に、View側の `onAppIntentExecution` も `#if !os(watchOS)` で囲む必要がある。

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
