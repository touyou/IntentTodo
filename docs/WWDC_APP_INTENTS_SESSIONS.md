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
| `EntityStringQuery` プロトコル | `entities(matching:)` を実装し文字列による Entity 検索に対応 |
| `EntityPropertyQuery` プロトコル | プロパティ条件で Entity を検索する高度クエリ。`QueryProperties` / `SortingOptions` ビルダーと組み合わせ |
| `QueryProperties` ビルダー | `EntityPropertyQuery` で検索可能プロパティを宣言するリザルトビルダー |
| `SortingOptions` ビルダー | `EntityPropertyQuery` でソート可能プロパティを宣言するリザルトビルダー |
| `SortableBy(keyPath:)` | ソート可能プロパティを指定するための構造体 |
| `EqualToComparator` / `ContainsComparator` / `LessThanComparator` / `GreaterThanComparator` | `QueryProperties` 内で使える比較演算子型 |
| `@Parameter` | Siri がユーザーに入力を求めるパラメータの宣言。`title`・`requestValueDialog` 等を指定 |
| `@Parameter(optionsProvider:)` | `DynamicOptionsProvider` を指定して動的な選択肢を提供（後述） |
| `DynamicOptionsProvider` プロトコル | `results() async throws` を実装してパラメータの動的な選択肢リストを提供する |
| `AppShortcutsProvider` | Siri フレーズの宣言的登録（最大 10 件）。アプリインストール直後から利用可 |
| `AppShortcut` | `intent:`・`phrases:`・`shortTitle:`・`systemImageName:` で 1 件分のショートカットを定義 |
| `DisplayRepresentation` | Entity の Siri / Shortcuts UI 上の表示文字列・アイコン |
| `TypeDisplayRepresentation` | Entity 型全体の表示名（ピッカーの見出しなど） |
| `IntentResult` / `.result()` 系 | 実行結果の返却。`.result()` / `.result(value:)` / `.result(dialog:)` / `.result(value:dialog:)` |
| `IntentDialog`（`full:`/`supporting:` を分けて指定する実例は wwdc2026-343 2:45） | Siri が読み上げる・表示するダイアログ文字列。`full:` と `supporting:` を分けて指定可 |
| `AppEnum` プロトコル | パラメータ・結果に使える列挙型。`caseDisplayRepresentations` で各 case の表示名を定義 |
| `ReturnsValue<T>` | Intent が値を返すことを宣言するプロトコル合成型 |
| `ProvidesDialog` | Intent がダイアログを返すことを宣言するプロトコル合成型 |
| `ShowsSnippetView` | Intent が SwiftUI スニペットを返すことを宣言（`.result(view:)` と組み合わせ） |
| `OpensIntent` | 別の Intent を返り値として続けて開くことを宣言するプロトコル合成型 |
| `openAppWhenRun` | `true` でアプリをフォアグラウンドへ（後に `supportedModes` へ移行） |
| `requestValue(_ dialog:)` | `perform()` 内から呼んでユーザーにパラメータ値を要求する |
| `requestDisambiguation(among:dialog:)` | 候補リストを提示してユーザーに選択させる（`$param` プロジェクション経由） |
| `requestConfirmation(for:dialog:)` | 値や実行前の確認ダイアログを挟む（`$param` プロジェクション経由） |
| `CustomLocalizedStringResourceConvertible` | Intent が throw するエラーをローカライズするためのプロトコル |
| ビルド時メタデータ抽出 | `Metadata.appintents` バンドルをビルド時に自動生成。Info.plist 設定不要 |
| Magic Variables / Find & Filter | EntityPropertyQuery を持つ Entity は Shortcuts 上で自動的に「検索・フィルタ」アクションを生成 |
| Focus Filters | Focus モードごとにアプリの状態を切り替える `SetFocusFilterIntent` 連携 |

### 新機能（10169 Design App Shortcuts）

UX ガイドラインが中心だが、以下の概念・API が言及される。

| API / 機能 | 概要 |
|-----------|------|
| `DynamicOptionsProvider` | パラメータの動的選択肢を管理（「Entity Query / Dynamic Options Provider」として言及） |
| パラメータ確認パターン | 仮定値を提示し `requestConfirmation` で確認するフロー設計（最大 5 件の候補には `requestDisambiguation`） |
| App Shortcut 最大 10 件 | アプリが宣言できる App Shortcut は最大 10 件 |

### 新機能（10170 Implement App Shortcuts with App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `ParameterSummary` | Shortcuts アプリ上でのパラメータ表示順・要約文のカスタマイズ |
| `Summary(String)` / `When` / `Switch` / `Case` / `Default` | ParameterSummary 内で使える条件分岐構造体 |
| `IntentDescription` | Intent の説明文・カテゴリ名・検索キーワードを Shortcuts UI に表示するための型 |
| `confirmBeforeRunning` | 破壊的操作の前に確認ダイアログを挟む（`requestConfirmation` の前身） |
| フレーズの `\(.applicationName)` 変数 | App Shortcut フレーズにアプリ名を埋め込む |
| `AppShortcut` フレーズへの `AppEnum` 埋め込み | `\(\.$filter)` 形式で AppEnum をフレーズに埋め込み（String は不可） |
| `updateAppShortcutParameters()` | フレーズのパラメータ値が変わった際に Siri へ通知して候補を更新 |
| `ShortcutsLink` | アプリの App Shortcuts 一覧を Shortcuts アプリで開く SwiftUI / UIKit コンポーネント |
| `SiriTipView` | 状況に応じた Siri ヒントを表示する SwiftUI / UIKit コンポーネント。スタイルや dismiss 対応あり |
| Multi-Phase Custom UI | 確認フェーズ・実行確認フェーズ・実行後フェーズでカスタム SwiftUI スニペットを表示 |

### ✂️ 非推奨化

| API | 移行先 | タイミング |
|-----|--------|----------|
| SiriKit `INIntent`（Shortcuts 系） | `AppIntent` | WWDC 2022（App Intents 登場と同時に移行推奨） |

---

## WWDC 2023 — ウィジェット連携（iOS 17）

ウィジェットへの App Intents 統合（インタラクティブウィジェット）が最大のトピック。`DynamicOptionsProvider`・`IntentParameterDependency`・`EnumerableEntityQuery` など動的パラメータ周りの API が大幅強化。Swift Package 内での Intent 定義も正式サポート。

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
| `@Parameter(optionsProvider:)` の実用例 | `DynamicOptionsProvider` 準拠型を渡してウィジェット内の選択肢を動的に提供 |
| ウィジェットの即時リロード | `perform()` 完了時にシステムが自動でタイムラインをリロード（"reloads initiated from an interaction are always guaranteed" 10:02 / "As soon as your perform returns, the system will immediately initiate a reload" 13:47）。`invalidatableContent()` は無効化中（データ更新待ち）の見た目を制御するモディファイアで、自動リロード自体は担わない |
| `@Parameter` のみ永続化 | Widget Extension プロセス内では `@Parameter` アノテーション付きプロパティのみが保持される |

### 新機能（10102 Spotlight your app with App Shortcuts）

| API / 機能 | 概要 |
|-----------|------|
| `OpenIntent` プロトコル | 特定 Entity を開くための Intent。Siri が「〇〇を開く」を自動理解 |
| `DisplayRepresentation` サムネイル対応 | URL・Data・named リソース・systemImage 名でサムネイルを設定可（iOS 17 新機能） |
| `DisplayRepresentation` synonyms | Entity / AppEnum case に同義語を追加して Siri の認識精度を向上（iOS 17 新機能） |
| ネガティブフレーズ API | 特定のフレーズを意図的に App Shortcut に反応させないよう指定 |
| Semantic Similarity Index | 端末内 ML による柔軟フレーズマッチング（フレーズを完全一致しなくても起動可）。opt-out 可 |
| App Shortcuts in Spotlight Top Hits | Spotlight 検索の Top Hits に App Shortcut が直接表示 |
| App Shortcuts Preview（Xcode 15） | アプリ実行不要でフレーズマッチングをプレビューできる Xcode 15 ツール（macOS Sonoma 必要） |
| String Catalog 形式 | `AppShortcuts.xcstrings` でロケールごとにフレーズを無制限に定義可（iOS 17+ ターゲット） |
| `AppShortcutsProvider.updateAppShortcutParameters()` | Shortcut パラメータの動的更新 |
| Short Title / systemImage 必須化 | iOS 17 から全 App Shortcut に `shortTitle` と `systemImageName` が必須に |
| 最大フレーズ数 1,000 件 | アプリ全体の Siri トリガーフレーズ合計の上限 |

### 新機能（10103 Explore enhancements to App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `DynamicOptionsProvider` プロトコル | `results() async throws` を実装してパラメータの動的な選択肢を提供。`@Parameter(optionsProvider:)` で指定 |
| `IntentParameterDependency<Intent>` | `DynamicOptionsProvider` や EntityQuery の中で別パラメータの現在値を参照するプロパティラッパー（`@IntentParameterDependency<MyIntent>(\.$param)` の形で使用） |
| `IntentProjection<Intent>`（API ドキュメント由来） | `IntentParameterDependency` を使って non-optional の参照を返すラッパー |
| `EnumerableEntityQuery` | `allEntities() async throws -> [Entity]` を実装して全件返す新プロトコル。Shortcuts のフィルタ・ソートが自動生成される |
| `WidgetConfigurationIntent` | `AppIntent` サブプロトコル。ウィジェットの構成 Intent を定義する |
| `AppIntentConfiguration` | `WidgetConfigurationIntent` を使ったウィジェット TimelineProvider の設定型 |
| `ForegroundContinuableIntent` | バックグラウンド実行途中に動的フォアグラウンド遷移（後に `supportedModes` へ移行） |
| `needsToContinueInForegroundError()` | `perform()` を中断してフォアグラウンド遷移を要求するエラーを生成 |
| `requestToContinueInForeground()` | ユーザーの許可を得てからフォアグラウンドで処理を再開するメソッド |
| `ProgressReportingIntent` | `progress.totalUnitCount` / `progress.completedUnitCount` で進捗を Siri UI に表示 |
| `IntentDonationManager`（API ドキュメント由来） | `donate(_:)` でアクション履歴を寄付し Siri 提案の学習を強化 |
| `PredictableIntent`（API ドキュメント由来） | 実行タイミングを予測して Shortcuts に提案するための準拠プロトコル |
| `RelevantIntent` | 状況に応じた Intent を Shortcuts に提案 |
| `RelevantIntentManager` | `RelevantIntent` の登録・削除を管理するマネージャ |
| `RelevantContext` | ウィジェット提案用の文脈（INDailyRoutine / INInteraction 相当）を指定する型 |
| `IntentDescription` の `resultValueName` | Intent の戻り値の名称を Shortcuts 上で「マジック変数」ラベルとして表示 |
| `IntentDescription` の `findIntentDescription` | Query 型の「検索」アクション説明文を指定するプロパティ |
| `isDiscoverable` | `false` にすると Siri / Shortcuts に Intent が表示されなくなる（内部専用 Intent に使用） |
| `AppIntentsPackage` | Swift Package 内に Intent / Entity / Query を定義する正式サポート |
| 静的抽出の改善 | Xcode 15 でビルドシステムによる Intent メタデータ抽出の信頼性向上・エラー行番号表示 |

---

## WWDC 2024 — Apple Intelligence 統合（iOS 18）

App Intent Domains（アシスタントスキーマ）導入で Siri の AI 機能との統合が強化。ControlWidget（コントロールセンター）サポート・Transferable / IndexedEntity などデータ共有 API も追加。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 10133 | [Bring your app to Siri](https://developer.apple.com/videos/play/wwdc2024/10133/) | App Intent Domains・エンティティの Spotlight インデックス化・Siri 統合 |
| 10134 | [What's new in App Intents](https://developer.apple.com/videos/play/wwdc2024/10134/) | Transferable API・IntentFile・Spotlight Indexing の新機能 |
| 10157 | [Extend your app's controls across the system](https://developer.apple.com/videos/play/wwdc2024/10157/) | ControlWidget・ControlWidgetToggle と App Intents の組み合わせ |
| 10176 | [Design App Intents for system experiences](https://developer.apple.com/videos/play/wwdc2024/10176/) | Intent 設計原則・パラメータ設計・アプリ外アクションの UX |

### 新機能（10133 Bring your app to Siri）

| API / 機能 | 概要 |
|-----------|------|
| `@AssistantIntent(schema:)` | iOS 18 時点での Intent スキーマ適合マクロ名（iOS 27 で `@AppIntent(schema:)` にリネーム） |
| `@AssistantEntity(schema:)` | iOS 18 時点での Entity スキーマ適合マクロ名（iOS 27 で `@AppEntity(schema:)` にリネーム） |
| `@AssistantEnum(schema:)` | iOS 18 時点での AppEnum スキーマ適合マクロ名（iOS 27 で `@AppEnum(schema:)` にリネーム） |
| App Intent Domains（12 ドメイン） | Photos / Mail / Books / Camera / Spreadsheets 等 12 ドメインが iOS 18 時点で利用可能 |
| `IndexedEntity` | `CSSearchableIndex` を使った Spotlight セマンティックインデックス対応 |
| `CSSearchableItemAttributeSet` 統合 | `attributeSet` プロパティで Entity をカスタム Spotlight メタデータと紐付け |
| `AppEntityContext`（wwdc2026-345 で導入） | 現在の文脈（再生中・閲覧中など）を指定して `RelevantEntities` に渡す |
| `RelevantEntities.shared.updateEntities(_:for:)`（wwdc2026-345 が出典） | 文脈に応じた Entity を寄付し Siri が状況を把握できるようにする |
| Apple Intelligence 統合 | 端末内 AI（Apple Intelligence）が App Intents を介してアプリのアクションを理解・実行 |
| セマンティック検索 | `IndexedEntity` を通じ「ペット」と言うと犬・猫・蛇の写真を発見するような意味理解検索 |

### 新機能（10134 What's new in App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `Transferable` + AppEntity | Entity に `Transferable` 準拠を追加してドラッグ&ドロップ・共有シートに対応 |
| `DataRepresentation` | バイト列・カスタム Codable 型でのデータ転送表現 |
| `FileRepresentation` | ファイル URL 経由での転送表現（PDF・PNG・RTF など） |
| `ProxyRepresentation` | `@Property` 付きプロパティをキーパスで参照する軽量転送表現 |
| `URLRepresentableEntity` | URL で Identity を表現できる Entity のプロトコル。Universal Links と連携 |
| `URLRepresentableIntent` | URL Representation に対応する Intent のプロトコル |
| `OpenURLIntent` | URL を開く Intent。URLRepresentableEntity と組み合わせて使用 |
| `IntentFile` | ファイルを `@Parameter` で受け渡す型（ドキュメント操作 Intent に活用） |
| `FileEntity` / `FileEntityIdentifier` | ファイルベースの Entity と URL ブックマークデータによる識別子 |
| `@UnionValue` マクロ | 複数の型を 1 パラメータ・戻り値で扱う Union enum マクロ（WWDC 2026 でさらに拡充） |
| `associateAppEntity(_:)` | `CSSearchableItem` に AppEntity を紐付けて Spotlight へドネート |
| `indexAppEntities(_:)` on `CSSearchableIndex` | Entity 群を Spotlight のセマンティックインデックスへ一括登録 |
| Spotlight Indexing 強化 | `IndexedEntity` の `attributeSet` に複数フィールドを設定してより豊かなインデックス |
| Framework サポート（Xcode 16） | "Only frameworks are supported at this time. Libraries outside of a framework are not." — Framework 形態でのみ Entity 定義に対応（Static Library・無印パッケージは未対応）。SPM パッケージでの Entity/Intent 定義が正式に拡充されたのは wwdc2025-244 / 275 |
| パラメータタイトル自動生成（Xcode 16） | Xcode 16 がパラメータ名から `@Parameter` タイトルを自動補完 |

### 新機能（10157 Extend your app's controls across the system）

| API / 機能 | 概要 |
|-----------|------|
| `ControlWidget` | コントロールセンターに表示するウィジェットの基底型 |
| `StaticControlConfiguration` | ユーザー設定なしのシンプルなコントロール設定型 |
| `AppIntentControlConfiguration` | `ControlConfigurationIntent` で設定可能なコントロール設定型 |
| `ControlWidgetButton`（wwdc2024-10210 が出典。10210 自体は本表未収録） | タップで Intent を実行するコントロールセンターボタン |
| `ControlWidgetToggle` | ON/OFF を切り替える Intent に紐付けたトグルコントロール |
| `SetValueIntent` | `value: Bool` プロパティを要求する。`ControlWidgetToggle` と組み合わせて状態変更 Intent を定義 |
| `ControlValueProvider` | コントロールの現在値（ON/OFF 状態・ラベルなど）をシステムに提供するプロトコル |
| `AppIntentControlValueProvider` | `currentValue(configuration:)` / `previewValue(configuration:)` を要求。設定依存のコントロール値を提供 |
| `ControlConfigurationIntent`（wwdc2024-10210 が出典） | コントロールの設定画面で使うパラメータを定義する Intent |
| `.controlWidgetActionHint(_:)` | Action ボタン用のヒントテキスト（動詞フレーズ）を設定するモディファイア |
| `.controlWidgetStatus(_:)` | コントロールセンターに一時的なステータス文字列を表示するモディファイア |
| `ControlCenter.shared.reloadControls(ofKind:)` | アプリ側から特定のコントロールを強制リロード |
| `LiveActivityIntent` との組み合わせ | `SetValueIntent` が `LiveActivityIntent` にも準拠してライブアクティビティも更新可 |

### 新機能（10176 Design App Intents for system experiences）

主に設計ガイドライン。新 API より「いつ Intent を使うか」「パラメータをどう設計するか」の指針を提供。

| API / 機能 | 概要 |
|-----------|------|
| `OpenIntent` の優先活用 | 特定ビューを開く Intent には `OpenIntent` 準拠が推奨 |
| Background / Foreground 使い分け | Background Intent + `OpensIntent` を返すパターン vs. `openAppWhenRun: true` の設計指針 |

---

## WWDC 2025 — Interactive Snippets / Visual Intelligence（iOS 26）

インタラクティブスニペット・Visual Intelligence・Deferred Properties・`supportedModes` など大型機能追加。OS バージョン番号が iOS 26 へ統一された年。`requestChoice` / `UndoableIntent` もこの年が初出。

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
| `EnumerableEntityQuery.allEntities()` | 全 Entity を返すメソッド（Shortcuts 上でフィルタ・ソートが自動生成される） |
| `Predicate<T>` | `EntityPropertyQuery` でのフィルタ条件を表す型 |
| `Sort<T>` | `EntityPropertyQuery` でのソート条件を表す型 |
| `ComparatorMode` | 複数の比較器を AND / OR で組み合わせるモード |

### 新機能（260 Develop for Shortcuts and Spotlight with App Intents）

| API / 機能 | 概要 |
|-----------|------|
| macOS Shortcuts 強化 | Mac の Shortcuts アプリで App Intents を使ったオートメーション対応を強化 |
| macOS Shortcuts フォルダ / Bluetooth / 時刻オートメーション | macOS 固有のトリガーから Intent を実行可能に |
| macOS Spotlight 統合 | IndexedEntity を Spotlight for Mac でも検索可能に |
| "Use Model" アクション連携 | Shortcuts から端末内モデル（FoundationModels）を呼び出すアクションとの連携 |
| `assistantOnly` フラグ（API ドキュメント由来） | `IntentDescription` のプロパティ。`true` にすると Shortcuts には非表示で Apple Intelligence のみが使用 |
| `PredictableIntent` の Spotlight 活用（wwdc2025-275 が出典） | 使用パターンを学習し Spotlight に「予測」として表示するためのプロトコル |
| `NSUserActivity.appEntityIdentifier` / `appEntityIdentifiers`（275 / wwdc2026-343 が出典） | 現在の画面コンテンツを表す Entity を Siri / ChatGPT に提供 |

### 新機能（275 Explore new advances in App Intents）

| API / 機能 | 概要 |
|-----------|------|
| `supportedModes`（`IntentModes`） | `.background` / `.foreground(.immediate)` / `.foreground(.dynamic)` / `.foreground(.deferred)` の 4 モードで実行タイミングを宣言的に制御。`openAppWhenRun` を置き換え |
| `continueInForeground(alwaysConfirm:)` | `perform()` 内から呼んで動的にアプリをフォアグラウンドへ遷移。`ForegroundContinuableIntent` を置き換え |
| `systemContext.currentMode` | `perform()` 内で現在の実行モード（background / foreground）を参照 |
| `systemContext.canContinueInForeground` | フォアグラウンドへの遷移が可能かを確認 |
| `@DeferredProperty` | Entity プロパティを非同期で遅延取得（`get async throws`）。Spotlight index には含まれない。要求時のみ取得されるため重い処理に適する |
| `SnippetIntent` | Siri の返答に埋め込む SwiftUI スニペット定義の Intent。`perform()` が `ShowsSnippetView` を返す |
| `SnippetIntent.reload()` | `perform()` 外からスニペット表示を強制リフレッシュするスタティックメソッド |
| `ShowsSnippetView` / `.result(view:)` | スニペット内に SwiftUI View を埋め込む返却型 |
| スニペット内 `Button(intent:)` | スニペット上のボタンから Intent を直接実行。システムが `SnippetIntent` を再実行して最新状態を反映 |
| `requestConfirmation(actionName:snippetIntent:)` | 実行前の確認に SwiftUI スニペットを添付して提示（iOS 26 新規） |
| `requestChoice(between:dialog:)` | 複数選択肢を提示してユーザーに選ばせる（iOS 26 新規）。`IntentChoiceOption` で選択肢を構成 |
| `requestChoice(between:dialog:view:)` | `requestChoice` に SwiftUI View を添えたオーバーロード |
| `IntentChoiceOption` | `requestChoice` の選択肢。`style: .default / .destructive / .cancel` を指定 |
| `UndoableIntent` | undo/redo 対応の Intent プロトコル。`undoManager.registerUndo(withTarget:handler:)` と組み合わせ |
| `UISceneAppIntent` | UIKit のシーンメンバーへアクセスできる Intent プロトコル |
| `IntentValueQuery` | `values(for: SemanticContentDescriptor)` を実装し Visual Intelligence の検索結果として Entity を返す |
| `SemanticContentDescriptor` | カメラ・スクショの内容（`labels: [String]`・`pixelBuffer`）を表す Visual Intelligence の入力型 |
| Onscreen Entities（単一） | `NSUserActivity.appEntityIdentifier = EntityIdentifier(for:)` で表示中 Entity を Siri / Apple Intelligence に提供 |
| `EntityIdentifier(for:)` | Entity の識別子を `NSUserActivity` に付与するためのラッパー型 |

### 新機能（281 Design interactive snippets）

主に UX ガイドライン。以下の実装ポイントが示される。

| API / 機能 | 概要 |
|-----------|------|
| Result Snippet vs Confirmation Snippet | Result Snippet（「完了」のみ）と Confirmation Snippet（アクション前の確認）を使い分ける設計指針 |
| `ContainerRelativeShape` | スニペット内で端末サイズに適応したマージンを持つ角丸形状。スニペット背景に使用 |

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
本プロジェクトで全セッションを検証済み（`xcode27` ブランチで実施し 2026-08-27 に `main` へマージ。詳細は `docs/APP_INTENTS_CENTRIC_PLAN.md` 参照）。

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 240 | [Build intelligent Siri experiences with App Schemas](https://developer.apple.com/videos/play/wwdc2026/240/) | App Schemas を使った Siri への高度なアプリ統合 |
| 295 | [Validate your App Intents adoption with AppIntentsTesting](https://developer.apple.com/videos/play/wwdc2026/295/) | 新テストフレームワーク AppIntentsTesting の使い方 |
| 297 | [Best practices for integrating visual intelligence in your app](https://developer.apple.com/videos/play/wwdc2026/297/) | カメラ・スクショ連携の Visual Intelligence 統合（macOS 対応含む） |
| 343 | [Explore advanced App Intents features for Siri and Apple Intelligence](https://developer.apple.com/videos/play/wwdc2026/343/) | Siri・Apple Intelligence 対応を磨くための高度テクニック |
| 344 | [Code-along: Make your app available to Siri](https://developer.apple.com/videos/play/wwdc2026/344/) | 既存アプリを Siri 対応にするコードアロング（実践形式） |
| 345 | [Discover new capabilities in the App Intents framework](https://developer.apple.com/videos/play/wwdc2026/345/) | ValueRepresentation・RelevantEntities・EntityCollection・SyncableEntity・長時間 Intent |

### 新機能（240 Build intelligent Siri experiences with App Schemas）

| API / 機能 | 概要 |
|-----------|------|
| `@AppEntity(schema:)` | iOS 27 時点でのリネーム版（iOS 18 では `@AssistantEntity`）。Entity をドメインに意味的適合 |
| `@AppIntent(schema:)` | iOS 27 時点でのリネーム版（iOS 18 では `@AssistantIntent`）。Intent を意味ドメインに適合 |
| `@AppEnum(schema:)` | iOS 27 時点でのリネーム版（iOS 18 では `@AssistantEnum`）。AppEnum をドメイン定義に適合 |
| `AppSchema` プロトコル | スキーマのドメイン契約を定義する基底プロトコル |
| `AppSchemaDomain` | 関連スキーマのグルーピング（例: Messages ドメインに `sendMessage`・`draftMessage` 等） |
| reminders ドメイン拡充（SDK 観測由来） | `@AppEntity(schema: .reminders.list/.reminder)` / `@AppEnum(schema: .reminders.listType)` が iOS 27+ で利用可能に |
| `AppEntity.ValueRepresentation`（`IntentValueRepresentation`） | Entity を `IntentPerson` / `PlaceDescriptor` 等のシステム値型へ bridge してクロスアプリ共有 |
| `IntentValueRepresentation(exporting:)` | `exporting:` クロージャまたはキーパスで export 方法を定義 |
| `IntentValueRepresentation(exporting:importing:)` | `importing:` クロージャで他アプリ等からの受け取り方法を定義 |
| `Transferable` + `ProxyRepresentation` | Entity をドラッグ&ドロップ・共有シートで送受信 |
| `@Property(indexingKey:)` | `PartialKeyPath<CSSearchableItemAttributeSet>` を指定し Spotlight セマンティックキーへ宣言的マッピング |
| Onscreen Entities（コレクション）（wwdc2026-343 が出典） | `.appEntityIdentifier(forSelectionType:)` View modifier で List / ScrollView 内の各行を onscreen Entity として提供 |
| `appEntityIdentifier(_:)` View modifier | 単一の View に Entity を紐付ける SwiftUI モディファイア |
| `EntityIdentifier(for:identifier:)` | Entity 型と識別子 String / UUID から EntityIdentifier を生成するイニシャライザ |
| `IntentValueQuery` for `[IntentPerson]` | `values(for input: [IntentPerson]) async throws -> [Entity]` で他アプリ由来の IntentPerson を Entity に解決 |
| 通知への Entity 付与（wwdc2026-343 が出典） | `UNMutableNotificationContent.appEntityIdentifiers` で通知に Entity を紐付け（iOS 27）|
| Xcode Fix-Its | 関連スキーマが欠落している場合にコンパイル時にエラー + Fix-It でスキャフォールド生成 |

### 新機能（295 Validate your App Intents adoption with AppIntentsTesting）

| API / 機能 | 概要 |
|-----------|------|
| `AppIntentsTesting` フレームワーク | Intent / Entity / Query をライブアプリプロセスで実行テスト（UI テストバンドル必須、unit test 不可）|
| `IntentDefinitions(bundleIdentifier:)` | アプリの intent / entity / enum / query をバンドル識別子で発見する起点 |
| `definitions.intents["XxxIntent"]` | 型名の文字列でアクセス（コンパイル時チェックなし） |
| `makeIntent(<param>: value).run()` | パラメータを指定して Intent を実経路実行 |
| `definitions.entities["TodoAppEntity"].entities(matching:)` | Entity Query をテスト |
| `EntityDefinition.spotlightQuery(_:)` | Spotlight インデックスへの登録を検証するテストメソッド |
| `EntityDefinition.viewAnnotations()` | 現在スクリーン上の View Entity アノテーションを取得してテスト |
| `ViewAnnotation` | `viewAnnotations()` が返す型。`.entity` プロパティで Entity を参照。動的メンバルックアップ対応 |
| `definitions.valueQueries["..."].values(for:)` | IntentValueQuery をテスト |
| 連鎖テスト | 複数の Intent を 1 テスト内で順序実行（Add → Show など） |
| `isDiscoverable = false` + `#if DEBUG` | テスト専用 Intent を本番 Siri / Shortcuts に露出させない書き方 |

### 新機能（297 Best practices for integrating visual intelligence in your app）

| API / 機能 | 概要 |
|-----------|------|
| Visual Intelligence の macOS 対応 | Xcode 27 beta 2 で `VisualIntelligence` フレームワークが Mac に import 可能に。`#if canImport(VisualIntelligence)` ガードで iOS + macOS に同時対応 |
| macOS openable 要件 | visual search 結果の全 Entity に `OpenIntent` 準拠が必須（union の全メンバが openable でないとビルドエラー） |
| `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` | Visual Intelligence の「もっと見る」に対応する Intent スキーマ。`@Parameter var semanticContent: SemanticContentDescriptor` を要求 |
| `@UnionValue` との組み合わせ | `IntentValueQuery` が複数 Entity 型を混在させて返す（todo と category の混在など）|
| パフォーマンス設計 | 結果は関連度順・件数制限・pixelBuffer を使った類似度フィルタで速く返す設計を推奨 |

### 新機能（343 Explore advanced App Intents features for Siri and Apple Intelligence）

| API / 機能 | 概要 |
|-----------|------|
| `requestConfirmation(_:confirmLabel:cancelLabel:)`（API ドキュメント由来） | iOS 27 追加の拡張オーバーロード。確認・キャンセルボタンのラベルを個別指定できる |
| `IntentDialog(full:supporting:)` | 音声専用（`full`）と視覚表示（`supporting`）でレスポンスを文脈に応じて出し分け |
| `IntentDonationMatchingPredicate`（API ドキュメント由来。donation 削除系 API も同様） | `deleteDonations(matching:)` で削除条件を絞り込み、関連 donate を一括解除 |
| `.appEntityIdentifier(forSelectionType:)` | コレクション行ごとの onscreen Entity 提供（「3 番目のやつ」参照を実現） |
| `UNMutableNotificationContent.appEntityIdentifiers` | 通知コンテンツへの Entity 紐付け（iOS 27）。画面外でも Siri が通知の文脈を理解 |
| `MusicContent.appEntityIdentifiers` | Now Playing コンテンツへの Entity 紐付け（複数 Entity 対応、優先度順に並べる） |
| `AlarmConfiguration.appEntityIdentifier` | AlarmKit のアラーム・タイマーへの Entity 紐付け |
| `OwnershipProvidingEntity` | Entity が public（公開）/ shared（共有）/ unknown かを宣言するプロトコル |
| `EntityOwnership` | `OwnershipProvidingEntity` が返す列挙型（`.shared` / `.public` / `.unknown`）。Siri が確認ダイアログを適切に調整 |
| `AudioSearch` | 音楽 Intent 向けの構造化検索入力型。`criteria: .searchQuery(String)` / `.unspecified` / `.url` のいずれかを持つ |
| `AppEntityAnnotatable`（UIKit） | UIKit のカスタムキャンバスビューで Entity を onscreen アノテーションするためのプロトコル |
| `UICollectionViewAppIntentsDataSource` | UICollectionView の各セルに Entity を対応付ける UIKit データソース |
| `appEntityUIElementProvider` | UIKit での onscreen Entity アノテーション提供メソッド |
| `DisplayRepresentation.Components` | Siri が要求する表示コンポーネント（`.text` 等）を指定するための列挙型 |
| view 付き `requestChoice(between:dialog:view:)`（wwdc2025-275 が出典） | iOS 26 の `requestChoice` に SwiftUI View を添付するオーバーロード |

### 新機能（344 Code-along: Make your app available to Siri）

| API / 機能 | 概要 |
|-----------|------|
| `TransientAppEntity` | `defaultQuery` 不要の一時 Entity。永続化・クエリなしで Intent 戻り値としてのみ使う（Shortcuts 条件分岐に活用）|
| `IntentParameter.valueState`（`$param.valueState`） | `.set(Value)` / `.unset` で「明示 nil クリア」と「未指定（据え置き）」を区別。部分更新 Intent に必須 |
| `OpenIntent` プロトコル | `var target: Target`（`Target: AppEntity`）を要求。Spotlight タップ → アプリ起動などをシステムが意味解釈 |
| `DeleteIntent`（`: SystemIntent`）（344 の実例はスキーマ版 `DeleteEventIntent`） | `var entities: [Entity]`（複数配列）を要求。system intent として「削除する」をシステムが意味解釈 |
| `@AppIntent(schema: .system.searchInApp)`（wwdc2026-343 が出典） | `ShowInAppSearchResultsIntent` をスキーマ適合させ、Siri / Apple Intelligence からアプリ内検索 UI へ橋渡し |
| `@AppIntent(schema: .system.open)` | エンティティを「開く」という意味でシステムが理解できる標準スキーマ |
| `StringSearchCriteria` / `searchScopes`（wwdc2026-343 が出典） | `.system.searchInApp` スキーマが要求するプロパティ。`criteria.term` で検索語を取得 |
| `EntityPropertyQuery`（344 の実例は `EnumerableEntityQuery`） | プロパティ条件で Entity を検索するクエリ型（`EntityStringQuery` の高度版） |
| `Calendar.RecurrenceRule` | 繰り返し Event の設定に使う Foundation 型（daily / weekly / monthly / yearly）|
| `IntentPerson` を使った Attendee Entity | `@AppEntity(schema: .calendar.attendee)` + `transferRepresentation` で IntentPerson と Bridge |

### 新機能（345 Discover new capabilities in the App Intents framework）

| API / 機能 | 概要 |
|-----------|------|
| `@ComputedProperty`（wwdc2025-275 が出典） | 同期 getter で導出する Entity プロパティマクロ（外部アクセス不要の計算値）|
| `@DeferredProperty`（詳細仕様は wwdc2025-275 が出典。345 で扱うのは `RelevantEntities` 等の拡張機能） | 非同期 getter で遅延取得する Entity プロパティマクロ |
| `Duration` / `PersonNameComponents` ネイティブ型 | `@Parameter` / `@Property` にシステム型をそのまま使えるネイティブ対応 |
| `AppEntity.ValueRepresentation` | Entity を `IntentPerson` / `PlaceDescriptor` 等のシステム値型に bridge（#240 と共通）|
| `RelevantEntities.updateEntities(_:for:)` 強化 | 文脈に応じた Entity 寄付。beta 6 の公開 SDK で確認できる context は `.audio(.nowPlaying)`（[現行の制約](insights/03-app-intents-core.md#relevantentities-は-todo-ドメインに不適合)） |
| `RelevantEntities.shared.removeAllEntities(for:)` | 特定文脈の Entity 寄付をまとめて削除 |
| `RelevantEntities.shared.removeEntities(_:from:)` | 特定 Entity のみを指定文脈から削除 |
| `RelevantEntities.shared.removeAllEntities()` | 全文脈の Entity 寄付を一括削除 |
| `EntityCollection<T>` | バルク `@Parameter` 型。entity 解決を `.identifiers` 取得まで遅延し大量件数でも効率的 |
| `LongRunningIntent`（`: ProgressReportingIntent`） | `performBackgroundTask { }` でバックグラウンド 30 秒制限を超える長時間処理。`progress` を定期更新が必要 |
| `CancellableIntent` | `performBackgroundTask(operation:onCancel:)` でグレースフルキャンセル対応。`Task.checkCancellation()` と組み合わせ |
| `allowedExecutionTargets`（`IntentExecutionTargets`） | `.main` / `.appIntentsExtension` / `.widgetKitExtension` で `perform()` の実行プロセスを限定 |
| `@UnionValue` 詳細仕様 | `typeDisplayRepresentation` / `caseDisplayRepresentations` の実装要件。`public enum` には `: Sendable` の明示が必要（本プロジェクトのビルド観測による知見） |
| `SyncableEntity` | デバイス間 ID 一貫性の宣言。`String` / `UUID` id でそのまま適合可。Siri 会話のデバイス転送などで安定参照 |
| `SyncableEntityIdentifier<Local, Stable>` | ローカル ID と安定 ID をペアで保持するジェネリック型（`init(local:stable:)` で初期化） |

### グループラボ（WWDC 2026）

| セッション番号 | タイトル | 概要 |
|---|---|---|
| 8011 | [Apple Intelligence Group Lab](https://developer.apple.com/videos/play/wwdc2026/8011/) | Apple エンジニア・デザイナーへの Q&A（Apple Intelligence / App Intents 全般） |

### ✂️ 非推奨化・リネーム

| API | 移行先 | タイミング |
|-----|--------|----------|
| `@AssistantIntent` / `@AssistantEntity` / `@AssistantEnum`（iOS 18 名称） | `@AppIntent(schema:)` / `@AppEntity(schema:)` / `@AppEnum(schema:)` | Xcode 27（iOS 27 SDK）でリネーム |
| `.system.search`（スキーマ名） | `.system.searchInApp` | Xcode 27 beta 3 でリネーム（`deprecated` 警告） |

---

## 非推奨化タイムライン まとめ

| API | 移行先 | 非推奨化タイミング |
|-----|--------|----------------|
| SiriKit `INIntent`（Shortcuts 系） | `AppIntent` | WWDC 2022（App Intents 登場と同時） |
| `confirmBeforeRunning` | `requestConfirmation(for:dialog:)` | WWDC 2022（requestConfirmation が推奨） |
| `openAppWhenRun` | `supportedModes` | WWDC 2025 |
| `ForegroundContinuableIntent` | `.foreground(.dynamic)` + `continueInForeground()` | WWDC 2025（公式ドキュメントに deprecated 明記） |
| `needsToContinueInForegroundError()` | `continueInForeground()` + `.foreground(.dynamic)` | WWDC 2025 |
| `@AssistantIntent` / `@AssistantEntity` / `@AssistantEnum` | `@AppIntent(schema:)` 等 | Xcode 27（WWDC 2026 サイクル中） |
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

| 年 | OS | 一言テーマ | 何が変わったか | セッション数 |
|---|---|---|---|---|
| 2022 | iOS 16 | **宣言的フレームワークへの転換** | SiriKit（Info.plist + Intents Extension）を捨てて Swift struct + ビルド時自動抽出へ。フレーズ登録ゼロ設定・DynamicOptionsProvider でパラメータ動的化の基盤も整う | 3 |
| 2023 | iOS 17 | **ウィジェットが動く＋パラメータ表現力向上** | `Button(intent:)` でウィジェットがインタラクティブに。`IntentParameterDependency` / `EnumerableEntityQuery` でパラメータ間依存や全件列挙が書けるようになった | 3 |
| 2024 | iOS 18 | **Apple Intelligence との統合元年** | App Intent Domains（スキーマ）で Siri がアクションを意味的に理解。IndexedEntity で Spotlight セマンティック検索にも乗れるように。ControlWidget も追加 | 4 |
| 2025 | iOS 26 | **Siri に見せ方と実行制御が備わった** | Interactive Snippets でリッチな返答、Visual Intelligence でカメラ連携、`supportedModes` で foreground/background の制御が整理。`requestChoice` / `UndoableIntent` もこの年が初出 | 4 |
| 2026 | iOS 27 | **本格的なシステム市民へ** | App Schemas でクロスアプリ意味連携、SyncableEntity でデバイス間 ID 同期、AppIntentsTesting で Intent を実経路テスト可能に。API の厚みより「つながり」が主題の年 | 6 (+1 Group Lab) |
