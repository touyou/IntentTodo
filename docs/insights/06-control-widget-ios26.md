# Control Widget と iOS 26

## supportedModes の使い分け

[Apple 公式 `supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) より (抜粋)：

- `.background` — バックグラウンド実行（アプリを開かない）。`openAppWhenRun = false` と同等の挙動
- `.foreground` / `.foreground(.immediate)` — パラメータ解決後すぐフォアグラウンド（`openAppWhenRun = true` と同等の挙動）
- `.foreground(.dynamic)` — 実行中に動的に判断。**`ForegroundContinuableIntent` の後継**（[公式](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent)が "This protocol is deprecated" と明記）
- `.foreground(.deferred)` — 初期バックグラウンド → 自動 foreground 化

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

**`kind` は reverse-domain 形式を推奨**。短い名前（例: `"QuickAddTodoControl"`）でも動作することは実機確認済みだが、以下の理由で reverse-domain 形式が望ましい:

- Apple 公式の全サンプル（[Creating controls to perform actions across the system](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)）が `com.example.MyApp.TimerToggle` / `com.example.myApp.performActionButton` / `com.yourcompany.GarageDoorOpener` 等の形式
- システムで一意識別するための文字列なので、他アプリの Control と衝突しにくい形式の方が安全

```swift
static let kind: String = "com.example.MyApp.TimerToggle"
```

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
