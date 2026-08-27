# 開発ログ: UI層とIntent統合

`docs/insights/04-ui-integration.md` の現在のルールが、どういう経緯で今の形になったかを記録する。

## 2026-08-11: watchOS 向け手動 perform() 呼び出し推奨記述を訂正

`07-platform-specific.md` には以前、watchOS 向けに `Task { try? await intent.perform() }` のような手動呼び出しを推奨する記述があった。これは誤りで、`@Dependency` が `AppDependencyManager` から解決されるのは `Button(intent:)` 経由でシステムが dispatch した場合のみのため、手動呼び出しでは `@Dependency` がゼロ初期化のままクラッシュする。2026-08-11 に検証し、`role:` を外した `Button(intent:)` を使えば watchOS でも問題なく動作することを確認、該当ドキュメントの記述を訂正した。

## 2026-08-11: onAppIntentExecution が macOS で使えない理由を SDK 調査で確認

「macOS では onAppIntentExecution が使えない」というルールについて、理由が明確でなかったため Xcode 27 beta 5 SDK の `.swiftinterface` を直接調べて再検証した。`onAppIntentExecution` は `_AppIntents_SwiftUI` フレームワークに実装されており、この配布は iOS / macCatalyst / visionOS / watchOS には存在するが、ネイティブ macOS 向けには存在しない（`MacOSX.sdk` 内では `System/iOSSupport`＝Mac Catalyst 配下にしか同フレームワークが無い）。一方 `TargetContentProvidingIntent`（プロトコル本体、`AppIntents.framework` 側）は macOS でも利用可能で、本プロジェクトの `#if os(iOS) || os(macOS) || os(visionOS)` による準拠は妥当（プロトコル準拠自体はできるが、SwiftUI 側のフック用モディファイアだけが無い、という切り分け）と確認できた。半矛盾を疑ったが、コード側の `#if` 条件と実際の SDK 制約は整合しており修正不要と判断した。

## 2026-04-12: cold start ナビゲーション失敗を App Intents ワークショップで確認

App Intents ワークショップにて、アプリが kill されている状態（cold start）での `onAppIntentExecution` 経由ナビゲーションを検証した。Workshop PDF は "In iOS 26.4 and above this works as before" と説明していたが、実機での体験では 26.4 でも安定して完走しないケースが残ることを確認した。初期 iOS 26（〜26.3）で cold start 失敗が確認され、Workshop PDF では 26.4 で修正と謳われていたが、実機では完全には解消していない印象で、Apple Feedback へ提出するには再現性をさらに詰める必要がある。この結果を受け、本プロジェクトでは `@Dependency var navigationModel` + `perform()` パターンを基本とし、`onAppIntentExecution` 経路は補助的にしか使わない方針にした。

## 2026-08-11: cold start 問題の原因仮説を整理 → 現状は非アクティブな経路と判明

上記の cold start 不安定性を「OS バグ」と断定する前に、切り分けるべき候補が3つ残っていた: ①`.onAppIntentExecution` を付けた View の `@State path` がクロージャ実行時点でまだ構築されていない、②シーンの activation conditions（wwdc2025-275 23:52-24:09「どのシーンが intent をハンドルするかは activation conditions で決まる」）が未設定、③対象 Intent の `supportedModes` に foreground が無くタイムアウトする。ただしコードベースを grep した結果、`.onAppIntentExecution` は実際にはどこにも使われていない（`LaunchAppIntent` が `TargetContentProvidingIntent` に準拠しているのみ）ことが判明した。本プロジェクトは既に `@Dependency var navigationModel` + `perform()` パターンへ完全移行済みで、この cold start 問題は現在アクティブなコードパスではないと確認した。上記3仮説の検証は、`.onAppIntentExecution` を実際に再導入する場面が来たときに行う。

## 2026-08-11: UISceneAppIntent が Package から使えない理由を訂正

「Package スコープで参照不可」という従来の理由付けは誤りだった。SPM パッケージは `#if canImport(UIKit)` で UIKit そのものを普通に import できる。実際の障壁は `UISceneAppIntent` が独立した `_AppIntents_UIKit` フレームワークに属し、このフレームワークが SDK レベルで iOS / watchOS / visionOS には存在するが、ネイティブ macOS には存在しないこと（Xcode 27 beta 5 SDK で確認: `_AppIntents_UIKit.framework` が macOS SDK 直下には無い）。`TodoAppIntents` は macOS 向けにもコンパイルされるプラットフォームマトリクスのため、`#if canImport(_AppIntents_UIKit)`（または `#if os(iOS) || os(watchOS) || os(visionOS)`）でガードすれば Package 内でも利用できる可能性が高いと判断した（必要になったら試す）。マルチウィンドウでのシーン固有ルーティングが必要な場合の代替は変わらず、メインアプリターゲット内で Intent を定義するか、`SceneDelegate` で `connectionOptions` を活用する。

## 2026-08-11: UISceneAppIntent の iOS 実行時確認

上記のガード方針を裏付けるため、`RunCodeSnippet` で `#if canImport(_AppIntents_UIKit)` を iOS シミュレータ（iOS 27）コンテキストで実行した結果、`_AppIntents_UIKit: available` と出力され、iOS では実際に import 可能なことを確認した（macOS 側は前述の `.swiftinterface` 静的調査のみで実行時確認はしていない）。ガード方針自体は妥当と裏付けられたが、`TodoAppIntents` に `UISceneAppIntent` を使う具体的なマルチウィンドウ機能が無いため実装は見送り（機能要求が出たら本ガードで着手する）。

## 2026-08-12: `LaunchAppIntent` のリスト系ターゲットが「アプリを開くだけ」だった

実機で Control Center を触っての指摘から発覚。Add コントロールは追加シートが開くのに、Todo Count
コントロールは**ただアプリが開くだけ**で、押した数字（未完了数）との関係が UI に何も反映されない、
という体験だった。

原因は `LaunchAppIntent.perform()` の実装漏れ:

```swift
switch target {
case .addTodo:
    navigationModel.showAddTodo()
case .todoList, .incompleteTodos, .favoriteTodos:
    break        // ← 何もしていない
}
```

`AppScreenTarget` には `.incompleteTodos` / `.favoriteTodos` が定義され、`caseDisplayRepresentations`
にも「Incomplete Todos」「Favorite Todos」と表示されるので**列挙としては遷移先を約束している**のに、
`perform()` 側は `navigateToRoot()` するだけだった。`NavigationModel` に filter を伝える口（`pendingSearchText`
に相当するもの）が無かったのが根本。Control 経由だけでなく、Siri の「お気に入りの Todo を見せて」
（`ShowTodosIntent` が `opensIntent: LaunchAppIntent(target:)` を返す経路）でも同じく絞り込まれずに
開くだけになっていた。

**対応**: `pendingSearchText` と同じハンドシェイクで `NavigationModel.pendingFilter: TodoFilterType?` を新設し、
`LaunchAppIntent` が `showList(filter:)` で書き込み、`TodoListView` / `VisionOSTodoListView` が
`.onChange` / `.onAppear` で `viewModel.filter` に転写してから nil に戻す。`.onAppear` があるので
cold start（Intent が先、View が後）でも取りこぼさない。

対応表 `LaunchAppIntent.listFilter(for:)` は純関数として切り出してテストした。`perform()` は `@Dependency`
解決が要り SPM テストから叩けないため、同じ穴が再発しても最低限マッピングだけは検知できるようにする狙い
（`ShowTodosIntent.screenTarget(for:)` と同じ方針）。

**教訓**: 画面ターゲットの `AppEnum` に case を足すのと、`perform()` でその状態を書き込むのは別作業。
列挙が約束した遷移先は必ず状態書き込みとセットで実装する。`switch` の `default` / まとめ `case` +
`break` は、この種の「宣言はあるが実装が無い」を静かに隠す。

## 2026-08-12: macOS で `onAppIntentExecution` が使えない理由の説明が誤っていた（C-5 / B-2 再検証）

`04-ui-integration.md` は 2026-08-11 の再検証（B-2）で「`onAppIntentExecution` を実装する `_AppIntents_SwiftUI` フレームワークはネイティブ macOS SDK に存在しない（`MacOSX.sdk` 内では Mac Catalyst 配下にしかない）」「一方 `TargetContentProvidingIntent` は macOS でも利用可能」と結論づけていた。どちらも誤りだった。

`My Mac` destination で `RunCodeSnippet` を実行して実測したところ:

- `#if canImport(_AppIntents_SwiftUI)` → **available**。`_AppIntents_SwiftUI.framework` は macOS 27 SDK の `System/Library/Frameworks/` 直下に実在する。前回の「0 件マッチ」は Xcode 27 beta 5 ではなく `/Applications/Xcode.app`（26.x 系）側を見ていた可能性が高い。
- 同 SDK の macOS スライス `.swiftinterface` に `onAppIntentExecution` の宣言は無い（iOS スライスにはある）。
- `TargetContentProvidingIntent` は macOS の `AppIntents.swiftinterface` に宣言はあるが `@available(macOS, unavailable)` / `@available(watchOS, unavailable)` 付き。実際に macOS ビルドで準拠を書くと `'TargetContentProvidingIntent' is unavailable in macOS` でコンパイルエラーになる。

結論として「macOS では `onAppIntentExecution` が使えない」というルール自体は正しいままだが、理由は**フレームワークの有無ではなく API の availability**。ドキュメント中のガード例も `#if os(iOS) || os(macOS) || os(visionOS)` と macOS を含む誤った形になっていた（実コード `LaunchAppIntent.swift` は `#if os(iOS) || os(visionOS)` で正しい）ため訂正した。

**教訓**: 複数の Xcode が並存する環境では、SDK の静的調査は「MCP / Xcode が実際に使っている Xcode.app」のパスで行う。`xcrun --sdk macosx --show-sdk-path` が返すのは `xcode-select` の指す Xcode であって、作業中の beta とは限らない。

## 2026-08-12: `UISceneAppIntent` は Swift Package 内で定義できる（C-5 決着）

「`UISceneAppIntent` は Swift Package 内 Intent には利用不可（UIKit 依存で Package スコープ参照不可）」という記述は、2026-08-11 に「障壁はパッケージスコープではなく `_AppIntents_UIKit` のプラットフォーム配布差」と因果を訂正済みだったが、パッケージ内に実際に置いてビルドする検証はしていなかった。

今回 `Packages/TodoAppIntents/Sources/TodoAppIntents/` に `UISceneAppIntent` 準拠の probe を置いてビルドし、決着させた:

1. `#if canImport(_AppIntents_UIKit)` だけのガードだと **watchOS ターゲットのビルドが落ちる**（`Cannot find type 'UISceneAppIntent' in scope` / `'UIScene' is unavailable in watchOS`）。watchOS SDK には `_AppIntents_UIKit.framework` が**存在する**ため `canImport` は true になるが、`UISceneAppIntent` は `TargetContentProvidingIntent` 経由で `@available(watchOS, unavailable)` を引き継いでおり型が無い。`IntentTodo` スキームは Watch App を同時にビルドするので iPhone destination のビルドで顕在化した。
2. `#if canImport(_AppIntents_UIKit) && !os(watchOS)` に直すと iPhone 17 Pro Max（iOS 27）/ My Mac / Apple Vision Pro の 3 destination すべてでビルド成功。

つまり Package スコープは障壁ではなく、正しいガードさえ書けば置ける。probe は検証後に削除した（`UISceneAppIntent` を要するマルチウィンドウ機能がまだ無いため実装は見送り）。これは `07-platform-specific.md` の「`#if canImport(X)` だけに頼らない」の 2 例目にあたる。

## 2026-08-27: UI コピーの抽出漏れは「String 型の経由」だけではなかった（#50）

#50 は「`StatusBadge` / `TodoListEmptyView.EmptyContent` が UI コピーを `String` 型で運んでいるため
`Text` / `Label` の verbatim 初期化子が選ばれ、String Catalog に抽出されない」という前提で立てた
issue だった。着手前に `xcodebuild -exportLocalizations` でベースラインを取ったところ、前提が
不完全だと分かった。

- **パッケージ（`UI` / `WatchUI` / `WidgetUI` / `LiveActivity`）の文言は 1 件も抽出されていなかった**。
  `String` 経由かどうかに関係なく、リテラル直書きの `Text("Todos")` も xcloc に出ない。抽出は
  ターゲット単位で、受け皿となる String Catalog を持つターゲットの分しか出力されないため
- 一方で `Add todo titled ${title}` のような **Intent の title は出ていた**。これは AppIntents の
  メタデータ経由でアプリターゲットの catalog に集約されるもので、パッケージの catalog とは別経路。
  この存在が「パッケージの文言も抽出されている」という誤読を招いていた

そのため作業の単位を「issue が挙げた 2 箇所の型を直す」から「**パッケージ単位でローカライズの
土台を入れる**」に広げた。部分適用だと「catalog には載っているのに実行時は `Bundle.main` を見て
引けない」という、より分かりにくい壊れ方になるため（`LocalizedStringKey` の既定 bundle はメイン
バンドルで、パッケージ同梱の catalog には当たらない）。

やったこと:

1. 4 パッケージに `defaultLocalization: "en"` + `Resources/Localizable.xcstrings` +
   `resources: [.process("Resources")]`
2. 各パッケージに internal な `LocalizedStringResource.copy(_:)`（`Bundle.module` を指す）を置き、
   UI コピー約 100 箇所をこの形へ機械的に移送
3. issue が挙げた 2 箇所に加え、`TodoFilter.displayName` / `TodoSortOrder.displayName`（`String`
   戻り）と `TodoRowView.accessibilityLabel`（`", completed"` を `+=` で連結）も同類として修正
4. `.swiftlint.yml` に `ui_copy_needs_module_bundle` を追加して、パッケージ内の `Text("...")`
   直書きへの回帰を検出できるようにした

検証は再 export での件数比較。`UI` パッケージが **71 → 97 件**（+26。増えたのは `Completed` /
`No Results` / `Newest First` など、まさに漏れていた文言。消えたものは無し）。iOS / watchOS /
visionOS / macOS の 4 destination でビルド成功、SwiftLint 0 violation。

副産物として分かったこと:

- 翻訳が 1 件も無い言語（今回は en のみ）では、ビルドされた `UI_UI.bundle` に
  `en.lproj/Localizable.strings` は**生成されない**。「バンドルに catalog が入っているか」を
  ユニットテストで見張ろうとしたが、この挙動のため成立しないので諦めた。確認は export で行う
- `\(date, style: .relative)` は `LocalizedStringKey` 専用の補間で `String.LocalizationValue` には
  無い。ここだけは `Text("...", bundle: .module)` 形が正解（`WatchUI` の Inline complication）
- 数値だけの `Text("\(count)")` を `.copy` に通すとキーが `"%lld"` になってしまう。
  `Text(count, format: .number)` に置き換えた
