# Control Widget と iOS 26

## openAppWhenRun から supportedModes への移行

### iOS 26+ での新API

- **`supportedModes`**: `openAppWhenRun` の後継
- **`IntentModes`**: `.background` / `.foreground` / `.foreground(.immediate)` / `.foreground(.deferred)` / `.foreground(.dynamic)`
- `ForegroundContinuableIntent` は非推奨、`supportedModes` に `.foreground(.dynamic)` を含めることで置き換え

### supportedModes 一覧

| モード | 用途 |
|--------|------|
| `.background` | バックグラウンド実行（アプリを開かない） |
| `.foreground` | フォアグラウンドでアプリを開く |
| `.foreground(.immediate)` | 即座にフォアグラウンド |
| `.foreground(.dynamic)` | `ForegroundContinuableIntent` の後継 |

---

## Control Widget の実装

### ControlWidgetButton + foreground Intent

Control Widget からアプリを開く場合、`ControlWidgetButton(action:)` に `.foreground(.immediate)` の Intent を渡す。

```swift
struct QuickAddTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchAppIntent.addTodo()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}
```

**`kind` は reverse-domain 形式を推奨**。Apple 公式の全サンプル（[Creating controls to perform actions across the system](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)）が `com.example.MyApp.TimerToggle` / `com.example.myApp.performActionButton` / `com.yourcompany.GarageDoorOpener` 等の reverse-domain 形式を使用：

```swift
static let kind: String = "com.example.MyApp.TimerToggle"
```

本プロジェクトで過去に `"QuickAddTodoControl"` のような短い名前にしていた時期は foreground 遷移が機能しなかった（経験則）。公式は形式を明示していないが、サンプルに合わせて reverse-domain 形式にしておくのが無難。

### ControlConfigurationIntent と SetValueIntent

`ControlConfigurationIntent` と `SetValueIntent` は同時準拠できない。トグル操作は `ControlWidgetButton(action:)` で実装する。

### ControlConfigurationIntent のモジュール境界

Widget Extension 内で定義した `ControlConfigurationIntent` は、アプリ本体から参照できない（Swift のモジュール Name Mangling が原因）。`StaticControlConfiguration` を使用し、ConfigurationIntent を必要としない設計にする。

### ControlConfigurationIntent のフィードバック

`.result(dialog:)` は非対応。視覚的状態変化 / システムハプティック / ローカル通知で代替する。

---

## バックグラウンドアクションパターン

Control Widget でアプリを開かずに処理だけ行いたい場合は `.background` モードの Intent を使う。**このとき `perform()` は Widget Extension プロセスで実行される** ので、Widget Extension 側でも `AppDependencyManager` に依存を登録する必要がある。

```swift
// IntentTodoWidget/IntentTodoWidgetBundle.swift
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        // Widget Extension プロセスで @Dependency を解決するため、
        // Extension 側にも ModelContainer を登録する。
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
    }

    var body: some Widget { /* ... */ }
}

// TodoAppIntents (SPM) 側の Intent
public struct ToggleUrgentTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Urgent Todo"
    public static let supportedModes: IntentModes = [.background]

    @Dependency
    var modelContainer: ModelContainer

    @MainActor
    public func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        // ... データ操作
        return .result()
    }
}
```

### プロセス別登録ルール

| 呼出元 / モード | 実行プロセス | 登録場所 |
|----------------|------------|---------|
| Shortcuts / UI | メインアプリ | `App.init()` |
| Widget `Button(intent:)` + `.foreground(.immediate)` | メインアプリ | `App.init()` |
| Widget `ControlWidgetButton(action:)` + `.background` | **Widget Extension** | `WidgetBundle.init()` |

### フィードバックはローカル通知で

`ControlConfigurationIntent` では `dialog` が使えないため、ユーザーへの結果表示はローカル通知で行う。

```swift
ControlNotificationHelper.sendToggledNotification(todoTitle: todo.title, isCompleted: ...)
```
