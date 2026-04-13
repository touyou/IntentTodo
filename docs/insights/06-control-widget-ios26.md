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

Control Widget からアプリを開く場合、`ControlWidgetButton(action:)` に `.foreground(.immediate)` の Intent を渡す。**`kind` は Extension Bundle ID 形式（reverse-domain）で書く**のが重要。

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

Apple 公式サンプル（"Adding refinements and configuration to controls"）も reverse-domain 形式：

```swift
static let kind: String = "com.example.MyApp.TimerToggle"
```

### 短い kind の失敗

`static let kind = "QuickAddTodoControl"` のような**短い名前は機能しない**（少なくとも iOS 26 初期）。`ControlWidgetButton` の foreground 遷移が起動しない。

### ControlConfigurationIntent と SetValueIntent

`ControlConfigurationIntent` と `SetValueIntent` は同時準拠できない。トグル操作は `ControlWidgetButton(action:)` で実装する。

### ControlConfigurationIntent のモジュール境界

Widget Extension 内で定義した `ControlConfigurationIntent` は、アプリ本体から参照できない（Swift のモジュール Name Mangling が原因）。`StaticControlConfiguration` を使用し、ConfigurationIntent を必要としない設計にする。

### ControlConfigurationIntent のフィードバック

`.result(dialog:)` は非対応。視覚的状態変化 / システムハプティック / ローカル通知で代替する。

---

## バックグラウンドアクションパターン

Control Widget でアプリを開かずに処理だけ行いたい場合は、`.background` モードの Intent を使う。

```swift
// IntentTodoWidget/Intents/ControlIntents.swift
struct ToggleUrgentTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Urgent Todo"
    static let supportedModes: IntentModes = [.background]

    @MainActor
    func perform() async throws -> some IntentResult {
        // 安全策として SharedModelContainer から直接コンテナを取得。
        // Extension 内定義の Intent の実行プロセスは未検証のため、
        // どのプロセスから呼ばれても動作する App Group 経由を使用。
        let container = try SharedModelContainer.createContainer()
        let context = container.mainContext
        // ... データ操作
        return .result()
    }
}
```

### フィードバックはローカル通知で

ユーザーへの結果表示はローカル通知で行う（`ControlConfigurationIntent` では dialog が使えないため）。

```swift
ControlNotificationHelper.sendCompletedNotification(todoTitle: todo.title)
```
