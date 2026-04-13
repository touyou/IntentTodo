# プラットフォーム固有の知見

## watchOS 固有の制約

### Button(intent:) の API 差異

watchOS では iOS と同じ `Button(intent:role:)` シグネチャが利用できない。代わりに async パターンを使用する。

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

watchOSアプリは単一ファイルが肥大化しやすいため、早期に分割する。

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

Live Activity から Activity の開始/更新/終了を伴うアクションを実行する場合は `LiveActivityIntent` を使用する（[Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Start-and-stop-Live-Activities-from-App-Intents) より "When you implement your app intent that starts the Live Activity, make sure it inherits from `LiveActivityIntent`."）。

**重要な挙動差**（[ActivityKit / Activity](https://developer.apple.com/documentation/activitykit/activity) および [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) より）:

- Live Activity の**開始**はアプリがフォアグラウンドにある時のみ可能。ただし `LiveActivityIntent` を使えばバックグラウンドからも可能:
  > "You can update or end a Live Activity while your app is in the background, but you can only start a Live Activity while the app is in the foreground, unless you adopt App Intents and start the Live Activity using a `LiveActivityIntent`."
- `LiveActivityIntent` の `perform()` は**アプリプロセス**で実行される:
  > "If you adopt the `LiveActivityIntent` or `AudioPlaybackIntent` protocol, the system runs the app intent in the app's process."
- 対して通常の `AppIntent` を Widget/Live Activity から呼ぶ場合は **Widget Extension プロセス**で実行される:
  > "If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target."

本プロジェクトでは `ToggleTodoCompletionIntent` と `SnoozeTodoIntent` を `#if os(iOS)` で `LiveActivityIntent` に条件付き準拠させ、Live Activity のボタン経由でアプリプロセス側で実行されるようにしている。

### Intent種別の使い分け

| Intent種別 | 用途 | 実行プロセス |
|-----------|------|------------|
| `AppIntent` | Siri/Shortcuts/UI/Widget | Siri/Shortcuts はアプリ、Widget は Widget Extension |
| `LiveActivityIntent` | Dynamic Island/ロック画面（Live Activity ボタン） | アプリプロセス（公式保証） |
| `ControlConfigurationIntent` | コントロールセンター設定値 | Extension 配置必須 |

---

## Live Activity の自動管理

### View Modifier パターン

Live Activityの自動開始/終了は、View modifierとして実装することで既存UIに非侵入的に追加できる。

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

---

## Widget への Button(intent:) 統合

### iOS 17+ での直接Intent実行

Widget内でボタンをタップして直接Intentを実行できる。

```swift
Button(intent: OpenAddTodoIntent()) {
    HStack {
        Image(systemName: "plus.circle.fill")
        Text("Add Todo")
    }
}
.buttonStyle(.plain)
```

### 注意点

- `AppIntents`モジュールのimportが必要
- Intent の実行モード（`supportedModes`）で挙動が決まる（`.background` / `.foreground(.immediate)` 等）
- **アプリを開くだけが目的の場合は `Link(destination:)` が公式推奨**（[Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) より "An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use `Link` and `widgetURL(_:)`"）

---

## Spotlight 検索属性（IndexedEntity）

### attributeSet の実装

`IndexedEntity` に準拠し `attributeSet` プロパティを実装することで、Spotlight検索でTodoが見つかるようになる。

```swift
#if os(iOS) || os(macOS)
extension TodoAppEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = title
        attributes.contentDescription = isCompleted ? "Completed" : "Incomplete"
        if let dueDate {
            attributes.dueDate = dueDate
        }
        attributes.keywords = buildKeywords()
        return attributes
    }

    private func buildKeywords() -> [String] {
        var keywords = ["todo", title]
        if isFavorite {
            keywords.append(contentsOf: ["favorite", "starred", "important"])
        }
        if isCompleted {
            keywords.append("completed")
        } else {
            keywords.append(contentsOf: ["incomplete", "pending"])
        }
        return keywords
    }
}
#endif
```

### 注意点

- `CoreSpotlight` は `#if canImport(CoreSpotlight)` でガード（watchOSでは利用不可）
- `IndexedEntity` 本体はプラットフォーム制限なし（`attributeSet`のみ条件付き）
- キーワードはコンテキスト別に動的生成（favorite/completed/incomplete等）
- `dueDate` を設定することで期限ベースのSpotlight検索が可能

---

## ファイル分割の一般的パターン

1ファイルが200行を超えたら分割を検討。

```
Target/
├── TargetMain.swift              # エントリーポイントのみ
├── Configuration/                # Intent/Configuration定義
├── Views/                        # UI View
├── Components/                   # 再利用可能な小さいView
├── Intents/                      # ターゲット固有のIntent
└── Manager/                      # ビジネスロジック管理
```

### 分割時の注意点

- **internal型の共有**: 同じターゲット内なら `import` 不要
- **Preview**: 分割後も各ファイルでPreviewが動作するよう依存を整理
- **ビルドエラー**: 循環参照に注意（型の定義順序）
