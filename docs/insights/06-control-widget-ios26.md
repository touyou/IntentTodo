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

Control Widget からアプリを開くだけの場合、`ControlWidgetButton(action:)` に `.foreground(.immediate)` の Intent を渡す。

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

### ControlValueProvider でデータを供給する

値を表示するタイプの Control（カウント表示・次の期限など）は、`StaticControlConfiguration(kind:provider:)` に `ControlValueProvider` を渡し、body ではその値を受け取るだけにする。body の中で直接 SwiftData fetch すると、WidgetKit 側の更新タイミング制御と噛み合わず body が過剰に評価される恐れがある。

```swift
struct TodoCountControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { count in
            ControlWidgetButton(action: ShowTodoCountIntent()) {
                Label { Text("\(count)") } icon: { Image(systemName: "checklist") }
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap for summary.")
    }
}

extension TodoCountControl {
    struct Provider: ControlValueProvider {
        var previewValue: Int { 3 }
        func currentValue() async throws -> Int {
            try await MainActor.run {
                let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isCompleted })
                return (try? sharedWidgetModelContainer.mainContext.fetchCount(descriptor)) ?? 0
            }
        }
    }
}
```

複数の値を返したい場合は `Snapshot` のような値型を自前で用意して `currentValue()` で返す（本プロジェクトの `ToggleUrgentTodoControl.Snapshot` 参照）。

### kind は reverse-DNS 形式で統一

本プロジェクトでは `dev.touyou.IntentTodo.<Target>.<WidgetName>` に統一している。対象は以下のすべて:

| 種別 | 例 |
|------|-----|
| ControlWidget (3 種) | `dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl` など |
| ホーム Widget | `dev.touyou.IntentTodo.IntentTodoWidget` |
| watchOS Complication | `dev.touyou.IntentTodo.IntentTodoWatchApp.TodoComplication` |

Apple 公式の全サンプル（[Creating controls to perform actions across the system](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)）も `com.example.MyApp.TimerToggle` の形式。短い名前でも動作することは確認済みだが、システム全体で一意識別される文字列なので他アプリと衝突しにくい reverse-DNS 形式が安全。

### ControlConfigurationIntent と SetValueIntent

`ControlConfigurationIntent` と `SetValueIntent` は同時準拠できない。トグル操作は `ControlWidgetButton(action:)` で実装する。

### ControlConfigurationIntent のモジュール境界

Widget Extension 内で定義した `ControlConfigurationIntent` は、アプリ本体から参照できない（Swift のモジュール Name Mangling が原因）。`StaticControlConfiguration` を使用し、ConfigurationIntent を必要としない設計にする。

### ControlConfigurationIntent のフィードバック

`.result(dialog:)` は非対応。視覚的状態変化 / システムハプティック / ローカル通知で代替する。

### visionOS 非対応: `#if !os(visionOS)` でガード

Apple 公式 [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy#Review-system-experiences-for-each-platform) のプラットフォーム対応表で、Controls は **iPhone / iPad / Apple Watch / Mac で Yes、Apple Vision Pro のみ No** と明記されている。

```swift
#if !os(visionOS)
import WidgetKit
// ... Control ウィジェット定義
#endif
```

`if #available(iOS 18.0, *)` は実行時版チェックであり、コンパイル時に visionOS SDK が `ControlWidget` / `ControlWidgetButton` / `StaticControlConfiguration` 型を提供しない問題を回避できない。条件付きコンパイル（`#if`）で型参照自体を切る必要がある。

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
