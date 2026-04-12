# Control Widget と iOS 26

## openAppWhenRun から supportedModes への移行

### iOS 26+ での新API

1. **`OpenIntent`プロトコル**: アプリを開くIntentの専用プロトコル
2. **`supportedModes`**: `openAppWhenRun`を置き換える新しいプロパティ
3. **`IntentModes`**: `.foreground(.dynamic)`, `.foreground`, `.background` 等

### supportedModes 一覧

| モード | 用途 |
|--------|------|
| `.background` | バックグラウンド実行（アプリを開かない） |
| `.foreground` | フォアグラウンドでアプリを開く |
| `.foreground(.dynamic)` | 動的フォアグラウンド（`ForegroundContinuableIntent`の後継） |
| `.foreground(.immediate)` | 即座にフォアグラウンド |

**注意**: `ForegroundContinuableIntent`はiOS 26で非推奨。`supportedModes`に`.foreground(.dynamic)`を含めること。

### OpenIntent の実装

`OpenIntent`プロトコルには`target`パラメータ（`AppEnum`型）が必要。**同じ`AppEnum`型を複数のOpenIntentで使用することはできない**。

```swift
// 画面を表す AppEnum
public enum AppScreenTarget: String, AppEnum {
    case addTodo, todoList, incompleteTodos, favoriteTodos
    // ...
}

// 統一された LaunchAppIntent
public struct LaunchAppIntent: OpenIntent {
    public static var title: LocalizedStringResource = "Open Todo App"
    public static var supportedModes: IntentModes { .foreground(.dynamic) }

    @Parameter(title: "Target")
    public var target: AppScreenTarget

    @MainActor
    public func perform() async throws -> some IntentResult {
        switch target {
        case .addTodo:
            IntentAppState.shared.requestShowAddTodo()
        default:
            break
        }
        return .result()
    }
}
```

### 比較表

| 項目 | iOS 18以前 | iOS 26+ |
|------|-----------|---------|
| アプリを開く | `openAppWhenRun = true`（不安定） | `OpenIntent` + `supportedModes` |
| バックグラウンド実行 | `openAppWhenRun = false` | `supportedModes: .background` |
| 動的フォアグラウンド | `ForegroundContinuableIntent` | `supportedModes: .foreground(.dynamic)` |

---

## Control Widget の制約

### ControlConfigurationIntent と SetValueIntent の非互換性

`ControlConfigurationIntent`と`SetValueIntent`を同時に準拠させることができない。

```swift
// ❌ コンパイルエラー
struct ToggleControlIntent: ControlConfigurationIntent, SetValueIntent {
    @Parameter(title: "Value")
    var value: Bool  // ControlConfigurationIntentではoptionalが必須
}

// ✅ ControlWidgetButton でトグル操作を実装
ControlWidgetButton(action: ToggleUrgentTodoControlIntent()) {
    Label { ... } icon: { ... }
}
```

### ConfigurationIntent のモジュール境界問題

Widget Extension内で定義した`ControlConfigurationIntent`は、アプリ本体から参照できない。SwiftのモジュールName Manglingが原因。

**解決策**: `StaticControlConfiguration`を使用し、ConfigurationIntentを必要としない設計にする。

### ControlConfigurationIntent のフィードバック制限

`ControlConfigurationIntent`は`.result(dialog:)`をサポートしていない。

| 手段 | サポート |
|------|---------|
| dialog パラメータ | ❌ |
| 視覚的状態変化 | ✅ |
| システムハプティック | ✅ |
| ローカル通知 | ✅ |

---

## iOS 26 トラブルシューティング: Control Widget からアプリを開く

### 結論（2026-04-12 更新）

**`ControlWidgetButton` + foreground Intent でアプリを開くことは可能。ただし `kind` の設定が正しいことが前提条件。**

ワークショップ（01/Mood）で `ControlWidgetButton(action: OpenMoodCreatorIntent())` による起動に成功。2026-03 時点の「全パターン失敗」という記録は、**`kind` が Extension の Bundle ID 形式と一致していなかったことが原因の可能性が高い**。

#### 正しい `kind` の設定

公式ドキュメントは `kind` を "A string that uniquely identifies the type of control." とのみ説明しており、形式の要件は明記されていない。ただし**公式サンプルコードは全て reverse-domain 形式**を使用している：

```swift
// Apple公式ドキュメントのサンプル
static let kind: String = "com.example.MyApp.TimerToggle"
static let kind: String = "com.yourcompany.GarageDoorOpener"
```

IntentTodo での正しい設定：

```swift
// ❌ 前回の設定（short name — 公式サンプルと異なる形式）
static let kind = "QuickAddTodoControl"

// ✅ 正しい設定（reverse-domain 形式）
static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl"
```

#### `ControlWidgetButton` + `OpenIntent` は公式サポート

Apple公式ドキュメント（"Adding refinements and configuration to controls"）に明示的なサンプルがある：

```swift
// Hint Text: "Hold to Open MyApp"
struct MyAppLauncher: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(...) {
            ControlWidgetButton(
                action: OpenMyAppIntent(),
                ...
            )
        }
        .displayName("MyApp")
    }
}
```

Apple はこの組み合わせを最初から想定して設計していた。2026-03 の時点で動作しなかったのは `kind` の形式が原因だった可能性が高い。

#### 採用すべき実装（`.foreground(.immediate)` + `ControlWidgetButton`）

```swift
// Intent 側
struct OpenAddTodoControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Add Todo"
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// Control Widget 側
struct QuickAddTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenAddTodoControlIntent()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
    }
}
```

#### `.background` + 通知パターンについて

現在の IntentTodo はこのパターンで実装されているが、`kind` を修正して foreground Intent に切り替えることで、より直接的な UX が実現できる。通知を挟む必要がなくなる。

### 採用した解決策: `.background` + 通知パターン

アプリを開く代わりに、`.background`モードのIntentで処理を行い、ローカル通知でユーザーにフィードバックを提供する。

```swift
struct QuickAddTodoNotifyIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Todo"
    static var supportedModes: IntentModes { .background }

    @MainActor
    func perform() async throws -> some IntentResult {
        ControlNotificationHelper.sendQuickAddNotification()
        return .result()
    }
}
```

### `import TodoAppIntents` の影響について

Widget Extension内でパッケージの `import TodoAppIntents` を使用する場合:

- **`.background`モードのIntent**: 正常に動作する（`perform()`は呼ばれる）
- **`.foreground`モードのIntent**: 動作しない（アプリが開かない）
- **`OpenIntent`**: システムは認識するがアプリは起動しない

当初「`import TodoAppIntents`が全Control Widgetを壊す」と推測したが、実際には**foreground/OpenIntentパターンのみが影響**を受ける。`.background`パターンは問題なく動作する。

### 試行した全アプローチと結果一覧

以下はiOS 26正式版での検証結果:

| # | アプローチ | perform() | アプリ起動 |
|---|-----------|-----------|-----------|
| 1 | OpenIntent を ControlWidgetButton に直接渡す | 不明 | ❌ |
| 2 | .background AppIntent + 通知テスト | ✅ | ❌ |
| 3 | .background + openAppWhenRun = true | - | ❌ |
| 4 | .background + .result(opensIntent:) チェイン | ✅ | ❌ |
| 5 | [.background, .foreground(.deferred)] + continueInForeground() | - | ❌ |
| 6 | supportedModes: .foreground(.immediate) | ❌ | ❌ |
| 7 | ControlConfigurationIntent + OpenURLIntent | ❌ | ❌ |
| 8 | OpenURLIntent を直接使用 | - | ❌ (権限エラー) |
| 9 | UIApplication.value(forKeyPath:) | - | ❌ (nil) |
| 10 | EnvironmentValues().openURL() | - | ❌ |

### 重要な発見

- **`perform()` は `.background` モードで確実に呼ばれる**（通知で確認済み）
- システムは `openAppWhenRun: YES` や `OpenIntent` を認識するが、アプリ起動アクションが実行されない
- Widget Extensionプロセスには LaunchServices データベースへのアクセス権限がない
- `ControlWidgetButton` に OpenIntent 用の専用 initializer が公式ドキュメントに存在する（"Creates a button template for a control that launches an app"）が、iOS 26では動作しない

### Home Widget との比較

Home Widget（WidgetKit）では `Link(destination:)` を使用してアプリを開くことが可能。これはApple公式ドキュメントで推奨されているパターン:

> "An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use Link"

つまりHome WidgetのLink使用は制限ではなく**公式推奨**。

### 今後の対応

1. Apple Developer Forumsで同様の報告を探す
2. Feedback Assistantでバグレポート提出
3. 次期Xcode/iOSベータでの動作確認
4. 最小再現プロジェクトでの検証
