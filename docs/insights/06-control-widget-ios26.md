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

値を表示するタイプの Control（カウント表示・次の期限など）は、`StaticControlConfiguration(kind:provider:)` に `ControlValueProvider` を渡し、body ではその値を受け取るだけにする。**2026-08-11 理由付け訂正**: 以前「body 過剰評価を避けるため」としていたが、Apple の説明（wwdc2024-10157 9:51 / 11:22）は非同期取得の分担を明確にしている——非同期でのデータ取得は `ControlValueProvider` の役割であり、reload 時にシステムが `ControlValueProvider` → `body` の順で実行する、という設計そのもの。body 内で直接 SwiftData fetch すると、この非同期取得と描画の分担モデルに沿わず（body は同期的に値を描くだけであるべき）、意図しない挙動やタイミング不整合につながる、というのが正確な理由。

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

**2026-08-11 表現訂正**: 「同時準拠できない」という制約表現は誤解を招く。wwdc2024-10157 のモデルでは configuration intent（設定パラメータ用）と action intent（`SetValueIntent` 等）はそもそも**別々の Intent** として設計されており、1 つの Intent に両方の役割を持たせようとした結果「同時に準拠できない」という制約に見えていただけ。本プロジェクトの Control 群（`ToggleUrgentTodoControl` / `QuickAddTodoControl` / `TodoCountControl`）は実際、カスタム `ControlConfigurationIntent` を持たず `StaticControlConfiguration` のみを使い、トグル操作は `ControlWidgetButton(action:)` に渡す独立した `AppIntent`（`SetValueIntent` 準拠ではない）で実装している。役割分離は既に達成できているので、コード変更は不要。

### ControlConfigurationIntent のモジュール境界

**2026-08-11 因果訂正**: Widget Extension 内で定義した `ControlConfigurationIntent` がアプリ本体から参照できない真因は「Name Mangling」ではなく、単純な**ターゲット/モジュール境界**（Extension ターゲットの型は別モジュールなのでアプリ側から import できない、Swift の通常のアクセス制御と同じ話）。共有したい場合は SPM パッケージへ型を移すのが公式サポートされた方法（wwdc2025-244 22:34）。本プロジェクトは `StaticControlConfiguration` を使い ConfigurationIntent 自体を必要としない設計にしているため、この問題は実質発生しない。

### Control Widget からの Intent では `.result(dialog:)` が表示されない

2026-04-14 実機検証で確認: Control Center から `ControlWidgetButton(action:)` 経由で
Intent を実行しても `.result(dialog:)` は UI に出ない。よってフィードバックは
**視覚的状態変化 / システムハプティック / ローカル通知**で代替する必要がある。

> **本プロジェクトの運用方針**: Control Widget はグラス風ミニマム UI が UX 設計語彙で、
> dialog 表示はそもそも設計の一部として想定されていない可能性が高い (Apple 公式には
> 明文記述なし)。本プロジェクトでは by-design 相当として扱い、**Apple Feedback の
> 提出は行わない**。Control 経由で完了メッセージを伝えたい場合は `ControlNotificationHelper`
> 経由でローカル通知を送る運用に統一している (`ToggleUrgentTodoIntent` / `ShowTodoCountIntent` 参照)。
>
> **未検討（2026-08-11 候補追加）**: Apple は Control 専用のフィードバック機構 `.controlWidgetStatus(_:)`
> （wwdc2024-10157）を用意している。ローカル通知はシステムの通知センターに残り続ける副作用があるため、
> 一時的な状態表示が目的なら `.controlWidgetStatus(_:)` の方が UX 上適切な可能性がある。
> `ToggleUrgentTodoIntent` / `ShowTodoCountIntent` で試して通知運用と比較検討する価値あり（未実施）。

### visionOS 非対応: `#if !os(visionOS)` でガード

Apple 公式 [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy#Review-system-experiences-for-each-platform) の "Review system experiences for each platform" セクションにある対応表で、Controls は **iPhone / iPad / Apple Watch / Mac で Yes、Apple Vision Pro のみ No** と明記されている（2026-04-15 時点の iOS 26 ドキュメントで確認済）。

```swift
#if !os(visionOS)
import WidgetKit
// ... Control ウィジェット定義
#endif
```

`if #available(iOS 18.0, *)` は実行時版チェックであり、コンパイル時に visionOS SDK が `ControlWidget` / `ControlWidgetButton` / `StaticControlConfiguration` 型を提供しない問題を回避できない。条件付きコンパイル（`#if`）で型参照自体を切る必要がある。

---

## バックグラウンドアクションパターン

Control Widget でアプリを開かずに処理だけ行いたい場合は `.background` モードの Intent を使う。**このとき `perform()` は既定ではヒューリスティクスでプロセスが決まる**（アプリが起動中ならアプリ本体を優先し、そうでなければ Widget Extension を起動。[WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) 15:59–16:55、`03-app-intents-core.md` の「実行プロセスごとに登録が必要」節参照）。`allowedExecutionTargets` を指定しない限りどちらのプロセスでも起動され得るため、Widget Extension 側でも `AppDependencyManager` に依存を登録しておく必要がある（固定したい場合は `allowedExecutionTargets = [.main]` 等を指定する）。

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
| Widget `ControlWidgetButton(action:)` + `.background`（`allowedExecutionTargets` 未指定） | **ヒューリスティクスで決定**（アプリ起動中はアプリ優先、未起動なら Widget Extension） | **両方**（`App.init()` と `WidgetBundle.init()`、保険として） |
| 同上（`allowedExecutionTargets` で明示指定） | 指定したプロセスに固定 | 指定先のみ |

### フィードバックはローカル通知で

`ControlConfigurationIntent` では `dialog` が使えないため、ユーザーへの結果表示はローカル通知で行う。

```swift
ControlNotificationHelper.sendToggledNotification(todoTitle: todo.title, isCompleted: ...)
```
