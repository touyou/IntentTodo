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
