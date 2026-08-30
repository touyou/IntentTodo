# App Intents API 採用状況マップ

App Intents（+ 密接に絡む WidgetKit / ActivityKit / Spotlight）の API を **1 行ずつ全部並べて、
このアプリが今どう扱っているか**を書いたもの。「まだ使っていない機能を眺めて次の拡張を考える」ための地図。

- API の**出典セッションと詳しい説明**は [WWDC_APP_INTENTS_SESSIONS.md](WWDC_APP_INTENTS_SESSIONS.md)
- **採用したものの実装パターンと落とし穴**は [insights/03-app-intents-core.md](insights/03-app-intents-core.md)
- **なぜその判断になったかの経緯**は [devlog/](devlog/README.md)
- **「やる」と決めたタスク**は GitHub issue（未採用候補の消化は **#68**）

> このファイルは**状態の地図**であってタスクリストではない。チェックボックスは置かない。
> 着手すると決めた時点で issue を立て、ここの状態列を更新する。

## 凡例

| 記号 | 意味 |
|:--:|---|
| ✅ | 採用済み（コードにある） |
| ⬜ | **未採用だが着手すれば価値が出る** → #68 |
| ⏸ | 意図的不使用（API は把握済み・このアプリには不要と判断） |
| 🚫 | 不適合 / 対象外（題材が持っていない、または適合できない） |
| ⛔ | deprecated（採用しない） |
| ⏳ | やりたいが外部要因（SDK バグ等）でブロック中 |

---

## 1. Intent の基本

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `AppIntent` | アクションの宣言 | ✅ | Intent ファイル 25 本。全アクションがここを通る |
| `@Parameter` | Siri / Shortcuts に見せる入力 | ✅ | 22 ファイルで使用 |
| `@Parameter(requestValueDialog:)` | 値を聞くときの文言 | ⬜ | 非 optional はシステムが自動で聞き返すため未使用。文言を作り込むなら候補 |
| `ParameterSummary` / `Summary` / `When` / `Switch` | Shortcuts エディタでのパラメータ表示 | ✅ | 16 ファイル。条件分岐（`When`）まで使用。**summary は表示の allowlist**なので、Intent が変えられるパラメータは trailing ブロックまで含めて全部載せる（`AGENTS.md` 参照） |
| `IntentDescription` | 説明・カテゴリ・検索キーワード | ✅ | 24 ファイル |
| `IntentDescription.resultValueName` | 戻り値のマジック変数名 | ✅ | `TodoEntityQuery` / `CategoryEntityQuery` |
| `IntentDescription.assistantOnly` | Shortcuts に出さず Apple Intelligence 専用にする | ⏸ | 隠したい Intent は `isDiscoverable = false` で足りている |
| `isDiscoverable = false` | 内部用 Intent を Siri / Shortcuts から隠す | ✅ | 6 本（`QuickSnooze` / `DeleteTodoImmediately` / `SetTodoCompletion` / `Reorder` / snippet 2 本） |
| `IntentResult` / `.result(value:dialog:)` | 実行結果の返却 | ✅ | 全 Intent |
| `OpensIntent` | 別 Intent を続けて開く | ✅ | `AddTodoIntent` / `ShowTodosIntent` |
| `CustomAppIntentErrorConvertible` | 自前エラーをシステムのエラー語彙へ | ✅ | `IntentError.notFound` → `entityNotFound` |
| `CustomLocalizedStringResourceConvertible` | エラー文言のローカライズ | ⏸ | 上記の `CustomAppIntentErrorConvertible` を採用したので不要 |
| `AppIntentsPackage` | Intent をパッケージに置く | ✅ | `TodoIntentsPackage` + 利用側 4 ターゲットで `includedPackages` 宣言 |
| `openAppWhenRun` | 旧・アプリを開くフラグ | ⛔ | `supportedModes` へ移行済み |

## 2. Intent の種別（プロトコル）

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `OpenIntent` | 「〇〇を開く」の system intent | ✅ | `OpenTodoIntent` / `OpenCategoryIntent` |
| `DeleteIntent` | 「削除する」の system intent | ✅ | `DeleteTodosIntent`（バルク） |
| `SetValueIntent` | 絶対値セット（トグル UI 用） | ✅ | `SetTodoCompletionIntent` |
| `ShowInAppSearchResultsIntent` | アプリ内検索へ橋渡し | ✅ | `ShowTodoSearchResultsIntent`（`#if !os(watchOS)`） |
| `SnippetIntent` | Siri 応答に SwiftUI を埋める | ✅ | `TodoSnippetIntent` / `TodoSummarySnippetIntent` |
| `SnippetIntent.reload()` | snippet を外から更新 | ⬜ | データが外から変わったときに Siri の表示を追随させられる |
| `LiveActivityIntent` | Live Activity の状態を触れる | ✅ | `ToggleTodoCompletionIntent` / `QuickSnoozeTodoIntent`（`#if os(iOS)`） |
| `UndoableIntent` | 取り消し可能な操作 | ✅ | 削除 3 本 + 完了トグル。登録は `TodoUndoRegistrar` に集約 |
| `LongRunningIntent` | 30 秒制限を超える処理 | ✅ | `CompleteTodosIntent` |
| `CancellableIntent` | グレースフルキャンセル | ✅ | 同上（`performBackgroundTask(operation:onCancel:)`） |
| `ProgressReportingIntent` | 進捗を Siri UI に出す | ✅ | `LongRunningIntent` 経由で自動的に準拠。`progress` を更新している |
| `SetFocusFilterIntent` | 集中モード連携 | ✅ | `TodoFocusFilterIntent`（カテゴリ / 急ぎのみ / 完了を隠す） |
| `WidgetConfigurationIntent` | ウィジェットの設定 Intent | ✅ | `TodoWidgetConfiguration` |
| `ControlConfigurationIntent` | コントロールの設定 Intent | ✅ | `SelectTodoConfigurationIntent` |
| `TargetContentProvidingIntent` | シーンへのコンテンツ遷移 | ✅ | `LaunchAppIntent`（iOS / visionOS のみ準拠。macOS / watchOS は SDK で unavailable） |
| `UISceneAppIntent` + `AppIntentSceneDelegate` | cold start でシーンに Intent を届ける | ✅ | `LaunchAppIntent` / `OpenTodoIntent` + `SceneDelegate.applyNavigation()` |
| `URLRepresentableIntent` | Intent を URL で表現 | ✅ | `OpenTodoIntent`（`OpenIntent` との組み合わせで無償） |
| `AudioPlaybackIntent` | 再生系 | 🚫 | 再生機能がない |
| `RunSystemShortcutIntent` / `SystemShortcut` | システム側ショートカットの実行（iOS 27, iOS 限定） | 🚫 | `SystemShortcut` に公開イニシャライザが無く、アプリから値を作れない（beta 6 の swiftinterface で確認） |
| `_ModelDelegationIntent` / `IntentResponseStream` | 応答をストリームで返す（iOS 27） | 🚫 | 下線付き + `@_documentation(visibility: internal)`。公開 API として使えない |
| `CustomIntentMigratedAppIntent` | SiriKit からの移行 | 🚫 | SiriKit 資産がない |
| `LiveActivityStartingIntent` | 旧・LA 開始専用 | ⛔ | iOS 17 で deprecated。`LiveActivityIntent` が後継 |
| `PredictableIntent` | 実行タイミングを予測して提案 | ⏸ | donation ゼロなので提案自体が出ない（#53 で donation 不採用を決着） |
| `ForegroundContinuableIntent` | 旧・動的 foreground 化 | ⛔ | `.foreground(.dynamic)` が後継（そちらも #55 で不採用） |

## 3. 実行制御

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `supportedModes` `.background` | アプリを開かない | ✅ | 変更系のほぼ全部 |
| `.foreground(.immediate)` | すぐ前面 | ✅ | `LaunchAppIntent` / `Open*Intent` |
| `.foreground(.deferred)` | 背景で始めて必要なら前面 | ✅ | `AddTodoIntent` |
| `.foreground(.dynamic)` / `continueInForeground()` | `perform()` 内で前面化を判断 | ⏸ | **#55 で「適所なし」と結論**。開くは `OpensIntent`、対話は `requestChoice`、読ませるは dialog + snippet で埋まっている |
| `systemContext.currentMode` / `canContinueInForeground` | 実行モードの参照 | ⏸ | 上と同じ理由で参照する必要がない |
| `allowedExecutionTargets` | 実行プロセスを固定 | ✅ | **書き込み系は全部 `[.main]`**。読み取り系は固定しない。宣言漏れは `IntentExecutionTargetsTests` が検出 |
| `performBackgroundTask` | 長時間処理の入れ物 | ✅ | `CompleteTodosIntent` |
| `performBackgroundTask(options:)` / `LongRunningTaskOptions` | `.requiresGPU` の宣言（iOS 27） | 🚫 | GPU を使う処理がない。バルク完了は SwiftData の書き込みだけ |

## 4. 対話・応答

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `IntentDialog` | Siri が読む / 表示する文言 | ✅ | 9 ファイル |
| `IntentDialog(full:supporting:)` | 音声専用と視覚併用を分ける | ✅ | `ShowTodosIntent` ほか |
| `ShowsSnippetView` / `.result(view:)` | 応答に View を添える | ✅ | snippet 2 本 |
| snippet 内 `Button(intent:)` | 応答から次のアクション | ✅ | `TodoSnippetView` |
| `requestConfirmation` | 実行前の確認 | ✅ | `DeleteTodoIntent` / `DeleteTodosIntent`。**UI からは呼べない**ので確認なし版を用意 |
| `requestConfirmation(actionName:snippetIntent:)` | 確認に snippet を添える | ⏸ | 確認は UI 側の `.confirmationDialog` に寄せているので出番がない |
| `requestChoice` / `IntentChoiceOption` | 選択肢を出す | ✅ | `SnoozeTodoIntent`（スヌーズ期間） |
| `requestValue` | 不足パラメータを能動的に聞く | ⏸ | 非 optional はシステムが自動で聞き返す。#68 で再評価 |
| `requestDisambiguation` | 候補から選ばせる | ⏸ | Entity は Query が解決するため出番がない |
| `ContainerRelativeShape` | snippet 背景の角丸 | ⏸ | snippet は標準レイアウトのまま。作り込むなら候補 |

## 5. Entity とプロパティ

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `AppEntity` | 名詞モデル | ✅ | `TodoAppEntity` / `CategoryAppEntity` / `SubTaskAppEntity` |
| `TransientAppEntity` | クエリ不要の一時 Entity | ✅ | `TodoListSummaryEntity`（`GetTodoSummaryIntent` の戻り値） |
| `AppEnum` | パラメータ用の列挙 | ✅ | `TodoFilterType` / `AppScreenTarget` / `TodoListType` |
| `@UnionValue` | 複数 Entity 型を 1 つの値に | ✅ | `TodoOrCategory`（検索 / Visual Intelligence） |
| `@Property` | システムに見せる属性 | ✅ | 4 Entity |
| `@ComputedProperty` | 同期 getter の派生属性 | ✅ | `TodoAppEntity.isOverdue` ほか |
| `@DeferredProperty` | 非同期の遅延取得属性 | ✅ | `TodoAppEntity.subtaskProgress` |
| `@Property(indexingKey:)` | Spotlight キーへの宣言的マッピング | ✅ | title → `\.title` / description → `\.contentDescription`。iOS / macOS / **visionOS**（watchOS / tvOS は SDK で unavailable なので素の `@Property`） |
| `DisplayRepresentation` | 表示表現 | ✅ | 全 Entity。実行時値は `"\(value)"` 補間で渡す |
| `DisplayRepresentation` の `synonyms:` | 同義語で認識精度を上げる | ✅ | Todo / Category / SubTask |
| `DisplayRepresentation` の画像 | サムネイル | ✅ | 遅延クロージャで指定 |
| `DisplayRepresentation.Components` | 要求される表示要素の指定 | ⏸ | 現状は text / image で十分 |
| `SyncableEntity` | デバイス間 ID 一貫性 | ✅ | `TodoAppEntity`（String UUID id でそのまま適合） |
| `SyncableEntityIdentifier` | ローカル ID と安定 ID のペア | ⏸ | id が最初から安定なのでペアにする必要がない |
| `OwnershipProvidingEntity` / `EntityOwnership` | public / shared の宣言 | ⏸ | 共有機能がない（個人利用主体）。CloudKit 共有を入れるなら候補 |
| `IntentPerson` / `PlaceDescriptor` への `ValueRepresentation` | システム値型へ bridge | ✅ | 担当者 → `IntentPerson` / 場所 → `PlaceDescriptor`。`TodoAppEntity.location` は `PlaceDescriptor?`（`@Property` は SSU バグを踏まない、2026-08-29 実測）。退避が必要なのは **App Shortcut 登録済み Intent の `@Parameter`** だけで、`AddTodoIntent.location` は `String` のまま（FB24548956 → #57） |
| `Transferable` + `ProxyRepresentation` | 共有・ドラッグ&ドロップ | ✅ | `TodoAppEntity` |
| `DataRepresentation` / `FileRepresentation` | バイト列 / ファイルでの転送 | 🚫 | Todo はファイルベースのコンテンツを持たない |
| `URLRepresentableEntity` | URL で Identity を表現 | ✅ | `TodoAppEntity` + `TodoDeepLink` |
| `IntentFile` / `FileEntity` / `FileEntityIdentifier` | ファイルの受け渡し | 🚫 | 同上 |
| `EntityCollection` | バルクパラメータ | ✅ | `CompleteTodosIntent` |
| `IntentParameter.valueState` | 新値 / 明示クリア / 据え置きの区別 | ✅ | `UpdateTodoIntent` + `TodoService.FieldUpdate` |
| `Duration` / `PersonNameComponents` | ネイティブ型パラメータ | ✅ | 所要時間 / 担当者名 |

## 6. Query

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `EntityQuery` | id からの解決 | ✅ | Todo / Category / SubTask の 3 本 |
| `EntityStringQuery` | 文字列検索（自分でフィルタする） | ✅ | 3 本。比較は `localizedStandardContains` |
| `EnumerableEntityQuery` | 全件返す。Shortcuts の Find が自動生成される | ✅ | `TodoEntityQuery` / `CategoryEntityQuery` |
| `EnumerableEntityQuery.findIntentDescription` | Find アクションの説明文 | ✅ | 同上 |
| `EntityQuery.displayRepresentations(for:)` | entity を作らず表示だけ返す | ✅ | 3 本 |
| `suggestedEntities()` | 候補の提案 | ✅ | `TodoEntityQuery` |
| `IndexedEntityQuery` | システム主導の Spotlight 再インデックス | ✅ | `TodoEntityQuery` |
| `IntentValueQuery` | Visual Intelligence の検索結果 | ✅ | `TodoVisualIntelligenceQuery`（`#if canImport(VisualIntelligence)`） |
| `EntityPropertyQuery` + `QueryProperties` / `SortingOptions` | Find を自前実装 | ⏸ | **不要**。`EnumerableEntityQuery` が Find と絞り込みを自動生成する。必要になるのは "many thousands of entities" 規模 |
| `DynamicOptionsProvider` | パラメータの動的選択肢 | ⏸ | 選択肢は `AppEnum` の静的リストで足りる |
| `IntentParameterDependency` | パラメータ間の動的依存 | ⏸ | そういうユースケースがない |

## 7. Spotlight / 検索

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `IndexedEntity` | Spotlight セマンティックインデックス | ✅ | `TodoAppEntity`（iOS / macOS / visionOS。watchOS は対象外） |
| `attributeSet` | 追加の Spotlight 属性 | ✅ | `indexingKey` で書けないものだけ。**二重書きは静かに壊れる** |
| `CSSearchableIndex.indexAppEntities(_:)` | entity の一括登録 | ✅ | `TodoSpotlightIndex`（名前付き index） |
| client state バッチ | 差分インデックスの整合 | ✅ | `clientState(for:)`（SHA-256）+ `beginBatch` / `endBatch` |
| `@AppIntent(schema: .system.searchInApp)` | Siri からアプリ内検索へ | ✅ | `ShowTodoSearchResultsIntent` |
| `associateAppEntity(_:)` / `relatedAppEntityIdentifier` | 既存の searchable item に entity を紐付け | 🚫 | 子アイテム（添付等）がないので対象なし |
| `SpotlightSearchTool` + `LanguageModelSession` | Spotlight を LLM の tool にする | 🚫 | **#52 でスコープ外決着**。残りが FoundationModels 側の作業になる |

## 8. App Shortcuts / Siri フレーズ

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `AppShortcutsProvider` | フレーズの宣言的登録 | ✅ | `TodoAppShortcuts`（**アプリターゲット直下必須**）。8 件 |
| フレーズへの `AppEntity` / `AppEnum` 埋め込み | `Complete <todo> in <app>` の形 | ✅ | 8 件中 5 件がパラメータ入り |
| `updateAppShortcutParameters()` | 候補の再取得 | ✅ | `App.init()` + `TodoService.dataDidChange()` から |
| `shortTitle` / `systemImageName` | iOS 17 以降必須 | ✅ | 全件 |
| `AppShortcutsProvider.shortcutTileColor` | Shortcuts タイルの色 | ✅ | 設定済み |
| `AppShortcuts.xcstrings` | フレーズのローカライズ | ✅ | ja 対応（#70）の最終工程として実施。8 キーすべて String Set で、訳ではなく発話バリエーションを並べる（全値に `${applicationName}` 必須）。schema 適合した Intent はフレーズも訓練も Apple 側が持つので対象外（wwdc2026-8011 `59:03`）。詳細: [docs/insights/04-ui-integration.md](insights/04-ui-integration.md#ja-を入れて分かった-catalog-の配置) |
| negative phrases API | 特定フレーズに反応させない | ⏸ | 誤爆の報告がないので未着手 |
| `SiriTipView` | アプリ内でフレーズを見せる | ✅ | `SiriTipBanner`。一覧上端に**アプリ内で 3 回目の追加をした直後だけ**出す（常設しない。macOS は SDK で unavailable） |
| `ShortcutsLink` | Shortcuts アプリへの導線 | ✅ | `SettingsView` の「Siri & Shortcuts」（探索の導線なので一覧の一等地には置かない。macOS / watchOS は SDK に型が無い） |

## 9. App Schema（意味ドメイン適合）

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `@AppEnum(schema: .reminders.listType)` | リスト種別の適合 | ✅ | `TodoListType`（watchOS は素の `AppEnum` にフォールバック） |
| `@AppEntity(schema: .reminders.list)` | リストの適合 | ✅ | `CategoryAppEntity`（同上。型名も `WatchCategoryAppEntity` に分ける必要がある） |
| `@AppEntity(schema: .reminders.reminder)` | Todo 本体の適合 | ✅ | `TodoAppEntity`（#56）。モデルに `completionDate` / `tags` / `urls` / `recurrenceFrequency` + `recurrenceInterval` / `locationTriggerEvent` を追加し（`Calendar.RecurrenceRule` は SwiftData 属性にできないので primitive で持つ）、スキーマ要求名は `@ComputedProperty` の別名で満たす。`dueDate` のみ型が衝突するので stored を `dueDateValue` に改名。**親の適合はサブエンティティの適合も要求する**。App Schema は watchOS / tvOS に存在しないので、watch には適合を持たない別型（`WatchTodoAppEntity`）を置く（#87） |
| `@AppEntity(schema: .reminders.locationTrigger)` | 場所トリガー | ✅ | `TodoLocationTriggerAppEntity`（`place: PlaceDescriptor` + `event`） |
| `@AppEnum(schema: .reminders.locationTriggerEvent)` | arrive / depart | ✅ | `TodoLocationTriggerEvent` |
| `@AppIntent(schema: .system.searchInApp)` | アプリ内検索 | ✅ | `ShowTodoSearchResultsIntent` |
| `@AppIntent(schema: .system.open)` | 「開く」の適合 | ⏸ | 素の `OpenIntent` で成立している |
| `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` | Visual Intelligence の「もっと見る」 | ✅ | `TodoSemanticContentSearchIntent` |
| `.system.search`（旧名） | — | ⛔ | `.system.searchInApp` にリネーム |

## 10. Onscreen / 通知 / 他フレームワーク統合

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `NSUserActivity.appEntityIdentifier` | 表示中の単一 entity を提供 | ✅ | `TodoDetailView` ほか |
| `.appEntityIdentifier(forSelectionType:)` | 一覧の各行を提供 | ✅ | `TodoListView` / `VisionOSTodoView`。**`List` の selection 型が手がかり**なので selection の無い watchOS は行ごとの単一 annotation |
| `.appEntityUIElements` | bounds を推測できない描画に明示 | 🚫 | `Canvas` 等を使っていない |
| `UNMutableNotificationContent.appEntityIdentifiers` | 通知に entity を紐付け | ✅ | Control のエラー通知 |
| `AppEntityAnnotatable` / `UICollectionViewAppIntentsDataSource` | UIKit 側の onscreen 提供 | 🚫 | SwiftUI アプリなので対象外 |
| `MusicContent.appEntityIdentifiers` / `AlarmConfiguration.appEntityIdentifier` | Now Playing / AlarmKit との紐付け | 🚫 | 該当機能がない |
| `RelevantEntities` + `AppEntityContext` | 文脈に応じた entity 寄付 | 🚫 | **todo / reminders 向けの `AppEntityContext` が存在しない**ため適合不能（beta 6 でもファクトリは `.audio(_:)` の 1 つだけ） |
| `RelevantIntent` / `RelevantIntentManager` | Smart Stack への Intent 提案 | ⬜ | `WidgetConfigurationIntent` があるので donation なしで成立する経路（#68） |
| `IntentDonationManager.donate(_:)` / `AppIntent.donate()` | 実行履歴の寄付 | ⏸ | **#53 で不採用決着**。`perform()` 内 donate は規約違反。加えて **`Button(intent:)` の実行はシステムが既に donation として記録している**（2026-08-30 実測）ので、UI が全部 `Button(intent:)` の本アプリには donate すべきものが残らない。別プロセス起点は未確定（#98） |
| `deleteDonations(matching:)` | 消えた entity の提案を消す | ✅ | 削除 3 経路すべて（呼出元に関係なく正しい後片付け） |
| EventKit / Contacts 連携 | 期限 → カレンダー等 | 🚫 | 別フレームワーク軸。記録のみ |

## 11. ウィジェット / コントロール / ライブアクティビティ

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `Button(intent:)`（ウィジェット） | ウィジェットからアクション | ✅ | `TodoWidgetRow` ほか |
| `Toggle(isOn:intent:)`（ウィジェット） | ウィジェット内のトグル | ⬜ | `SetTodoCompletionIntent` があるので素直に置き換えられる（#68） |
| `Link(destination:)` / `widgetURL(_:)` | アプリを開くだけの導線 | ✅ | 行タップ（公式推奨） |
| `invalidatableContent()` | 無効化中の見た目 | ⬜ | Button 実行中の表示を作り込むなら（#68） |
| `AppIntentConfiguration` | 設定可能ウィジェット | ✅ | `IntentTodoWidget` |
| `supportedFamilies` | サイズ対応 | ✅ | Small / Medium / Large / ExtraLargePortrait |
| `widgetAccentedRenderingMode` / `widgetAccentable()` | ティント表示時の制御 | ⏸ | SF Symbols のみなので実害が薄い |
| `supportedMountingStyles` / `widgetTexture` / `levelOfDetail` | visionOS ウィジェット強化 | ⬜ | WidgetKit 側の拡張候補（#68） |
| `ControlWidget` + `StaticControlConfiguration` | 設定なしコントロール | ✅ | `QuickAddTodoControl` / `TodoCountControl` |
| `AppIntentControlConfiguration` | 設定可能コントロール | ✅ | `ToggleTodoControl`（対象 todo を固定） |
| `ControlWidgetButton` / `ControlWidgetToggle` | 単発 / 2 状態 | ✅ | 用途で使い分け |
| `ControlValueProvider` / `AppIntentControlValueProvider` | 現在値の供給 | ✅ | 2 コントロール（body 直 fetch より推奨） |
| `.controlWidgetActionHint(_:)` | Action ボタン用ヒント | ✅ | 2 コントロール |
| `.controlWidgetStatus(_:)` | 一時的なステータス表示 | ⬜ | Control は dialog も snippet も出ないので、通知に頼らない伝達経路になり得る（#68。まず実機で出るか確認） |
| `.promptsForUserConfiguration()` | 未設定のまま置かせない | ✅ | `ToggleTodoControl`（2026-08-12 に設定シートを確認） |
| `ControlCenter.shared.reloadAllControls()` | コントロールのリロード | ✅ | `WidgetReloader`（`WidgetCenter` だけではコントロールは更新されない） |
| `reloadControls(ofKind:)` | 特定 kind だけ | ⏸ | 全リロードのコストが無視できる規模 |
| `ActivityConfiguration` / Live Activity | ロック画面 + Dynamic Island | ✅ | 期限 1 時間以内で自動表示 |

## 12. テスト

| API | 一言 | 状態 | このアプリでの扱い |
|---|---|:--:|---|
| `AppIntentsTesting` + `IntentDefinitions` | Intent を実経路で実行テスト | ✅ | `IntentTodoUITest/AppIntents/` に 23 テスト（UI テストバンドル必須） |
| `makeIntent(...).run()` | Intent 実行 | ✅ | 追加 / トグル / スヌーズ / サマリ / 連鎖 |
| `entities(matching:)` / `allEntities()` / `suggestedEntities()` | Query の検証 | ✅ | `TodoEntityQueryTests` |
| `spotlightQuery(_:)` | Spotlight 登録の検証 | ✅ | 追加で載る / 削除で消える |
| `viewAnnotations()` | onscreen annotation の検証 | ✅ | 一覧の全行 + 詳細画面 |
| `values(for:)`（valueQueries） | `IntentValueQuery` の検証 | 🚫 | `VisualIntelligence.framework` が Simulator SDK に無く、ビルドから除外される |
| watchOS での `run()` | — | 🚫 | `LNPerformActionPrebuiltErrorCodeActionNotAllowed` で落ちる。watchOS は手動確認（#30） |
| フレーズ（Siri）のルーティング | — | 🚫 | `AppIntentsTesting` に phrase / siri 相当の API が無い。Apple の想定どおり手動（#30） |

---

## いま空いている穴（優先度つき）

着手判断は **#68** で行う。理由と前提は各行の「このアプリでの扱い」列に書いてある。

1. `.controlWidgetStatus(_:)` — Control のフィードバック経路がもう 1 本増える可能性
2. `Toggle(isOn:intent:)` — 完了切り替えの意味論に合う
3. `invalidatableContent()` / `SnippetIntent.reload()` — 表示の追随
4. `RelevantIntent` — donation なしで成立する提案経路。**設定の連携セクションに on/off の置き場ができた**
5. visionOS ウィジェット強化（`supportedMountingStyles` / `widgetTexture` / `levelOfDetail`）
6. `AudioPlaybackIntent` — 「この Todo をやる間これを流す」。未採用の Intent 種別

ブロック中のものは #57（GM SDK 棚卸し）。App Schema と watch ターゲットの両立は Apple 報告済みで
#57 にぶら下げた（FB24570185 / `docs/feedback/2026-08-30-app-schema-watch-metadata-merge.md`）。

`ShortcutsLink` はこのリストから外した（採用済み。置き場は設定画面）。
経緯: [docs/devlog/04-ui-integration.md](devlog/04-ui-integration.md)（2026-08-28 の Siri Tip / ShortcutsLink の置き場）

`AppShortcuts.xcstrings` はこのリストから外した（長く 1 位に置いていたが前提が事実と違った）。
アプリ全体が英語のみでフレーズだけ訳しても成立しないため、ja 対応を通しでやる **#70** の
最終工程として 2026-08-28 に実施済み。
経緯: [2026-08-28-appshortcuts-localization-reeval.md](devlog/2026-08-28-appshortcuts-localization-reeval.md)
（降格の判断）/ [2026-08-28-ja-localization.md](devlog/2026-08-28-ja-localization.md)（実施）
