# App Intents - WWDC セッション リンク集

App Intents フレームワークが登場した WWDC 2022 から最新の WWDC 2026 までの公式セッション・ラボアーカイブをまとめたリンク集。  
各セッションで紹介された新 API・機能を網羅的に記載。非推奨化タイムラインも末尾にまとめた。

---

## WWDC 2022 — 初登場（iOS 16）

App Intents フレームワークが SiriKit の後継として導入された年。Info.plist 設定不要・ビルド時メタデータ自動抽出という設計が最大の革新。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 10032 | [Dive into App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/) | App Intents の全体像・SiriKit との違い・基本実装 |
| 10169 | [Design App Shortcuts](https://developer.apple.com/videos/play/wwdc2022/10169/) | App Shortcuts の UX 設計ガイドライン |
| 10170 | [Implement App Shortcuts with App Intents](https://developer.apple.com/videos/play/wwdc2022/10170/) | パラメータ付きフレーズ・カスタムスニペット実装 |

### 新機能（10032 Dive into App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `AppIntent` プロトコル | アプリのアクションを宣言する基底プロトコル。`perform() async throws -> some IntentResult` を実装 |
| `AppEntity` プロトコル | Siri / Shortcuts が参照できる名詞モデル。`id`・`displayRepresentation`・`defaultQuery` を要求 |
| `EntityQuery` プロトコル | `entities(for:)` / `suggestedEntities()` を実装し Entity を検索・提案 |
| `@Parameter` | Siri がユーザーに入力を求めるパラメータの宣言。`title`・`requestValueDialog` 等を指定 |
| `AppShortcutsProvider` | Siri フレーズの宣言的登録（最大 10 件）。アプリインストール直後から利用可 |
| `AppShortcut` | `intent:`・`phrases:`・`shortTitle:`・`systemImageName:` で 1 件分のショートカットを定義 |
| `DisplayRepresentation` | Entity の Siri / Shortcuts UI 上の表示文字列・アイコン |
| `TypeDisplayRepresentation` | Entity 型全体の表示名（ピッカーの見出しなど） |
| `IntentResult` / `.result()` 系 | 実行結果の返却。`.result()` / `.result(value:)` / `.result(dialog:)` / `.result(value:dialog:)` |
| `IntentDialog` | Siri が読み上げる・表示するダイアログ文字列 |
| `AppEnum` プロトコル | パラメータ・結果に使える列挙型。`caseDisplayRepresentations` で各 case の表示名を定義 |
| `openAppWhenRun` | `true` でアプリをフォアグラウンドへ（後に `supportedModes` へ移行） |
| ビルド時メタデータ抽出 | `Metadata.appintents` バンドルをビルド時に自動生成。Info.plist 設定不要 |

### 新機能（10170 Implement App Shortcuts with App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `ParameterSummary` | Shortcuts アプリ上でのパラメータ表示順・要約文のカスタマイズ |
| `ReturnsValue<T>` | Intent が値を返すことを宣言するプロトコル合成型 |
| `ProvidesDialog` | Intent がダイアログを返すことを宣言するプロトコル合成型 |
| `ShowsSnippetView` | Intent が SwiftUI スニペットを返すことを宣言（`.result(view:)` と組み合わせ） |
| `confirmBeforeRunning` | 破壊的操作の前に確認ダイアログを挟む（`requestConfirmation` の前身） |
| フレーズの `\(.applicationName)` 変数 | App Shortcut フレーズにアプリ名を埋め込む |
| `AppShortcut` フレーズへの `AppEnum` 埋め込み | `\(\.$filter)` 形式で AppEnum をフレーズに埋め込み（String は不可） |

### ✂️ 非推奨化

| API | 移行先 | タイミング |
|-----|--------|----------|
| SiriKit `INIntent`（Shortcuts 系） | `AppIntent` | WWDC 2022（App Intents 登場と同時に移行推奨） |

---

## WWDC 2023 — ウィジェット連携（iOS 17）

ウィジェットへの App Intents 統合（インタラクティブウィジェット）が最大のトピック。Swift Package 内での Intent 定義も正式サポート。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 10028 | [Bring widgets to life](https://developer.apple.com/videos/play/wwdc2023/10028/) | App Intents によるウィジェットのインタラクティブ化 |
| 10102 | [Spotlight your app with App Shortcuts](https://developer.apple.com/videos/play/wwdc2023/10102/) | iOS 17 の新機能・Shortcuts アプリ UI 改善・Spotlight 連携 |
| 10103 | [Explore enhancements to App Intents](https://developer.apple.com/videos/play/wwdc2023/10103/) | フレームワーク強化・静的抽出改善・開発者体験向上 |

### 新機能（10028 Bring widgets to life）

| API / 機能 | 概要 |
|-----------|------|
| `Button(intent:)` | SwiftUI ウィジェット内から Intent を直接実行。アプリ起動なしでアクション完結 |
| `Toggle(isOn:intent:)` | ウィジェット内のトグルを Intent にバインド |
| ウィジェットの即時リロード | Intent 実行後にウィジェットを自動リロードするための `invalidatableContent()` モディファイア |

### 新機能（10102 Spotlight your app with App Shortcuts）

| API / 機能 | 概要 |
|-----------|------|
| App Shortcuts in Spotlight | Spotlight 検索から App Shortcut を直接起動できる統合 |
| Shortcuts アプリ UI 改善 | アプリアイコンと App Shortcut が Shortcuts アプリ内でより視覚的に表示 |
| `AppShortcutsProvider.updateAppShortcutParameters()` | Shortcut パラメータの動的更新 |

### 新機能（10103 Explore enhancements to App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `EntityStringQuery` | `entities(matching:)` を実装し文字列による Entity 検索に対応 |
| `ForegroundContinuableIntent` | バックグラウンド実行途中に動的フォアグラウンド遷移（後に `supportedModes` へ移行） |
| `IntentDonationManager` | `donate(_:)` でアクション履歴を寄付し Siri 提案の学習を強化 |
| `PredictableIntent` | 実行タイミングを予測して Shortcuts に提案するための準拠プロトコル |
| `RelevantIntent` | 状況に応じた Intent を Shortcuts に提案 |
| `AppIntentsPackage` | Swift Package 内に Intent / Entity / Query を定義する正式サポート |
| 静的抽出の改善 | ビルドシステムによる Intent メタデータ抽出の信頼性向上 |

---

## WWDC 2024 — Apple Intelligence 統合（iOS 18）

App Intent Domains 導入で Siri の AI 機能との統合が強化。ControlWidget（コントロールセンター）サポートも追加。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 10133 | [Bring your app to Siri](https://developer.apple.com/videos/play/wwdc2024/10133/) | App Intent Domains・エンティティの Spotlight インデックス化・Siri 統合 |
| 10134 | [What's new in App Intents](https://developer.apple.com/videos/play/wwdc2024/10134/) | Transferable API・IntentFile・Spotlight Indexing の新機能 |
| 10157 | [Extend your app's controls across the system](https://developer.apple.com/videos/play/wwdc2024/10157/) | ControlWidget・ControlWidgetToggle と App Intents の組み合わせ |
| 10176 | [Design App Intents for system experiences](https://developer.apple.com/videos/play/wwdc2024/10176/) | Intent 設計原則・パラメータ設計・アプリ外アクションの UX |

### 新機能（10133 Bring your app to Siri）

| API / 機能 | 概要 |
|-----------|------|
| `@AppEntity(schema:)` | Entity をドメイン（`.photos.asset` / `.mail.message` / `.reminders.reminder` 等）に意味的適合 |
| `@AppIntent(schema:)` | Intent を意味ドメインに適合。Siri / Apple Intelligence がコンテンツを理解 |
| `@AppEnum(schema:)` | AppEnum をドメイン定義に適合（例: `.reminders.listType`）|
| `IndexedEntity` | `CSSearchableIndex` を使った Spotlight セマンティックインデックス対応 |
| `CSSearchableItemAttributeSet` 統合 | `attributeSet` プロパティで Entity をカスタム Spotlight メタデータと紐付け |
| `AppEntityContext` | 現在の文脈（再生中・閲覧中など）を指定して `RelevantEntities` に渡す |
| `RelevantEntities.shared.updateEntities(_:for:)` | 文脈に応じた Entity を寄付し Siri が状況を把握できるようにする |
| Apple Intelligence 統合 | 端末内 AI（Apple Intelligence）が App Intents を介してアプリのアクションを理解・実行 |

### 新機能（10134 What's new in App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `Transferable` + AppEntity | Entity に `Transferable` 準拠を追加してドラッグ&ドロップ・共有シートに対応 |
| `IntentFile` | ファイルを `@Parameter` で受け渡す型（ドキュメント操作 Intent に活用） |
| Spotlight Indexing 強化 | `IndexedEntity` の `attributeSet` に複数フィールドを設定してより豊かなインデックス |

### 新機能（10157 Extend your app's controls across the system）

| API / 機能 | 概要 |
|-----------|------|
| `ControlWidget` | コントロールセンターに表示するウィジェットの基底型 |
| `ControlWidgetButton` | タップで Intent を実行するコントロールセンターボタン |
| `ControlWidgetToggle` | ON/OFF を切り替える Intent に紐付けたトグルコントロール |
| `ControlValueProvider` | コントロールの現在値（ON/OFF 状態・ラベルなど）をシステムに提供 |
| `ControlConfigurationIntent` | コントロールの設定画面で使うパラメータを定義する Intent |
| `AppIntentControlConfiguration` | `ControlWidget` のタイムラインエントリを Intent で設定する構造体 |

### 新機能（10176 Design App Intents for system experiences）

主に設計ガイドライン。新 API より「いつ Intent を使うか」「パラメータをどう設計するか」の指針を提供。

---

## WWDC 2025 — Interactive Snippets / Visual Intelligence（iOS 26）

インタラクティブスニペット・Visual Intelligence・Deferred Properties など大型機能追加。OS バージョン番号が iOS 26 へ統一された年。グループラボ形式も初導入。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 244 | [Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/) | Intent・Entity・Query の基礎から Apple Intelligence 連携まで総合入門 |
| 260 | [Develop for Shortcuts and Spotlight with App Intents](https://developer.apple.com/videos/play/wwdc2025/260/) | Mac の Shortcuts/Spotlight 強化・"Use Model" アクション連携 |
| 275 | [Explore new advances in App Intents](https://developer.apple.com/videos/play/wwdc2025/275/) | Deferred Properties・インタラクティブスニペット・Visual Intelligence 対応 |
| 281 | [Design interactive snippets](https://developer.apple.com/videos/play/wwdc2025/281/) | スニペットの UX 設計指針（レイアウト・タイポグラフィ・インタラクション） |

### 新機能（244 Get to know App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `TargetContentProvidingIntent` | Siri / Shortcuts から実行されたとき特定のシーンへコンテンツ遷移を指示する Intent プロトコル |
| `onAppIntentExecution(_:perform:)` | View modifier。`TargetContentProvidingIntent` 実行時に UI 側でハンドリング（iOS 26.4+ でコールドスタートも安定） |
| `AppIntentSceneDelegate` | シーンレベルで Intent 実行をハンドリングするプロトコル |

### 新機能（260 Develop for Shortcuts and Spotlight with App Intents）

| API / 機能 | 概要 |
|-----------|------|
| macOS Shortcuts 強化 | Mac の Shortcuts アプリで App Intents を使ったオートメーション対応を強化 |
| macOS Spotlight 統合 | IndexedEntity を Spotlight for Mac でも検索可能に |
| "Use Model" アクション連携 | Shortcuts から端末内モデル（FoundationModels）を呼び出すアクションとの連携 |

### 新機能（275 Explore new advances in App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `supportedModes`（`IntentModes`） | `.background` / `.foreground(.immediate)` / `.foreground(.dynamic)` / `.foreground(.deferred)` の 4 モードで実行タイミングを宣言的に制御。`openAppWhenRun` を置き換え |
| `continueInForeground()` | `perform()` 内から呼んで動的にアプリをフォアグラウンドへ遷移。`ForegroundContinuableIntent` を置き換え |
| `@DeferredProperty` | Entity プロパティを非同期で遅延取得（`get async throws`）。Spotlight index には含まれない。要求時のみ取得されるため重い処理に適する |
| `SnippetIntent` | Siri の返答に埋め込む SwiftUI スニペット定義の Intent。`perform()` が `ShowsSnippetView` を返す |
| `ShowsSnippetView` / `.result(view:)` | スニペット内に SwiftUI View を埋め込む返却型 |
| スニペット内 `Button(intent:)` | スニペット上のボタンから Intent を直接実行。システムが `SnippetIntent` を再実行して最新状態を反映 |
| `IntentValueQuery` | `values(for: SemanticContentDescriptor)` を実装し Visual Intelligence の検索結果として Entity を返す |
| `SemanticContentDescriptor` | カメラ・スクショの内容（`labels: [String]`・`pixelBuffer`）を表す Visual Intelligence の入力型 |
| Onscreen Entities（単一） | `NSUserActivity.appEntityIdentifier = EntityIdentifier(for:)` で表示中 Entity を Siri / Apple Intelligence に提供 |
| `EntityIdentifier(for:)` | Entity の識別子を `NSUserActivity` に付与するためのラッパー型 |

### 新機能（281 Design interactive snippets）

主に UX ガイドライン。スニペットのレイアウト・タイポグラフィ・ボタン配置・インタラクション設計の指針。

### グループラボ（WWDC 2025）

App Intents / Apple Intelligence 専用の Q&A セッションが開催されたが、アーカイブ動画として公開は確認できていない。

### ✂️ 非推奨化

| API | 移行先 | タイミング |
|-----|--------|----------|
| `openAppWhenRun` | `supportedModes` | WWDC 2025（`supportedModes` が公式推奨 API） |
| `ForegroundContinuableIntent` | `.foreground(.dynamic)` + `continueInForeground()` | WWDC 2025（[公式ドキュメント](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent)に deprecated 明記） |

---

## WWDC 2026 — App Schemas / SyncableEntity / テスト基盤（iOS 27）

App Schemas による Siri 統合の新アプローチ、AppIntentsTesting フレームワーク、SyncableEntity など大幅拡張。  
本プロジェクトの `xcode27` ブランチで全セッションを検証済み（詳細は `docs/APP_INTENTS_CENTRIC_PLAN.md` 参照）。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 240 | [Build intelligent Siri experiences with App Schemas](https://developer.apple.com/videos/play/wwdc2026/240/) | App Schemas を使った Siri への高度なアプリ統合 |
| 295 | [Validate your App Intents adoption with AppIntentsTesting](https://developer.apple.com/videos/play/wwdc2026/295/) | 新テストフレームワーク AppIntentsTesting の使い方 |
| 297 | [Integrate your app with Visual Intelligence](https://developer.apple.com/videos/play/wwdc2026/297/) | カメラ・スクショ連携の Visual Intelligence 統合（macOS 対応含む） |
| 343 | [Explore advanced App Intents features for Siri and Apple Intelligence](https://developer.apple.com/videos/play/wwdc2026/343/) | Siri・Apple Intelligence 対応を磨くための高度テクニック |
| 344 | [Code-along: Make your app available to Siri](https://developer.apple.com/videos/play/wwdc2026/344/) | 既存アプリを Siri 対応にするコードアロング（実践形式） |
| 345 | [Discover new capabilities in the App Intents framework](https://developer.apple.com/videos/play/wwdc2026/345/) | ValueRepresentation・RelevantEntities・EntityCollection・SyncableEntity・長時間 Intent |

### 新機能（240 Build intelligent Siri experiences with App Schemas）

| API / 機能 | 概要 |
|-----------|------|
| reminders ドメイン拡充 | `@AppEntity(schema: .reminders.list/.reminder)` / `@AppEnum(schema: .reminders.listType)` が iOS 27+ で利用可能に |
| `AppEntity.ValueRepresentation`（`IntentValueRepresentation`） | Entity を `IntentPerson` / `PlaceDescriptor` 等のシステム値型へ bridge してクロスアプリ共有 |
| `IntentPerson` / `PlaceDescriptor` への export | `ValueRepresentation(exporting:)` / `ValueRepresentation(exporting:importing:)` で定義。closure は `async throws` |
| `Transferable` + `ProxyRepresentation` | Entity をドラッグ&ドロップ・共有シートで送受信 |
| `@Property(indexingKey:)` | `PartialKeyPath<CSSearchableItemAttributeSet>` を指定し Spotlight セマンティックキーへ宣言的マッピング（iOS / macOS 限定 overload）|
| Onscreen Entities（コレクション） | `.appEntityIdentifier(forSelectionType:)` で List / ScrollView 内の各行を onscreen Entity として提供 |
| 通知への Entity 付与 | `UNMutableNotificationContent.appEntityIdentifiers` で通知に Entity を紐付け（iOS 27）|

### 新機能（295 Validate your App Intents adoption with AppIntentsTesting）

| API / 機能 | 概要 |
|-----------|------|
| `AppIntentsTesting` フレームワーク | Intent / Entity / Query をライブアプリプロセスで実行テスト（UI テストバンドル必須、unit test 不可）|
| `IntentDefinitions(bundleIdentifier:)` | アプリの intent / entity / enum / query をバンドル識別子で発見する起点 |
| `definitions.intents["XxxIntent"]` | 型名の文字列でアクセス（コンパイル時チェックなし） |
| `makeIntent(<param>: value).run()` | パラメータを指定して Intent を実経路実行 |
| `definitions.entities["TodoAppEntity"].entities(matching:)` | Entity Query をテスト |
| `definitions.valueQueries["..."].values(for:)` | IntentValueQuery をテスト |
| 連鎖テスト | 複数の Intent を 1 テスト内で順序実行（Add → Show など） |

### 新機能（297 Integrate your app with Visual Intelligence）

| API / 機能 | 概要 |
|-----------|------|
| Visual Intelligence の macOS 対応 | Xcode 27 beta 2 で `VisualIntelligence` フレームワークが Mac に import 可能に。`#if canImport(VisualIntelligence)` ガードで iOS + macOS に同時対応 |
| macOS openable 要件 | visual search 結果の全 Entity に `OpenIntent` 準拠が必須（union の全メンバが openable でないとビルドエラー） |
| `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` | Visual Intelligence の「もっと見る」に対応する Intent スキーマ。`@Parameter var semanticContent: SemanticContentDescriptor` を要求 |
| `@UnionValue` との組み合わせ | `IntentValueQuery` が複数 Entity 型を混在させて返す（todo と category の混在など）|
| EventKit / Contacts システム連携（記録のみ） | 期限→カレンダー / 担当者→連絡先 への連携は別フレームワーク軸として提示 |

### 新機能（343 Explore advanced App Intents features for Siri and Apple Intelligence）

| API / 機能 | 概要 |
|-----------|------|
| `requestConfirmation(_:confirmLabel:cancelLabel:)` | `perform()` を中断して yes/no 確認を提示。`.background` モードでも Siri UI に surface |
| `requestChoice(between:dialog:)` | `perform()` を中断して多択選択肢を提示。`.cancel` を含めると選択時に Intent を中断 |
| `IntentChoiceOption` | `requestChoice` の選択肢。`style: .default / .destructive / .cancel`。`Equatable` 準拠 |
| `IntentDialog(full:supporting:)` | 音声専用（`full`）と視覚表示（`supporting`）でレスポンスを文脈に応じて出し分け |
| `IntentDonationMatchingPredicate` | `deleteDonations(matching:)` で削除条件を絞り込み、関連 donate を一括解除 |
| `.appEntityIdentifier(forSelectionType:)` | コレクション行ごとの onscreen Entity 提供（「3 番目のやつ」参照を実現） |
| `UNMutableNotificationContent.appEntityIdentifiers` | 通知コンテンツへの Entity 紐付け（iOS 27）。画面外でも Siri が通知の文脈を理解 |
| view 付き `requestChoice(between:dialog:view:)` | 選択肢に SwiftUI View を添えた多択提示 |

### 新機能（344 Code-along: Make your app available to Siri）

| API / 機能 | 概要 |
|-----------|------|
| `TransientAppEntity` | `defaultQuery` 不要の一時 Entity。永続化・クエリなしで Intent 戻り値としてのみ使う（Shortcuts 条件分岐に活用）|
| `IntentParameter.valueState`（`$param.valueState`） | `.set(Value)` / `.unset` で「明示 nil クリア」と「未指定（据え置き）」を区別。部分更新 Intent に必須 |
| `OpenIntent` プロトコル | `var target: Target`（`Target: AppEntity`）を要求。Spotlight タップ → アプリ起動などをシステムが意味解釈 |
| `DeleteIntent`（`: SystemIntent`） | `var entities: [Entity]`（複数配列）を要求。system intent として「削除する」をシステムが意味解釈 |
| `@AppIntent(schema: .system.searchInApp)` | `ShowInAppSearchResultsIntent` をスキーマ適合させ、Siri / Apple Intelligence からアプリ内検索 UI へ橋渡し |
| `StringSearchCriteria` / `searchScopes` | `.system.searchInApp` スキーマが要求するプロパティ。`criteria.term` で検索語を取得 |
| `EntityPropertyQuery` | プロパティ条件で Entity を検索するクエリ型（`EntityStringQuery` の高度版） |

### 新機能（345 Discover new capabilities in the App Intents framework）

| API / 機能 | 概要 |
|-----------|------|
| `@ComputedProperty` | 同期 getter で導出する Entity プロパティマクロ（外部アクセス不要の計算値）|
| `@DeferredProperty` | 非同期 getter で遅延取得する Entity プロパティマクロ（本セッションで詳細仕様を提示）|
| `Duration` / `PersonNameComponents` ネイティブ型 | `@Parameter` / `@Property` にシステム型をそのまま使えるネイティブ対応 |
| `AppEntity.ValueRepresentation` | Entity を `IntentPerson` / `PlaceDescriptor` 等のシステム値型に bridge（#240 と共通）|
| `RelevantEntities.updateEntities(_:for:)` 強化 | 文脈寄付の改善（ドメイン対応 context 拡張）|
| `EntityCollection<T>` | バルク `@Parameter` 型。entity 解決を `.identifiers` 取得まで遅延し大量件数でも効率的 |
| `LongRunningIntent`（`: ProgressReportingIntent`） | `performBackgroundTask { }` でバックグラウンド 30 秒制限を超える長時間処理。`progress` を定期更新が必要 |
| `CancellableIntent` | `performBackgroundTask(operation:onCancel:)` でグレースフルキャンセル対応。`Task.checkCancellation()` と組み合わせ |
| `allowedExecutionTargets`（`IntentExecutionTargets`） | `.main` / `.appIntentsExtension` / `.widgetKitExtension` で `perform()` の実行プロセスを限定 |
| `@UnionValue` | 複数の AppEntity 型を 1 パラメータ・戻り値で扱う Union enum マクロ。`public enum` には `: Sendable` の明示が必要 |
| `SyncableEntity` | デバイス間 ID 一貫性の宣言。`String` / `UUID` id でそのまま適合可。Siri 会話のデバイス転送などで安定参照 |

### グループラボ（WWDC 2026）

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 8011 | [Apple Intelligence Group Lab](https://developer.apple.com/videos/play/wwdc2026/8011/) | Apple エンジニア・デザイナーへの Q&A（Apple Intelligence / App Intents 全般） |

### ✂️ 非推奨化・リネーム

| API | 移行先 | タイミング |
|-----|--------|----------|
| `.system.search`（スキーマ名） | `.system.searchInApp` | Xcode 27 beta 3 でリネーム（`deprecated` 警告） |

---

## 非推奨化タイムライン まとめ

| API | 移行先 | 非推奨化タイミング |
|-----|--------|----------------|
| SiriKit `INIntent`（Shortcuts 系） | `AppIntent` | WWDC 2022（App Intents 登場と同時） |
| `openAppWhenRun` | `supportedModes` | WWDC 2025 |
| `ForegroundContinuableIntent` | `.foreground(.dynamic)` + `continueInForeground()` | WWDC 2025（公式ドキュメントに deprecated 明記） |
| `.system.search`（schema 名） | `.system.searchInApp` | Xcode 27 beta 3（WWDC 2026 サイクル中） |

---

## 学習ロードマップ（推奨視聴順）

### 初学者向け

1. [Dive into App Intents（WWDC22）](https://developer.apple.com/videos/play/wwdc2022/10032/) — 基礎概念
2. [Implement App Shortcuts with App Intents（WWDC22）](https://developer.apple.com/videos/play/wwdc2022/10170/) — 実装基礎
3. [Get to know App Intents（WWDC25）](https://developer.apple.com/videos/play/wwdc2025/244/) — 2025 年版の総合入門（最新）

### 設計を深めたい

4. [Design App Shortcuts（WWDC22）](https://developer.apple.com/videos/play/wwdc2022/10169/) — UX 設計
5. [Design App Intents for system experiences（WWDC24）](https://developer.apple.com/videos/play/wwdc2024/10176/) — システム統合設計
6. [Design interactive snippets（WWDC25）](https://developer.apple.com/videos/play/wwdc2025/281/) — スニペット設計

### Apple Intelligence 統合

7. [Bring your app to Siri（WWDC24）](https://developer.apple.com/videos/play/wwdc2024/10133/) — App Intent Domains
8. [Explore new advances in App Intents（WWDC25）](https://developer.apple.com/videos/play/wwdc2025/275/) — Visual Intelligence
9. [Build intelligent Siri experiences with App Schemas（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/240/) — App Schemas（最新）
10. [Explore advanced App Intents features for Siri and Apple Intelligence（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/343/) — 高度テクニック

### マルチプラットフォーム・Widget・Controls

- [Bring widgets to life（WWDC23）](https://developer.apple.com/videos/play/wwdc2023/10028/) — ウィジェット連携
- [Extend your app's controls across the system（WWDC24）](https://developer.apple.com/videos/play/wwdc2024/10157/) — ControlWidget

### 最新機能・実践

- [Code-along: Make your app available to Siri（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/344/) — コードアロング
- [Validate your App Intents adoption with AppIntentsTesting（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/295/) — テスト
- [Discover new capabilities in the App Intents framework（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/345/) — 最新 API

---

## 年別サマリー

| 年 | OS | キーワード | セッション数 |
|---|---|---|---|
| 2022 | iOS 16 | App Intents 初登場・App Shortcuts・SiriKit 後継 | 3 |
| 2023 | iOS 17 | インタラクティブウィジェット・Spotlight 強化・SPM 対応 | 3 |
| 2024 | iOS 18 | Apple Intelligence・App Intent Domains・ControlWidget | 4 |
| 2025 | iOS 26 | Interactive Snippets・Visual Intelligence・Deferred Properties・supportedModes | 4 |
| 2026 | iOS 27 | App Schemas・SyncableEntity・AppIntentsTesting・TransientAppEntity | 6 (+1 Group Lab) |
