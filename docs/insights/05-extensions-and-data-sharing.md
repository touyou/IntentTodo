# Extension とデータ共有

## Extension ターゲットの基本制約

### WidgetBundle の明示的登録

WidgetやControlWidgetは、定義しただけでは動作しない。必ず `WidgetBundle` に登録する必要がある。

```swift
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        // Widget Extension プロセスで .background Intent の @Dependency を
        // 解決するために同期登録する (詳細は 06-control-widget-ios26.md)。
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
    }

    var body: some Widget {
        IntentTodoWidget()           // ホーム画面ウィジェット

        // ControlWidget は visionOS で提供されないので #if で除外。
        // `if #available(iOS 18.0, *)` では型解決を止められない。
        #if !os(visionOS)
        QuickAddTodoControl()     // コントロールセンター
        TodoCountControl()
        ToggleUrgentTodoControl()
        #endif
    }
}
```

### Extension ターゲットごとの ModelContainer

各Extension（Widget、LiveActivity）は独立したプロセスで動作するため、ModelContainerを個別に作成する必要がある。

---

## App Groups によるデータ共有

### 問題: Extension とメインアプリのデータ分離

各ターゲットで個別に`ModelContainer`を作成すると、**データベースファイルが異なりデータが共有されない**。

### 解決策: SharedModelContainer

App Groupsを使用して共有コンテナにデータベースを配置する。

```swift
public enum SharedModelContainer {
    public static let appGroupIdentifier = "group.com.example.MyApp"

    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    public static func createContainer() throws -> ModelContainer {
        if let containerURL = sharedContainerURL {
            let storeURL = containerURL.appendingPathComponent("MyApp.store")
            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        }
        return try ModelContainer(for: schema)
    }
}
```

### 全ターゲットで統一して使用

```swift
// Main App / Widget / LiveActivity / Control Center 全て同じ
let container = try SharedModelContainer.createContainer()
```

### Xcodeでの App Groups 設定手順

1. **メインアプリターゲット**: Signing & Capabilities → + Capability → App Groups
2. **各Extensionターゲット**: 同様に App Groups を追加
3. **全ターゲットで同じ識別子を使用**

**重要**: この設定はXcodeで手動で行う必要がある。

### watchOS の注意点

watchOS と iOS は別デバイスのため、App Groups では直接データ共有できない。Watch Connectivityを使用するか、CloudKitで同期する必要がある。

### マイグレーションは 1 プロセス（アプリ本体）だけが担当する

複数プロセス（アプリ本体 / Widget / LiveActivity）が同じ App Group 上の store を共有する場合、**スキーマのマイグレーションを走らせるプロセスを 1 つに固定する**必要がある。

> **出典なしの伝聞**（2026-08-12 に追跡を打ち切り）: この指針はかつて「WWDC 2026 SwiftData Group Lab (session 8017)」由来として記録していたが、`docs/references/wwdc/` にも Apple の公開セッション一覧にも session 8017 は存在しない（Group Lab は 8011 の Apple Intelligence のみ）。一次資料を用意できないため出典表記を外し、**根拠は下記の理由付けのみ**として扱う。理由付け自体は妥当なので運用は維持する。経緯: [docs/devlog/05-extensions-and-data-sharing.md](../devlog/05-extensions-and-data-sharing.md)

> 複数プロセスから同じデータベースを触るなら、マイグレーションを担当するプロセスをひとつに決める。アプリ本体を担当にして、Widget や Extension はマイグレーション完了後のファイルを読み書きする構成にする。**新バージョンへの更新後、アプリ本体より先に Widget が動く場合もある**ため、Widget / Extension 側にはマイグレーションプランを含めない。必要ならアプリの起動を促す。

理由は、アプリ更新直後は **アプリ本体より先に Widget / Extension プロセスが起動し得る** ため。両者がマイグレーションプランを持っていると、Extension が古い→新しいスキーマへの移行を先に試み、本体のマイグレーションと競合する危険がある。

本プロジェクトでの現状と指針:

- 現状 `SharedModelContainer.createContainer()` は全ターゲット共通で、**まだ `SchemaMigrationPlan` を導入していない**ため問題は顕在化していない。
- 将来スキーマ変更でマイグレーションプランを導入する際は、**マイグレーションプランを渡すのはアプリ本体の `ModelContainer` だけ**にする。Widget / LiveActivity が使うコンテナはマイグレーションプラン無し（= 移行済みファイルを読むだけ）で構成する。
  - 例: `SharedModelContainer.createContainer(migrationPlan:)` のように引数化し、アプリ本体だけがプランを渡す。Extension は引数なしで呼ぶ。
- Extension が「まだ移行されていない store」を読む可能性に備え、Extension 側の起動失敗時は **アプリ起動を促す**フォールバック（`Link` でアプリを開く等）を用意しておくと安全。

---

## UserDefaults の App Group 対応

Extension は別プロセスで動作するため、`UserDefaults.standard` ではデータを共有できない。

```swift
// ❌ 共有されない
UserDefaults.standard.bool(forKey: "someKey")

// ✅ App Group で共有
let sharedDefaults = UserDefaults(suiteName: "group.com.example.MyApp") ?? .standard
sharedDefaults.bool(forKey: "someKey")
```

**ModelContainer** と **UserDefaults** の両方で App Group を使用すること。

---

## Intent から UI へのコミュニケーション

### 基本パターン: @Dependency + NavigationModel

メインアプリプロセスで動作する Intent（SPM 配置で `.foreground` 系のもの）は、`AppDependencyManager` 経由で共有される `NavigationModel` に書き込む。詳細は `04-ui-integration.md` 参照。

```swift
// Intent 側
struct LaunchAppIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Dependency var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showAddTodo()
        return .result()
    }
}
```

### 通知タップ経由の経路: NotificationHandler への NavigationModel 注入

通知タップで `didReceive` デリゲートが発火してアプリが表示されるルートは、Intent 経路とは別。ただしゴールは同じく NavigationModel に書き込むことで UI を更新する。アプリ側 (`App.init()`) で `NotificationHandler.shared.navigationModel` に同じインスタンスを注入しておく。

```swift
// IntentTodoApp.init()
let navigation = NavigationModel()
self.navigationModel = navigation
AppDependencyManager.shared.add(dependency: navigation)   // Intent 経路

#if os(iOS) || os(visionOS) || os(macOS)
MainActor.assumeIsolated {
    NotificationHandler.shared.navigationModel = navigation  // 通知経路
}
#endif
```

```swift
// NotificationHandler
@MainActor var navigationModel: NavigationModel?

@MainActor
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    if isAddTodoAction {
        navigationModel?.showAddTodo()
    }
}
```

旧 `IntentAppState` (UserDefaults + NotificationCenter) は cross-process に届かない `NotificationCenter.post` を含んでおり、`NavigationModel` と機能重複もしていたため撤去。同じ意図は `NavigationModel` への直接注入で十分達成できる。

### Widget / Extension 側から Intent 経由でアプリを操作する場合

Widget Extension の `Button(intent:)` や `ControlWidgetButton(action:)` から SPM 配置の Intent を呼んだ場合、どこで実行されるかはモード次第で挙動が異なる可能性がある。現状の本プロジェクトでは：

- Shortcuts から SPM の Intent 呼び出し → 正常動作（`AppDependencyManager` 経由で main プロセスの依存にアクセス可能）
- Widget の `Button(intent:)` 経由 → Apple 公式は「アプリを開くだけなら `Link(destination:)` を使え」と明記。データ操作は動作検証が必要

アプリ起動が目的の場合は `Link(destination:)` を優先する。

> "An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use `Link` and `widgetURL(_:)`"
> — [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

---

## WidgetKit 更新パターン

### 問題

Widget 内の `Button(intent:)` から呼ばれた Intent は、システムが `perform()` 完了時に自動でタイムラインをリロードすることを保証している（wwdc2023-10028 13:47/10:02）。一方、アプリ本体 / Siri / Shortcuts など **Widget 起点でない経路**でデータを変更した場合はウィジェットは自動更新されないため、明示的にタイムラインの再読み込みが必要になる。全 Intent で無条件に `WidgetReloader.reloadAllWidgets()` を呼ぶ現在のルールは、この判定を省いた安全側の運用（呼び出し重複のコストは無視できる）。経緯は [docs/devlog/05-extensions-and-data-sharing.md](../devlog/05-extensions-and-data-sharing.md) 参照。

### 解決策: WidgetReloader ヘルパー

```swift
public enum WidgetReloader {
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
```

### 全データ変更Intentで呼び出し

```swift
try repository.create(todoItem)
WidgetReloader.reloadAllWidgets()

todoItem.isCompleted.toggle()
try repository.update(todoItem)
WidgetReloader.reloadAllWidgets()
```

`WidgetReloader` は `TodoAppIntents` パッケージ内にあり、`IntentTodoLiveActivity` / `IntentTodoWidget` の両 Extension ターゲットは（Intent 型を使うために）既に `import TodoAppIntents` している。Extension から import できるかどうかはプラットフォーム制約ではなく、Extension ターゲットの SPM 依存グラフに `WidgetReloader` の所在パッケージが含まれているかどうかの問題であり、本プロジェクトでは既に含まれている。全 `WidgetReloader.reloadAllWidgets()` 呼び出しは `TodoService`（`TodoAppIntents` パッケージ内）に集約されており、Extension ターゲットのコードから直接 `WidgetCenter.shared.reloadAllTimelines()` を呼んでいる箇所は無い。依存が無いケースに遭遇したら、`WidgetReloader` の所在パッケージを Extension ターゲットの依存に追加すれば import できる。経緯は [docs/devlog/05-extensions-and-data-sharing.md](../devlog/05-extensions-and-data-sharing.md) 参照。
