# 制約記述の再検証候補リスト

**目的**: プロジェクトドキュメント（CLAUDE.md / docs/insights/ / docs/APP_INTENTS_CENTRIC_PLAN.md）が「プラットフォームの制約」として記録している事項を、`docs/references/wwdc/` の WWDC セッション書き起こし（2022–2026、25本）と全数突き合わせた結果、**実装の仕方が原因である可能性が強い**ものを抽出したもの。

**使い方**: 別セッションでコード側の検証を進める際の作業リスト。各項目に「仮説」「調査対象ファイル」「検証手順」を記載。検証が済んだら該当ドキュメントを修正し、この項目に結果を追記する。

**検証日**: 2026-08-11（xcode27 ブランチ、Xcode 27 beta 5 時点のドキュメントに対して実施）

**進捗（2026-08-11 完了）**: 全項目（A-1〜A-5, B-1〜B-2, C-1〜C-9, 付録）を再検証・ドキュメント修正済み。各見出しに ✅ 済マークと結果概要を付記。詳細な差分は CLAUDE.md（実体は AGENTS.md）/ `docs/insights/03,04,05,06,07` / `docs/APP_INTENTS_CENTRIC_PLAN.md` / `docs/WWDC_APP_INTENTS_SESSIONS.md` を参照。

**追加検証（2026-08-11 その2）**: コード修正を伴う項目のうち自動化可能なものは実施済み（下記「解消済み」）。一方で実機 / Siri 実行 / 大規模機能作業を要するものはこのセッションでは着手できず、残タスクとして以下に一覧化する。

## 残タスク（実機検証 or 将来の機能作業が必要、このセッションでは未着手）

- [ ] **A-1**: `includedPackages` 付き `AppIntentsPackage` を複数ターゲットへ重複宣言した場合の Siri/Shortcuts 実機ルーティング（`LNContextErrorDomain Code=2001` 系）未検証。ビルド/メタデータレベルの重複は無いことのみ確認済み。実機検証までは現状の非重複運用を維持。
- [ ] **A-3**: Live Activity Extension プロセスで `TodoAppEntity`（`@Parameter`）の事前 entity 解決が走ると SwiftData が trap する件、現行 SDK での再現有無を実機未検証。Primary 版 Intent を LA ボタンに直結して実機実行し、trap の再現/非再現を確認する必要がある（再現しなければ FromExtension 分離を簡素化できる）。
- [ ] **A-5**: `allowedExecutionTargets` 未指定の Widget/Control Intent（`SetTodoCompletionIntent` 等）について、実行プロセスと entity 解決プロセスの実機ログ確認は未実施（`CompleteTodosIntent` のみ `[.main]` 固定で対応済み）。
- [ ] **C-1**: `.onAppIntentExecution` は現在プロジェクト内で未使用（`@Dependency` + `perform()` パターンへ移行済み）。再導入する際は cold start 失敗の3仮説（`@State path` 未構築 / activation conditions 未設定 / `supportedModes` 不足）を実機で検証する必要がある。
- [ ] **C-5**: `_AppIntents_UIKit` が iOS で import 可能なことは `RunCodeSnippet` で実証済みだが、macOS 側は `.swiftinterface` の静的調査のみで実際の macOS ビルドでの `canImport` 結果は未確認。また `UISceneAppIntent` を使う具体的なマルチウィンドウ機能が無いため実装自体は保留中（機能要求が出たら着手）。
- [ ] **C-6**: `TodoAppEntity` の `.reminders.reminder` スキーマ適合の再挑戦（wwdc2026-344 の CometCal パターン: 手書き init 無し + Query 側 populate + 入れ子は `TransientAppEntity`）。大規模な機能作業のため未着手、`docs/APP_INTENTS_CENTRIC_PLAN.md` #48 の出発点としてリードのみ記録済み。
- [ ] **C-8**: Control のフィードバック設計は 2026-08-12 に見直し済み（Toggle 化 + 成功通知廃止 + `.controlWidgetStatus` 撤去、経緯は `docs/devlog/06-control-widget-ios26.md`）。残るのは**実機 Control Center での見え方の確認**（Toggle の on/off 表示、設定フローの `.promptsForUserConfiguration()`、失敗時のエラー通知）。
- [x] **C-10**: **Control から実行した Intent の snippet は提示されない**ことを実機で確定（2026-08-12）。同一 Intent・同一 snippet を Spotlight から呼ぶと出て、Control から呼ぶと出ない（`allowedExecutionTargets = [.main]` 固定でも、Button / Toggle どちらの形でも出ない）。snippet 実装 / パラメータの有無 / 実行プロセス / `isDiscoverable` / メタデータ登録はすべて Spotlight 側で同条件のまま成立しているため、差分は呼出元のみ。詳細は `docs/devlog/06-control-widget-ios26.md`。出なかった場合の次の手（`allowedExecutionTargets = [.main]` → ボタン形状で再試行）は `docs/devlog/06-control-widget-ios26.md` 2026-08-12 の項に記載。
- [ ] **C-9**: `#Predicate` の Optional 比較制約について、visionOS/toolchain バージョン差による再現/非再現の実際の切り分けは優先度低のため未再検証。
- [ ] **付録**: `docs/insights/05` L90 の「WWDC 2026 session 8017 SwiftData Group Lab」引用元がローカルアーカイブに存在せず（8011 のみ確認可能）、一次資料未確認のまま一次確認不能な伝聞として記録している。

---

## 優先度 A: WWDC の公式説明と矛盾している（最優先で再検証）

### A-1. 「メインアプリターゲットに `includedPackages` 付き `AppIntentsPackage` を重複宣言してはいけない」 ✅ 済（断定を撤回）

**結果**: 実ビルドで再検証（アプリ+全Extensionターゲットに `includedPackages` 付き `AppIntentsPackage` を追加）した結果、`Metadata.appintents` の件数は無宣言時と完全に同一で重複は確認できなかった。「絶対禁止」という断定を撤回し、「ビルド/メタデータレベルでは問題ないが実機 Siri ルーティングは未確認」に改めた。修正先: AGENTS.md（CLAUDE.md 実体）「Swift Package内でのAppIntents」節、`docs/insights/03-app-intents-core.md`「パッケージ内での定義」節。

- **記載箇所**: CLAUDE.md「Swift Package内でのAppIntents」節 / docs/insights/03-app-intents-core.md L207 付近
- **現在の主張**: アプリ全体で `AppIntentsPackage` は1つまで。アプリ側に `includedPackages` 付きで宣言すると二重扱いになり Shortcuts ルーティングが壊れる（`LNContextErrorDomain Code=2001`）。
- **WWDC の説明（矛盾）**: wwdc2025-244 (23:29–24:00) は**まさにこの禁止パターンが公式手順**: "To share types between targets, I'll need to register **each target** as an App Intents Package. First, I'll create an App Intents Package in the same target as the entity. **I'll add another App Intents Package to my app target. I can supply a list of included packages**... Finally, I'll do the same from my extension." サマリーも "You **must** register each target as an App Intents Package to ensure proper indexing and validation." wwdc2025-275 (25:50) にも同じアプリ側 `includedPackages` パターンのコード例あり。
- **仮説**: 当時の破損は「アプリ側宣言そのもの」ではなく、①同一パッケージのメタデータが SPM 自動抽出とアプリ側宣言で二重 extraction された、②パッケージが複数ターゲット（Widget/Watch）にリンクされ各々で再登録された、③当時の beta のバグ、のいずれか。
- **調査対象**: `Packages/TodoAppIntents/Sources/TodoAppIntents/TodoIntentsPackage`（宣言）、アプリターゲット側の宣言有無（git 履歴 2026-04-13 前後で削除された `AppIntentsPackage`）、`project.pbxproj` の TodoAppIntents リンク状況、各ターゲットの `Metadata.appintents`。
- **検証手順**: 244 の公式パターン（アプリ側 `AppIntentsPackage` + `includedPackages: [TodoIntentsPackage.self]`、Extension 側も同様）を現 SDK で実装 → Shortcuts ルーティングと `Metadata.appintents` を確認。壊れる場合は再現手順つきで「SDK バージョン固有の逸脱」として記録し直す。

### A-2. 「`AppShortcutsProvider` は SPM パッケージに置けない（`autoShortcuts: 0` になる）」 ✅ 済（制約は正しいと再確認、変更不要）

**結果**: A-1 の `AppIntentsPackage` 設定を追加した状態でも `AppShortcutsProvider` がパッケージ内にある限り `autoShortcuts` は 0 のままで、アプリターゲットへ移動した時点でのみ 0→8 に変化した。A-1 とは独立した制約であることを確認、ルール自体は変更不要（AGENTS.md / insights/03 に再確認済みの注記を追加）。

- **記載箇所**: CLAUDE.md「⚠️ 例外」節 / docs/insights/03 L209–235
- **現在の主張**: パッケージに置くと App Shortcut がメタデータに集約されず、必ずアプリターゲット直下に置く必要がある。
- **WWDC の説明（ニュアンス）**: wwdc2023-10103 (17:21) が明示的に認めるのは「メインアプリバンドル」と「App Intents extension」のみ。wwdc2025-275 (25:34) の "you can now put your App Intents in Swift Packages and static libraries" は Intent/Entity 一般の話で、AppShortcutsProvider を名指ししていない。→ 制約自体は否定されていない。
- **仮説**: ただし **A-1 と連動**。当時「アプリ側に `AppIntentsPackage` + `includedPackages` を宣言しない」運用だったため集約されなかった可能性がある。公式登録パターンなら `autoShortcuts` も集約されるかもしれない。
- **調査対象**: A-1 と同じ + `IntentTodo/IntentTodo/TodoAppShortcuts.swift`。
- **検証手順**: A-1 の公式パターン適用後、AppShortcutsProvider をパッケージへ移して `extract.actionsdata` の `autoShortcuts` 数を再計測。

### A-3. Live Activity の実行プロセス表と「LA Extension プロセスで entity 解決 → SwiftData trap」の因果 ✅ 済（断定を精緻化）

**結果**: git 考古学でクラッシュ自体は実在（コミット `c37ee97`/`a234842`、スタックトレース有）と確認。ただし「Live Activity Extension プロセスで解決された」という原因断定は、Apple 公式の「`LiveActivityIntent` の `perform()` はアプリプロセスで実行」という保証と厳密には矛盾しうるため撤回し、「`perform()` はアプリプロセス保証、ただし entity の事前解決フェーズがどこで走るかは未文書化かつ実機 crash 歴あり」という正確な切り分けに改めた。FromExtension 分離は結果的に安全なので維持。修正先: AGENTS.md「なぜ分けるか」節・実行プロセス表、`docs/insights/03`「Primary / FromExtension 分離パターン」節、`docs/insights/07`。

- **記載箇所**: CLAUDE.md「Primary / FromExtension 分離パターン」+「実行プロセスと登録先」表 / docs/insights/03 L328–345 / docs/insights/07 L128–150
- **現在の主張**: `@Parameter var todo: TodoAppEntity` の解決が Live Activity Extension プロセスで走ると SwiftData が `EXC_BREAKPOINT` で trap する。そのため String ID の FromExtension 系 Intent を分離。実行プロセス表では「Live Activity ボタン → LA Extension プロセスで実行、Extension 側で登録」。
- **矛盾（同一ファイル内）**: CLAUDE.md 自身が引用する Apple ドキュメントは "If you adopt the **LiveActivityIntent** ... protocol, the system runs the app intent **in the app's process**"。`LiveActivityIntent` がアプリプロセス実行なら、entity 解決が LA Extension で走ったという前提自体が要再検証。表と引用は両立しない。
- **仮説**: crash の真因は実装側にある可能性: (a) 当時その Intent が `LiveActivityIntent` 未準拠だった（準拠が `#if os(iOS)` ゲートされている点も注意）、(b) LA Extension プロセスに `AppDependencyManager` 登録が無く `TodoEntityQuery` の `@Dependency var modelContainer` が不正だった、(c) LA Extension 用 ModelContainer の App Group / CloudKit オプション設定不備。
- **調査対象**: `Packages/TodoAppIntents` の `TodoEntityQuery`、`IntentTodoLiveActivity/IntentTodoLiveActivityBundle.swift`（依存登録の有無）、`SharedModelContainer`、LA Extension の entitlements（App Group）、当時のコミット履歴。
- **検証手順**: LA Extension プロセスへの登録・entitlements を整えた上で Primary 版（`TodoAppEntity` パラメータ）を LA ボタンから実機実行し、trap が再現するか確認。再現しなければ FromExtension 分離は簡素化できる。

### A-4. 「`\.textContent` は indexingKey として SDK に露出していない」 ✅ 済（誤りと確定、訂正）

**結果**: 実ビルドで確認: `\.textContent` は `CSSearchableItemAttributeSet_Messaging.h` に実在し、`String?` でも `AttributedString?` でも同一の `indexingKey:` オーバーロードが使える（型で分岐しない）。「AttributedString 専用」仮説も誤り。`todoDescription` を `contentDescription` にマップする結論自体は変わらないが、理由を「型の制約」から「意味の制約（CSDocuments vs CSMessaging）」に訂正。修正先: `docs/insights/03-app-intents-core.md`「`@Property(indexingKey:)`」節。

- **記載箇所**: docs/insights/03 L784–786
- **現在の主張**: `textContent` は無く、本文は `contentDescription` に載せるのが妥当。
- **WWDC の説明（矛盾）**: wwdc2026-240 のコード例が `@Property(indexingKey: \.textContent) var body: AttributedString?` を使用。wwdc2024-10131 (2:41) も "make sure to set the title and **textContent**" と明言。
- **仮説**: `\.textContent` キーパスは `AttributedString?` プロパティにのみ vend される（240 の例は `AttributedString?`、本プロジェクトの `todoDescription` はおそらく `String`）。または当時の beta SDK のオーバーロード差。
- **調査対象**: `TodoAppEntity` の `todoDescription` の型と indexingKey 適用箇所。
- **検証手順**: `AttributedString?` プロパティで `\.textContent` を現 beta で再試行。

### A-5. 実行プロセス「固定表」全般（Widget `.background` → 必ず Widget Extension 等） ✅ 済（誤りと確定、訂正）

**結果**: SDK 実物確認（`IntentExecutionTargets` が `.default` を独立ケースとして持つ `OptionSet`）で、既定はヒューリスティクス、固定するには `allowedExecutionTargets` が必要という理解を裏付けた。「固定的に決まる」という表現を「ヒューリスティクスで決定、固定するには `allowedExecutionTargets`」に全面訂正。二重 `AppDependencyManager` 登録は未指定 Intent がある限り撤廃できないと結論。修正先: AGENTS.md「実行プロセスと登録先」節、`docs/insights/03/06/07` の該当表。

- **記載箇所**: CLAUDE.md「実行プロセスと登録先」表 / docs/insights/03 L75–83 / 06 L151–157 / 07 L111–114
- **現在の主張**: 呼出元とモードで実行プロセスが固定的に決まる。
- **WWDC の説明（ニュアンス）**: wwdc2026-345 (15:59–16:55): 共有パッケージの Intent は**ヒューリスティクスでプロセス選択**（"It picks a target based on heuristics like if the app is already running, it prefers the app"）。明示制御は `allowedExecutionTargets`（`.main` / `.appIntentsExtension` / `.widgetKitExtension`）。
- **仮説**: 現在の「両プロセスで AppDependencyManager 登録」運用は動くが、表の前提（固定）が誤りなら `allowedExecutionTargets` 指定で登録要件を単純化できる。また FromExtension 分離の代替（entity 解決がプロセスに追随するか）は 03 L632 で「未検証」と自認済み。
- **調査対象**: `TodoAppIntents` 内の `.background` Intent 群、`IntentTodoWidgetBundle.init()` の登録。
- **検証手順**: `allowedExecutionTargets = [.main]` を付けた Intent を Widget / Control から実機実行し、実行プロセスと entity 解決プロセスをログで確認。

---

## 優先度 B: プロジェクト内ドキュメント同士が矛盾している

### B-1. watchOS の `Task { intent.perform() }` 推奨 vs 「手動 perform は @Dependency クラッシュ」 ✅ 済（07 側が誤り、訂正）

**結果**: `Packages/WatchUI` の実コード（`WatchTodoRow.swift` / `WatchTodoDetailView.swift` / `WatchAddTodoView.swift`）は一貫して `role:` 無しの `Button(intent:)` を使用しており、04 側の指針（手動 perform は危険）が正しい。07 側の「watchOS では手動 `Task { perform() }` を推奨」は誤記と判明し訂正。watchOS で使えないのは `role:` 付きシグネチャのみ。修正先: `docs/insights/07-platform-specific.md`「Button(intent:) の API 差異」節。

- **記載箇所**: docs/insights/07 L7–23（watchOS では `Button(intent:role:)` が使えないため手動 `perform()` を推奨）vs docs/insights/04 L40–52（手動 `Task { intent.perform() }` は `@Dependency` がゼロ初期化でクラッシュするため `Button(intent:)` 必須）
- **問題**: 真逆の指針が並存。また `role:` 無しの `Button(intent:)` は watchOS でも使えるはずで、07 の前提も要確認。
- **調査対象**: `Packages/WatchUI/Sources` の実装（どちらのパターンを実際に使っているか）、その Intent が `@Dependency` を持つか。
- **検証手順**: 実装を確認し、watchOS 実機/シミュレータで両パターンを試して doc を一本化。

### B-2. 「macOS では `onAppIntentExecution` が使えない」 ✅ 済（制約は正しいと確認、変更不要）

**結果**: Xcode 27 beta 5 SDK の `.swiftinterface` を直接調査した結果、`onAppIntentExecution` を実装する `_AppIntents_SwiftUI` フレームワークは iOS / macCatalyst / visionOS / watchOS には存在するが、**ネイティブ macOS には存在しない**ことを確認（0件マッチ）。制約は正しかった。一方 `TargetContentProvidingIntent`（プロトコル本体）は macOS でも利用可能で、プロジェクトの `#if os(iOS) || os(macOS) || os(visionOS)` によるプロトコル準拠は妥当（半矛盾ではなく、プロトコル準拠とSwiftUI側モディファイアの利用可否が別問題だった）。修正先: `docs/insights/04-ui-integration.md` に確認済みの注記を追加（ルール自体は変更なし）。

- **記載箇所**: docs/insights/04 L94
- **問題**: wwdc2025-275 (21:26–23:52) はプラットフォーム制限に言及なし。しかも同プロジェクトの `OpenAddTodoIntent` まわりの extension は `#if os(iOS) || os(macOS) || os(visionOS)` で macOS を含んでおり記述と半ば矛盾。メモリの方針（「プラットフォーム限定」は当時の制約かもしれない → SDK 更新時に実ビルドで確認）にも該当。
- **調査対象**: `Packages/UI` の `.onAppIntentExecution` 使用箇所、SwiftUI SDK の availability。
- **検証手順**: macOS destination で `.onAppIntentExecution` を使うコードをビルドして確認。使えるなら 04 と CLAUDE.md の「macOS は @Dependency パターン必須」を修正。

---

## 優先度 C: 経験則だが実装原因の可能性が濃い

### C-1. cold start 時の `onAppIntentExecution` ナビゲーション不安定（iOS 26.4 でも） ✅ 済（現状非アクティブと判明、仮説は保留）

**結果**: コードベースを grep した限り `.onAppIntentExecution` は現在どこにも使われていない（`@Dependency` + `perform()` パターンへ完全移行済み）。3つの仮説（`@State path` 未構築 / activation conditions 未設定 / `supportedModes` 不足）はコードで検証できる対象が無いため保留とし、再導入時に検証する旨を注記。修正先: `docs/insights/04-ui-integration.md`。

- **記載箇所**: docs/insights/04 L103–109
- **仮説**: OS バグではなく、①`.onAppIntentExecution` を付けた View / NavigationStack の `@State path` がクロージャ実行時点で未構築、②シーンの activation conditions（wwdc2025-275 23:52–24:09 は「どのシーンが intent をハンドルするかは activation conditions で決まる」と明言）未設定、③Intent の `supportedModes` に foreground が無くタイムアウト、のいずれか。
- **調査対象**: `Packages/UI` の `.onAppIntentExecution` 装着位置、`IntentTodoApp.swift` / `SceneDelegate.swift` のシーン構成、対象 Intent の `supportedModes`。
- **検証手順**: アプリを kill した状態から Shortcuts 経由で実行し、クロージャ呼び出しタイミングと path 適用をログで確認。

### C-2. 「`ControlConfigurationIntent` と `SetValueIntent` は同時準拠できない」 ✅ 済（表現訂正）

**結果**: `IntentTodoWidget/Controls/` を確認、実際にはカスタム `ControlConfigurationIntent` を持たず `StaticControlConfiguration` のみ使用、トグル操作は独立した `AppIntent` を `ControlWidgetButton(action:)` に渡す形で役割分離済み。「同時準拠できない」という制約表現を「Apple の設計では元々別 Intent」に訂正。修正先: `docs/insights/06-control-widget-ios26.md`。

- **記載箇所**: docs/insights/06 L84
- **仮説**: wwdc2024-10157 のモデルでは configuration intent（設定パラメータ用）と action intent（`SetValueIntent`）は**そもそも別の Intent** に分ける設計。「同時準拠不可」は 1 つの Intent に両役割を混ぜようとした痕跡で、制約ではなく設計の取り違えの可能性。
- **調査対象**: `IntentTodoWidget/Controls/` と `IntentTodoWidget/Configuration/` の Intent 分割。
- **検証手順**: 役割分離した形で実装できているか確認し、doc の表現を「役割が異なるので別 Intent に分ける（Apple の設計）」に改める。

### C-3. 「Widget Extension 内定義の `ControlConfigurationIntent` はアプリから参照不可 — Name Mangling が原因」 ✅ 済（因果訂正）

**結果**: 「Name Mangling」という因果説明を「ターゲット/モジュール境界（Extension は別モジュール）」に訂正。共有したい場合は SPM へ移すのが公式サポート（wwdc2025-244）。本プロジェクトは `StaticControlConfiguration` のみでこの問題自体が発生しない設計。修正先: `docs/insights/06-control-widget-ios26.md`。

- **記載箇所**: docs/insights/06 L88
- **仮説**: 参照不可の真因は単なる**ターゲット/モジュール境界**（Extension ターゲットの型はアプリから import 不能）。「Name Mangling」という因果説明は誤りの可能性大。共有したい場合は SPM へ移すのが公式サポート（wwdc2025-244 22:34）。
- **検証手順**: doc の因果説明を修正。共有が必要なら SPM 移送を試す。

### C-4. 「Extension 内では `WidgetReloader` を import できない場合がある」 ✅ 済（現状当てはまらないと確認、訂正）

**結果**: `WidgetReloader` は `TodoAppIntents` パッケージ内にあり、`IntentTodoLiveActivity` / `IntentTodoWidget` の両 Extension ターゲットは既に `import TodoAppIntents` している（Intent 型を使うため）ことを確認。実際、全 `reloadAllWidgets()` 呼び出しは `TodoService` 内に集約されており、Extension から直接 `WidgetCenter` を呼ぶ箇所は無い。修正先: `docs/insights/05-extensions-and-data-sharing.md`。

- **記載箇所**: docs/insights/05 L220
- **仮説**: プラットフォーム制約ではなく Extension ターゲットの SPM 依存グラフの問題（`WidgetReloader` の所在パッケージが Extension ターゲットの依存に入っていないだけ）。
- **調査対象**: `WidgetReloader` の所在パッケージ、`IntentTodoLiveActivity` / `IntentTodoWidget` ターゲットの依存（pbxproj）。
- **検証手順**: 依存を追加して import できるか確認。

### C-5. 「`UISceneAppIntent` は Swift Package 内 Intent には利用不可（UIKit 依存で Package スコープ参照不可）」 ✅ 済（因果訂正）

**結果**: SDK 調査で `UISceneAppIntent` は独立フレームワーク `_AppIntents_UIKit` に属し、これが **iOS / watchOS / visionOS には存在するがネイティブ macOS には存在しない**ことを確認（Package スコープの問題ではなく SDK レベルのプラットフォームギャップ）。`#if canImport(_AppIntents_UIKit)` でガードすれば Package 内でも使える可能性が高いと訂正。**2026-08-11 追記**: `RunCodeSnippet` で実際に iOS シミュレータ (iOS 27) コンテキストで `#if canImport(_AppIntents_UIKit)` を実行し `available` を確認、ガード方針が iOS 側で機能することを実証した（macOS 側は `.swiftinterface` の静的調査のみ）。ただし本プロジェクトには `UISceneAppIntent` を要する具体的なマルチウィンドウ機能が無いため、コード実装は見送り。修正先: `docs/insights/04-ui-integration.md`。

- **記載箇所**: docs/insights/04 L206
- **仮説**: SPM パッケージは `#if canImport(UIKit)` で UIKit を import 可能であり、理由付けが疑わしい。実際の障壁は TodoAppIntents が watchOS/macOS 向けにもコンパイルされるプラットフォームマトリクスで、ガードで解決できる可能性。
- **検証手順**: 必要になったら `#if canImport(UIKit)` ガード付きで試す（優先度低、理由付けの修正のみ先行可）。

### C-6. `.reminders.reminder` スキーマ適合の据え置き理由（マクロ生成 init の `EntityProperty<T>` 要求） ✅ 済（新リード追記、再挑戦は未実施）

**結果**: 実際のマイグレーション再挑戦は大規模な機能作業になるため今回はスコープ外。wwdc2026-344 の CometCal パターン（手書き init なし、スニペット生成 + Query 側 populate + 入れ子は TransientAppEntity）を新しいリードとして `docs/APP_INTENTS_CENTRIC_PLAN.md` に追記し、#48 再挑戦時の出発点とした。

- **記載箇所**: CLAUDE.md ロードマップ注記 / docs/APP_INTENTS_CENTRIC_PLAN.md L120–133 / docs/insights/03 L853–866
- **仮説**: wwdc2026-344 は同等にリッチな `calendar_event` スキーマ（入れ子 entity: attendee は `TransientAppEntity`、location は union）を**手書き init なし**で適合させている — Xcode のスキーマ・コードスニペットで型の骨格を生成し、Query 側で model → entity をマッピングする流儀。本プロジェクトの「自前 `init(from: TodoItem)` で順次代入」というスタイルがマクロ生成 backing storage と衝突している可能性。
- **調査対象**: 適合を試みた probe ブランチのコード、`TodoAppEntity` の init 構造。
- **検証手順**: 344 の CometCal パターン（スニペット生成の形 + Query 側 populate + 入れ子は TransientAppEntity）で再挑戦。

### C-7. 「Intent でデータ変更してもウィジェットは自動更新されない → 全 Intent で `WidgetReloader.reloadAllWidgets()` 必須」 ✅ 済（理由付けを正確化、ルールは維持）

**結果**: wwdc2023-10028 の通り Widget 起点の `Button(intent:)` は自動リロード保証がある。ルール自体（全 Intent で無条件に呼ぶ）は安全側なので維持し、理由を「Widget 起点は自動、それ以外の経路のために必要」に正確化。修正先: AGENTS.md（CLAUDE.md 実体）、`docs/insights/05-extensions-and-data-sharing.md`。

- **記載箇所**: CLAUDE.md「データ更新 Intent は必ず…」節 / docs/insights/05 L195
- **ニュアンス**: wwdc2023-10028 (13:47): "As soon as your perform returns, the system will immediately initiate a reload of your widget timeline"（**Widget 内 `Button(intent:)` 起点は自動リロード保証**、10:02 "reloads initiated from an interaction are always guaranteed"）。手動 reload が必要なのはアプリ/Siri 側で変更したケースのみ。
- **検証手順**: ルール自体は安全側なので維持でよいが、doc の理由説明を「Widget 起点は自動、それ以外の経路のために必要」と正確化。呼び出し重複による無駄リロードが気になる場合のみ最適化。

### C-8. Control Widget のフィードバック: `.controlWidgetStatus(_:)` 未検討 ✅ 済（→ 2026-08-12 に設計ごと見直し）

**結果**: `ToggleUrgentTodoControl`（`IntentTodoWidget/Controls/ToggleUrgentTodoControl.swift`）のラベルに `.controlWidgetStatus(snapshot.isCompleted ? "Completed" : "Due soon")` を追加し、IntentTodo スキーム（iPhone 17 Pro Max シミュレータ, iOS 27）でビルド成功を確認した。ローカル通知（`ControlNotificationHelper`）運用はそのまま維持し、Control 自体の即時状態表示との併用とした。`TodoCountControl` はボタンの表示値がタップで変化しない（fire-and-forget）ため対象外とした。詳細は `docs/insights/06-control-widget-ios26.md`「Control Widget からの Intent では `.result(dialog:)` が表示されない」節。実機での見え方確認は未実施。

- **記載箇所**: CLAUDE.md「Dialog vs 通知の使い分け」/ docs/insights/06 L92–100
- **ニュアンス**: 「Dialog が表示されない → ローカル通知」という現運用に対し、Apple が Control 用に用意するフィードバック機構 `.controlWidgetStatus(_:)`（wwdc2024-10157）が未検討。
- **検証手順**: `ToggleUrgentTodoIntent` / `ShowTodoCountIntent` で `.controlWidgetStatus` を試し、通知運用と比較。
- **後日談 (2026-08-12)**: 比較の結果、併用ではなく**通知（成功）と `.controlWidgetStatus` の両方を撤去**する結論になった。Control を `ControlWidgetToggle` 化して状態自体をコントロール面に出したため、どちらも「コントロールが既に伝えている情報」の重複表示になったため。Snippet で置き換える案も検討したが、Snippet は Siri / Spotlight / Shortcuts でしか描画されず Control では出ない。詳細: `docs/devlog/06-control-widget-ios26.md` 2026-08-12 の項。

### C-9. 「`#Predicate` の Optional 直接比較は visionOS 等でコンパイル不可のことがある」 ✅ 済（表現を汎化）

**結果**: プラットフォーム限定の書き方を「全プラットフォーム共通の toolchain 依存問題」に汎化訂正（優先度低のため深掘りはせず）。修正先: `docs/insights/07-platform-specific.md`。

- **記載箇所**: docs/insights/07 L265–275
- **仮説**: `#Predicate` の Optional 制約は通常**全プラットフォーム共通**のマクロ/型推論問題で、「visionOS 等で」というプラットフォーム差は toolchain バージョン差の可能性。優先度低。

---

## 付録: コード検証不要だが修正すべきドキュメント誤り（照合で発見）

コード側ではなく **doc 修正のみ** で済むもの。別途 docs 修正タスクとして処理する。

### WWDC_APP_INTENTS_SESSIONS.md の誤帰属（主要なもの） ✅ 全行修正済み（2026-08-11）

以下の表の全行に `docs/WWDC_APP_INTENTS_SESSIONS.md` 上でインライン注記を追加済み（誤帰属の訂正・正しい出典への付記）。297 のタイトルも本文中で修正済み。

| 記載箇所 | 誤り | 正しい出典 |
|---------|------|-----------|
| 10133 (2024) の行 | `AppEntityContext` / `RelevantEntities.shared.updateEntities` は 10133 に登場しない | wwdc2026-345（新 API として導入） |
| 10157 (2024) の行 | `ControlWidgetButton` / `ControlConfigurationIntent` は 10157 に登場しない（10157 は Toggle のみ） | wwdc2024-10210（**この表自体に 10210 が未収録**なのが根因） |
| 10134 (2024) の行 | 「Static Library / Swift Package 内でも Entity 定義可能」は逆。10134 は "Only frameworks are supported at this time. Libraries outside of a framework are not." | SPM/static lib 対応は wwdc2025-244 / 275 |
| 345 (2026) の行 | `@ComputedProperty` / `@DeferredProperty` は 345 に登場しない | wwdc2025-275 |
| 345 (2026) の行 | 「`@UnionValue` の public enum に `: Sendable` 明示必要」はセッション内容でなくプロジェクトのビルド観測 | 「プロジェクト検証による」と注記へ |
| 240 (2026) の行 | 「reminders ドメイン拡充」「`.appEntityIdentifier(forSelectionType:)`」「`UNMutableNotificationContent.appEntityIdentifiers`」は 240 に無い | reminders は SDK 観測由来、後者2つは wwdc2026-343 |
| 260 (2025) の行 | `assistantOnly` / `PredictableIntent` / `NSUserActivity.appEntityIdentifier` は 260 に無い | PredictableIntent は 275、appEntityIdentifier は 275/343。assistantOnly は全書き起こしに無し（API docs 由来と注記） |
| 344 (2026) の行 | `.system.searchInApp` / `StringSearchCriteria` / `searchScopes` / `EntityPropertyQuery` / 素の `DeleteIntent` プロトコルは 344 に無い | searchInApp/StringSearchCriteria は wwdc2026-343。344 は EnumerableEntityQuery + スキーマ版 DeleteEventIntent |
| 10103 (2023) の行 | `IntentDonationManager` / `PredictableIntent` / `IntentProjection` は 10103 に無い | API docs 由来と注記（RelevantIntent/RelevantContext は 10103 にあり） |
| 343 (2026) の行 | `requestConfirmation(confirmLabel:cancelLabel:)` / `requestChoice(...view:)` / donation 削除 API は 343 に無い | requestChoice は 275。他は API docs 由来と注記 |
| 10028 (2023) の行 | 「`invalidatableContent()` が自動リロードする」は混同。自動リロードは perform 完了時のシステム挙動、`invalidatableContent()` は無効化中の視覚効果のみ | wwdc2023-10028 13:47 / 16:44 |
| 10032 (2022) の行 | `IntentDialog(full:supporting:)` の実例は 10032 に無い | wwdc2026-343 (2:45) |
| 297 (2026) のタイトル | 正式タイトルは "Best practices for integrating visual intelligence in your app"（INDEX.md 指摘済み・未修正） | — |

### その他の doc 精度向上 ✅ 全項目対応済み（2026-08-11）

insights/05（8017出典未確認注記）、APP_INTENTS_CENTRIC_PLAN.md（RelevantEntities 実例訂正・EntityCollection.resolvedEntities() の SDK 実在確認）、insights/03（openable 要件の全プラットフォーム共通性・IntentValueQuery 1つ制約・AppIntentsTesting 同一チーム署名要件）、insights/06（ControlValueProvider 理由付け訂正）を全て反映済み。

- **docs/insights/05 L90**: 「WWDC 2026 session 8017 SwiftData Group Lab」の引用元がローカルアーカイブに存在しない（8011 のみ）。一次確認不能な伝聞として注記するか出典を用意する。
- **docs/APP_INTENTS_CENTRIC_PLAN.md**: `RelevantEntities` の例示 `.audio(.nowPlaying)` — 345 の実例は `.audio(.workout(activityType: .running))`。また `EntityCollection` の `resolvedEntities()` というシンボルは書き起こしに無い（345 は `.identifiers`）ため SDK で要確認。
- **docs/insights/03 L702–725**: 「Mac では visual search の entity が全て openable 必須」— openable 要件自体は全プラットフォーム共通（wwdc2025-275 9:19 "This OpenIntent must exist, otherwise your app won't show up"）。Mac 固有なのは**ビルド時強制**という enforce のされ方のみ。表現を正確化。
- **docs/insights/06 L38**: ControlValueProvider 推奨の理由を「body 過剰評価」としているが、Apple の説明（10157 9:51/11:22）は「非同期取得は ValueProvider で、reload 時に ValueProvider → body の順で実行される」。理由付けを差し替え。
- **docs/insights/03 L681 付近**: wwdc2026-297 (11:39) の「`SemanticContentDescriptor` を受ける `IntentValueQuery` はアプリに **1 つだけ**」という制約が未記録。追記推奨。
- **wwdc2026-295 (2:54)**: AppIntentsTesting の same-team code-signing 要件が insights 未記録。追記推奨。

---

## 照合で裏付けが取れた主要な制約（変更不要）

以下は書き起こしが明確に支持しており、再検証不要:

- App Shortcuts 最大 10 件・フレーズ 1,000 件上限（10169 4:02 / 10170 5:39 / 10102 20:58）
- `AppShortcutsProvider` はアプリに 1 つだけ（10102 3:44 / 2025-244 9:22）
- App Shortcut フレーズに埋め込めるのは事前定義値のみ、自由入力 String 不可（10170 14:40–15:15）
- supportedModes の 4 モードの意味（275 19:31–20:14）
- Intent 実行前に entity 解決が走る（345 7:37）/ `EntityCollection` は識別子のみ渡す（345 8:09）
- `LongRunningIntent` は progress 報告必須（345 13:55）/ `allowedExecutionTargets` は 3 種（345 16:55）
- 通知等への entity annotation は TransientAppEntity 不可（343 21:38）
- `.system.search` → `.system.searchInApp` リネーム（343 14:50）
- AppIntentsTesting は UI テストバンドル必須・別プロセス実行（295 2:35 / 8:18）
- `valueState` の `.set(nil)` / `.unset` セマンティクス（344 20:17）
- Widget の interactive 要素は Button / Toggle のみ（10028 12:15）
- Extension は独立プロセス・データ共有は App Group（10028 7:48 / 2026-277 2:30–2:53）

watchOS の assistant schema 非対応、`.reminders` ドメインの iOS 27+ 限定、`indexingKey:` のプラットフォーム制限、SSU beta バグ等は**書き起こしに記載が無い実ビルド観測**であり、メモリの方針どおり SDK 更新ごとに再検証する（ドキュメントの記録方法は適切）。
