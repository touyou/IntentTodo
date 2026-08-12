# Control Widget と iOS 26

## supportedModes の使い分け

[Apple 公式 `supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) より (抜粋)：

- `.background` — バックグラウンド実行（アプリを開かない）。`openAppWhenRun = false` と同等の挙動
- `.foreground` / `.foreground(.immediate)` — パラメータ解決後すぐフォアグラウンド（`openAppWhenRun = true` と同等の挙動）
- `.foreground(.dynamic)` — 実行中に動的に判断。**`ForegroundContinuableIntent` の後継**（[公式](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent)が "This protocol is deprecated" と明記）
- `.foreground(.deferred)` — 初期バックグラウンド → 自動 foreground 化

---

## Control Widget の実装

### Button と Toggle の使い分け

Apple の線引きは明確で、**対象が固定されているか**で決まる。

| | 用途 | 必要な Intent | 公式の説明 |
|---|------|--------------|-----------|
| `ControlWidgetButton` | fire-and-forget。状態を持たない | `AppIntent` / `OpenIntent` | "Buttons don't have state; use them for fire-and-forget actions such as playing a sound or launching an app" |
| `ControlWidgetToggle` | 2 状態の切り替え | `SetValueIntent where ValueType == Bool` | "Toggles are controls that have two states, 'off' and 'on'" |

`isOn` は **provider が次のリロードで読み戻せる永続的な bool** でなければならない。「最も緊急な Todo を完了する」のように対象が動くアクションは、完了させると provider が別の（未完了の）Todo を返して on 状態が永続しないため Toggle にできない。Toggle にするなら対象を固定する — `AppIntentControlConfiguration` + `ControlConfigurationIntent` でユーザーに選ばせる（Apple のサンプル TimerToggle / GarageDoorOpener もすべて「設定で選ばれた特定 entity」に対する操作）。

本プロジェクトの `ToggleTodoControl` がこの形：

```swift
struct ToggleTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.ToggleTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in
            ControlWidgetToggle(
                snapshot.title,
                isOn: snapshot.isCompleted,
                action: SetTodoCompletionIntent(todoId: snapshot.todoId ?? "")
            ) { isOn in
                Label(isOn ? "Completed" : "To Do", systemImage: isOn ? "checkmark.circle.fill" : "circle")
                    .controlWidgetActionHint(isOn ? "Complete Todo" : "Reopen Todo")
            }
        }
        .promptsForUserConfiguration()   // 対象未設定だと機能しないコントロールなので
        .displayName("Complete Todo")
        .description("Complete or reopen a todo you choose.")
    }
}
```

実装上の注意点:

- **action Intent は絶対値で受ける**。`SetValueIntent` の `value` はシステムが「トグルが移った先の状態」で埋める（"Don't set or manage the value parameter"）。Toggle はその状態に収束しなければならないので、flip する `toggleCompletion` ではなく `TodoService.setCompletion(todoId:isCompleted:)` のような絶対値 API を呼ぶ。
- **パラメータは `todoId: String`**。`TodoAppEntity` パラメータにすると Extension プロセスでの事前 entity 解決フェーズを踏む（`03-app-intents-core.md` の Primary / FromExtension 分離パターンと同じ理由）。呼出元が id を知っているので解決自体が不要。
- **configuration の entity スナップショットは古い**。選んだ時点の値しか持たないので、`currentValue(configuration:)` で id からストアを引き直して title / isCompleted を取る。設定後に削除されていたら未設定表示に戻す。
- **ConfigurationIntent の置き場所**は、アプリ本体から参照する必要が無いなら Widget Extension 内でよい（SPM に置くと watchOS / visionOS を含む全ターゲットでコンパイルされる）。共有が必要になったときだけ SPM へ移す（後述「モジュール境界」）。

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

値を表示するタイプの Control（カウント表示・次の期限など）は、`StaticControlConfiguration(kind:provider:)` に `ControlValueProvider` を渡し、body ではその値を受け取るだけにする。非同期でのデータ取得は `ControlValueProvider` の役割であり、reload 時にシステムが `ControlValueProvider` → `body` の順で実行する（wwdc2024-10157 9:51 / 11:22）。body 内で直接 SwiftData fetch すると、この非同期取得と描画の分担モデルに沿わない（body は同期的に値を描くだけであるべき）ため避ける。

経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)

```swift
struct TodoCountControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { count in
            ControlWidgetButton(action: LaunchAppIntent.incompleteTodos()) {
                Label { Text("\(count)") } icon: { Image(systemName: "checklist") }
                    .controlWidgetActionHint("Show Incomplete Todos")
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap to open the list.")
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

複数の値を返したい場合は `Snapshot` のような値型を自前で用意して `currentValue()` で返す（本プロジェクトの `ToggleTodoControl.Snapshot` 参照）。

### kind は reverse-DNS 形式で統一

本プロジェクトでは `dev.touyou.IntentTodo.<Target>.<WidgetName>` に統一している。対象は以下のすべて:

| 種別 | 例 |
|------|-----|
| ControlWidget (3 種) | `dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl` など |
| ホーム Widget | `dev.touyou.IntentTodo.IntentTodoWidget` |
| watchOS Complication | `dev.touyou.IntentTodo.IntentTodoWatchApp.TodoComplication` |

Apple 公式の全サンプル（[Creating controls to perform actions across the system](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)）も `com.example.MyApp.TimerToggle` の形式。短い名前でも動作することは確認済みだが、システム全体で一意識別される文字列なので他アプリと衝突しにくい reverse-DNS 形式が安全。

### ControlConfigurationIntent と SetValueIntent

wwdc2024-10157 のモデルでは configuration intent（設定パラメータ用）と action intent（`SetValueIntent` 等）はそもそも**別々の Intent** として設計する。本プロジェクトの `ToggleTodoControl` もこの分離に従い、対象選択は `SelectTodoConfigurationIntent`（`ControlConfigurationIntent`）、トグル操作は `SetTodoCompletionIntent`（`SetValueIntent`）と別々に定義している。設定が不要な `QuickAddTodoControl` / `TodoCountControl` は `StaticControlConfiguration` のまま。

経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)

### ControlConfigurationIntent のモジュール境界

Widget Extension 内で定義した `ControlConfigurationIntent` はアプリ本体から参照できない。原因は単純な**ターゲット/モジュール境界**（Extension ターゲットの型は別モジュールなのでアプリ側から import できない、Swift の通常のアクセス制御と同じ話）。共有したい場合は SPM パッケージへ型を移すのが公式サポートされた方法（wwdc2025-244 22:34）。

本プロジェクトの `SelectTodoConfigurationIntent` はアプリ本体から参照する必要が無いので Widget Extension 内に置いている。SPM に置くと watchOS / visionOS を含む全ターゲットでコンパイルされるため、共有が必要になるまでは Extension 内が既定。

経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)

### Control のフィードバック: dialog も snippet も出ない（実機で切り分け済み）

Control Center から `ControlWidgetButton` / `ControlWidgetToggle` 経由で Intent を実行しても、**`.result(dialog:)` も `snippetIntent:` も提示されない**。どちらも実機確認済み（dialog: 2026-04-14 / snippet: 2026-08-12）。

snippet のほうは Apple の記述が割れており、**ドキュメントの肯定リストだけでは判断できない**:

| 出典 | 示唆 |
|------|------|
| AppIntents [Visual presentation](https://developer.apple.com/documentation/AppIntents/visual-presentation) | "**Siri, Spotlight, and the Shortcuts app** display snippets" — Control は列挙されない |
| wwdc2025-281 0:29 | "This includes Spotlight, Siri, and the Shortcuts app" — 同上 |
| **wwdc2025-275 1:40–1:59** | "**I'll tap on the control that runs an App Intent** […] the intent will show a snippet […] **The snippet will immediately update**" — コントロールのタップから snippet が出ているように見える |

肯定リストは Control を明示的に除外していないので「列挙に無い＝出ない」とは読めず（この推論で一度設計を誤った）、デモとも矛盾する。そこで**同一 Intent・同一 snippet を呼出元だけ変えて比較**した:

| 条件 | 結果 |
|---|---|
| Spotlight → `ShowTodoCountIntent`（→ `TodoSummarySnippetIntent`）| **出る** ✅ |
| Control（Button）→ 同じ Intent・同じ snippet | **出ない** ❌ |
| 同上 + `allowedExecutionTargets = [.main]`（アプリプロセスに固定）| **出ない** ❌ |
| Control（Toggle / `SetValueIntent`）→ `TodoSnippetIntent` | **出ない** ❌ |

snippet 実装・パラメータの有無・実行プロセス・`isDiscoverable` はいずれも Spotlight 側で同条件のまま成立しているため、**残る差分は「呼出元が Control であること」だけ**。よって Control は snippet の提示先ではないと結論した（iOS 27 / Xcode 27 beta 5）。wwdc2025-275 の "control" は Control Center のコントロールではなく、アプリ内 UI のボタンを指していたと解釈するのが妥当（直前に "The TravelTracking app contains lots of landmarks" とアプリ画面の話をしている）。

セッション横断でも裏付けが取れている: **Controls 専門の wwdc2024-10157 は snippet にも dialog にも一度も触れず**（挙げるフィードバック手段は上記 3 つのみ）、**Snippets 専門の wwdc2025-281 は control / Control Center に一度も触れない**。wwdc2024-10210 も "Or add actions and **status** to Control Center" と status 止まりで、コントロールのアクションはアプリを開く `OpenTrail`。唯一の反例に見えた wwdc2025-275 は、そもそも "Control Center" / "controls" / "ControlWidget" という語を全編で一度も使っておらず（他セッションは必ず明示する）、あの "the control" はアプリ内 UI のボタンを指していたと読むのが自然。

> **教訓**: 呼出元だけを変えて同じ Intent を走らせる比較が、この手の「どの面が何を提示するか」を
> 最短で確定させる。逆に肯定リストからの推論や、複数の変数（プロセス・形状・実装）を同時に
> 動かした実験では、いつまでも確定しない。

Control に**公式に**用意されているフィードバック経路は次の 3 つ:

1. **`perform()` 完了時の自動リロード**による、コントロール自身の再描画（"the system automatically reloads it when the control's app intent's `perform()` function returns"）
2. `controlWidgetStatus(_:)` — 操作時に Control Center へ一時表示されるステータス文字列
3. `controlWidgetActionHint(_:)` — Action button のヒント文（動詞始まり）

> **本プロジェクトの運用方針**: 成功時のフィードバックは **(1) コントロール自身の再描画**で行い、
> ローカル通知は送らない。Toggle なら on/off が、`TodoCountControl` なら未完了数が、
> コントロール面にそのまま出るため、通知は二重表示になるうえ通知センターに残り続ける。
>
> `controlWidgetStatus(_:)` も公式ガイダンス（"Use status text sparingly and only in situations
> where important information isn't conveyed by the control"）に従い、**コントロールが既に
> 伝えている情報には使わない**。現状 3 種いずれも該当しないため未使用。
>
> **失敗時だけはローカル通知**（`ControlNotificationHelper.sendErrorNotification`）。失敗すると
> コントロールは前の状態のまま再描画されるので、「何も起きなかった」と区別できないため。
>
> 件数サマリのような「読ませたい情報」は Control ではなく **Siri / Spotlight / Shortcuts 側**に
> 寄せる（`ShowTodoCountIntent` / `GetTodoSummaryIntent` が dialog +
> `snippetIntent: TodoSummarySnippetIntent()` を返す。Spotlight で表示を実機確認済み）。
> Control 側は「その場で完結する即時アクション + 状態表示」に徹し、読ませたい情報が
> 主目的なら `LaunchAppIntent` でアプリの該当画面に送る（`TodoCountControl` が未完了一覧を開くのがこれ）。

### Extension プロセスでも `TodoEntityStore` を登録する

`SnippetIntent`（`TodoSnippetIntent` / `TodoSummarySnippetIntent`）と `TodoAppEntity` の deferred property は `@Dependency` を使えないため `TodoEntityStore.container` からコンテナを読む。アプリ側 (`IntentTodoApp.init`) だけに登録していると、**Widget Extension プロセスで解決されたときに中身が空になり「Todo not found」を描く**。Widget / Control の Intent は既定でどちらのプロセスでも実行されうるので、`IntentTodoWidgetBundle.init()` でも登録しておく。

```swift
MainActor.assumeIsolated {
    AppDependencyManager.shared.add(dependency: todoService)
    TodoEntityStore.register(container: sharedWidgetModelContainer)   // ← これ
}
```

`@Dependency`（`AppDependencyManager`）と `TodoEntityStore` は**別々の登録**である点に注意。前者だけ登録して満足すると、Intent は動くのに snippet だけ空、という切り分けにくい症状になる。

経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)

### visionOS 非対応: `#if !os(visionOS)` でガード

Apple 公式 [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy#Review-system-experiences-for-each-platform) の "Review system experiences for each platform" セクションにある対応表で、Controls は **iPhone / iPad / Apple Watch / Mac で Yes、Apple Vision Pro のみ No** と明記されている。

経緯: [docs/devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)

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
public struct SetTodoCompletionIntent: SetValueIntent {
    public static let title: LocalizedStringResource = "Set Todo Completion"
    public static let supportedModes: IntentModes = [.background]
    public static let isDiscoverable = false   // Control 専用（Siri/Shortcuts には出さない）

    @Parameter(title: "Todo ID")
    public var todoId: String

    /// システムがトグルの遷移先状態で埋める。自分で設定しないこと。
    @Parameter(title: "Completed")
    public var value: Bool

    @Dependency
    var todoService: TodoService

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.setCompletion(todoId: todoId, isCompleted: value)
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

### 失敗時のフィードバックだけローカル通知で

成功はコントロール自身の再描画で伝わる（上記「Control では dialog も snippet も表示されない」参照）。
一方**失敗は前の状態のまま再描画されるだけ**で「何も起きなかった」と区別できないため、ここだけ通知で補う。

```swift
do {
    try todoService.setCompletion(todoId: todoId, isCompleted: value)
} catch {
    ControlNotificationHelper.sendErrorNotification(
        message: "Couldn't update the todo. Open the app to retry.",
        todoId: todoId   // appEntityIdentifiers に紐付け (WWDC 2026 #343)
    )
    throw error
}
```

`ControlValueProvider` / `AppIntentControlValueProvider` の `currentValue()` 側は通知ではなく **throw** する
（"You can also throw an error to tell the system that the state couldn't be computed" — wwdc2024-10157 10:26）。
`try?` で `0` や `.empty` に潰すと「全部完了」「期限近い Todo なし」という嘘を表示してしまう。
