ナビゲーション目的の Intent には `.foreground(.immediate)` が適切。アプリを即座にフォアグラウンドに持ってきてから `perform()` が実行される。

```swift
static let supportedModes: IntentModes = [.foreground(.immediate)]
```

### `onAppIntentExecution` との使い分け

| 方式 | 特徴 |
|------|------|
| `onAppIntentExecution` | 宣言的・View modifier に集約。`TargetContentProvidingIntent` 準拠 Intent が対象。初期 iOS 26 では cold start 時に失敗する可能性 |
| `AppDependencyManager` + `@Dependency` + `perform()` | Intent 側に集約。cold start でも安定。実行プロセスごとに依存登録が必要（`App.init()` だけでなく、Widget 経由の `.background` Intent を使うなら `WidgetBundle.init()` にも登録が必要）|

---

### UISceneAppIntent の制限

**2026-08-11 因果訂正**: 「Package スコープで参照不可」という理由付けは誤り。SPM パッケージは `#if canImport(UIKit)` で UIKit そのものを普通に import できる。実際の障壁は `UISceneAppIntent` が独立した `_AppIntents_UIKit` フレームワークに属し、**このフレームワークが SDK レベルで iOS / watchOS / visionOS には存在するが、ネイティブ macOS には存在しない**こと（Xcode 27 beta 5 SDK で確認: `_AppIntents_UIKit.framework` が macOS SDK 直下には無い）。`TodoAppIntents` は macOS 向けにもコンパイルされるプラットフォームマトリクスのため、`#if canImport(_AppIntents_UIKit)`（または `#if os(iOS) || os(watchOS) || os(visionOS)`）でガードすれば Package 内でも利用できる可能性が高い（必要になったら試す）。マルチウィンドウでのシーン固有ルーティングが必要な場合の代替は変わらず、メインアプリターゲット内でIntentを定義するか、`SceneDelegate`で`connectionOptions`を活用する。

**2026-08-11 追記（iOS シミュレータで実行時確認）**: `RunCodeSnippet` で `#if canImport(_AppIntents_UIKit)` を iOS シミュレータ (iOS 27) コンテキストで実行した結果、`_AppIntents_UIKit: available` と出力され、iOS では実際に import 可能なことを確認した（macOS 側は前述の `.swiftinterface` 静的調査のみで実行時確認はしていない）。ガード方針自体は妥当と裏付けられたが、`TodoAppIntents` に `UISceneAppIntent` を使う具体的なマルチウィンドウ機能が無いため実装は見送り（機能要求が出たら本ガードで着手する）。

---
