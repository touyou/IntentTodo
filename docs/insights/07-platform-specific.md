# プラットフォーム固有の知見

## watchOS 固有の制約

### Button(intent:) の API 差異

watchOS で利用できないのは `role:` 付きの `Button(intent:role:)` シグネチャのみで、`role:` 無しの `Button(intent:)` は watchOS でも問題なく使える。

経緯: [docs/devlog/07-platform-specific.md](../devlog/07-platform-specific.md)

```swift
// ❌ watchOS ではエラー（role: 付きシグネチャが無い）
Button(intent: ToggleTodoCompletionIntent(todo: entity), role: .none) {
    Text("Complete")
}

// ✅ watchOS 対応パターン（role: を外すだけ。システム dispatch 経由なので @Dependency も正常解決される）
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Text("Complete")
}
```

### watchOS 向けのパッケージ分離（現行構成）

watchOS の View・Components・Complication 一式は `Packages/WatchUI` に集約し、Extension ターゲットには `@main` と `TodoComplicationWidget` 宣言だけ残す。これによりプレビュー高速化・再利用・単体テスト可能化が得られる。

```
Packages/WatchUI/Sources/WatchUI/
├── Views/      (WatchTodoListView / WatchTodoDetailView / WatchAddTodoView)
├── Components/ (WatchTodoRow / WatchDueDateLabel)
└── Complication/ (TodoComplicationEntry / Provider / Views)

IntentTodoWatchApp/                # watchOS Extension
├── IntentTodoWatchApp.swift       # @main（WatchUI を import）
└── TodoComplication.swift         # Widget 宣言
```

`WatchUI` は `Package.swift` で `.watchOS(.v26)` のみを宣言することで、iOS/macOS/visionOS 側ターゲットから誤って import された場合にコンパイル時に弾ける。

### ナビゲーションは iOS と同じ `NavigationModel` に載せる

watch アプリも `NavigationModel` を `AppDependencyManager` に登録し、`.environment()` で View に
渡す。`WatchTodoListView` は `NavigationStack(path: $navigationModel.path)` +
`.navigationDestination(for: NavigationDestination.self)`（iOS の NavigationSplitView +
`selectedTodo` に対するスタック版）。

これで 3 つが揃う:

- **`AddTodoIntent` が動く**。この Intent は完了時に `navigationModel.dismissAddTodo()` を呼ぶので、
  未登録だと watch では追加が**無音で失敗する**（2026-08-27 に実機シミュレータで確認。
  詳細は `AGENTS.md` の `@Dependency` 節）
- **`OpenTodoIntent`（Siri / Spotlight の「この Todo を開く」）が watch でも遷移先を持つ**。
  `NavigationModel.showDetail(for:)` が `path` に積む値と、一覧の `NavigationLink(value:)` が
  積む値が同じ `NavigationDestination.todoDetail(entity)` なので、両方が同じ入口を通る
- **追加シートの閉じ方が iOS と揃う**。`@Query` の件数差分で閉じる形（旧 watch 実装）は他デバイス /
  ウィジェットからの追加で誤クローズするため使わない

行のタップ先は 2 つに分ける（純正リマインダーの watch アプリと同じ）: 左の丸が完了トグル
（`Button(intent: ToggleTodoCompletionIntent)`）、行本体が詳細への `NavigationLink`。
行全体を完了トグルにすると、説明文や期限の時刻を watch から見る手段が無くなる。

### Onscreen annotation は行ごとに付ける（`forSelectionType:` は効かない）

一覧の `WatchTodoListView` は `List` だが **selection を持たない**（行はトグル +
`NavigationLink`）。`.appEntityIdentifier(forSelectionType:)` は `List` の selection 値の型を
手がかりにする仕組みなので当て先が無い。`WatchTodoRow` / `WatchTodoDetailView` に
`.appEntityIdentifier(EntityIdentifier(for: entity))` を 1 つずつ付ける
（`.appEntityIdentifier` は watchOS 11.4+）。

詳細画面で iOS が使っている `.userActivity` + `appEntityIdentifier` 形は使わない。watch アプリは
`GENERATE_INFOPLIST_FILE = YES` で plist 実体を持たず `NSUserActivityTypes` を宣言できないため、
宣言の要らない単一 annotation の modifier のほうが素直。

**watchOS ではこの経路を自動テストできない**（2026-08-27 実測）。`AppIntentsTesting` は watchOS
にもあり `IntentDefinitions` / `suggestedEntities()` までは通るが、intent の `run()` が
`LNPerformActionPrebuiltErrorCodeActionNotAllowed`（code 4025）で落ちるため、前提データを
作れない。手動確認は #30 に置いている。

---

## macOS native 対応: Delegate の `#if` 分岐 + NotificationHandler 共通化

`@UIApplicationDelegateAdaptor`（UIKit）と `@NSApplicationDelegateAdaptor`（AppKit）は別プロトコル依存なので完全共通化は不可能。SwiftUI マルチプラットフォームで定番とされる Paul Hudson / Swift by Sundell のパターンは、**通知デリゲート本体を cross-platform な 1 クラスに集約し、`#if` で AppDelegate を分岐して、そこから委譲する**構成。

```swift
// 共通 (platform-independent)
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    @MainActor var navigationModel: NavigationModel?

    func install() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([ /* ... */ ])
    }

    @MainActor
    func userNotificationCenter(_: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse) async {
        // ... 共通ロジック
        navigationModel?.showAddTodo()
    }
}

// iOS / visionOS
#if os(iOS) || os(visionOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationHandler.shared.install()
        return true
    }
    // SceneDelegate 結線等
}
#elseif os(macOS)
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NotificationHandler.shared.install()
    }
}
#endif

// @main
@main
struct IntentTodoApp: App {
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var delegate
    #endif
}
```

- `UNUserNotificationCenterDelegate` は iOS / macOS / visionOS / watchOS すべてで同じシグネチャのため、本体の 1 クラス化は堅い選択。
- 埋め込み Extension (`IntentTodoWatchApp.app` / `IntentTodoLiveActivityExtension.appex`) を macOS ビルドから除外するには、`project.pbxproj` の PBXBuildFile に `platformFilter = ios;` を追加する。
- SceneDelegate は UIKit 専用なので `#if os(iOS) || os(visionOS)` で切る（macOS native で `UIScene` は存在しない）。

---

## LiveActivity の Intent 設計

### LiveActivityIntent vs AppIntent

Live Activity から Activity の開始/更新/終了を伴うアクションを実行する場合は `LiveActivityIntent` を使用する（[Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Start-and-stop-Live-Activities-from-App-Intents) より "When you implement your app intent that starts the Live Activity, make sure it inherits from `LiveActivityIntent`."）。

**重要な挙動差**（[ActivityKit / Activity](https://developer.apple.com/documentation/activitykit/activity) および [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) より）:

- Live Activity の**開始**はアプリがフォアグラウンドにある時のみ可能。ただし `LiveActivityIntent` を使えばバックグラウンドからも可能:
  > "You can update or end a Live Activity while your app is in the background, but you can only start a Live Activity while the app is in the foreground, unless you adopt App Intents and start the Live Activity using a `LiveActivityIntent`."
- `LiveActivityIntent` の `perform()` は**アプリプロセス**で実行される:
  > "If you adopt the `LiveActivityIntent` or `AudioPlaybackIntent` protocol, the system runs the app intent in the app's process."
- 通常の `AppIntent` を Widget から呼ぶ場合は、その Intent をウィジェット Extension ターゲットとアプリターゲットの
  両方に追加する必要がある:
  > "If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target."
  この一文は**ターゲットメンバーシップ**（ビルド時にどのターゲットへ含めるか）についての要件であり、実行時に必ず
  Widget Extension プロセスで動くことを意味しない。共有パッケージの Intent がどのプロセスで実行されるかはシステムの
  **ヒューリスティクス**（アプリが起動中ならアプリを優先、等）で決まり、固定するには `allowedExecutionTargets`
  （`.main`/`.appIntentsExtension`/`.widgetKitExtension`）を明示する必要がある（詳細は `03-app-intents-core.md` の
  「`allowedExecutionTargets`」節）。

本プロジェクトでは `ToggleTodoCompletionIntent` と `SnoozeTodoIntent` を `#if os(iOS)` で `LiveActivityIntent` に条件付き準拠させ、Live Activity のボタン経由で `perform()` がアプリプロセス側で実行されるようにしている。

経緯: [docs/devlog/07-platform-specific.md](../devlog/07-platform-specific.md)

### Intent種別の使い分け

| Intent種別 | 用途 | 実行プロセス |
|-----------|------|------------|
| `AppIntent` | Siri/Shortcuts/UI/Widget | Siri/Shortcuts/UI はアプリ、Widget は `allowedExecutionTargets` 未指定ならヒューリスティクスで決定（アプリ起動中はアプリ優先）、指定すればそこに固定 |
| `LiveActivityIntent` | Dynamic Island/ロック画面（Live Activity ボタン） | `perform()` はアプリプロセス（公式保証）。`AppEntity` パラメータの事前解決も iOS 27 実測ではアプリプロセス（後述） |
| `ControlConfigurationIntent` | コントロールセンター設定値 | Extension 配置必須 |

### Live Activity ボタンにも Entity パラメータの Intent をそのまま使う

Live Activity のボタンは Siri / UI と同じ Intent を呼ぶ。Activity が持っているのは id と title だけだが、`TodoAppEntity(id:title:)` で組んで渡せばよい（システムが `perform()` 前に `TodoEntityQuery.entities(for:)` で id から再解決するため、他のフィールドは埋めなくても正しく動く）。

```swift
// Live Activity View 側
let todoEntity = TodoAppEntity(id: context.attributes.todoId, title: context.state.title)
Button(intent: ToggleTodoCompletionIntent(todo: todoEntity)) {
    Label("Complete", systemImage: "checkmark.circle.fill")
}
```

Activity の状態を触る Intent（`activity.end` / `activity.update`）は `#if os(iOS)` で `LiveActivityIntent` に準拠させる。

**LA ボタンからも `TodoAppEntity` パラメータの Intent をそのまま呼ぶ**（id / title だけしか無くても
`TodoAppEntity(id:title:)` で組んで渡す）。iOS 27 では `entities(for:)` も `perform()` もメインアプリ
プロセスで走るため、`IntentTodoLiveActivityBundle.init()` が `AppDependencyManager` に何も登録して
いなくても問題にならない。詳細: `03-app-intents-core.md`

経緯: [docs/devlog/07-platform-specific.md](../devlog/07-platform-specific.md) / [docs/devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

---

## Live Activity の自動管理

### View Modifier パターン

Live Activityの自動開始/終了は、View modifierとして実装することで既存UIに非侵入的に追加できる。

View 変化への追従には `.task(id:)` を使うと `id` 変化のたびにタスクが自動キャンセル＆再起動され、structured cancellation とシリアル実行が保証される（`.onChange` + unstructured `Task {}` ペアより安全）。

```swift
#if os(iOS)
@available(iOS 16.1, *)
struct LiveActivityMonitorModifier: ViewModifier {
    let todos: [TodoItem]

    func body(content: Content) -> some View {
        content.task(id: todos.map(\.id)) {
            await checkAndReconcileActivities()
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

### 設定で無効なときに無言で消えない

`Activity.request` の前に `ActivityAuthorizationInfo().areActivitiesEnabled` を見て抜けるのは
必須（無効な端末で毎回 throw させると reconcile のたびにエラーが溢れる）。ただし**そこで
無言 return すると、ユーザーは「期限が近い todo がロック画面に出てこない」理由に到達できない**。

`TodoLiveActivityManager.startActivity` では抜ける前に:

- `logger.warning` に todoId 付きで残す（`error` にしないのは、ユーザー設定に沿った正常系のため）
- `MissedFeedback.record(.liveActivity)` で記録し、アプリの一覧が設定誘導のバナーを出す
- 逆に有効に戻っていたら記録を消す（バナーを出し続けない）

仕組みの本体は `docs/insights/06-control-widget-ios26.md`「唯一の伝達手段が塞がれたら記録して
設定へ送る」。

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

## プラットフォームガードの指針

プロジェクト全体で一貫した `#if` 条件を使い分ける指針。

| 条件 | 用途 | 代表例 |
|------|------|--------|
| `#if os(iOS)` と `os(visionOS)` の OR | UIKit 依存コード | `@UIApplicationDelegateAdaptor`、`UISceneConfiguration`、`.navigationBarTitleDisplayMode`、`.topBarTrailing` (iOS/iPadOS/visionOS のみ) |
| `#if os(macOS)` | AppKit 依存コード | `@NSApplicationDelegateAdaptor`、`NSApplicationDelegate` |
| `#if os(iOS)` | ActivityKit など iOS だけの API | `Activity<...>.request`、LiveActivity 関連の全て |
| `#if !os(visionOS)` | visionOS 非対応の API | `ControlWidget`、`ControlWidgetButton`、`StaticControlConfiguration` |
| `#if os(watchOS)` | watchOS 専用 | Complication 関連（`AccessoryWidgetBackground` 等） |

**根拠**:
- `@UIApplicationDelegateAdaptor` と `@NSApplicationDelegateAdaptor` は別プロトコル依存のため完全共通化は不可。プロジェクトでは `NotificationHandler` を cross-platform 実体として共通化し、Adaptor 宣言と AppDelegate 実装だけを `#if` 分岐する（Paul Hudson / Swift by Sundell の定番パターン）。
- `ControlWidget` は Apple 公式 "Developing a WidgetKit strategy" の対応表で iPhone / iPad / Apple Watch / Mac 対応、visionOS のみ非対応と明記されているため、正しいガードは `#if !os(visionOS)`。
- `if #available(iOS 18.0, *)` は実行時版チェックでありコンパイル時の型解決は止められない。プラットフォーム非対応 API には条件付きコンパイル（`#if`）が必須。

経緯: [docs/devlog/07-platform-specific.md](../devlog/07-platform-specific.md)

### `#if canImport(X)` だけに頼らない（新 SDK で実機ビルドが落ちる罠）

`canImport(FrameworkX)` は「そのフレームワークが import 可能か」しか見ず、「その中の **API が当該プラットフォームで available か**」までは保証しない。SDK が更新されてフレームワーク自体はどのプラットフォームでも import 可能になったが、特定 API は一部プラットフォーム非対応、というケースで**シミュレータは通るのに実機ビルドだけ落ちる**という見えにくい失敗になる。

具体例: `VisualIntelligence`（Visual Intelligence / #297）。
- **visionOS シミュレータ**: `canImport(VisualIntelligence)` が false → コード除外 → ビルド成功
- **visionOS 実機 SDK**: `canImport` が true になり `.visualIntelligence.semanticContentSearch` スキーマ（visionOS 非対応 API）までコンパイル → `'visualIntelligence' is unavailable in visionOS` でビルド失敗

```swift
// ❌ import 可否しか見ていない → visionOS 実機で崩れる
#if canImport(VisualIntelligence)

// ✅ 非対応プラットフォームを明示的に外す
#if canImport(VisualIntelligence) && !os(visionOS)
```

教訓:
- `canImport` はあくまで「存在チェック」。API の対応プラットフォームが限定される機能では **`&& !os(...)` / `&& os(...)` を併用**する。
- **シミュレータのビルド成功を「その OS で通る」根拠にしない**。Xcode Cloud / アーカイブは実機（device）SDK でビルドするので、実機向け（`Any <OS> Device`）でも確認する。両者で `canImport` の結果が変わりうる。
- 機能が Intent + Query など複数ファイルの対で構成される場合、ガードは**全ファイルで揃える**（片方だけ外すと相互参照が dangling する）。

経緯: [docs/devlog/07-platform-specific.md](../devlog/07-platform-specific.md)

## `#Predicate` の Optional 比較回避

`#Predicate<TodoItem> { $0.id == optionalUUID }` のように **非 Optional のプロパティを Optional の値と比較する**式はコンパイルが通らない（`value of optional type 'UUID?' must be unwrapped to a value of type 'UUID'`）。

Xcode 27 beta 5 / iOS 27 で再検証した結果、これは**プラットフォーム差でも toolchain バージョン差でもなく `#Predicate` マクロ固有の制約**と確定した。素の Swift や普通のクロージャでは Optional の暗黙昇格が効いて `nonOptional == optional` が通るが、`#Predicate` の展開後は両辺の型が一致していることを要求するため昇格が働かない。落ちるのは 1 パターンだけ:

| 式 | 結果 |
|---|---|
| 非 Optional プロパティ == Optional 値（`$0.id == optionalUUID`） | ❌ コンパイルエラー |
| Optional プロパティ == Optional 値（`$0.dueDate == optionalDate`） | ✅ |
| Optional プロパティ == 非 Optional 値（`$0.dueDate == date`） | ✅ |
| Optional プロパティ != nil | ✅ |
| 素の Swift / 普通のクロージャで `$0.id == optionalUUID` | ✅（`#Predicate` の外なら通る） |

回避策は:

1. 非 Optional な定数を capture してから比較する（推奨）
   ```swift
   let targetId = UUID(uuidString: entity.id) ?? UUID()  // 失敗時はマッチしない値
   _todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
   ```
2. どうしても難しい場合は `Query()` 全件取得 + computed property で in-memory filter

`TodoItem.id` が非 Optional `UUID` である限り、上記 1 で SwiftData の store 側フィルタを効かせられる（全件フェッチよりも効率的）。

経緯: [docs/devlog/07-platform-specific.md](../devlog/07-platform-specific.md)

## `Button(intent:role:)` の引数順

Swift 6 以降、`Button(role:intent:)` の順が正（`role` が先）。`Button(intent:, role:)` の形だと別の `init` に解決されて `"extraneous argument label 'intent:'"` エラーになることがある。UI レビューで引数順の混在を見つけたら `role:` が先になっているかを確認する。

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
