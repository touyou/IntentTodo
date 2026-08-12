# 開発ログ: App Intents コア設計

`docs/insights/03-app-intents-core.md` および `AGENTS.md`（`CLAUDE.md` 実体）に書かれている
「App Intents コア設計」まわりの現在のルールが、どういう調査・失敗・再検証を経て今の形になったかを
時系列で記録する。現在のルール自体は各ドキュメント側を参照。ここは経緯のみ。

## 2026-04-13: Shortcuts Intent ルーティングの謎の失敗を調査 → `AppIntentsPackage` 重複宣言が原因と結論

Shortcuts から呼ぶと `LNContextErrorDomain Code=2001` / `LNPerformIntentPrebuiltErrorDomain Code=4025` で失敗する問題を調査。
`ShowTodosIntent`（`.foreground`）だけが動作し、他は全て失敗。BackgroundShortcutRunner が
`IntentTodoWidgetExtension` プロセスにルーティングされてしまい、Widget Extension 側に登録の無い
`@Dependency`（`NavigationModel`, `ModelContainer`）が解決できず落ちていた。

大規模リファクタ（コミット `3f6d835`、Intent routing 問題の解決と `@Dependency` パターン統一を一括で行った PR）で、
諸悪の根源と見立てた `IntentTodoAppIntentsPackage`（アプリターゲット側の `AppIntentsPackage` 重複宣言）を削除し、
`ModelContainer` / `NavigationModel` をメインターゲットの `AppDependencyManager` に同期登録する形に統一。
以降「アプリターゲットに `includedPackages` 付き `AppIntentsPackage` を重複宣言してはいけない」という制約として記録していた。

## 2026-04-14: Live Activity ボタンから entity パラメータ版 Intent を呼ぶと `EXC_BREAKPOINT`

entity パラメータ版（`@Parameter var todo: TodoAppEntity`）の Intent を LA ボタンに直結した状態で実機実行したところ、
`TodoEntityQuery.entities(for:) → SwiftDataTodoRepository.fetch → ModelContext.fetch` の経路で
`EXC_BREAKPOINT` が発生（コミット `c37ee97`/`a234842`）。

原因: App Intents は `@Parameter var todo: TodoAppEntity` を持つ Intent の `perform()` 実行前に、
別フェーズで `TodoEntityQuery.entities(for:)` を呼んで entity を解決する
（[WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) 7:37）。
この事前解決フェーズが Live Activity Extension プロセスで走ったと見られ、
`IntentTodoLiveActivityBundle.init()` は `AppDependencyManager` に何も登録していないため、
`TodoEntityQuery` 側の `@Dependency var modelContainer` が解決できず落ちた。

対応: 呼出元（LA ボタン）は todoId をすでに持っているため、`todo: TodoAppEntity` ではなく
`todoId: String` を受け取る FromExtension 系 Intent に分離し、entity 解決自体を経由しないようにした
（`ToggleTodoCompletionFromExtensionIntent` / `SnoozeTodoFromExtensionIntent`）。

## 2026-04-14: Control Widget から呼んだ Intent は `.result(dialog:)` が表示されないことを実機で確認

Control Center 経由で呼ぶ Intent（`ToggleUrgentTodoIntent`, `ShowTodoCountIntent`）で `.result(dialog:)` を
試したが、Control Widget では Dialog が画面に表示されないことを実機で確認した。UI/Widget の
`Button(intent:)` 経由でも表示されないのは把握済みだったが、Control Widget 固有の挙動として記録。
以降 Control Center 起点の Intent はローカル通知でフィードバックする運用にした。

## 2026-04-14: Control Widget からの `continueInForeground()` 不動作という記録を「未検証」に訂正

それまで「`continueInForeground()` は Control Widget コンテキストでは動作しない。Shortcuts/Siri 経由での使用を想定」
と断定的に記録していたが、見直したところ当時の失敗は `IntentTodoAppIntentsPackage` 重複宣言 Bug（上記 2026-04-13
の一件）が原因だった可能性が高く、`continueInForeground()` 自体の制約として確定できる根拠がないと判明した
（コミット `d71101e`、issue #24）。fix 後に Control Widget から改めて動作検証した記録は無いため、
「動作しない」という経験則ではなく「現時点で未検証」という正確な不確実性の表現に書き換えた。

## 2026-06-19: `allowedExecutionTargets` の選択肢の記録漏れを訂正（`.widgetKitExtension` も存在）

WWDC 2026 セッション #345 を踏まえた追加検証（issue #42–#48）で `IntentExecutionTargets` の選択肢を確認したところ、
それまで「`.main`（アプリ本体）/ `.appIntentsExtension`（App Intents Extension）の2択」と記録していたのは誤りで、
`.widgetKitExtension`（WidgetKit Extension）も選択肢として存在すると判明した（Widget ボタンからの更新を本体に
寄せてデータ競合を避ける用途）。ドキュメントを2択→3択に訂正した（コミット `4e0e09a`、docs: WWDC 2026 追加検証
(#42-#48) を反映）。ただし FromExtension/Primary 分離の結論（`allowedExecutionTargets` では統合できない）は
`.widgetKitExtension` の存在を踏まえても変わらない: この API が制御するのは「どのプロセスが perform するか」で
あって、Live Activity 由来の entity 解決クラッシュ回避に必要な「パラメータ型を変えて解決自体を避ける」という
話とは別の軸だから。パラメータ解決 (entity resolution) の実行プロセスまで `[.main]` 指定で本体に寄るかどうかは
実機未検証のまま残した（#42 の R 深度タスク）。

## 2026-07-02: 「VisualIntelligence は iOS 専用」の思い込みを実ビルドで覆す → macOS 対応

macOS/visionOS のフルビルドを回したところ、Xcode 27 beta 2 で `VisualIntelligence` フレームワークが Mac にも
import 可能になっていることが判明し、既存の `#if canImport(VisualIntelligence)` ガードがそのまま Mac でも真に
なっていた。Mac は visual search の `IntentValueQuery` が返す entity すべてが openable（`OpenIntent` を保持）
であることを要求するため、`TodoOrCategory` union の `CategoryAppEntity` が not openable でビルド失敗（
`result type 'CategoryAppEntity' that is not openable ... must be associated with an OpenIntent`）。iOS
シミュレータ/iPhone ビルドでは発火せず、macOS destination のみで顕在化した。「iOS 専用」は当時 SDK に
フレームワークが存在しなかった時点の制約に過ぎず恒久的な不可能ではなかった、と判断し、`OpenCategoryIntent`
（`OpenIntent`, `target: CategoryAppEntity`, `perform()` は `navigateToRoot()` のみ）を新設して union を
全メンバ openable にし、Mac ビルドを通した（コミット `8ddc76f`）。

同日中に追検証（コミット `16556e5`）で、このエラーの発火先を当初「Mac Catalyst」と記録していたのは誤りで、
本プロジェクトの Mac ターゲットは `SUPPORTS_MACCATALYST` 無し・`macosx` SDK の native macOS アプリであり、
正しくは「macOS destination（native）」で発火することを確認して訂正した。教訓として「プラットフォーム限定は
当時の SDK 制約に過ぎない場合がある。SDK 更新時は `#if canImport` ガードを外して本当に不可能かを実ビルドで
確かめる」という方針を明文化した（[[verify-platform-limits-on-sdk-updates]] に対応するプロジェクト内の実例）。

## 2026-07-08: `AppShortcutsProvider` がパッケージ内にあると App Shortcut が黙って消えることを発見

Siri / Shortcuts アプリ / Spotlight に App Shortcut が一切出てこない症状を調査（ビルド・実行はエラー無しで
成功するため気付きにくかった）。Xcode 27 beta 3 / toolchain 27A5218g で、ビルド時に生成される
`Metadata.appintents` バンドル（DerivedData の `.appintents/extract.actionsdata`、JSON）をパッケージ側と
アプリ側で比較したところ、`actions`（20件）/`entities`（3件）/`queries`（3件）はパッケージからアプリの統合
メタデータへ集約されるのに対し、`autoShortcuts`（`AppShortcutsProvider.appShortcuts`）だけはパッケージ側
8 件・アプリ側 0 件で**集約されない**ことを確認した。それまでこの節には「`AppShortcutsProvider` も Swift
Package 内に配置可能」と書いていたが、これは誤りだったと判明した（Intent 自体は集約経由で動くため、App
Shortcut フレーズの欠落だけが長く気付かれていなかった）。

`TodoAppShortcuts` をメインアプリターゲット直下（`IntentTodo/IntentTodo/TodoAppShortcuts.swift`）へ移動した
ところ、同じ検証で `autoShortcuts` が 0 → 8 に変化することを確認し、ルールを確定した（コミット `3280bed`）。
検証手順（`python3 -c "import json; d=json.load(open('.../Metadata.appintents/extract.actionsdata')); print('autoShortcuts:', len(d['autoShortcuts']))"`）も併せて記録した。

## 2026-07-08: reminders/system ドメインの watchOS 非対応を Xcode 27 beta 3 で再確認

Xcode 27 beta 2 で `reminders` / `system` の assistant schema が watchOS で unavailable になっていた件
（`'reminders' is unavailable in watchOS` 等）について、beta 3 で解消されていないかを実ビルドで再確認した。
`TodoListType` の `#if os(watchOS)` フォールバックを一時的に無効化して watchOS スキームをビルドしたところ、
`'reminders'/'listType' is unavailable in watchOS` が再現し、`.system` ドメイン側でも同様に
`'system'/'search' is unavailable in watchOS` を確認した。結論として beta 3 でも制約は解消されておらず、
`CategoryAppEntity`/`TodoListType` の watchOS フォールバックおよび `ShowTodoSearchResultsIntent` の
`#if !os(watchOS)` 除外は維持が必要と判断した（コミット `3280bed`、[[verify-platform-limits-on-sdk-updates]]
の方針に沿って実ビルドで確認）。

## 2026-07-08: `.system.search` が Xcode 27 beta 3 で deprecated に → `.system.searchInApp` へリネーム追従

iOS ビルドでビルド警告を精査していたところ、`@AppIntent(schema: .system.search)` が Xcode 27 beta 3 で
deprecated になっていることを発見した（`'search' is deprecated: Use .system.searchInApp instead`）。issue
#47 起票時点では `.system.searchInApp` という表記を使っていたが、その後 SDK の正式名が `.system.search` だと
判明して一度 `.system.search` に修正した経緯があり、beta 3 のリネームにより issue #47 の当初表記が結果的に
正しかったことになった。`ShowInAppSearchResultsIntent` のスキーマ指定とドキュメント中の表記をすべて
`.system.searchInApp` に統一し、iOS ビルドで警告 0 件を確認した（コミット `adccb24`。同コミットで
`Activity.end(dismissalPolicy:)` の deprecated 警告も `end(nil, dismissalPolicy:)` に更新）。

## 2026-08-11: 上記の制約を Xcode 27 beta 5 で再検証 → 断定を撤回

WWDC の公式説明（wwdc2025-244 23:29–24:00「各ターゲットを App Intents Package として登録すべき」、
wwdc2025-275 25:50 も同様の実装例）と、プロジェクトの禁止ルールが正面から矛盾していることに気づき、
`docs/devlog/2026-08-11-constraint-recheck.md`（A-1）で再検証を実施。

アプリターゲット・Widget/LiveActivity/watchOS の全 Extension ターゲットに `includedPackages: [TodoIntentsPackage.self]`
付きの `AppIntentsPackage` を追加してビルドした結果、`Metadata.appintents` の `actions`/`entities`/`queries` 件数は
無宣言時と完全に同一（11/1/1）で、重複はメタデータ上確認できなかった。

結論: 「絶対禁止」という断定は撤回。2026-04-13 時点の破損は次のいずれかだった可能性が高いが、
どれが真因かを確定づける再現実験は当時行われていない。
1. 同一パッケージのメタデータが SPM 自動抽出とアプリ側宣言で二重 extraction された
2. パッケージが複数ターゲット（Widget/Watch）にリンクされ各々で再登録された
3. 当時の beta のバグ

ビルド/メタデータレベルでの重複は無いことを確認できたが、Siri/Shortcuts の実機ルーティング
（`LNContextErrorDomain` 系）は未再検証のまま。現状は重複宣言しない運用を維持し、複数ターゲットでの
再利用パターンが本当に必要になった際は実機で Siri 経由の呼び出しを確認してから採用する。

## 2026-08-11: `AppShortcutsProvider` がパッケージに置けない制約は独立の話と確認

上記 A-1 の再検証中、`AppShortcutsProvider` を疑うついでに確認。A-1 のパターン
（アプリ/Extension ターゲットに `AppIntentsPackage` を追加）を適用した状態でも、
`AppShortcutsProvider` がパッケージ内にある限り `autoShortcuts` は 0 のままで、
アプリターゲットへ移動した時点でのみ 0→8 に変化した。
`AppIntentsPackage` 重複宣言の話（A-1）とは独立した制約であることを確認、ルール自体は変更不要。

## 2026-08-11: entity 解決フェーズの実行プロセス断定を精緻化（再検証、未確定のまま）

上記の「LA Extension プロセスで entity 解決が走った」という原因断定について、Apple 公式ドキュメントが
「`LiveActivityIntent` の `perform()` はアプリプロセスで実行される」と明言している点と厳密には矛盾しうることに気づいた
（`docs/devlog/2026-08-11-constraint-recheck.md` A-3）。

git 考古学でクラッシュ自体の実在は確認済み（スタックトレース有）だが、「どこで entity 解決が走ったか」は
Apple 文書に明記が無く未確定のまま。`perform()` はアプリプロセス保証、ただし entity の事前解決フェーズが
どこで走るかは未文書化かつ実機 crash 歴あり、という正確な切り分けに改めた。FromExtension 分離は
結果的に安全なので維持し、Primary 版を LA ボタンに直結して trap が再現するかどうかの実機検証は
残タスクとして未着手のまま。

## 2026-08-11: `WidgetReloader.reloadAllWidgets()` を全 Intent で無条件に呼ぶ理由を正確化

wwdc2023-10028 (13:47 "As soon as your perform returns, the system will immediately initiate a reload of your
widget timeline" / 10:02 "reloads initiated from an interaction are always guaranteed") を確認した結果、
Widget 内 `Button(intent:)` 起点は自動リロードが保証されており、手動 reload が本当に必要なのは
Siri / Shortcuts / アプリ UI など Widget 起点でない経路だけだと判明。ルール自体（全 Intent で無条件に呼ぶ）は
安全側の運用として変更不要と判断し、理由の説明だけを正確化した（呼び出し重複のコストは無視できる）。

## 2026-08-11: 実行プロセスの「固定表」が誤りと判明 → ヒューリスティクスに訂正

wwdc2026-345 (15:59–16:55) が「共有パッケージの Intent はヒューリスティクスでプロセスが選ばれる
（アプリが起動中ならアプリを優先）」と明言しており、SDK 実物確認（`IntentExecutionTargets` が `.default` を
独立ケースとして持つ `OptionSet`）でも裏付けが取れた。従来「呼出元とモードで実行プロセスが固定的に決まる」と
記録していたのは誤りで、固定するには `allowedExecutionTargets` の明示指定が必要だと訂正した。

本プロジェクトは大半の Widget/Control Intent で `allowedExecutionTargets` を未指定のままにしているため、
二重登録（`App.init()` と `WidgetBundle.init()` の両方）は撤廃できない。`CompleteTodosIntent` のみ
`[.main]` 固定済み（詳細は `docs/insights/03-app-intents-core.md`）。

## 2026-08-11: `RelevantEntities` 不適合の根拠に挙げた WWDC 実例が誤帰属と判明 → 訂正

`docs/devlog/2026-08-11-constraint-recheck.md` の全項目再検証の一環で、`RelevantEntities` が todo ドメインに適合
しないという結論の根拠として挙げていた WWDC 引用を洗い直した。それまで「提供される context は
`.audio(.nowPlaying)` のみ」と記録していたが、wwdc2026-345（3:57 前後）が実際に挙げている例は
`.audio(.workout(activityType: .running))`（ワークアウト開始時にプレイリストを提案する例）であり、
`.nowPlaying` ではなかった。ただし Xcode 27 beta 5 SDK の `AppIntents.swiftinterface` を確認すると
`AudioContext.nowPlaying` のみが存在し、`.workout(activityType:)` は HealthKit 等のオーバーレイ側にも
まだ見当たらない（beta 未実装の可能性があり要再確認）。どちらの例で確認しても「todo を寄付するのは
意味的に誤り（再生中メディア/ワークアウト扱いになる）」という結論自体は変わらないため、`RelevantEntities`
適合を保留する結論は維持しつつ、引用元の記述だけを訂正した（コミット `3140e5b`）。

## 2026-08-11: `IntentValueQuery` はアプリに1つだけという制約を記録し忘れていたと判明

`docs/devlog/2026-08-11-constraint-recheck.md` の再検証中に wwdc2026-297（11:39）を聞き直したところ、
「`SemanticContentDescriptor` を受ける `IntentValueQuery` はアプリに **1 つだけ**」と明言されていることに
気づいた。Phase 5 実装時（コミット `069aa48` 前後）にはこの制約をドキュメント化しておらず、本プロジェクトは
`TodoVisualIntelligenceQuery` の1つのみを実装していたため実害はなかったが、将来2つ目を追加しようとした
場合に不可能だと気づかず地雷を踏む可能性があった。制約を明文化し、複数の視覚検索エンティティ種別を扱いたい
場合は `@UnionValue` で戻り値の型を1つの query に集約するのが正しい対処だと記録した（コミット `3140e5b`）。

## 2026-08-11: Visual Intelligence の openable 要件を「Mac 固有」と書いていたのは不正確と判明 → enforce の違いに訂正

`docs/devlog/2026-08-11-constraint-recheck.md` の再検証で、Visual Intelligence の openable 要件（visual search の
`IntentValueQuery` が返す entity は全て `OpenIntent` を持つ必要がある）についての記述を見直した。それまで
「Mac 固有の追加バリデーション」と書いていたが、wwdc2025-275（9:19）が "This `OpenIntent` must exist,
otherwise your app won't show up" と明言している通り、これは全プラットフォーム共通のルールだった。実際に
違うのは「コンパイル時エラーとして enforce されるのが macOS destination のビルドだけ」という enforce の
されかたであり、ルール自体が Mac 限定というわけではないと訂正した（iOS シミュレータ/iPhone ビルドでは
コンパイルエラーとして出ない）。`TodoOrCategory` union に `CategoryAppEntity` を含めるために新設した
`OpenCategoryIntent` の位置づけ自体（2026-07-02 の対応）は変更なし（コミット `3140e5b`）。

## 2026-08-11: AppIntentsTesting に「テストランナーとアプリで同じ development team が必要」という要件があると判明

`docs/devlog/2026-08-11-constraint-recheck.md` の再検証中に wwdc2026-295（2:54）を確認したところ、"AppIntentsTesting
requires the test runner and the app to use the same development team for code signing" と明言されている
ことに気づいた。Phase 6 実装時（コミット `0b27bf0` 前後）にはこの要件を記録しておらず、CI 環境や複数
Apple ID を切り替える環境でこの設定がずれると原因不明の失敗になりやすい落とし穴だったため、テスト追加時に
まず署名チームの一致を確認するようドキュメント化した（コミット `3140e5b`）。

## 2026-08-11: 「`textContent` は SDK に露出していない」という記録が誤りと判明 → 訂正

`docs/devlog/2026-08-11-constraint-recheck.md` の再検証で `@Property(indexingKey:)` 周りの記述を洗い直したところ、
Phase 7 実装時（コミット `756735e`/`4e0e09a` 前後）に「`textContent` は SDK に露出していない（`title`/
`contentDescription`/`textContentSummary`(read-only) のみ確認）」と記録していたのが誤りだったと判明した。
実際には `CSSearchableItemAttributeSet_Messaging.h` に `NSString *textContent`（macOS 10.11 / iOS 9〜、
tvOS・watchOS 対象外）として存在する（wwdc2026-240 のコード例、wwdc2024-10131 2:41 が言及）。さらに
`EntityProperty.init(indexingKey:)` は `PartialKeyPath<CSSearchableItemAttributeSet>` を取るだけでローカル
プロパティの型とキーパスの値型を静的に対応付けないため、`String?` でも `AttributedString?` でも同一の
`indexingKey:` オーバーロードが使えることも実ビルドで確認した（SDK の `swiftinterface` 上、
`Value.ValueType == String` と `Value.ValueType == AttributedString` の両方に同シグネチャの init 群がある
ことを確認）。「`textContent` は `AttributedString?` 専用」という仮説も誤りだった。それでも `todoDescription`
は `contentDescription`（`CSDocuments` カテゴリ、アイテムの説明文の意味）にマップし続けるのが妥当という
結論自体は変わらない——`textContent`（`CSMessaging` カテゴリ、メール/メッセージ本文全文を想定）よりも
todo の詳細説明というユースケースに近いため、型の制約ではなく意味の制約による選択だと整理し直した
（コミット `3140e5b`）。

## 2026-08-12: LA ボタンの entity 解決クラッシュは iOS 27 で再現しないと実測（A-3 決着）

`docs/devlog/2026-08-11-constraint-recheck.md` の A-3 残タスク（「Primary 版 Intent を LA ボタンに直結して実機実行し、trap の再現/非再現を確認する」）を、iPhone 17 Pro Max シミュレータ（iOS 27 / Xcode 27 beta 5）で実施した。

**仕込み**: `@Parameter var todo: TodoAppEntity` + `@Dependency var todoService` を持つ probe Intent を `TodoAppIntents` に置き、ロック画面 Live Activity と Dynamic Island の「Mark Complete」ボタンをそれに差し替えた。あわせて `TodoEntityQuery.entities(for:)` と probe の `perform()` に `pid` / `processName` を出すログを入れた。プロセスをまたぐログは Xcode の launch session では拾えないので、`simctl spawn <udid> log config --subsystem dev.touyou.IntentTodo --mode "level:debug,persist:debug"` で永続化してから `log show` で読んだ（アプリを kill する検証では launch session が切れるため、これが必須）。

**結果**（3 ケースすべて crash 無し、entity 解決も `perform()` もメインアプリプロセス）:

| ケース | `entities(for:)` | `perform()` |
|---|---|---|
| アプリ起動中 + `LiveActivityIntent` 準拠 | IntentTodo (pid 38962) | IntentTodo (同 pid) |
| アプリ kill 済み + `LiveActivityIntent` 準拠 | IntentTodo (pid 47386, LA タップで起動) | IntentTodo (同 pid) |
| アプリ kill 済み + `LiveActivityIntent` **非**準拠（素の `AppIntent`） | IntentTodo (pid 48600) | IntentTodo (同 pid) |

3 ケース目が効いていて、**`LiveActivityIntent` 準拠の有無は entity 解決プロセスに影響しない**。2026-08-11 の A-3 で挙げた仮説 (a)「当時その Intent が `LiveActivityIntent` 未準拠だったのが原因」は、少なくとも現行 SDK では成立しない。仮説 (b)「LA Extension プロセスに `AppDependencyManager` 登録が無いこと」も、`IntentTodoLiveActivityBundle.init()` が今も何も登録していないまま動いているので現行 SDK では無関係。

**副産物（A-5 の裏取り）**: 同じログに `IntentTodoWidgetExtension[48073] TodoEntityQuery entities(for:)` が出ていた。Widget のタイムライン描画では entity 解決が Widget Extension プロセスで走る。つまり「entity 解決は必ずアプリで走る」わけではなく、上の結論は **Live Activity ボタン経由に限った話**。Widget Extension 側の `AppDependencyManager` 登録は引き続き必要。

**判断**: FromExtension 分離は現行 SDK では不要と分かったが、削除は別の設計判断（`isDiscoverable` の扱い、`endMatchingLiveActivity` の置き場所）を伴うので今回は撤去せず、ドキュメントに「現行 SDK では不要」と明記するに留めた。probe と一時ログは検証後に全て削除済み。

**教訓**: プロセスをまたぐ検証では Xcode の launch session ログでは足りない。`simctl spawn ... log config --mode "persist:debug"` + `log show` にしておくと、アプリを kill した後の再起動や Extension 側のログまで一続きで読める。

## 2026-08-12: FromExtension 分離を撤去（1 アクション 1 Intent へ）

前項の実測で分離の根拠が消えたため、`ToggleTodoCompletionFromExtensionIntent` と `SnoozeTodoFromExtensionIntent` を削除した。

**Toggle**: `ToggleTodoCompletionIntent`（`@Parameter var todo: TodoAppEntity`）に一本化。FromExtension 側にしか無かった「完了したら対応する Live Activity を畳む」副作用を `perform()` に移し、`#if os(iOS)` で `LiveActivityIntent` に準拠させた（`activity.end` を触るため、`perform()` がアプリプロセスで走る公式保証を得ておく）。`LiveActivityMonitor` の reconcile は `TodoListView` が画面に居るときしか走らないので、この副作用を落とすとロック画面から完了させた Live Activity が出っぱなしになる。

**Snooze**: 一本化**しなかった**。`SnoozeTodoIntent` は `requestChoice` で期間を選ばせるが、Live Activity のボタンは背景実行で問い合わせ先の UI が無いため、期間固定の変種が要る。ただし残す理由は「entity 解決の回避」ではなく「対話できるかどうか」なので、名前を `QuickSnoozeTodoIntent` に変え、パラメータも `todoId: String` → `todo: TodoAppEntity` に揃えた。

**Live Activity View 側**: Activity が持つのは id と title だけなので `TodoAppEntity(id:title:)` で組んで渡す。システムが `perform()` 前に id から再解決するため、他のフィールドは埋めなくても正しく動く（前項の実測どおり）。

`SetTodoCompletionIntent`（Control 用、`SetValueIntent`）は `todoId: String` のまま。こちらも理由は「トグルではなく絶対値セット」という振る舞いの違いであって、プロセスの都合ではない。ドキュメント上の「FromExtension convention に従う」という説明だけ書き換えた。

**残った教訓**: 呼出元プロセスの都合で Intent を複製すると、副作用（LA を畳む / 更新する）が片方にしか無い状態が生まれ、統合するときに拾い直しが要る。分けるなら**振る舞いが違うとき**だけにする。

## 2026-08-12: 検証観点を AppIntentsTesting に寄せる（B 深度 → U 深度）

「制約の再検証」を実機・シミュレータの手作業で進めていたが、AppIntentsTesting で押さえられる観点はテストに寄せた方がデグレも防げる、という方針転換。`IntentTodoUITest/AppIntentsTestingTests.swift` を 3 テスト → 10 テストに拡張し、実 run でグリーンを確認した（従来は buildForTesting までの B 深度だった）。

追加したのは、**落ちても他のテストでは捕まらない**観点を優先:

| テスト | 押さえている経路 |
|---|---|
| `testEntityResolutionByIdentifier` | `TodoEntityQuery.entities(for:)`。A-3 で問題になった、LA / Widget のボタンが `perform()` 前に通る経路 |
| `testEntityResolutionOfUnknownIdentifierReturnsEmpty` | 削除済み todo を指す古いボタンで throw しないこと |
| `testAllEntitiesIncludesSuggestedIncompleteTodo` | `EnumerableEntityQuery.allEntities()` / `suggestedEntities()` |
| `testNewTodoIsIndexedInSpotlight` | `IndexedEntity` + `@Property(indexingKey:)`。落ちると検索から消えるだけで他は正常に見える |
| `testToggleCompletionRoundTrip` | FromExtension 撤去で副作用を寄せた `ToggleTodoCompletionIntent` |
| `testQuickSnoozePushesDueDateByThirtyMinutes` | `QuickSnoozeTodoIntent` が 30 分ちょうど押すこと |
| `testTodoSummaryReflectsNewTodo` | `TransientAppEntity`（`TodoListSummaryEntity`）のプロパティ名込み |

**実行して初めて分かった落とし穴**（insights/03 にも記録）:

1. `AnyAppEntity` の dynamic member lookup で見えるのは `@Property` だけ。`entity.id` は `castingFailed(elementType: "NSNull", targetType: "String")` になる。id は `entity.identifier.instanceIdentifier` から取る。
2. `setUp` で毎回 `app.launch()` すると、テスト数を増やしたところで `Simulator device failed to launch ... did not return a process handle nor launch error` が散発するようになった。`launch()` は起動中のアプリを terminate して再起動するため。起動済みなら `activate()` に分岐して解消。3 テストの頃は顕在化していなかった。
3. Spotlight の index は Intent 完了と非同期。`spotlightQuery()` はタイムアウト付きでポーリングする。
4. `requestChoice` を使う `SnoozeTodoIntent` は run できない（応答する相手が居ない）。対話しない `QuickSnoozeTodoIntent` を別に持っていたおかげでスヌーズの計算自体はテストできた。**対話版と非対話版を分けておくとテスト可能性が上がる**という、分離の思わぬ効能。

**残る手作業**: 最終的にシステム UI の見え方に依存するもの（dialog の読み上げ、snippet の描画、Control の表示、Siri のルーティング）だけ。`viewAnnotations()` / `valueQueries` / `exported(as:)` はまだ未着手だが API はあるので寄せられる。

## 2026-08-12: AppIntentsTesting を 22 テストへ拡張、ファイルを分割

前項の方針の続き。1 ファイルに詰め込んでいたテストを `IntentTodoUITest/AppIntents/` 配下へ分割した（`IntentTodoUITest` は現在 synchronized folder なので、ファイルを置くだけでターゲットに入る。以前 insights に書いていた「synchronized folder ではない」は古い記述だったので訂正した）。

- `AppIntentsTestCase.swift` — 共通基底（起動 / 後片付け / ヘルパー）
- `TodoIntentExecutionTests.swift` — Intent 実行（作成・トグル・スヌーズ・部分更新・バルク・集計・連鎖）
- `TodoEntityQueryTests.swift` — entity query（文字列一致・id 解決・allEntities・suggested・Spotlight・union 検索）
- `TodoSystemIntegrationTests.swift` — アプリの外に届く部分（view annotation・ナビゲーション・ValueRepresentation）

**新しく U 深度に上がった観点**: `viewAnnotations()`（onscreen entity, #46）、`exported(as: IntentPerson.self)`（ValueRepresentation, #44）、`valueState` の三状態（#45）、`CompleteTodosIntent`（LongRunningIntent + EntityCollection + `allowedExecutionTargets [.main]`）、`DeleteTodosIntent`、`SearchEverythingIntent`（`@UnionValue`）、Spotlight の de-index、`LaunchAppIntent` のナビゲーション（`@Dependency` + `perform()` パターン。`onAppIntentExecution` を使わない代替経路なので、これで C-1 の「再導入したら検証」以前に現行経路は押さえられた）。

**詰まったところ 3 つ**:

1. **`.set(nil)` が効かないように見えた**。`makeIntent(todoDescription: nil)` は `.set(nil)` ではなく **`.unset`**（引数を渡さなかった扱い）になる。最初これをアプリ側のバグと誤診しかけたが、`UpdateTodoIntent` の実装は正しかった。`Optional` 自身が `IntentValueExpressing` に適合しているので、`let explicitNull: any IntentValueExpressing = String?.none` のように**型付きの nil** を渡すと `.set(nil)` になり、期待どおりクリアされた。

2. **クリーンビルド直後の最初のテストだけ `AppIntentsServicesMetadataErrorDomain Code=400 "dev.touyou.IntentTodo is not present"`**。App Intents のメタデータサービスが新しいアプリをまだ認識していないだけ。`setUp` で軽いクエリが通るまでポーリングしてから本体に入るようにして解消した。

3. **`app.launch()` → `app.activate()`**。前項では「起動済みなら activate」と条件分岐にしていたが、クリーンビルド後は結局 `launch()` を通って落ちたので、無条件 `activate()`（未起動なら起動・起動済みなら前面化）に単純化した。`--uitesting` 起動引数はアプリ側で読んでいなかったので失うものは無い。

**テストにできないと分かったもの**: `IntentValueQuery`（Visual Intelligence）。`VisualIntelligence.framework` は iOS **実機** SDK と macOS SDK にはあるが **iOS Simulator SDK には無い**ため、シミュレータビルドでは `#if canImport(VisualIntelligence)` が false になり `TodoVisualIntelligenceQuery` 自体がバイナリに入らない。`definitions.valueQueries[...]` で参照できないので、この観点だけは実機か macOS destination に回すしかない。
