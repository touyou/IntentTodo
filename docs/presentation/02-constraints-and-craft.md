# スライド骨子② App Intents 中心設計を 1 年やって見えた制約と工夫

> **狙い**: 「全部 Intent で書く」を本気でやったときに**実際に何が起きるか**を、実測ベースで共有する。
> API 紹介ではなく、**ドキュメントに書いていない / 書いてあっても間違いやすい**ところに絞る。
>
> **想定尺**: 25〜30 分（T01〜T30）。短縮するなら第5部（プラットフォーム）と第8部（不適合）を落とす
> **想定聴衆**: App Intents を少し触ったことがある層。「便利そうだけど怖い」と思っている人
>
> 各スライド: `見せるもの` / `話の要点` / `出典`。⚠️ は一次ソース未確認 or 発表前に再確認したい箇所。

---

## 構成の全体像

```
第0部  前提          T01–T04  何を作ったか / どこまで徹底したか
第1部  設計の芯      T05–T08  1アクション1Intent / 唯一の実行経路 / ロジックの置き場
第2部  制約A メタデータ T09–T12  ビルドは通るのに機能しない
第3部  制約B プロセス   T13–T17  どこで perform されるのか問題
第4部  制約C 呼出元     T18–T21  同じ Intent でも出るものが違う
第5部  制約D プラットフォーム T22–T24  #if の当て方を間違える
第6部  検証           T25–T27  AppIntentsTesting と検証の梯子
第7部  調査のコツ      T28–T29  どうやって確定させるか（一番持ち帰ってほしい）
第8部  総括           T30      効能と代償
```

貫くメッセージ（T02 / T28 / T30 で 3 回）:

> **App Intents の失敗は「ビルドが通って、エラーも出ず、ただ動かない」という形で来る。**
> **だから「呼出元を 1 つだけ変えて同じものを走らせる」比較と、メタデータを直接見る癖が要る。**

---

## 第0部 前提

### T01. 何を作ったか

- **見せるもの**: 6 プラットフォームのスクショ並べ（iOS / iPadOS / macOS native / watchOS / visionOS / ウィジェット・コントロール・ライブアクティビティ）
- **話の要点**:
  - Todo アプリ 1 本。App Intents 中心設計の実験台として、iOS / iPadOS / macOS（Catalyst ではなくネイティブ）/ watchOS / visionOS + ウィジェット / コントロールセンター / ライブアクティビティ / Siri / Shortcuts / Spotlight / Visual Intelligence
  - 数字: **Intent 定義 24 ファイル**（メタデータ上の intent 型数 23 — Visual Intelligence 系はプラットフォーム条件付き）、**AppEntity 4 種**（+ `@UnionValue` 1 種）、**Query 4 種**、**App Shortcut 8 件 / 上限 10**
  - パッケージは 7 つ。**`TodoAppIntents` がコア**で、そこにビジネスロジックが全部いる
- **出典**: [../../CLAUDE.md](../../CLAUDE.md) パッケージ構成 / リポジトリ実体

### T02. 「Intent 中心」をどこまで徹底したか

- **見せるもの**: 依存図。`Domain → Repository → TodoAppIntents → (UI / WidgetUI / WatchUI / LiveActivity)`
- **話の要点**:
  - **UseCase 層を作らなかった**。App Intents がその役を担う
  - **UI からのアクションは必ず `Button(intent:)`**。ViewModel はフィルタ・ソート・検索テキストといった**表示状態だけ**持つ
  - Extension ターゲット（Widget / LiveActivity / Watch App）は **`@main` と宣言だけ**。View も状態管理も SPM に置く（プレビューとテストのため）
  - この徹底が効いた部分と、代償になった部分の両方を今日話す
- **出典**: [../../CLAUDE.md](../../CLAUDE.md) / [../insights/01-swift-package-design.md](../insights/01-swift-package-design.md)

### T03. 効いたこと（先に結論）

- **見せるもの**: 3 つの「増やさずに済んだ」
- **話の要点**:
  1. **プラットフォームを増やすコストが低い**。watchOS を足すとき、書いたのは View だけ。アクションは既にある
  2. **Siri / Shortcuts / Spotlight / コントロール対応が「ついでに終わる」**。個別対応をしていない
  3. **ロジックの二重実装がゼロ**。ウィジェットのチェックボックスと Siri の「完了にして」が**同じ 1 つの Intent**
- **出典**: 実装実績

### T04. しんどかったこと（先に結論）

- **見せるもの**: 3 つの「エラーが出ないのに壊れる」
- **話の要点**:
  1. **メタデータ抽出が静かに失敗する**（ビルド成功、`autoShortcuts: 0`）
  2. **どのプロセスで実行されるか**が呼出元とアプリの状態で変わる
  3. **呼出元によって、返した dialog / snippet が出るか出ないかが変わる**。しかも公式ドキュメントの記述が割れている
  - 共通点: **どれも「ビルドは通る」「例外も出ない」「ただ動かない」**
- **出典**: 以降の各スライド

---

## 第1部 設計の芯

### T05. 1 アクション 1 Intent（呼出元ごとに複製しない）

- **見せるもの**: 1 つの `ToggleTodoCompletionIntent` から矢印が 6 方向（UI / Widget / Control / Live Activity / Siri / Shortcuts）
- **話の要点**:
  - 同じアクションは呼出元が違っても**同じ Intent**。Live Activity のボタンも Siri も `ToggleTodoCompletionIntent(todo:)` を呼ぶ
  - Live Activity が持っているのが id と title だけでも `TodoAppEntity(id:title:)` で組んで渡せばよい。**システムが `perform()` の前に `entities(for:)` で id から再解決する**
  - **昔は分けていた**: 「Primary（entity パラメータ）/ FromExtension（String パラメータ）」。理由は entity の事前解決中に SwiftData が `EXC_BREAKPOINT` で落ちた実績
  - **2026-08-12 に iOS 27 で再現しないことを実測して分離を撤去**。cold start でも、`LiveActivityIntent` 非準拠でも、`entities(for:)` も `perform()` もメインアプリプロセスで走る
  - 教訓: **回避策は原因が消えたら消す**。残しておくと「なぜこうなっているか分からない複製」になる
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「1 アクション 1 Intent」/ [../devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

### T06. じゃあ、どういう時に Intent を分けるのか

- **見せるもの**: 表をそのまま出す

| 分けている Intent | 分けた理由 |
|---|---|
| `SnoozeTodoIntent` / `QuickSnoozeTodoIntent` | 前者は `requestChoice` で期間を選ばせる。Live Activity のボタンは問い合わせ先の UI が無いので後者が既定 30 分で即実行 |
| `DeleteTodoIntent` / `DeleteTodoImmediatelyIntent` | 前者は `requestConfirmation` で確認を取る。UI 側は SwiftUI の `.confirmationDialog` で確認して後者を呼ぶ |
| `ToggleTodoCompletionIntent` / `SetTodoCompletionIntent` | 前者はトグル、後者は絶対値セット（`SetValueIntent`）。`ControlWidgetToggle` は「移った先の状態」を渡してくるのでトグルでは表現できない |

- **話の要点**:
  - 判断基準は **「呼出元のプロセスの都合」ではなく「振る舞いが違うか」**
  - 現存する 3 つの分岐は、突き詰めると **「対話できるか」** と **「トグルか絶対値か」** の 2 種類だけ
  - 内部専用は `isDiscoverable = false` にして Siri / Shortcuts に出さない（`ReorderTodosIntent` / `SetTodoCompletionIntent` / `SnippetIntent` など）
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)

### T07. ロジックは Intent ではなく Service に集約した

- **見せるもの**: `Intent（薄い） → TodoService（@MainActor final class） → Repository（protocol）`
- **話の要点**:
  - 当初は Intent の `perform()` にロジックを書いていた。**24 個に増えると同じ処理が散る**
  - `TodoService`（`@MainActor final class`）に集約し、Intent は `@Dependency var todoService` で参照するだけにした
  - 副作用: **`WidgetReloader.reloadAllWidgets()` を Service 側の `defer` で呼ぶ**ようにできた。Intent 側で呼び忘れる余地が消えた
  - `WidgetReloader` は `WidgetCenter.reloadAllTimelines()` と **`ControlCenter.reloadAllControls()` の両方**を呼ぶ。⚠️ ここは実際にバグった（次スライド）
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「共通ロジックは TodoService に集約」

### T08. 小ネタ: ホームウィジェットとコントロールは別 API

- **見せるもの**: Control Center のスクショ 2 枚（トグルで完了にしたのに、隣のカウントが `2` のまま / 修正後 `1`）
- **話の要点**:
  - `WidgetCenter.shared.reloadAllTimelines()` は**コントロールを更新しない**
  - システムが自動リロードするのは「その Intent を実行したコントロール自身」だけ。**隣のコントロールは取り残される**
  - 実測（2026-08-12 / iOS 27 シミュレータ）: `ToggleTodoControl` で完了 → 隣の `TodoCountControl` が `2` のまま。`ControlCenter.shared.reloadAllControls()` を 1 行足したら同時に `1` へ
  - なお Widget 内の `Button(intent:)` から呼ばれた場合はシステムが自動リロードを**保証**している（wwdc2023-10028 `13:47`）。全 Intent で無条件に呼ぶのは判定を省いた安全側の運用
- **出典**: [../insights/05-extensions-and-data-sharing.md](../insights/05-extensions-and-data-sharing.md)「WidgetKit 更新パターン」

---

## 第2部 制約A: メタデータ — ビルドは通るのに機能しない

### T09. App Intents の実体は「ビルド時に抽出されたメタデータ」

- **見せるもの**: `Metadata.appintents/extract.actionsdata` の JSON を開いた図。キー: `actions` / `entities` / `queries` / `autoShortcuts`
- **話の要点**:
  - App Intents は**ランタイムのリフレクションではなく、ビルド時に Swift コンパイラが抽出した JSON** をシステムが読む
  - つまり「型を書いた」と「システムに登録された」は**別のこと**。ここが全部の落とし穴の源
  - デバッグの入口はここ:
    ```bash
    python3 -c "import json; d=json.load(open('<DerivedData>/.../IntentTodo.app/Metadata.appintents/extract.actionsdata')); print({k: len(v) for k, v in d.items() if isinstance(v, list)})"
    ```
- **出典**: wwdc2022-10032 `29:12` / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)

### T10. ⭐ 一番効いた落とし穴: `AppShortcutsProvider` は SPM パッケージに置けない

- **見せるもの**: 比較表をそのまま出す

| キー | パッケージ `TodoAppIntents.appintents` | アプリ `IntentTodo.app/Metadata.appintents` |
|------|--------------------------------------|--------------------------------------------|
| `actions`（Intent） | 20 | 20 ✅ 集約される |
| `entities` | 3 | 3 ✅ 集約される |
| `queries` | 3 | 3 ✅ 集約される |
| **`autoShortcuts`（AppShortcut）** | **8** | **0 ❌ 集約されない** |

- **話の要点**:
  - 症状: **Siri / Shortcuts アプリ / Spotlight に App Shortcut が一切出てこない。ビルドも実行もエラーなし**
  - 原因: `actions` / `entities` / `queries` は依存パッケージからアプリの統合メタデータへ集約されるが、**`autoShortcuts` だけ集約されない**
  - システムが読むのはアプリバンドル内の統合メタデータ 1 つだけ。そこが `0` なら「存在しない」のと同じ
  - **`AppShortcutsProvider` をアプリターゲット直下に移すと 0 → 8 になる**。Intent 本体はパッケージのまま（`public`）で、`import TodoAppIntents` して参照するだけ
  - `XcodeRefreshCodeIssuesInFile` でも通常ビルドでも**一切露見しない**タイプ。App Shortcuts を触ったらメタデータの件数を直接見るのが唯一確実
  - ⚠️ 「アプリあたり 1 つまで」と明文化された Apple のリファレンス記述は見つけられていない。実機観測ベースの知見として話す
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「`AppShortcutsProvider` は SPM パッケージに置いてはいけない」/ [../devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

### T11. `AppIntentsPackage` / `includedPackages` は「全ターゲットに書く」

- **見せるもの**: パッケージ側 1 個 + 利用側 4 ターゲット（App / Widget / LiveActivity / WatchApp）に 1 個ずつ、の図
- **話の要点**:
  - パッケージ側に `AppIntentsPackage` を 1 つ宣言する（公式パターン）
  - さらに **利用側の各ターゲットでも `includedPackages` 付きで宣言する**
    > "You must register each target as an App Intents Package to ensure proper indexing and validation."（wwdc2025-244 `23:29`–`24:00`）
  - **一度これを外していた**。「アプリ側にも宣言すると Shortcuts のルーティングが壊れる」と思っていたため
  - 2026-08-12 に再検証して採用に切り替えた根拠 3 点:
    1. 全バンドルの `Metadata.appintents` の件数が宣言の有無で**完全一致**（DerivedData を消したクリーンビルドでも `actions` 23 = intent 型数 23、重複なし）
    2. 宣言した状態で **AppIntentsTesting が全グリーン**（Siri / Shortcuts / Spotlight と同じインフラを通る）
    3. **Shortcuts アプリで実機確認**（アクション一覧・パラメータ表示が壊れていない）
  - 残る未確認は **App Shortcut の「フレーズ」ルーティング（Siri）だけ**。AppIntentsTesting は型名で intent を引くのでフレーズ経路を構造上通らない
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「パッケージ内での定義」/ [../devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)

### T12. App Shortcut の枠は 10 件。設計上の意思決定になる

- **見せるもの**: 8/10 のゲージ + 節約テクニック 2 つ
- **話の要点**:
  - `appShortcuts` の上限は **10 件**（アプリ全体のフレーズ総数は 1,000 件）。本プロジェクトは 8 件で運用し、枠 2 件分を意識的に空けている
  - 節約の型:
    - **パラメータ違いは 1 件にまとめる**。`ShowTodosIntent` は `filter` を受けて `Show my todos / Show incomplete todos / Show favorite todos` を 1 枠に収める
    - **「開くだけ」は登録しない**（`LaunchAppIntent`）。ウィジェット / コントロールから呼べば足りる
    - **system intent（`OpenIntent` / `DeleteIntent`）は登録不要**。AppShortcut 無しでも意味解釈される
  - **フレーズに埋め込めるのは `AppEntity` と `AppEnum` だけ**。`String` パラメータは埋め込めない（コンパイルエラー）。文字列を取りたいなら Siri に後から聞かせる
  - ⚠️ この String 制限は公式リファレンスに明記を見つけられていない（コンパイラ挙動からの観測）。SDK メジャー更新時は再確認する
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「10 件上限と設計指針」「フレーズのパラメータ型制限」

---

## 第3部 制約B: プロセス — どこで perform されるのか

### T13. `supportedModes` は「実行プロセス」を決めない

- **見せるもの**: よくある誤解 → 実際、の 2 段
- **話の要点**:
  - 誤解: 「`.background` にしたから Extension で走る / `.foreground` だからアプリで走る」
  - 実際: **`supportedModes` は「フォアグラウンド遷移するか」だけを決める**。実行プロセスは固定しない
  - Intent / Entity / Query が複数ターゲットにリンクされた共有パッケージにあると、システムは**ヒューリスティクス**で選ぶ（アプリ起動中ならアプリ優先、未起動なら Extension を起動）
  - 固定したければ **`allowedExecutionTargets`**（`.main` / `.appIntentsExtension` / `.widgetKitExtension`）で明示する
- **出典**: [WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) `15:59`–`16:55` / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)

### T14. だから `@Dependency` はプロセスごとに登録が要る

- **見せるもの**: 表をそのまま出す

| 呼出元 / モード | 実行プロセス | 登録場所 |
|---|---|---|
| Siri / Shortcuts / UI の `Button(intent:)` | メインアプリ | `App.init()` |
| Widget `Button(intent:)` + `.foreground(.immediate)` | メインアプリ | `App.init()` |
| Widget / ControlWidget + `.background`（`allowedExecutionTargets` 未指定） | **ヒューリスティクス** | **両方**（`App.init()` と `WidgetBundle.init()`、保険） |
| 同上（`allowedExecutionTargets` 明示） | 指定先に固定 | 指定先のみ |
| Live Activity のボタン | メインアプリ（`perform()` は公式保証。entity 事前解決も iOS 27 実測でアプリ） | `App.init()` |

- **話の要点**:
  - `AppDependencyManager.shared` は**プロセスごとに独立したインスタンス**
  - 本プロジェクトは大半の Widget/Control Intent で `allowedExecutionTargets` を未指定にしているため、**二重登録は撤廃できない**。`CompleteTodosIntent` だけ `[.main]` 固定
  - **登録は同期で**。`App.init()` の中で `Task { @MainActor in ... }` に入れると、`perform()` が Task 完了を待たずに走って `@Dependency` 解決に失敗しうる
  - Live Activity は例外的に楽: `LiveActivityIntent` は `perform()` がアプリプロセスであることが公式保証。加えて **entity の事前解決も iOS 27 実測ではアプリプロセス**（cold start でも同じ）なので、LA Extension 側の登録は不要
  - ただしこれは **LA ボタン経由に限った話**。**Widget のタイムライン描画では `entities(for:)` が Widget Extension で走る**のを同じログ収集で観測している
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「実行プロセスごとに登録が必要」/ [../insights/07-platform-specific.md](../insights/07-platform-specific.md)

### T15. `Button(intent:)` を使う。`perform()` を直接呼ばない

- **見せるもの**: ❌ / ✅ のコード 2 枚
  ```swift
  // ❌ @Dependency が未解決のまま実行されてクラッシュ
  Button { Task { try? await AddTodoIntent(title: title).perform() } } label: { ... }

  // ✅ システム dispatch 経由にする
  Button(intent: AddTodoIntent(title: title)) { ... }
  ```
- **話の要点**:
  - `@Dependency` は **システムが dispatch した時にだけ** `AppDependencyManager` から解決される
  - 手で `perform()` を呼ぶと `@Dependency` がゼロ初期化状態のままで、`ModelContainer` を触った瞬間に落ちる
  - つまり **「Intent は関数ではない」**。呼び出しの外側にシステムの仕事がある（パラメータ解決 → entity 解決 → 依存注入 → perform → リロード）
  - 例外的にどうしても Intent 経路に乗せられないケース（ドラッグ並べ替えの確定など）は、**Intent と UI が同じ `TodoService` を呼ぶ**形にして二重実装を避ける
- **出典**: [../insights/04-ui-integration.md](../insights/04-ui-integration.md)「直接 `perform()` を呼ばない」

### T16. `AppEntity` は `@Dependency` を使えない（`EntityQuery` は使える）

- **見せるもの**: 使える / 使えないの対照表
- **話の要点**:
  - `@Dependency` は Apple 公式に「main app から **intent** へデータを渡すため」のもの。`AppEntity` に書くと `Unknown attribute 'Dependency'`
  - でも `@DeferredProperty` の getter からはデータが要る → **`TodoEntityStore`（`@MainActor enum` の static）にコンテナを登録**して参照する（Apple サンプルの ambient `modelData` パターン相当）
  - **`EntityQuery` と `IntentValueQuery` は `@Dependency` OK**（`_SupportsAppDependencies` に適合しているため）
  - ハマった形: **`@Dependency`（`AppDependencyManager`）と `TodoEntityStore` は別々の登録**。アプリ側だけ登録して満足すると、**Intent は動くのに snippet だけ空**（「Todo not found」を描く）という切り分けにくい症状になる
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「@ComputedProperty / @DeferredProperty」/ [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md)「Extension プロセスでも TodoEntityStore を登録する」

### T17. 小ネタ: プロパティマクロは `Hashable` の自動合成を壊す

- **見せるもの**: 1 行のエラー + 対処
- **話の要点**:
  - `@Property` / `@ComputedProperty` / `@DeferredProperty` は **非 `Hashable` な `EntityProperty` backing** を生成するので、`Hashable` / `Equatable` の自動合成が効かなくなる
  - → `==` と `hash(into:)` を明示実装する（id ベースの hash + スナップショット比較の等価）
  - 同種の話として、`@AppEntity(schema:)` などのマクロは `typeDisplayRepresentation` を生成するので手書きを消す必要がある。**マクロ付き宣言は `#if` で属性行と本体を分割できない**（`Expected '}' in struct`）ので、プラットフォーム分岐が必要なら型を 2 系統まるごと書く
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)

---

## 第4部 制約C: 呼出元 — 同じ Intent でも出るものが違う

### T18. ⭐ フィードバックのマトリクス

- **見せるもの**: 表をそのまま出す（このスライドが本発表の山）

| 呼出元 | `.result(dialog:)` | Snippet（`snippetIntent:`） | ローカル通知 |
|-------|------------------|---------------------------|------------|
| Siri | 読み上げ ✅ | 表示 ✅ | ✅ |
| Spotlight / Shortcuts | 結果欄に表示 ✅ | 表示 ✅ | ✅ |
| アプリ UI の `Button(intent:)` | 表示なし | 表示なし | ✅ |
| Widget の `Button(intent:)` | 表示なし | 表示なし | ✅ |
| **Control（`ControlWidgetButton` / `ControlWidgetToggle`）** | **表示なし** | **表示なし** | ✅ |

- **話の要点**:
  - 「dialog を返したのに何も出ない」は**バグではなく仕様**。ただしどこにもまとまって書いていない
  - Control の 2 つの「表示なし」は**実機確認済み**（dialog: 2026-04-14 / snippet: 2026-08-12）
  - 使い分けの結論:
    - **Control**: 成功のフィードバックは **`perform()` 完了時の自動リロードによるコントロール自身の再描画**。**失敗時だけローカル通知**（失敗すると前の状態のまま再描画されて「何も起きなかった」と区別できないため）
    - **Siri / Shortcuts 前提の Intent**: **Dialog + Snippet**。`IntentDialog(full:supporting:)` で音声単独用と視覚併用を出し分ける
    - **UI Button 中心の Intent**: dialog も通知も不要（UI が即座に反映する）
- **出典**: [../../CLAUDE.md](../../CLAUDE.md)「Dialog vs 通知の使い分け」/ [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md)

### T19. ⭐ どうやって「Control では snippet が出ない」を確定させたか

- **見せるもの**: 出典が割れている表 → 比較実験の表、の 2 段
- **話の要点**:
  - 公式の記述が**割れていた**:
    | 出典 | 示唆 |
    |---|---|
    | AppIntents [Visual presentation](https://developer.apple.com/documentation/AppIntents/visual-presentation) | "**Siri, Spotlight, and the Shortcuts app** display snippets" — Control は列挙されない |
    | wwdc2025-281 `0:29` | 同上（Spotlight / Siri / Shortcuts） |
    | **wwdc2025-275 `1:40`–`1:59`** | "**I'll tap on the control that runs an App Intent** […] the intent will show a snippet" — コントロールから出ているように見える |
  - **肯定リストは Control を明示的に除外していない**ので「列挙に無い＝出ない」とは読めない。実際この推論で**一度設計を誤った**
  - そこで **呼出元だけを変えて同じ Intent・同じ snippet を走らせた**:
    | 条件 | 結果 |
    |---|---|
    | Spotlight → `ShowTodoCountIntent`（→ `TodoSummarySnippetIntent`） | **出る** ✅ |
    | Control（Button）→ 同じ Intent・同じ snippet | **出ない** ❌ |
    | 同上 + `allowedExecutionTargets = [.main]`（プロセス固定） | **出ない** ❌ |
    | Control（Toggle / `SetValueIntent`）→ `TodoSnippetIntent` | **出ない** ❌ |
  - 残る差分は「**呼出元が Control であること**」だけ → 確定
  - 裏付け: Controls 専門の wwdc2024-10157 は snippet も dialog も一度も触れない。Snippets 専門の wwdc2025-281 は control / Control Center に一度も触れない。wwdc2025-275 は全編で "Control Center" / "controls" / "ControlWidget" を一度も使っていない（＝あの "the control" はアプリ内 UI のボタン）
- **出典**: [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md)「Control のフィードバック」/ [../devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md)

### T20. ⭐ `requestConfirmation` を含む Intent はアプリ内 `Button(intent:)` から呼べない

- **見せるもの**: 「削除ボタンを押しても、何も起きない。エラーも出ない」のスクショ or 図
- **話の要点**:
  - 応答する面が無いため **`LNPerformActionErrorCodeUnsupportedValueType` で失敗し、エラー表示も出ずに何も起きない**（2026-08-12 実測）
  - 実際に **詳細画面の削除ボタンが長期間まったく動いていなかった**
  - Siri / Shortcuts / AppIntentsTesting 経由なら**成功する**。だから **AppIntentsTesting では検出できない** → **UI テストが必要**
  - 対処: **確認は SwiftUI 側で取り、実行は確認なし版の Intent に渡す**
    | 経路 | 確認の取り方 | 実行する Intent |
    |---|---|---|
    | 詳細画面の削除ボタン | `.confirmationDialog` + `@State` | `DeleteTodoImmediatelyIntent` |
    | リストのスワイプ削除 | スワイプ操作自体が確認 | `DeleteTodoImmediatelyIntent` |
    | Siri / Shortcuts | Intent 内の `requestConfirmation` | `DeleteTodoIntent` |
  - 一般化: **対話（`requestConfirmation` / `requestChoice`）を伴う Intent は Siri / Shortcuts 専用**と考える
- **出典**: [../insights/04-ui-integration.md](../insights/04-ui-integration.md)「削除確認の現状」/ [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)

### T21. Control 設計の型（Button か Toggle か）

- **見せるもの**: Apple の線引き表 + `ToggleTodoControl` のコード
- **話の要点**:
  - 線引きは **「対象が固定されているか」**
    - `ControlWidgetButton`: 状態を持たない fire-and-forget（"Buttons don't have state"）
    - `ControlWidgetToggle`: 2 状態の切り替え。**`SetValueIntent where ValueType == Bool` が必須**
  - `isOn` は **provider が次のリロードで読み戻せる永続的な bool** でなければならない
    - だから「**最も緊急な Todo を完了する**」は Toggle にできない。完了させると provider が別の Todo を返して on 状態が永続しない
    - Toggle にするなら**対象を固定する**（`AppIntentControlConfiguration` + `ControlConfigurationIntent` でユーザーに選ばせる）。Apple のサンプルも全部「設定で選ばれた特定 entity」に対する操作
  - `SetValueIntent` の `value` はシステムが「**移った先の状態**」で埋める（"Don't set or manage the value parameter"）。だから **flip する `toggleCompletion` ではなく絶対値の `setCompletion`** を呼ぶ
  - 値の供給は `ControlValueProvider` に置く（body で直接 fetch しない）。**失敗時は `try?` で潰さず throw する** — `0` に潰すと「全部完了しました」という嘘を表示する
- **出典**: [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md) / wwdc2024-10157 `9:51`/`10:26`/`11:22`

---

## 第5部 制約D: プラットフォーム — `#if` の当て方

### T22. `#if canImport(X)` だけに頼ってはいけない

- **見せるもの**: ❌ / ✅ と、落ちるプラットフォームの表
- **話の要点**:
  - `canImport` は「**フレームワークが import できるか**」しか見ない。「**その API が当該プラットフォームで available か**」は見ない
  - 具体例 1: `VisualIntelligence` — visionOS **シミュレータ**では `canImport` が false（ビルド成功）、visionOS **実機 SDK** では true になって `.visualIntelligence.*` スキーマまでコンパイルされ**実機ビルドだけ落ちる**
  - 具体例 2: `_AppIntents_UIKit` — **watchOS では import できるが `UISceneAppIntent` 型が無い**（`UIScene` が unavailable）。`#if canImport(_AppIntents_UIKit)` 単独では watchOS が落ちる → `&& !os(watchOS)` が必要
  - 具体例 3: `onAppIntentExecution` / `TargetContentProvidingIntent` — `_AppIntents_SwiftUI.framework` は **macOS SDK にも存在する**（`canImport` は true）が、macOS スライスの `.swiftinterface` に宣言が無く、前提の `TargetContentProvidingIntent` が `@available(macOS, unavailable)`。**正しい判定軸は `os(...)`**
  - 教訓: **シミュレータのビルド成功を「その OS で通る」根拠にしない**。アーカイブは実機 SDK でビルドする
- **出典**: [../insights/07-platform-specific.md](../insights/07-platform-specific.md)「`#if canImport(X)` だけに頼らない」/ [../insights/04-ui-integration.md](../insights/04-ui-integration.md)

### T23. 「複数 destination をフルビルドしないと分からない」差分がある

- **見せるもの**: 「iOS だけ緑 → watchOS で赤」の例 3 つ
- **話の要点**:
  - `@Property(indexingKey:)` の overload は **iOS / macOS でしか vend されない**。visionOS / watchOS では `Extra argument 'indexingKey'` でビルド失敗
  - `reminders` / `system` ドメインの assistant schema は **watchOS で unavailable**（Xcode 27 beta 2 で発生、beta 5 でも継続）。→ `CategoryAppEntity` / `TodoListType` は素の `AppEntity` / `AppEnum` にフォールバック、`ShowTodoSearchResultsIntent` は `#if !os(watchOS)` で丸ごと除外
  - Visual Intelligence の **openable 要件は macOS ビルドでだけコンパイルエラーになる**。visual search が返す entity は全部 `OpenIntent` を持っていなければならない（`@UnionValue` の全メンバ）。iOS シミュレータでは出ない
    - → `OpenCategoryIntent` を「**openable にすること自体が目的**」で新設した（perform は `navigateToRoot()` だけ）
  - **`XcodeRefreshCodeIssuesInFile`（iOS コンテキスト）は通る**。entity 系を触ったら iOS / macOS / visionOS / watchOS をフルビルドする
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「Phase 7」「macOS 対応」/ [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md)

### T24. プラットフォームガードの指針（1 枚表）

- **見せるもの**: 表をそのまま出す

| 条件 | 用途 | 代表例 |
|------|------|--------|
| `#if os(iOS) \|\| os(visionOS)` | UIKit 依存 | `@UIApplicationDelegateAdaptor`, `TargetContentProvidingIntent` 準拠 |
| `#if os(macOS)` | AppKit 依存 | `@NSApplicationDelegateAdaptor` |
| `#if os(iOS)` | ActivityKit | `Activity<...>.request`, `LiveActivityIntent` 準拠 |
| `#if !os(visionOS)` | visionOS 非対応 API | `ControlWidget`, `ControlWidgetButton`, `ControlCenter` |
| `#if os(watchOS)` | watchOS 専用 | Complication 関連 |
| `#if canImport(X) && !os(...)` | フレームワークは存在するが API が非対応 | `VisualIntelligence`, `_AppIntents_UIKit` |

- **話の要点**:
  - `if #available(iOS 18.0, *)` は**実行時**のバージョンチェック。**コンパイル時に型が無い問題は解決できない**。プラットフォーム非対応 API には `#if` が必須
  - 機能が Intent + Query の対で構成される場合、**ガードは全ファイルで揃える**（片方だけ外すと相互参照が dangling する）
- **出典**: [../insights/07-platform-specific.md](../insights/07-platform-specific.md)「プラットフォームガードの指針」

---

## 第6部 検証

### T25. AppIntentsTesting（2026 / iOS 27）— Intent を実経路でテストする

- **見せるもの**: テストコード 1 枚
  ```swift
  let definitions = IntentDefinitions(bundleIdentifier: "dev.touyou.IntentTodo")
  try await definitions.intents["AddTodoIntent"].makeIntent(title: "…").run()
  let matches = try await definitions.entities["TodoAppEntity"].entities(matching: "…")
  ```
- **話の要点**:
  - **UI テストバンドル必須**。unit test では動かない（intent を**ライブのアプリプロセス**で実行するため）。SPM の Testing パッケージでも不可
  - 型消去 API。**型名の文字列**でキーする（コンパイル時チェックなし）→ **誤りの多くは実行時に出る**。テストは「一意タイトルで作成 → 操作 → 削除」の自己クリーンアップ設計にする
  - 本プロジェクトは既存の UI テストターゲットに追加して **22 テスト**（実行系 10 / query 系 8 / システム統合 4）
  - ⚠️ 前提: **テストランナーとアプリの development team（署名）が一致していないと動かない**（wwdc2026-295 `2:54`）。CI や複数 Apple ID 環境で原因不明の失敗になりやすい
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「Phase 6: テスト基盤」/ Apple 公式 [Testing your App Intents code](https://developer.apple.com/documentation/AppIntentsTesting/testing-your-app-intents-code)

### T26. AppIntentsTesting の落とし穴（実 run して分かったもの）

- **見せるもの**: 箇条書き（各 1 行、症状 → 対処）
- **話の要点**:
  - **dynamic member lookup で見えるのは `@Property` だけ**。`entity.id` は `castingFailed(elementType: "NSNull", …)` になる（`TodoAppEntity.id` は `@Property` ではない）→ **`entity.identifier.instanceIdentifier`** を使う
  - **`setUp` で `app.launch()` を使わない。`app.activate()` にする**。`launch()` は起動中のアプリを terminate → 再起動するため、テストが増えるとシミュレータが散発的に落ちる（3 テストでは顕在化せず、10 に増やして毎回どれかが落ちた）
  - **アプリを入れ直した直後は待つ**。クリーンビルド後の最初のテストだけ `AppIntentsServicesMetadataErrorDomain Code=400 "<bundle id> is not present"` で落ちる。軽いクエリが通るまでポーリングする
  - **`makeIntent(x: nil)` は `.set(nil)` ではなく `.unset`**。「明示クリア」を出すには**型付きの nil** を渡す（`let explicitNull: any IntentValueExpressing = String?.none`）。これを知らないと**アプリ側のバグに見える**（実際に一度誤診した）
  - **Spotlight の index は Intent の完了と非同期**。`spotlightQuery()` はタイムアウト付きでポーリングする
  - **`IntentValueQuery`（Visual Intelligence）は iOS シミュレータでテストできない**。`VisualIntelligence.framework` が Simulator SDK に無く、`canImport` が false でビルドから除外されるため
  - **`requestChoice` / `requestConfirmation` を使う Intent は run できない**（応答する相手が居ない）→ 対話しない固定版を別 Intent で持っておくとそちらはテストできる
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「実行して分かった落とし穴」

### T27. Apple が示す「検証の梯子」と、自動化の限界

- **見せるもの**: 4 段の梯子図 + 「4 段目は自動化できない」
- **話の要点**:
  - wwdc2026-240 `24:13`–`25:57` が progressive validation として順序を明示:
    1. **AppIntentsTesting** — ビジネスロジックを分離して検証（"entirely in isolation. **No Siri involved.**"）
    2. **Shortcuts アプリ** — intent の形（パラメータ / parameter summary）
    3. **Spotlight** — コンテンツの index
    4. **Siri** — 自然言語・entity 解決・onscreen・cross-app の end-to-end
  - **4 は自動化できない**。wwdc2026-295 `24:46` も "be sure to test your intents **manually** with Siri and the Shortcuts app" と明示。`AppIntentsTesting` の公開 API に `shortcut` / `phrase` / `siri` / `utterance` に相当するシンボルは 1 つも無い（swiftinterface 全文検索で 0 件）
  - **テストに寄せられる観点は積極的に寄せる**（落ちても他のテストでは捕まらないもの優先）:
    | 観点 | API | 落ちたときの症状 |
    |---|---|---|
    | entity の id 解決 | `entities(identifiers:)` | Live Activity / Widget のボタンが無反応 |
    | `allEntities()` | 同 | Shortcuts の一覧が空になる |
    | `suggestedEntities()` | 同 | パラメータ picker に何も出ない |
    | Spotlight index | `spotlightQuery(_:)` | 検索・Siri から消えるだけで他は正常に見える |
    | Onscreen entity | `viewAnnotations()` | Siri が画面上の対象を認識しない |
    | 部分更新の三状態 | `valueState` | Shortcuts で項目を消せなくなる |
  - **⚠️ 条件付き assert を書かない**。`if element.waitForExistence(...) { XCTAssert… }` は要素が見つからないと中身が一度も実行されず**緑になる**。実際にこの形で「削除がまったく動いていない」のを長期間見逃した
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「検証の梯子」/ [../devlog/06-control-widget-ios26.md](../devlog/06-control-widget-ios26.md) / [../../CLAUDE.md](../../CLAUDE.md) テスト方針

---

## 第7部 調査のコツ（一番持ち帰ってほしいところ）

### T28. ⭐ 「呼出元だけを変えて同じ Intent を走らせる」

- **見せるもの**: 良い実験 / 悪い実験の対比
- **話の要点**:
  - App Intents は **同じコードが、呼出元・プロセス・プラットフォームによって違う振る舞いをする**フレームワーク
  - だから **変数を 1 つだけ動かした比較**が最短で確定する。「Spotlight から呼ぶと出る / Control から呼ぶと出ない」で終わり
  - 逆にダメだったやり方:
    - **公式ドキュメントの肯定リストからの推論**（「列挙されていない＝非対応」）→ 一度これで設計を誤った
    - **複数の変数を同時に動かす実験**（プロセスも Intent の形も実装も変える）→ いつまでも確定しない
  - もう 1 つの型: **メタデータを直接見る**（`autoShortcuts` の件数）。「動いていない」の原因を推測せず、システムが読む JSON を見る
- **出典**: [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md)「教訓」/ [../devlog/](../devlog/README.md)

### T29. ⭐ 「プラットフォーム限定」「これは無理」は当時の SDK 制約かもしれない

- **見せるもの**: 撤去したワークアラウンド 3 つ
- **話の要点**:
  - 実際に**前提が消えていた**もの:
    - `TodoAppEntity` パラメータの Live Activity 経由 crash → **iOS 27 で再現せず**。FromExtension 分離を撤去（Intent 2 個削減）
    - `VisualIntelligence` が iOS 限定 → **Xcode 27 beta 2 で macOS に import 可能に**。`OpenCategoryIntent` を足して Mac 対応
    - `IntentTodoUITest` が synchronized folder ではない → **現在はなっている**。ファイルを置けばターゲットに入る
  - 運用ルール:
    - **回避策にはコミット/日付と「何を確認したら外せるか」を書いて残す**（本プロジェクトは `docs/devlog/` に経緯を分離している）
    - **SDK メジャー更新時に `#if` ガードを外して、本当に不可能かを実ビルドで確かめる**
    - 逆向きの注意: **ベータ SDK 追従のコストは実在する**。beta 1〜5 で `.reminders` 有効化 → watchOS で unavailable 化 → `PlaceDescriptor` の SSU バグ回避 → …と、4 年で非推奨 7 個 + ベータごとの追従
- **出典**: [../devlog/2026-08-11-constraint-recheck.md](../devlog/2026-08-11-constraint-recheck.md) / [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md)「Xcode 27 beta ごとの変更追跡」

---

## 第8部 総括

### T30. やって分かったこと（効能と代償）

- **見せるもの**: 2 列の表
- **話の要点**:

| 効能 | 代償 |
|------|------|
| プラットフォームを増やすコストが View だけになる | 「どこで実行されるか」を常に意識する必要がある |
| Siri / Shortcuts / Spotlight / コントロールが「ついで」で終わる | 呼出元ごとに**出るもの / 出ないもの**が違い、公式にまとまっていない |
| ロジックの二重実装がゼロになる | 対話を伴う Intent は UI から呼べず、結局 2 本用意する場所がある |
| デザイン（ユースケース）と実装（Entity-Intent）が写像する | メタデータ抽出は**静かに失敗する**。件数を直接見る運用が要る |
| 将来の出口に自動で乗る | 毎年 API が変わる。ベータ追従コストは実在する |

  - 結論の言い方:
    - **App Intents 中心設計は「Siri 対応のため」ではなく「アプリの機能をどこからでも呼べる形に保つため」**
    - **一番の学びは API ではなく検証の作法**。ビルドが通っても、テストが緑でも、動いていないことがある。**呼出元を 1 つだけ変えて比べる / システムが読むメタデータを直接見る / 回避策には期限を書く**
  - 適合しなかったもの（正直に言う）:
    - **`RelevantEntities`**: todo / reminders 向けの `AppEntityContext` が存在せず適合不能
    - **コア entity の `.reminders.reminder` スキーマ適合**: `list` が非 optional / `dueDate` が `DateComponents` / `locationTrigger` が `PlaceDescriptor` を強制して SSU training バグに正面衝突。**SDK 修正待ちで着手不可**と確定。ただし **list 適合 + 自前 Intent 群で新 Siri 連携自体は成立する**
    - **意図的不使用**: `DynamicOptionsProvider` / `IntentParameterDependency`（パラメータ間の動的依存が起きるユースケースが無い）、`UndoableIntent`（将来評価）
- **出典**: [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md) / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md) / [../../CLAUDE.md](../../CLAUDE.md)

---

## 発表前チェックリスト

- [ ] T01 の数字（Intent 24 / 型 23 / Entity 4 / Query 4 / AppShortcut 8）を発表直前のコードで再カウント
- [ ] T10 の件数（20 / 3 / 3 / 8→0）は当時の実測値。**現在は Intent 23 / Entity 4 / Query 4** なので「当時の実測」と断って出す
- [ ] T12 の「フレーズに String 不可」/ T10 の「アプリあたり 1 つ」は一次ソース未確認。**観測ベースと明言する**
- [ ] T19 / T20 / T08 の実測は iOS 27 / Xcode 27 beta 5 時点。**SDK が上がっていたら再確認**
- [ ] T25 の 22 テストが今も緑か（`RunAllTests` or `RunSomeTests`）
- [ ] スクショ類（Control Center の 2 / 1、削除ボタンが無反応、Snippet）を撮り直す
- [ ] 骨子① の S24 から続ける前提。単独発表するなら T01 の前に「App Intents とは」1 枚を足す
