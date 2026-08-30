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
第1部  設計の芯      T05–T08  1アクション1Intent / 唯一の実行経路 / ロジックの置き場 / 従来の層との対比(T07b)
第2部  制約A メタデータ T09–T12  ビルドは通るのに機能しない
第3部  制約B プロセス   T13–T17  どこで perform されるのか問題
第4部  制約C 呼出元     T18–T21  同じ Intent でも出るものが違う
第5部  制約D プラットフォーム T22–T24  #if の当て方を間違える
第6部  検証           T25–T27  AppIntentsTesting と検証の梯子
第7部  調査のコツ      T28–T29  どうやって確定させるか（一番持ち帰ってほしい）
第8部  総括           T30      効能と代償
```

> **`b` 付きの ID は後から足したもの**。既存の ID を動かさないために枝番にしてある。
> T12b / T21b / T29b は 2026-08-21 追加（実測ネタ）、**T07b は 2026-08-25 追加**（Layered / Clean Architecture との対比）。
> 最終構成では既存カードと差し替える判断もありうる。

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

---

### T02. 「Intent 中心」をどこまで徹底したか

- **見せるもの**: 依存図。`Domain → Repository → TodoAppIntents → (UI / WidgetUI / WatchUI / LiveActivity)`
- **話の要点**:
  - **UseCase 層をパッケージとして作らなかった**。宣言は Intent、実装は `TodoService`（詳しい対応は T07b）
  - **UI からのアクションは必ず `Button(intent:)`**。ViewModel はフィルタ・ソート・検索テキストといった**表示状態だけ**持つ
  - Extension ターゲット（Widget / LiveActivity / Watch App）は **`@main` と宣言だけ**。View も状態管理も SPM に置く（プレビューとテストのため）
  - この徹底が効いた部分と、代償になった部分の両方を今日話す
- **出典**: [../../CLAUDE.md](../../CLAUDE.md) / [../insights/01-swift-package-design.md](../insights/01-swift-package-design.md)

---

### T03. 効いたこと（先に結論）

- **見せるもの**: 3 つの「増やさずに済んだ」
- **話の要点**:
  1. **プラットフォームを増やすコストが低い**。watchOS を足すとき、書いたのは View だけ。アクションは既にある
  2. **Siri / Shortcuts / Spotlight / コントロール対応が「ついでに終わる」**。個別対応をしていない
  3. **ロジックの二重実装がゼロ**。ウィジェットのチェックボックスと Siri の「完了にして」が**同じ 1 つの Intent**
- **出典**: 実装実績

---

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

---

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

---

### T07. ロジックは Intent ではなく Service に集約した

- **見せるもの**: `Intent（薄い） → TodoService（@MainActor final class） → Repository（protocol）`
- **話の要点**:
  - 当初は Intent の `perform()` にロジックを書いていた。**24 個に増えると同じ処理が散る**
  - `TodoService`（`@MainActor final class`）に集約し、Intent は `@Dependency var todoService` で参照するだけにした
  - 副作用: **`WidgetReloader.reloadAllWidgets()` を Service 側の `defer` で呼ぶ**ようにできた。Intent 側で呼び忘れる余地が消えた
  - `WidgetReloader` は `WidgetCenter.reloadAllTimelines()` と **`ControlCenter.reloadAllControls()` の両方**を呼ぶ。⚠️ ここは実際にバグった（次スライド）
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「共通ロジックは TodoService に集約」

---

### T07b. ⭐ 「UseCase 層を廃止した」は説明として間違っている（Clean Architecture との対比）

> 2026-08-25 追加。T07 の直後に置くと「じゃあ従来の層とどう対応するの？」に先回りできる。
> 骨子① / 99-script の「レイヤードアーキテクチャ」節と同じ話なので、単独発表なら片方だけでよい。

- **見せるもの**: 同心円が破綻している図 → 砂時計（bowtie）図、の 2 段
- **話の要点**:
  - よく聞かれるのが **「UseCase と Repository の使い分けが、図にすると綺麗に退避できないのでは？」**。これは正しい直感で、原因は**説明の言葉**のほう
  - Clean / Layered の同心円が成立しているのは、レイヤーが **1 本の軸（依存方向 = 抽象 ← 具体）だけ**で切られているから。App Intents 中心設計は**別の軸（誰が呼ぶか）**を持ち込むので、2 軸を同心円 1 枚に押し込もうとして破綻する
  - 実際 `AppIntent` は Clean Architecture の語彙で **3 役を同時に**やっている:
    - **Controller**（`@Parameter` / `EntityQuery` による解決 / 曖昧性解消）
    - **Presenter**（`IntentDialog` / Snippet / `DisplayRepresentation`）
    - **UseCase の入力ポート**（名前と signature = ユースケースの同一性）
  - そして **UseCase の「本体」だけが `AppIntent` に入っていない**。それが `TodoService`
  - → **言い直し: 「UseCase 層を廃止した」ではなく「UseCase の宣言が Intent に、実装が Service に分かれた」**。`Packages/` に `UseCase/` が無いのは層が消えたからではなく、宣言が `Intents/`、実装が `Services/TodoService.swift` に同居しているから
  - **対応表**（1 枚で出す）:

    | Clean Architecture | 本プロジェクト |
    |---|---|
    | Entity | `Domain`（`@Model`） |
    | UseCase の**宣言** | `AppIntent` 型 + `@Parameter` |
    | UseCase の**実装** | `TodoService` のメソッド |
    | Controller | `perform()` 前半 + `EntityQuery` |
    | Presenter / ViewModel | `IntentDialog` / Snippet / SwiftUI View |
    | Gateway | `TodoRepositoryProtocol` |
    | DB / Framework | `SwiftDataTodoRepository` |

  - **図は同心円ではなく砂時計にする**。くびれが `Intent + Entity`。この形にすると同心円で言えなかった 2 つが言える:
    - **UI は特権的な最上層ではなく、Siri と対等な呼出面の一つ**（`Button(intent:)` 必須の理由が図から出る）
    - **呼出面ごとに能力が違う**（T18 のマトリクスがここに接続する）。同心円だと「外側は全部同じ Presentation」に見えて、この差が図から消える
  - **「UseCase と Repository の使い分け」を納得させるコツ**: 素通しの例（`createTodo()` → `repository.create()`）を出すと「なぜ 2 段？」で終わる。**差が出る実例**を出す:

    | Service にあって Repository に置けないもの | 理由 |
    |---|---|
    | `toggleMostUrgentTodo()` | fetch + mutate の 2 呼び出しが、ユーザーには **1 行為** |
    | `snapshot()` / `restore()` | 「**同じ id で**戻す」という undo の不変条件。Repository は id の意味論を知らない |
    | `dataDidChange()`（Widget reload + AppShortcut パラメータ更新） | **「1 行為が完了した」ことを知っているのは UseCase 層だけ**。Repository の `update()` は自分が行為の途中か終端か判別できない |

  - ⭐ **Clean Architecture と本質的に反転している 2 点**（ここが対比の山）:
    1. **凍る方向が逆**。Clean は「内側 = 安定、外側 = 揺れる詳細」。App Intents 中心では **外周の Intent 型名 / parameter 名 / `AppEnum` の raw value がユーザーのショートカットに永続化されていて最もリファクタできない**。内側の `TodoService` のほうが自由に触れる
    2. **依存逆転の目的が違う**。「DB を差し替えられる」はほぼ使われない口実だが、ここでは `TodoRepositoryProtocol` が **プロセス境界**で効く（`allowedExecutionTargets` / Widget Extension とメインアプリで同じロジックが別プロセスに載る → T14 に接続）
  - **正直に言う非対称**: `EntityQuery` 系の**読み取りは `TodoService` も Repository も飛ばして**ストアに直通している。実態は **書き込み側だけ層が厚い CQRS 的な形**。理由は「読み取り系は実行先を固定せず Extension で応答させたい（アプリ起動コストを避ける）」。**同心円 1 枚だとこの線が引けない**のも砂時計にする理由
- **出典**: [../APP_INTENT_DRIVEN_DESIGN.md](../APP_INTENT_DRIVEN_DESIGN.md#layered--clean-architecture-との対比) / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md) / リポジトリ実体（`TodoService` 494 行 / `TodoRepositoryProtocol`）

---

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

---

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

---

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

---

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

### T12b. もう 1 つのメタデータ: Spotlight の属性を二重に書くと、本文だけが静かに入れ替わる

> 2026-08-21 追加。第2部の主題（ビルドは通るのに機能しない）に最も素直に当てはまる例なので、
> T10 の代替カードとしても使える。

- **見せるもの**: 同じ entity の 2 つの宣言を並べて、`contentDescription` の矢印が衝突している図
- **話の要点**:
  - Spotlight に entity を載せる口は 2 つあり、**別の場所に書く**:
    - `@Property(title:indexingKey: \.contentDescription)` — 宣言的にセマンティックインデックスへ（意味ベース検索・Q&A の対象）
    - `IndexedEntity.attributeSet` — `CSSearchableItemAttributeSet` を手で組む
  - 公式ドキュメントは「両方使える（`indexingKey` は attribute set を置き換えるのではなく追加する）」と読めるが、**同じキーを両方から書いたときどちらが勝つかは書いていない**
  - 実際にやっていたこと: `todoDescription` を `indexingKey: \.contentDescription` に載せつつ、`attributeSet` で `contentDescription = isCompleted ? "Completed" : "Incomplete"` を代入していた
  - 症状: **ビルドは通る。Spotlight にも出る。検索でも見つかる。** でも**セマンティック検索に載せたかった本文が完了ステータスの固定文に置き換わりうる**。「動いている」ように見える範囲が広いぶん、T10 より気づきにくい
  - 対処: `attributeSet` には **`indexingKey:` が受け持たないキーだけ**を書く（`dueDate` / `keywords` / `displayName`）。状態は `keywords` で表現する。`displayName` は `.title` とは別キーなので衝突しない
  - **話のオチ**: 「App Intents の落とし穴は `Metadata.appintents` だけじゃなかった。**"宣言的な口" と "手で組む口" が同じ場所を指したとき、どちらが勝つかは誰も教えてくれない**」
  - ⭐ **オチの強化（2026-08-22 / Group Lab #8011 `27:24`）**: Apple 自身がこの面倒さを認識していて、
    **「Spotlight を触ったことがあれば indexing key の面倒さを知っているはず。"本のタイトルは display name"
    のような対応付けは、app schemas なら全部やってある」**と言っている。開発者は
    **「entity を定義し、スキーマに適合させ、プロパティに値を入れるだけ」**でよい、と
    → つまり **T12b でハマったのは、まさにスキーマが肩代わりしてくれる領域を手で書いていたから**。
      「**肩代わりされる側に居なかったので、自分でキーの衝突を踏んだ**」という言い方ができる
    - **`IndexedEntity` とスキーマは対立ではなく相補的**とも明言（`27:24`）。
      スキーマ = コンテンツの**形**を定義 / `IndexedEntity` = それを**セマンティックインデックスに載せる**。
      **両方やって初めて最良の Siri AI 体験になる**
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「Phase 9」/ [../devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)（2026-08-21）

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

---

### T14. だから `@Dependency` はプロセスごとに登録が要る

- **見せるもの**: 表をそのまま出す

| 呼出元 / モード | 実行プロセス | 登録場所 |
|---|---|---|
| Siri / Shortcuts / UI の `Button(intent:)` | メインアプリ | `App.init()` |
| Widget `Button(intent:)` + `.foreground(.immediate)` | メインアプリ | `App.init()` |
| Widget / ControlWidget + `.background`（`allowedExecutionTargets` 未指定 = **読み取り系**） | **ヒューリスティクス** | **両方**（`App.init()` と `WidgetBundle.init()`） |
| **`.background` + `allowedExecutionTargets = [.main]`（書き込み系はすべてこれ）** | メインアプリに固定 | `App.init()` のみ |
| Live Activity のボタン | メインアプリ（`perform()` は公式保証。entity 事前解決も iOS 27 実測でアプリ） | `App.init()` |

- **話の要点**:
  - `AppDependencyManager.shared` は**プロセスごとに独立したインスタンス**
  - **本プロジェクトの現在のルール: SwiftData を書き換える Intent は必ず `allowedExecutionTargets = [.main]` を宣言する**。共有パッケージが Widget Extension にもリンクされているので、未指定だとアプリ未起動時に **Extension プロセスが同じストアの書き手になり得る**（wwdc2026-345 `16:30` が名指しで避けている構成）。現在 **13 Intent が `[.main]` 固定**
  - **読み取り系は逆に固定しない**。アプリを起こさず Extension で応答できるほうが速い
  - **宣言漏れはテストで検出する** — `Packages/TodoAppIntents/Tests/TodoAppIntentsTests/IntentExecutionTargetsTests.swift`。T13 の「プロセスはヒューリスティクスで決まる」に対する**運用解がこれ**
  - したがって二重登録（`App.init()` と `WidgetBundle.init()`）は**撤廃ではなく役割分離**になった。Widget 側の `TodoService` 登録は**読み取り系 Intent・entity 解決・snippet 描画のためだけ**に残っている
  - **登録は同期で**。`App.init()` の中で `Task { @MainActor in ... }` に入れると、`perform()` が Task 完了を待たずに走って `@Dependency` 解決に失敗しうる
  - Live Activity は例外的に楽: `LiveActivityIntent` は `perform()` がアプリプロセスであることが公式保証。加えて **entity の事前解決も iOS 27 実測ではアプリプロセス**（cold start でも同じ）なので、LA Extension 側の登録は不要
  - ただしこれは **LA ボタン経由に限った話**。**Widget のタイムライン描画では `entities(for:)` が Widget Extension で走る**のを同じログ収集で観測している
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「実行プロセスごとに登録が必要」/ [../insights/07-platform-specific.md](../insights/07-platform-specific.md)

---

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

---

### T16. `AppEntity` は `@Dependency` を使えない（`EntityQuery` は使える）

- **見せるもの**: 使える / 使えないの対照表
- **話の要点**:
  - `@Dependency` は Apple 公式に「main app から **intent** へデータを渡すため」のもの。`AppEntity` に書くと `Unknown attribute 'Dependency'`
  - でも `@DeferredProperty` の getter からはデータが要る → **`TodoEntityStore`（`@MainActor enum` の static）にコンテナを登録**して参照する（Apple サンプルの ambient `modelData` パターン相当）
  - **`EntityQuery` と `IntentValueQuery` は `@Dependency` OK**（`_SupportsAppDependencies` に適合しているため）
  - ハマった形: **`@Dependency`（`AppDependencyManager`）と `TodoEntityStore` は別々の登録**。アプリ側だけ登録して満足すると、**Intent は動くのに snippet だけ空**（「Todo not found」を描く）という切り分けにくい症状になる
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「@ComputedProperty / @DeferredProperty」/ [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md)「Extension プロセスでも TodoEntityStore を登録する」

---

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
  - ⭐ **`IntentDialog(full:supporting:)` は Apple が「あまり使われていない API」として名指しで推している**
    （Group Lab #8011 `36:14`）。理由も具体的: **AirPods 使用時は画面が無いのでもう少し饒舌に、
    iPad で snippet が綺麗に出るならテキストは短く**。→ **本プロジェクトの使い分けルールがこの助言と一致している**
    ので、「Apple があまり使われていないと言っている API を、必要に迫られて使っていた」という形で出せる
- **出典**: [../../CLAUDE.md](../../CLAUDE.md)「Dialog vs 通知の使い分け」/ [../insights/06-control-widget-ios26.md](../insights/06-control-widget-ios26.md)

---

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

---

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

---

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

### T21b. ⭐ 中心設計にしたせいで、公式ルールを原理的に満たせなくなった話（donation）

> 2026-08-21 追加。第4部の締めにも、T30 の「代償」列の 1 行にも使える。
> D-1 の ③（`requestConfirmation` が UI から呼べない）と**同じ形**の乖離なので、
> 「理想と現実の乖離」を 2 本立てにするなら対になる。

- **見せるもの**: 「公式ルール」「`perform()` から見える情報」「本アプリの UI」の 3 枚を並べて、真ん中が空白になっている図
- **話の要点**:
  - 公式ルールは**呼出元ベース**:
    > "Restrict your donations to direct interactions with your app's interface, and **not to interactions started by Siri or the Shortcuts app**."
    > — Apple 公式 [Donations and discovery](https://developer.apple.com/documentation/AppIntents/donations-and-discovery)
  - ところが **`perform()` は呼出元を判別できない**。`systemContext`（`IntentSystemContext`）が持つのは `currentMode` と `isVoiceOnly` だけで、invocation source に相当するプロパティが無い
  - つまり `perform()` の末尾で `donate()` を呼ぶと、**Siri / Shortcuts 起点の実行でも必ず走る** = 公式が「するな」と言っている donate をしてしまう。しかも**エラーにもならないので気づかない**（今回撤去するまで実際にそうなっていた）
  - **公式サンプルの回避策はどちらも「UI が Intent を通らない」前提**:

    | サンプル | 形 |
    |---|---|
    | CometCal | サービスメソッドに `donateIntent:` フラグ。UI 経路は既定 `true`、Intent 側が `false` を明示して抜ける |
    | CosmoTunes | UI のタップ地点から `DonationManager` 経由で donate（`perform()` の中では donate するなとコメントに明記） |
  - **本アプリは UI も `Button(intent:)`**（＝設計の核そのもの）。サービスに届く時点で必ず Intent 経由なので、**上のどちらもそのまま当てはまらない**
  - ⭐ **想定質問「Intent に donate 用のフラグを 1 個持たせて、UI から渡せばいいのでは？」への答え**（実際に出た質問）。これは**成立しない**。素のプロパティは Intent のシリアライズ面（`@Parameter`）に乗らないので実行プロセスに届かず、**アプリ内 `Button(intent:)` だけ通って Widget / Control で静かに落ちる**。`@Parameter` にすると今度は統合メタデータに乗るので **Siri / Shortcuts 側からそのフラグを立てられてしまい**、避けたかった違反が起こる（しかも保存済みショートカットに焼き付いて消せない）。そして根本的に、Apple のガイダンスは「呼出元で分岐せよ」ではなく**「`perform()` の中では donate するな」**（システムが自分の走らせた Intent を既に donate しているため二重計上）。つまり **donate は「呼出元を知っている層 = UI」に置くしかない**、という T21b の結論に戻ってくる
  - 現状の選択: **規約違反になる donate を消す**。結果として **UI タップ由来の donation はゼロ**になった（Siri の予測精度を捨てた）。戻す手段は `AppIntent.callAsFunction(donate:)` で一部の UI 経路だけ直接実行に変えること — つまり**「全部 `Button(intent:)`」を部分的にやめる**判断が要る
  - 一方 **`deleteDonations(matching:)` は呼出元に関係なく正しい**（消えた entity への提案を残さない後片付け）ので、削除経路には入れたまま
  - **代償の重さは 2026 で増した**: Group Lab（#8011 `21:47`）で Apple は **新しい intent donation を「Siri に影響を与える主要な手段」として押している**。ユーザーの操作を donate すると Siri が学習し、「いつもこのアプリでこの人に連絡する」を覚える。⚠️ つまり **中心設計を徹底すると、Apple が今年一番推している導線を 1 本落とすことになる**。ここは正直に言ったほうが誠実で、話も強い
    （出典: [03-group-lab-evidence.md](03-group-lab-evidence.md) B-1）
  - **話のオチ**: 「これは**バグではなく、設計を徹底したことの帰結**です。Apple のサンプルは 2 本とも "UI はサービスを直接呼ぶ" 前提で書かれている。つまり **App Intents 中心設計は Apple が想定している標準形ではない**。徹底するなら、こういう "公式ルールを書けない場所" が出てくることを引き受ける必要がある」
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「donation は『アプリ UI 起点の操作』だけ」/ [../devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)（2026-08-21）/ [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md)

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

---

### T23. 「複数 destination をフルビルドしないと分からない」差分がある

- **見せるもの**: 「iOS だけ緑 → watchOS で赤」の例 3 つ
- **話の要点**:
  - `@Property(indexingKey:)` の overload は **watchOS / tvOS で unavailable**。watchOS では `Extra argument 'indexingKey'` でビルド失敗（当初「iOS / macOS 限定」と記録していたが、visionOS では使えると 2026-08-28 に判明して有効化した）
  - `reminders` / `system` ドメインの assistant schema は **watchOS で unavailable**（Xcode 27 beta 2 で発生、beta 6 でも継続）。→ `CategoryAppEntity` / `TodoListType` は素の `AppEntity` / `AppEnum` にフォールバック、`ShowTodoSearchResultsIntent` は `#if !os(watchOS)` で丸ごと除外
  - Visual Intelligence の **openable 要件は macOS ビルドでだけコンパイルエラーになる**。visual search が返す entity は全部 `OpenIntent` を持っていなければならない（`@UnionValue` の全メンバ）。iOS シミュレータでは出ない
    - → `OpenCategoryIntent` を「**openable にすること自体が目的**」で新設した（perform は `navigateToRoot()` だけ）
  - **`XcodeRefreshCodeIssuesInFile`（iOS コンテキスト）は通る**。entity 系を触ったら iOS / macOS / visionOS / watchOS をフルビルドする
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「Phase 7」「macOS 対応」/ [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md)

---

### T24. プラットフォームガードの指針（1 枚表）

- **見せるもの**: 表をそのまま出す

| 条件 | 用途 | 代表例 |
|------|------|--------|
| `#if os(iOS)` と `os(visionOS)` の OR | UIKit 依存 | `@UIApplicationDelegateAdaptor`, `TargetContentProvidingIntent` 準拠 |
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
  - 本プロジェクトは既存の UI テストターゲットに追加して **23 テスト**（実行系 10 / query 系 8 / システム統合 5）
  - ⚠️ 前提: **テストランナーとアプリの development team（署名）が一致していないと動かない**（wwdc2026-295 `2:54`）。CI や複数 Apple ID 環境で原因不明の失敗になりやすい
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「Phase 6: テスト基盤」/ Apple 公式 [Testing your App Intents code](https://developer.apple.com/documentation/AppIntentsTesting/testing-your-app-intents-code)

---

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

---

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
  - **onscreen annotation は「画面ごとに」書く**。公式サンプル（CosmoTunes）は Now Playing / ライブラリの 4 セグメント / `Canvas` / タイマーカードと**面ごとに 6 本**持っている。annotation の形が面ごとに違い、独立に壊れるため。本アプリは詳細画面 1 本だけで、**リストのコレクション annotation は未テスト**
  - **`.appEntityIdentifier(forSelectionType:)` は `List` に付けたときだけ効く**。`ScrollView { VStack { ForEach } }` に付けても**黙って no-op**（アプリの見た目は 1 ピクセルも変わらない）。この形の面は行ごとの単一 `.appEntityIdentifier(_:)` に落とす。**「付け先が違うと静かに無効」という、この talk の主題そのままの例**
    - ⭐ **深刻さの格上げ（Group Lab #8011 `33:11`）**: Apple は **「画面上のコンテンツを理解して
      その文脈でアクションする」のを新しい Siri AI の 3 本柱のひとつ**と位置づけている
      （API は **既存の user activity + 新しい view annotations**）。体験の説明も
      「SwiftUI の View を作り、entity を持ち、結びつけて、喋ると思ったとおりに動く」と自信満々
      → **「柱と呼ばれている機能なのに、付け先を間違えると黙って no-op で、見た目は 1 ピクセルも変わらない」**
        という 1 行が作れる。⚠️ 3 本柱の残り 2 つはこの場で明示されていないので、**「3 本柱のひとつ」までにする**
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

---

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

### T29b. ⭐ 公式のサンプルコードを読む（散文は「合成のしかた」を書かない）

> 2026-08-21 追加。T28 / T29 と並ぶ 3 つ目の「調査の作法」。
> 実測ネタとして一番新しく、かつ**自分が間違っていた話**なので掴みは強い。

- **見せるもの**: 「読んだもの」と「それでも間違っていた数」の対比 1 枚
  - 読んでいたもの: WWDC の App Intents 関連セッション**全部**（2022〜2026、トランスクリプト全文）+ 公式ドキュメント + 1 年の実測（`docs/insights/` 7 トピック）
  - それでも**間違っていた箇所: 4**（WWDC 2026 の公式サンプル 4 本を読んだ結果）
- **話の要点**:
  - WWDC 2026 の App Intents 系サンプルは 4 本（session 240 / 295 / 343 / 344）:

    | サンプル | ドメイン |
    |---|---|
    | CometCal | カレンダー（`@AppEntity(schema: .calendar.*)`、AppIntentsTesting 一式）|
    | UnicornChat | メッセージ（`.messages.*`、通知への entity 付与）|
    | CosmoTunes | 音楽 + 時計（`.audio.*` / `.clock.*`、Spotlight、`UndoableIntent`、Now Playing）|
    | PhotosDomainExample | 写真（`.photos.*`）|
  - 出てきた誤り 4 件（**全部この talk の共通メッセージと同じ形**）:
    1. `perform()` の中で `donate()` を呼んでいた → 公式ルール違反（T21b）
    2. `attributeSet` と `indexingKey` で同じキーを書いていた → セマンティック検索の本文が入れ替わる（T12b）
    3. `LocalizedStringResource(stringLiteral: todo.title)` → **ランタイム値をローカライズキーにしていた**。毎回存在しないキーの引きが走り、String Catalog にも載らない。正しくは `"\(todo.title)"` の補間形式
    4. `entities(matching:)` の比較が `lowercased().contains()` → ロケール非依存。**かな / カナ、濁点、トルコ語の I が別文字扱い**。ユーザーが喋った / 打った文字列との比較なので `localizedStandardContains(_:)`
  - **なぜ散文では気づけなかったのか**（ここが持ち帰り）:
    - 公式ドキュメントは **1 シンボルずつ**説明する。「`indexingKey` は attribute set を置き換えず追加する」とは書いてあるが、**同じキーを両方から書いたらどうなるかは書いていない**
    - **合成のしかた（どれとどれを一緒に書いてよいか）はサンプルにしか書いていない**。しかもサンプルはコメントで理由まで書いている（例: 「Siri は subtitle を読み上げるので `"5:00"` のような位置指定表記は避ける」← ドキュメントのどこにも無い）
  - ⭐ **「サンプルを読む」は Apple 自身が案内している経路**（Group Lab #8011 `1:43`）:
    - **ドキュメントページに専用の sample セクションがある**。**セッションビデオに出てきたものはそこに載る**
    - 今年 App Intents は**セッション 5 本 + 複数のサンプルアプリ**を出し、**多くのセッションがそれを使っている**
    - **「今年ドキュメントに大きく投資した。API の説明だけでなく、どう使うか / ユーザーにどう役立つかを書いている」**
    - → **「サンプルを読め」は裏技ではなく公式の推奨経路。それでも自分は 4 箇所間違えていた**、という言い方にできる
  - **ただしサンプルは証拠であって権威ではない**。Apple 自身が非推奨 API を使っている（UnicornChat / PhotosDomainExample の `static let openAppWhenRun = true`。現行の綴りは `supportedModes`）。**合成のしかたを読み、個々の呼び出しは各自のドキュメントで確認する**
  - 実務的な注意: **サンプルをリポジトリの中に置かない**。Xcode の同期グループがサンプルの `.xcodeproj` を拾って、**追跡下の `project.pbxproj` に project reference を書き込む**（`.gitignore` では防げない）。実際にやって 50 行の差分が出た
  - **話のオチ**: 「T28 が『呼出元を 1 つだけ変えて比べる』、T29 が『制約は当時の SDK の話かもしれない』。3 つ目が **『Apple が書いたコードを読む』** です。全部読んだつもりでいて、サンプルを開いたら 4 箇所出ました」
- **出典**: [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「Phase 9: 公式サンプル 4 本との突き合わせ」/ [../devlog/03-app-intents-core.md](../devlog/03-app-intents-core.md)（2026-08-21）

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
| — | **公式ルールを原理的に書けない場所が出る**。donation は「UI 起点だけ」が規約だが、UI も `Button(intent:)` にした時点で `perform()` から呼出元が見えず、条件を書き分けられない（T21b）|
| **システムオーケストレーターに参加できる**。2026 から**複数アプリの App Intents を横断実行する主体がシステム側に立った**。アプリ同士が直接呼び合う API は無いので、**App Intents に出すことが唯一の参加手段**（#8011 `8:18`）| **横断するのはアクションであってデータではない**。セマンティックインデックスからの retrieval はアプリのサンドボックス内に閉じる（同一開発者・同一 App Group でも他アプリの donated content は引けない。#8011 `53:53`）。データを渡したいなら `Transferable` で明示的に |

  - 結論の言い方:
    - **App Intents 中心設計は「Siri 対応のため」ではなく「アプリの機能をどこからでも呼べる形に保つため」**
    - **一番の学びは API ではなく検証の作法**。ビルドが通っても、テストが緑でも、動いていないことがある。**呼出元を 1 つだけ変えて比べる / システムが読むメタデータを直接見る / Apple が書いたコードを読む / 回避策には期限を書く**
    - 最後のひと押し: 「WWDC のセッションを全部見て、ドキュメントも読んで、1 年実測して書いたコードに、**公式サンプルを 4 本読んだら 4 箇所間違いが出ました**。散文は 1 シンボルずつしか説明しないので、**合成のしかたはサンプルにしか書いていない**んです」（T29b）
  - 適合しなかったもの（正直に言う）:
    - **`RelevantEntities`**: todo / reminders 向けの `AppEntityContext` が存在せず適合不能
    - **コア entity の `.reminders.reminder` スキーマ適合**: `list` が非 optional / `dueDate` が `DateComponents` / `locationTrigger` が `PlaceDescriptor` を強制して SSU training バグに正面衝突。**SDK 修正待ちで着手不可**と確定。ただし **list 適合 + 自前 Intent 群で新 Siri 連携自体は成立する**
    - **意図的不使用**: `DynamicOptionsProvider` / `IntentParameterDependency`（パラメータ間の動的依存が起きるユースケースが無い）
    - **2026-08-22 の Group Lab 突き合わせで出てきた 4 件 — 調査完了**（詳細: [03-group-lab-evidence.md](03-group-lab-evidence.md) §4-4）:

      | 項目 | 結論 | 本アプリへの適用 |
      |---|---|---|
      | **`FileEntity`** | **2024 の API**（#10134 `9:01`–`10:40`）。`id` が `FileEntityIdentifier` である必要があり、URL の bookmark data を使うので**ファイルを移動・改名しても entity が有効**。`files` ドメインのスキーマ（`.files.file`）も存在する | ❌ **対象外**。Todo はファイルベースのコンテンツを持たない。「未着手の候補」ではなく「対象外」に分類し直す |
      | **新しい Siri の「3 本柱」** | #240 `1:51` が明示: **① entities へのアクセス ② intents によるアクション実行 ③ onscreen context の理解** | 骨子① S23 の裏付けとして使う |
      | **`EntityOwnership` / `OwnershipProvidingEntity`** | 用途は**確認ダイアログの出し分け**。`.public` / `.shared` / `.unknown` のフラグを返すと、**共有 / 公開 entity への破壊的操作でシステムが文脈つきの確認を出す** | ⚠️ **現状は非該当**（共有機能が無いので常に `.unknown`）。ただし**「優先度低」の理由が変わる** — 用途不明だからではなく**該当機能が無いから**。共有 Todo を作るなら真っ先に必要 |
      | **Apple Pencil** | **「タップ」ではなく `Apple Pencil Pro` の「スクイーズ」**（2024 / iOS 18）。⭐ **既存の App Shortcuts が何も書かずにそのまま動いた** | 骨子① S16 の「出口は勝手に増える」の実例に追加済み |

      - ⭐ **`OwnershipProvidingEntity` は T20 と対になる**。`requestConfirmation` が**アプリが明示的に取る確認**なのに対し、
        こちらは**システムが所有権を見て自動で出す確認**。**「確認を取る」に 2 系統ある**という整理ができる。
        そして後者は **スキーマに嵌めた見返りとして付いてくる**（骨子① S18b の理由 ⑤ の実体）
    - **`UndoableIntent`: 未着手 → 実装済み（2026-08-22 にコミット済み）**。`DeleteTodoIntent` / `DeleteTodoImmediatelyIntent` / `DeleteTodosIntent` / `ToggleTodoCompletionIntent` の **4 本**が準拠。**当初「ソフトデリートへの設計変更とセット」と見積もっていたが、実際は不要だった** — `TodoItemSnapshot`（Domain）で消す前の値を丸ごと控え、`TodoUndoRegistrar` が `undoManager` に「同じ id で復元する」ハンドラを登録する形で足りた（公式サンプル CosmoTunes `DeleteAlarmIntent` と同じ形）
      - **カードとして使えるオチ**: 「T29 の逆パターンです。**"設計変更が要ると思っていたら、要らなかった"**。見積もりのほうが古かった」
      - 数字（4 本）とトグルの undo セマンティクス（**逆トグルではなく元の値を `setCompletion` で絶対値指定**）は
        2026-08-28 時点のコードで確定済み
- **出典**: [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md) / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md) / [../../CLAUDE.md](../../CLAUDE.md)

---

## 発表前チェック

チェックリストは **[#67](https://github.com/touyou/IntentTodo/issues/67)** に移した（数字の再カウント / 一次ソースの裏取り /
スクショ / 言い方の判断）。ドキュメントには `- [ ]` を残さない運用のため
（[AGENTS.md の「ドキュメント運用」](../../AGENTS.md#ドキュメント運用現在のルール--経緯--残タスク-の三分割)）。

この骨子で使う数字の **2026-08-28 時点の実測**:

| 項目 | 値 | 注意 |
|---|---|---|
| Intent ファイル / 型 | **25** | うち `isDiscoverable = false` が 6 / watchOS 除外 1 / iOS 限定 1 |
| `AppEntity` | **4 種** | `TodoAppEntity` / `CategoryAppEntity` / `SubTaskAppEntity` / `TodoListSummaryEntity`（Transient）|
| `AppEnum` / `@UnionValue` | **3 / 1** | `TodoListType` は `AppEnum`、`TodoOrCategory` は `@UnionValue`、`NavigationDestination` は別枠。**この注釈なしで「Entity 4 種」と言うと突っ込まれる** |
| Query | **4** | うち 1 つは `IntentValueQuery`（Visual Intelligence 用） |
| AppShortcut | **8** | うち 5 件がパラメータ入りフレーズ |
| `allowedExecutionTargets = [.main]` | 書き込み系すべて | 宣言漏れは `IntentExecutionTargetsTests` が検出 |

- T10 の件数（20 / 3 / 3 / 8→0）は**当時の実測値**。上の表と混ぜず「当時の実測」と断って出す
- T13 → T14 は「落とし穴 → 運用解」の流れ。二重登録は「撤廃不可」ではなく**役割分離**
- T19 / T20 / T08 の実測は iOS 27 / Xcode 27 beta 5 時点（GM での再確認は #57）
- T07b は 99-script のレイヤードアーキテクチャ節（L73–79）と同じ話。両方使うなら役割を分ける
- 骨子① の S24 から続ける前提
