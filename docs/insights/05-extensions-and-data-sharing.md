# Extension とデータ共有

## Extension ターゲットの基本制約

### WidgetBundle の明示的登録

WidgetやControlWidgetは、定義しただけでは動作しない。必ず `WidgetBundle` に登録する必要がある。

```swift
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        IntentTodoWidget()           // ホーム画面ウィジェット

        if #available(iOS 18.0, *) {
            QuickAddTodoControl()     // コントロールセンター
            TodoCountControl()
            ToggleUrgentTodoControl() // ← 忘れがち！
        }
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

### 問題

`OpenAddTodoIntent`のようにアプリを開いて特定のUI状態を設定したい場合、IntentからSwiftUIのViewに直接アクセスできない。

### 解決策: SharedState + UserDefaults

```swift
@MainActor
public final class IntentAppState {
    public static let shared = IntentAppState()

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
    }

    public var shouldShowAddTodo: Bool {
        get { sharedDefaults.bool(forKey: Keys.shouldShowAddTodo) }
        set { sharedDefaults.set(newValue, forKey: Keys.shouldShowAddTodo) }
    }

    /// Intent側: 表示をリクエスト
    public func requestShowAddTodo() {
        shouldShowAddTodo = true
    }

    /// UI側: リクエストを消費（一度だけ処理）
    public func consumeShowAddTodoRequest() -> Bool {
        guard shouldShowAddTodo else { return false }
        shouldShowAddTodo = false
        return true
    }
}
```

### View での使用

```swift
public var body: some View {
    NavigationStack { /* ... */ }
        .onAppear {
            if IntentAppState.shared.consumeShowAddTodoRequest() {
                navigationViewModel.showAddTodo()
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if IntentAppState.shared.consumeShowAddTodoRequest() {
                navigationViewModel.showAddTodo()
            }
        }
        #endif
}
```

---

## WidgetKit 更新パターン

### 問題

Intentでデータを変更してもウィジェットは自動更新されない。明示的にタイムラインの再読み込みが必要。

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

Extension内（LiveActivity, Control Widget）では`WidgetReloader`をimportできない場合があるため、`WidgetCenter.shared.reloadAllTimelines()` を直接呼び出す。
