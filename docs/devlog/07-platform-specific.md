# 開発ログ: プラットフォーム固有の知見

`docs/insights/07-platform-specific.md` の現在のルールが、どういう経緯で今の形になったかを記録する。

## 2026-04-14: Live Activity ボタンから entity パラメータ版 Intent を呼ぶと `EXC_BREAKPOINT`

entity パラメータ版（`@Parameter var todo: TodoAppEntity`）の `ToggleTodoCompletionIntent` を Live Activity のボタンに直結して実機実行したところ、`TodoEntityQuery.entities(for:) → SwiftDataTodoRepository.fetch → ModelContext.fetch` の経路で `EXC_BREAKPOINT` が発生した（コミット `c37ee97`/`a234842`）。

原因として、App Intents が `AppEntity` パラメータを持つ Intent の `perform()` 実行前に `TodoEntityQuery.entities(for:)` を呼んで entity を解決する処理があり、この解決フェーズが Live Activity Extension プロセスで走ったと見て、`IntentTodoLiveActivityBundle.init()` が `AppDependencyManager` に何も登録していないため `TodoEntityQuery` 側の `@Dependency var modelContainer` が解決できずに落ちたと当時は説明していた。

対応として、呼出元（LA ボタン）はすでに todoId を持っているため、`todo: TodoAppEntity` ではなく `todoId: String` を受け取る FromExtension 系 Intent（`ToggleTodoCompletionFromExtensionIntent` / `SnoozeTodoFromExtensionIntent`）に分離し、entity 解決自体を経由しないようにした。これが現在の「Live Activity Intent のパラメータは String ID にする」ルールの由来。

## 2026-04-15: ControlWidget のプラットフォームガードを `#if os(iOS)` から `#if !os(visionOS)` に訂正

`ControlWidget` 系（`QuickAddTodoControl` / `ToggleUrgentTodoControl` / `TodoCountControl` / `IntentTodoWidgetBundle`）を `#if os(iOS)` でガードしていたが、Apple 公式 "Developing a WidgetKit strategy" のプラットフォーム対応表を確認したところ Controls は iPhone / iPad / Apple Watch / Mac で利用可能、非対応は visionOS のみと明記されていた。`#if os(iOS)` のままだと macOS native ビルドで Control Widget が無効化されてしまっていたため、コミット `7acc5db`（fix: ControlWidget のガードを #if !os(visionOS) に訂正）で該当4ファイルのガードを `#if !os(visionOS)` に修正した。これが「プラットフォームガードの指針」表の `#if !os(visionOS)` 行の由来。

## 2026-07-08: `canImport(VisualIntelligence)` が visionOS 実機ビルドだけで失敗する罠を発見

Visual Intelligence 連携（`IntentValueQuery` + `semanticContentSearch`、#297）を `#if canImport(VisualIntelligence)` でガードしていたところ、visionOS シミュレータではビルドが通るのに visionOS 実機 SDK ではビルドが落ちる現象が発生した。

原因は、`canImport` が「フレームワークが import 可能か」しか見ておらず、「フレームワーク内の特定 API が当該プラットフォームで available か」までは保証しないこと。SDK 更新により `VisualIntelligence` フレームワーク自体はどのプラットフォームでも import 可能になっていたが、visionOS シミュレータでは `canImport(VisualIntelligence)` が false と評価されコードごと除外されビルド成功していた一方、visionOS 実機 SDK では `canImport` が true になり、visionOS 非対応の `.visualIntelligence.semanticContentSearch` スキーマまでコンパイル対象になって `'visualIntelligence' is unavailable in visionOS` でビルド失敗していた。

コミット `b0f1c11`（fix: visionOS 実機ビルドで Visual Intelligence を除外）でガードを `#if canImport(VisualIntelligence) && !os(visionOS)` に修正し、コミット `ec92fc3` でこの罠を教訓としてドキュメント化した。以降「シミュレータのビルド成功をそのOSで通る根拠にしない」「`canImport` は存在チェックに過ぎない」という教訓として `07-platform-specific.md` に記録している。

## 2026-08-11: watchOS `Button(intent:)` の記録が実際のコードと逆になっていたのを訂正

`07-platform-specific.md` の「watchOS 固有の制約」節は当初「watchOS では `Button(intent:role:)` シグネチャが利用できない。代わりに `Task { try? await ToggleTodoCompletionIntent(todo: entity).perform() }` の async パターンを使用する」と記録していた。

しかし実際の `Packages/WatchUI` のコード（`WatchTodoRow.swift` / `WatchTodoDetailView.swift` / `WatchAddTodoView.swift`）はすべて `role:` 無しの `Button(intent:)` を一貫して使っており、手動で `.perform()` を呼ぶパターンは存在しなかった。さらに `04-ui-integration.md` の「直接 `perform()` を呼ばない」節は、手動 `perform()` 呼び出しが `@Dependency` をゼロ初期化のまま実行しクラッシュしうる危険な実装だと明記しており、この節の記述と真逆の指針が同一ドキュメント群の中に並存していた。

`docs/devlog/2026-08-11-constraint-recheck.md` の再検証作業（コミット `3140e5b`）でこの矛盾に気づき、正しい制約は「watchOS で利用できないのは `role:` 付きの `Button(intent:role:)` シグネチャのみで、`role:` 無しの `Button(intent:)` は watchOS でも問題なく使える」だと訂正した。

## 2026-08-11: LiveActivityIntent 節の「Widget は必ず Widget Extension プロセスで動く」という記述を撤回

`07-platform-specific.md` は当初「対して通常の `AppIntent` を Widget/Live Activity から呼ぶ場合は **Widget Extension プロセス**で実行される」と、Apple の "If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target." という一文を根拠に断定していた。

`docs/devlog/2026-08-11-constraint-recheck.md` の再検証で、この一文は**ターゲットメンバーシップ**（ビルド時にどのターゲットへ含めるか）についての要件であり、実行時のプロセスを固定すると明言しているわけではないことに気づいた。WWDC 2026 #345（15:59–16:55）が「共有パッケージの Intent がどのプロセスで実行されるかはシステムのヒューリスティクス（アプリが起動中ならアプリを優先、等）で決まる」と明言しており、SDK の `IntentExecutionTargets` が `.default` を独立ケースとして持つ `OptionSet` であることでも裏付けが取れたため、コミット `3140e5b` で「Widget から呼ぶと必ず Widget Extension で実行される」という記述を撤回し、「ヒューリスティクスで決まり、固定するには `allowedExecutionTargets` の明示が必要」に訂正した（`03-app-intents-core.md` の同時期の訂正と同じ調査に基づく）。

## 2026-08-11: Live Activity の entity 解決クラッシュの原因断定を「未確定」に後退

2026-04-14 に記録した「Live Activity Extension プロセスで entity 解決処理が走ったため crash した」という原因記述が、Apple の「`LiveActivityIntent` の `perform()` はアプリプロセスで実行される」という公式保証と厳密には矛盾しうることに `docs/devlog/2026-08-11-constraint-recheck.md`（A-3）の再検証中に気づいた。

git 考古学でクラッシュ自体（スタックトレース）の実在は確認済みだが、「entity 解決フェーズがどのプロセスで走ったか」は Apple 文書に明記が無く、確定できないままだった。コミット `3140e5b` で断定を後退させ、「`perform()` はアプリプロセス保証、ただし `AppEntity` パラメータの事前解決フェーズがどこで走るかは未文書化かつ実機 crash 歴あり」という正確な切り分けに改めた。`IntentTodoLiveActivityBundle.init()` が `AppDependencyManager` に何も登録していないことも絡んだ可能性は残るが未確定。FromExtension 分離は結果的に安全なワークアラウンドとして機能しているためコード変更は不要と判断し、Primary 版を LA ボタンに直結して trap が再現するか確認する実機検証は未着手のまま残タスクとした。

## 2026-08-11: `#Predicate` の Optional 比較制約を「visionOS 等で」から「全プラットフォーム共通」に訂正

`#Predicate<TodoItem> { $0.id == optionalUUID }` のコンパイル失敗について、`07-platform-specific.md` は当初「visionOS 等でコンパイルが通らないことがある」とプラットフォーム限定の書き方をしていた。

`docs/devlog/2026-08-11-constraint-recheck.md` の全項目再検証（コミット `3140e5b`）でこの記述を洗い直したところ、`#Predicate` マクロの Optional 絡みの型推論制約は基本的に全プラットフォーム共通の問題であり、visionOS 固有ではなく toolchain バージョン差によって再現/非再現が分かれていた可能性が高いと判断した。優先度が低く再現条件の特定までは至らなかったため未再検証のままだが、「visionOS 等で」という誤ったスコープ限定の表現だけは訂正した。

## 2026-08-12: `#Predicate` の Optional 比較制約を実測で確定（C-9 決着）

2026-08-11 の再検証では「全プラットフォーム共通の toolchain 依存問題、優先度低のため未再検証」という書き方で保留していた。今回 `Packages/Domain/Sources/Domain/Models/TodoItem.swift` のコンテキストで `RunCodeSnippet` を回して、条件を絞り込んだ。

| 式 | 結果 |
|---|---|
| `#Predicate<TodoItem> { $0.id == optionalUUID }`（非 Optional プロパティ == Optional 値） | ❌ `value of optional type 'UUID?' must be unwrapped to a value of type 'UUID'` |
| `#Predicate<TodoItem> { $0.dueDate == optionalDate }` | ✅ |
| `#Predicate<TodoItem> { $0.dueDate == concreteDate }` | ✅ |
| `#Predicate<TodoItem> { $0.dueDate != nil }` | ✅ |
| `let closure: (TodoItem) -> Bool = { $0.id == optionalUUID }`（`#Predicate` の外） | ✅ |
| 素の `UUID == UUID?` | ✅ |

同じ式が `#Predicate` の外なら通り、中だけ落ちる。よって **toolchain バージョン差でもプラットフォーム差でもなく `#Predicate` マクロ固有の制約**と確定した（Xcode 27 beta 5 / iOS 27 シミュレータ）。素の `==` に効く Optional の暗黙昇格が、マクロ展開後の型要求では働かないため。落ちるのは「非 Optional のプロパティを Optional の値と比較する」1 パターンだけで、Optional プロパティ側は全パターン通る。

回避策（非 Optional な定数を capture してから比較する）は変更なし。

## 2026-08-12: 「LA ボタンの Intent は String ID パラメータにする」ルールを撤回

`07-platform-specific.md` の「Live Activity Intent のパラメータは String ID にする（Entity を取らない）」節は、entity の事前解決中に SwiftData が `EXC_BREAKPOINT` で落ちる実績を根拠にしていた。同日の A-3 実測（`docs/devlog/03-app-intents-core.md` 参照）でその crash が iOS 27 で再現しないと確定したため、ルールごと撤回し「LA ボタンにも entity パラメータの Intent をそのまま使う」に書き換えた。

View 側は Activity が持つ id / title から `TodoAppEntity(id:title:)` を組んで渡す。他のフィールドを埋めなくてよいのは、システムが `perform()` 前に `TodoEntityQuery.entities(for:)` で id から再解決するため。

`ToggleTodoCompletionFromExtensionIntent` / `SnoozeTodoFromExtensionIntent` は削除し、後者だけは「`requestChoice` を使えない呼出元向けの固定間隔版」という別の理由で `QuickSnoozeTodoIntent` として残した。

## 2026-08-27: watchOS の onscreen annotation は行ごとに付ける + テストは通せない（#54）

#54（watchOS にも `.appEntityIdentifier` を付ける）に着手して 2 つ分かった。

**1. `forSelectionType:` は watchOS の一覧には効かない形だった**

iOS / visionOS は `List(selection:)` + `.tag(todo)` なのでコレクション版
（`.appEntityIdentifier(forSelectionType:)`）が 1 つで済む。`WatchTodoListView` も `List` だが
**selection を持たない**（行が `Button(intent:)` で、タップは完了トグル）。`forSelectionType:` は
selection 値の型を手がかりにする仕組みなので当て先が無く、`WatchTodoRow` / `WatchTodoDetailView`
に行ごとの単一 annotation を付ける形にした。「`List` なら効く」ではなく「**selection のある `List`
なら効く**」と理解を訂正した（`AGENTS.md` / `docs/insights/03-app-intents-core.md` の記述も直した）。

**2. watchOS では AppIntentsTesting で annotation を検証できない**

issue には「`AppEntityDefinition.viewAnnotations()` で押さえる」と書いていたが、実際に
`IntentTodoWatchAppUITest` へ移植して動かしたところ通らなかった。切り分けた結果:

- `AppIntentsTesting.framework` は watchOS SDK にも存在し、リンクも runner の起動も通る
- `IntentDefinitions(bundleIdentifier: "dev.touyou.IntentTodo.watchkitapp")` と
  `suggestedEntities()` は動く（＝メタデータの発見までは成立している）
- しかし **intent の `run()` が `LNPerformActionPrebuiltErrorDomain` code 4025
  `LNPerformActionPrebuiltErrorCodeActionNotAllowed` で落ちる**。テストの前提データを作る
  `AddTodoIntent`（`.background` + `allowedExecutionTargets = [.main]`）が走らないので、
  annotation を読む地点まで到達できない

前提データを watch アプリの UI から作る道もあるが、watchOS シミュレータの `typeText` が
不安定なのは既存テストのコメントにあるとおりで、そちらに寄せると「落ちても理由が分からない
テスト」になる。**条件付き assert（todo が無ければ緑）を書かない**という方針もあるので、
watchOS 側は自動化を諦めて #30 の手動確認へ回した。実装（annotation）は 4 プラットフォームの
ビルドで担保している。

**副産物**: watchOS シミュレータで UI テストを連続実行すると、xctrunner の起動が
`FBSOpenApplicationServiceErrorDomain Code=1 / RequestDenied` で失敗するようになる。
これはテスト内容とは無関係のフレークで、失敗の本当の理由（上記 4025）は xcodebuild の
標準出力ではなく `.xcresult` の Failure Message にしか出ない。`xcrun xcresulttool get
test-results tests --path <xcresult>` で読む。

**もう 1 つ見つけたもの**: `WatchTodoDetailView` は**どこからも到達できない**（watch アプリは
`WatchTodoListView` だけを出し、行は `Button(intent:)` で完了トグル。詳細への遷移が無い）。
annotation は付けたが、現状は死んだ画面に付いている状態。→ #63 で追跡。
