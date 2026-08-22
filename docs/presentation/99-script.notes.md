# 99-script.md の補完メモ（iOSDC 40 分枠）

> [99-script.md](99-script.md) に書かれた本人スクリプトを**書き換えずに補完する**ためのメモ。
> - **A. 事実確認** — 直したほうがいい / 言い方を変えたほうがいい箇所（まさかり対策）
> - **B. 詳細ゾーンの材料** — L38「ここは詳細ゾーン、もうちょいみながら詰める」に入れる候補
> - **C. 各節の補強材料** — 一次ソースの引用と、聴衆に効く具体
> - **D. 残りアウトラインの材料** — L82〜88 の 4 項目
> - **E. 尺の目安 / F. 想定 Q&A**
>
> 骨子側の詳細は [01-app-intents-history.md](01-app-intents-history.md) / [02-constraints-and-craft.md](02-constraints-and-craft.md) に置いてある（このメモは「99 に足すぶんだけ」抜粋）。

---

## A. 事実確認（まさかり対策・優先度順）

### A-1. ⚠️ 最優先: SiriKit は **2016 年 / iOS 10** 登場（L30–31）

スクリプト現状: 「2022年、もっといえばその元となった技術は**2020年**に登場しています。それがSiriKitです。」

- 正しくは **WWDC 2016 / iOS 10**。Apple 自身が明言している:
  > "In iOS 10, we introduced the SiriKit Intents framework, which lets you hook up your app's functionality to Siri domains like messaging, workouts, and payments."
  > — wwdc2022-10032「Dive into App Intents」`0:33`
- **2020 年は「Intent がウィジェットの設定言語になった年」**。WidgetKit 登場時、設定可能ウィジェットの仕組みが SiriKit の Custom Intent（`IntentConfiguration` / `IntentTimelineProvider`）だった。混同しやすいポイントなので、むしろ**そこを話のネタにできる**
  > "Prior to iOS 17, iPadOS 17, and macOS 14, configurable widgets used SiriKit Intents."
  > — Apple 公式 [Making a configurable widget](https://developer.apple.com/documentation/WidgetKit/Making-a-Configurable-Widget)
- 差し替え案（1 文だけ変える）:
  > 「App Intents 自体は 2022 年ですが、元をたどると **2016 年の iOS 10** に遡ります。それが SiriKit です。」
  - 2020 に触れたいなら後段で: 「ちなみに 2020 年、ウィジェットが出たときの設定の仕組みも SiriKit の Intent でした。つまりこの頃には Intent は "Siri のための API" から "システムがアプリに問い合わせる共通言語" に役割が広がっていたんです。」

### A-2. ⚠️ 「Dive into App Intents で SiriKit が非推奨になることが語られている」は不正確（L33）

- 実際の 2022 の発言は**逆に「使い続けろ」**:
  > "For those of you who have existing apps with SiriKit Intents that you want to upgrade, **if you adopt intents to integrate with widgets, or domains like messaging or media, you should keep using the SiriKit Intents framework.** But if you add **custom intents for Siri and Shortcuts**, you should go ahead and upgrade to App Intents."
  > — wwdc2022-10032 `29:29`–`29:48`
- つまり 2022 に非推奨化したのは **「Siri / Shortcuts 向けのカスタム Intent」だけ**。ウィジェット設定とシステムドメインは SiriKit のままだった
- **そこが後から回収されていく**のがこの 4 年の物語なので、ここは事実に寄せたほうが話が強くなる:
  - **2023 / iOS 17**: ウィジェット設定が App Intents 側へ（`WidgetConfigurationIntent`。Xcode の **Convert to App Intent** ボタン 1 クリックで移行）
  - **2024 / iOS 18**: システムドメインが **App Intent Domains（assistant schemas）** として App Intents 側に再登場。ただしこの時点でも Apple は "SiriKit domains are still the best ways for you to enable these kinds of features"（wwdc2024-10133 `1:03`）と言っている
  - **2026 / iOS 27**: **App Intents 系 6 セッション（240/295/297/343/344/345）に "SiriKit" という語が 1 回も出てこない**（`docs/references/wwdc/` を全文検索して 0 件。2022 と 2024 は必ず言及していた）
- 差し替え案:
  > 「2022 年の Dive into App Intents では、SiriKit の**カスタム Intent** については App Intents への移行が明確に推奨されました。一方でウィジェットの設定やメッセージ・メディアのドメインは "SiriKit を使い続けてください" と言われていて、まだ二本立てだったんです。それが 2023 年にウィジェット、2024 年にドメインと順に App Intents 側へ回収されて、2026 年のセッションではもう SiriKit という単語が 1 回も出てこなくなりました。」
- ⚠️ ネット上には「WWDC 2026 で SiriKit が正式に deprecated」という記事が複数あるが、**Apple の一次ソースで確認できていない**（公式ドキュメントには SiriKit も `CustomIntentMigratedAppIntent` も現役で載っている）。**断定しないほうが安全**。「もう SiriKit の話は出てこない」という事実提示で十分効く

### A-3. 「最小の構成単位はタイトルと description、そして perform 関数」（L28）

- 厳密には **必須は `title` と `perform()`**。`description` は `static var description: IntentDescription?` で **optional**（スキーマ適合時はスキーマが供給する）
- ただし Apple 公式のチュートリアルは「各 intent で以下を実装せよ」として **title / description / isDiscoverable / parameterSummary** を挙げているので、**「実務上そろえるべき最小セット」と言い直せば正確かつ Apple 準拠**になる
  > — Apple 公式 [Creating your first app intent](https://developer.apple.com/documentation/AppIntents/Creating-your-first-app-intent#Customize-your-app-intents-description-and-behavior)
- 言い換え案: 「プロトコル的に必須なのは title と perform だけです。ただ実際には description と isDiscoverable、parameterSummary までを 1 セットで書くのが Apple の推奨です」

### A-6. ⚠️ 「App Schema 適合は任意」は 2 層に分けて話す（F. 想定 Q&A の修正）

- Group Lab（#8011 `3:09`）で **「新しい Siri AI との統合にはスキーマ適合が必要」**と明言されている。
  一方 `21:47` では **「advantage（優遇）という捉え方は違う」**とも言っている。矛盾ではなく **2 層**:
  - **App Intents（スキーマ不要）** → Shortcuts / Spotlight / ウィジェット / コントロール / ライブアクティビティ / 従来の Siri フレーズ
  - **App Schema 適合** → **新しい agentic Siri（多ターン会話・自然な言い回し・確認や所有権の自動処理・ローカライズ）**
- F の「Apple Intelligence / Siri AI 対応は必須？ → 必須ではない」は **「任意」ではなく「どこまで行きたいかで決まる」**に直す
- ⚠️ 根拠が**字幕由来の粗起こし**なので、スライドに断定で書くなら `3:09` を視聴して逐語確認
- 詳細: [03-group-lab-evidence.md](03-group-lab-evidence.md)

### A-4. 「AppEntity はパラメータをつけるときに出てくる」（L28）

- 半分正しいが狭い。`AppEntity` はパラメータだけでなく **戻り値・Spotlight インデックス・画面上のコンテンツ提供（onscreen）・他アプリへの受け渡し**にも使う
- L76 の「AppIntents は動詞 / AppEntity は名詞」という整理と**そのまま繋がる**ので、L28 では「パラメータの型として最初に出会うのが AppEntity ですが、実は後半で話す通りこれは "アプリの名詞" そのものです」と**伏線にする**のがおすすめ

### A-5. 用語の細かいところ

- 「AppIntents プロトコルに適合した構造体」→ 正確には **`AppIntent`**（単数）プロトコル。フレームワーク名が `AppIntents`（複数）でプロトコル名が `AppIntent`。スライドの文字は単数に
- 「SiriKit が UIKit、App Intents が SwiftUI」の比喩は**そのまま使える。むしろ良い**。補強すると:
  - SiriKit = `Info.plist` + Intents App Extension（`INExtension`、別プロセス）+ **`.intentdefinition`（GUI エディタ + コード生成）**
  - App Intents = **Swift の struct を書くだけ**。`Info.plist` 登録なし、Extension なし、**ビルド時に Swift コンパイラがメタデータを抽出**して `Metadata.appintents` を生成
  - つまり「宣言的」の本質は見た目の書き味だけでなく、**宣言そのものがビルド生成物になる**こと。この 1 行があると「単に書き方が変わっただけでは？」というツッコミを先に潰せる
    > "your intents are compiled into a metadata representation … containing information received from the Swift compiler as it runs on your code" — wwdc2022-10032 `29:12`
- 「名前から Siri という単語を抜いたことに伴って適用範囲が増えた」→ **良い切り口**。裏付けとして: App Intents は Siri を一度も使わなくても価値が出る（本プロジェクトはウィジェット / コントロールセンター / ライブアクティビティ / Spotlight / アプリ内 UI で日常的に使っている）。ここは後半の「なるべく多くの面で活用する」に繋がる

---

## B. L38「詳細ゾーン」の材料（3 案・尺つき）

アンケートで「知らない」に手が挙がった人向けの解説ゾーン。**全部やると長い**ので 1 案か 2 案。

### B-1【推奨・約 3 分】1 つの Intent が何面に出るかを実演する

- 見せ方: `ToggleTodoCompletionIntent` を 1 つスライドに出し、そこから矢印を 6 方向（アプリ内ボタン / ウィジェット / コントロールセンター / ライブアクティビティ / Siri / Shortcuts）
- 台詞の骨: 「この 20 行で、この 6 か所が全部動きます。**ウィジェットのチェックボックスと、Siri に "完了にして" と言うのは、同じ 1 つの Intent を呼んでいます**」
- ここで `Button(intent:)` を紹介できる。「App Intents は Siri 用の API だと思われがちですが、**アプリ内の UI からも同じものを呼ぶ**のが今日の設計の核です」→ 中心設計への自然な橋
- 実物: `Packages/TodoAppIntents/Sources/TodoAppIntents/Intents/ToggleTodoCompletionIntent.swift`

### B-2【約 2 分】Intent / Entity / Query の 3 点セット

- Apple 自身の要約が短くて使いやすい:
  > "Intents are actions built into your app that can be used throughout the system. Intents use entities to represent your app's concepts. App Shortcuts wrap your intents to make them automatic and discoverable."
  > — wwdc2022-10032 `1:08`
- 「動詞 / 名詞 / 探し方」の 3 つで説明すると、L76 の「動詞・名詞」に綺麗に繋がる
  - **Intent = 動詞**（できること）
  - **Entity = 名詞**（扱っている概念。`@Property` で公開すると Shortcuts の変数として使える）
  - **Query = 名詞の探し方**（`entities(matching:)` / `suggestedEntities()` / `allEntities()`）
- ここで「**Query を書くと Shortcuts に "検索" と "フィルタ" のアクションが自動で生えます**」を言うと「1 個書くと勝手に増える」感が伝わる

### B-3【約 2 分】App Shortcuts の「設定ゼロ」がどれだけ異常か

- SiriKit 時代は **ユーザーが「Add to Siri」ボタンを押してフレーズを録音する**必要があった。App Shortcuts はそれが消えた
  > "They no longer need to head to the Shortcuts app or use an Add to Siri button to set anything up."
  > — wwdc2022-10170「Implement App Shortcuts with App Intents」`1:24`
- つまり **インストール直後から Siri で呼べて、Spotlight にも出る**。開発者が `AppShortcutsProvider` にフレーズを書くだけ
- 数字のネタ: **App Shortcut は 1 アプリ 10 件まで**（フレーズ総数は 1,000 件まで）。「10 件しかない枠に何を置くかが設計判断になる」という話は後半の実践パートの伏線になる

---

## C. 各節の補強材料

### C-1. Liquid Glass の節（L41–51）— ここが一番補強すると強くなる

**仮説を裏付ける一次ソース（HIG Materials）。「コンテンツを目立たせる」の実文言はこれ:**

> "Liquid Glass forms a **distinct functional layer for controls and navigation elements** — like tab bars and sidebars — **that floats above the content layer**, establishing a clear visual hierarchy between functional elements and content."
>
> "**Don't use Liquid Glass in the content layer.**"
>
> "**Liquid Glass seeks to bring attention to the underlying content**, and overusing this material in multiple custom controls can provide a subpar user experience by distracting from that content."
>
> — Apple HIG [Materials / Liquid Glass](https://developer.apple.com/design/Human-Interface-Guidelines/materials#Liquid-Glass)

- ここが効くポイント: Apple は **「機能レイヤー（クローム）」と「コンテンツレイヤー」を明示的に分離**し、**前者だけ**をガラスにした。「UI を文字通り透明にしようとしたのでは」という仮説と**構造的に一致する**
- 併せて HIG [Layout / Visual hierarchy](https://developer.apple.com/design/Human-Interface-Guidelines/layout#Visual-hierarchy) の "**Differentiate controls from content.**" も使える

**⚠️ まさかり対策（言い方の調整をおすすめ）:**

- 「アクセシビリティの優先度が下がったのではないか」は**反論されやすい**。同じ HIG に、Liquid Glass の見た目が **アクセシビリティ設定（透明度を下げる / コントラストを上げる）や好みの設定に応じて変わる**と明記されている
  > "The appearance of these variants can differ in response to certain system settings, like if people choose a preferred look for Liquid Glass in their device's settings, or **turn on accessibility settings that reduce transparency or increase contrast** in the interface."
- なので **「捨てた」ではなく「クロームの視覚的な存在感を下げても成立するように、適応表示 + 代替経路の両方を用意した」**という言い方に寄せると、同じ結論に着地しつつ突っ込まれにくい
- そして「代替経路」の方が App Intents につながるので、**論旨はむしろ強くなる**

**構造的な傍証（推測に頼らないカード）:**

- Apple は「アクションを UI の外に出す面」を**毎年増やし続けている**。2023 ウィジェットのボタン → 2024 コントロールセンター / Action Button → 2025 Interactive Snippets / Visual Intelligence → 2026 Siri AI・通知オートメーション
- つまり **「UI を薄くしても操作が失われない」という前提を、Apple は App Intents で先に作っていた**。これは推測ではなく年表の事実として言える（骨子① S16 の積み上げ図がそのまま使える）
- Matthew Cassinelli（元 Apple / Shortcuts）の啓蒙は既にスクリプトに引用済み。加えるなら **Vidit Bhargava の Action-Centered Design**（L67 で既出）が「アプリ = アクションの集合体」を UX 側から言っているので、**「Apple の中の人 + デザイン側 + 実装側の 3 方向から同じことが言われている」**という構図にできる

### C-2. 中心設計の 3 原則（L61）の裏付け

スクリプトの 3 つ ——「App Intents から設計する / なるべく DRY / なるべく多くの面で活用する」—— に対応する具体を 1 つずつ:

| 原則 | 具体（このプロジェクトでやったこと） |
|---|---|
| App Intents から設計する | 設計プロセスを**最も制約の厳しい面（Apple Watch）から**始める。そこで残る本質的なアクションを Intent 化してから、他プラットフォームへ広げる（Action-Centered Design の手順） |
| なるべく DRY | **UI からのアクションは必ず `Button(intent:)`**。ロジックは `TodoService` 1 箇所。「ウィジェットのボタンと Siri が同じ Intent」が結果として得られる |
| なるべく多くの面で活用 | 1 アプリで **iOS / iPadOS / macOS ネイティブ / watchOS / visionOS + ウィジェット / コントロール / ライブアクティビティ / Siri / Shortcuts / Spotlight / Visual Intelligence**。watchOS を足すときに書いたのは **View だけ** |

- 数字を出すなら: **Intent 定義 24 ファイル / AppEntity 4 種 / Query 4 種 / App Shortcut 8 件（上限 10）/ SPM パッケージ 7 つ**

### C-3. レイヤードアーキテクチャの節（L73–79）の補足

- 実際の構成は 4 層 7 パッケージ。「表示側の葉ノード」が 4 つ並列にぶら下がる形なので、図にするならこれ:
  ```
  Domain ── Repository ── TodoAppIntents ─┬─ UI          (iOS/iPadOS/macOS/visionOS)
                          （★コア）        ├─ WidgetUI    (ホームウィジェット)
                                          ├─ WatchUI     (watchOS + コンプリケーション)
                                          └─ LiveActivity (iOS 限定)
  ```
- **Extension ターゲットには `@main` と宣言だけ**しか置かない、が実務上効いた点。View を SPM に移すと **プレビューが速くなる / テストできる / 他プラットフォームで再利用できる**
- UseCase 廃止の補強として言えること: **`@Dependency` + `AppDependencyManager` があるので、Intent がアプリの共有状態（Service / NavigationModel / ModelContainer）に正規の方法で到達できる**。UseCase 層を挟む動機（DI と実行の分離）が Apple 側の仕組みで埋まっている
- ただし正直に言うべき境界: **ロジックを Intent の `perform()` に書くのは 24 個に増えると破綻する**。本プロジェクトは `TodoService`（`@MainActor final class`）に集約して、Intent は「システムとの接続点」に薄く保っている。**「UseCase を廃止した」＝「ロジックの置き場をなくした」ではない**、と言い切っておくと誤解されない
- 「制約によりけりで柔軟に」（L79）の実例: **`AppShortcutsProvider` だけは SPM に置けない**（後述 D-1）。理想の分割が SDK 側の都合で崩れる代表例として使える

---

## D. 残りアウトラインの材料（L82–88）

### D-1. 「実際どんなつまずきや理想との乖離があったか」（L82）

40 分枠だと **3 本 + 締め 1 行**が限界。**「ビルドは通る・エラーも出ない・ただ動かない」**という共通点で括るのがおすすめ。

**① `AppShortcutsProvider` は SPM パッケージに置けない（理想の分割が崩れる話）**

- 症状: **Siri / Shortcuts / Spotlight に App Shortcut が 1 つも出てこない。ビルドも実行もエラーなし**
- 原因: App Intents の実体は**ビルド時に生成される `Metadata.appintents`**。`actions` / `entities` / `queries` は依存パッケージからアプリへ集約されるが、**`autoShortcuts` だけ集約されない**

  | キー | パッケージ側 | アプリ側 |
  |---|---|---|
  | `actions`（Intent） | 20 | 20 ✅ |
  | `entities` | 3 | 3 ✅ |
  | `queries` | 3 | 3 ✅ |
  | **`autoShortcuts`** | **8** | **0 ❌** |

  （※当時の実測値。現在は Intent 23 / Entity 4 / Query 4）
- 解決: `AppShortcutsProvider` **だけ**アプリターゲット直下へ移す（`import TodoAppIntents` で Intent を参照）。それで `0 → 8` になる
- **話のオチ**: 「理想は全部 SPM に寄せることでした。でも**システムが読むのはアプリバンドルの中の 1 つのメタデータだけ**なので、そこに集約されないものはアプリ側に置かないといけない。**綺麗な分割は、ビルド生成物の都合に負けます**」
- ⚠️ 「アプリあたり 1 つまで」と明文化された Apple のリファレンス記述は見つけられていない。**実機観測ベースと明言する**

**② 呼出元によって、返したものが出るか出ないかが変わる（一番驚かれるやつ）**

| 呼出元 | `.result(dialog:)` | Snippet | ローカル通知 |
|---|---|---|---|
| Siri | 読み上げ ✅ | ✅ | ✅ |
| Spotlight / Shortcuts | 結果欄に ✅ | ✅ | ✅ |
| アプリ UI の `Button(intent:)` | 出ない | 出ない | ✅ |
| ウィジェットの `Button(intent:)` | 出ない | 出ない | ✅ |
| **コントロールセンター** | **出ない** | **出ない** | ✅ |

- **どうやって確定させたかがこの話の本体**。公式の記述が割れていた:
  - AppIntents [Visual presentation](https://developer.apple.com/documentation/AppIntents/visual-presentation): "Siri, Spotlight, and the Shortcuts app display snippets"（Control は列挙されない）
  - 一方 wwdc2025-275 `1:40`–`1:59`: "**I'll tap on the control that runs an App Intent** […] the intent will show a snippet"
- 肯定リストは Control を**明示的に除外していない**ので「列挙に無い＝出ない」とは読めない。**実際この推論で一度設計を誤った**
- そこで **呼出元だけを変えて同じ Intent・同じ snippet を走らせた**: Spotlight から → 出る / Control から → 出ない / プロセスを `[.main]` に固定しても → 出ない / Toggle でも → 出ない。**残る差分は「呼出元が Control であること」だけ**
- **話のオチ**: 「App Intents は**同じコードが呼出元によって違う振る舞いをする**フレームワークです。だからドキュメントの読解より、**変数を 1 つだけ動かした比較**が早い」
- 設計上の帰結: Control の成功フィードバックは **コントロール自身の再描画**、**失敗時だけローカル通知**（失敗すると前の状態のまま再描画されて「何も起きなかった」と区別できない）

**③ `requestConfirmation` を含む Intent はアプリ内 `Button(intent:)` から呼べない（一番痛かったやつ）**

- 応答する面が無いため `LNPerformActionErrorCodeUnsupportedValueType` で失敗し、**エラー表示も出ずに何も起きない**
- 実際 **詳細画面の削除ボタンが長期間まったく動いていなかった**
- しかも **Siri / Shortcuts / AppIntentsTesting 経由なら成功する** → **テストでは検出できない**
- さらに追い打ち: UI テスト側が `if element.waitForExistence(...) { XCTAssert... }` という**条件付き assert** になっていて、要素が見つからないと中身が実行されず**緑になっていた**
- 解決: **確認は SwiftUI の `.confirmationDialog` で取り、実行は確認なし版の Intent に渡す**。`requestConfirmation` / `requestChoice` を持つ Intent は **Siri / Shortcuts 専用**と割り切る
- **話のオチ**: 「**DRY にしたい気持ちと、対話できる面かどうかは別問題**でした。同じアクションでも "問い合わせられる相手がいるか" で 2 本必要になる。これが理想と現実の乖離の一番大きいところです」

**④ 候補（2026-08-21 追加）: 公式サンプルを読んだら 4 箇所間違っていた**

> 3 本の枠に対する **4 本目の候補**。①〜③ と違って「制約の話」ではなく **「調査の作法の話」** なので、
> ①〜③ のどれかと差し替えるより、**締めの直前に 1 分足す**ほうが効くかもしれない。骨子側は T29b。

- 前提として**読んでいたもの**: WWDC の App Intents 関連セッション全部（2022〜2026、トランスクリプト全文）+ 公式ドキュメント + 1 年の実測
- それでも **WWDC 2026 の公式サンプル 4 本（CometCal / UnicornChat / CosmoTunes / PhotosDomainExample）を読んだら 4 箇所間違っていた**:
  1. `perform()` の中で `donate()` を呼んでいた（公式は「Siri / Shortcuts 起点には donate するな」。`perform()` は呼出元を見られない）
  2. `attributeSet` と `@Property(indexingKey:)` で同じ Spotlight キーを書いていた（セマンティック検索に載る本文が固定文に入れ替わりうる）
  3. `LocalizedStringResource(stringLiteral: todo.title)`（**ランタイム値をローカライズキーにしていた**）
  4. `entities(matching:)` の比較が `lowercased().contains()`（ロケール非依存。かな / カナ、濁点、トルコ語の I が別文字扱い）
- **なぜ散文では気づけなかったか**が本体: 公式ドキュメントは 1 シンボルずつ説明する。「`indexingKey` は attribute set を置き換えず追加する」とは書いてあるが、**同じキーを両方から書いたらどうなるかは書いていない**。**合成のしかたはサンプルにしか書いていない**
- サンプルのコメントにしか無い知見の例: **「Siri は entity の subtitle を読み上げるので `"5:00"` のような位置指定表記を避ける」**（"five colon zero zero" と読まれる）
- ただし **サンプルは証拠であって権威ではない**。Apple 自身が非推奨 API を使っている（`static let openAppWhenRun = true`。現行は `supportedModes`）
- **話のオチ**: 「①〜③ が『動かないものをどう見つけるか』の話でした。これは **『間違っていることにどう気づくか』** の話です。全部読んだつもりでいて、Apple が書いたコードを開いたら 4 箇所出ました」

**締めの 1 行（3 本の共通点）**

> 「3 つとも、**ビルドは通り、例外も出ず、ただ動かない**という形で来ました。App Intents は宣言的なので、**宣言が届いていないことに気づけない**。だから **① システムが読むメタデータを直接見る、② 呼出元を 1 つだけ変えて比べる**、この 2 つが必須の作法になります」

> ④ を入れるなら 3 つ目を足す: **「③ Apple が書いたサンプルコードを読む」**

**時間が余ったら足すカード（各 30 秒）**

- **`supportedModes` は実行プロセスを決めない**。共有パッケージの Intent は**ヒューリスティクス**でプロセスが選ばれる（アプリ起動中なら本体優先、未起動なら Extension）。`@Dependency` はプロセスごとの `AppDependencyManager` から解決されるので、固定しないなら**両方に登録**が要る。→ 本プロジェクトの現在の運用は **「SwiftData を書き換える Intent は必ず `allowedExecutionTargets = [.main]`」（13 Intent）+ 宣言漏れを `IntentExecutionTargetsTests` で検出**。読み取り系は固定せず二重登録のまま（骨子② T14。2026-08-22 更新）
- **`perform()` を手で呼んではいけない**。`@Dependency` はシステムが dispatch したときだけ解決される。手で呼ぶとゼロ初期化のまま落ちる → **「Intent は関数ではない」**
- **`#if canImport(X)` だけに頼れない**。`VisualIntelligence` は visionOS **シミュレータでは false / 実機 SDK では true** になって**実機ビルドだけ落ちる**
- **回避策は原因が消えたら消す**。「Live Activity 経由の entity 解決でクラッシュする」を理由に Intent を 2 系統に分けていたが、iOS 27 で再現しないことを実測して**分離ごと撤去**した
- **公式ルールを原理的に書けない場所がある**（2026-08-21 追加 / 骨子 T21b）。donation は「アプリ UI 起点の操作だけ」が公式ルールだが、`perform()` は呼出元を判別できない（`IntentSystemContext` にあるのは `currentMode` / `isVoiceOnly` だけ）。**UI も `Button(intent:)` にした時点で条件を書き分けられない**。公式サンプル 2 本の回避策はどちらも「UI がサービスを直接呼ぶ」前提 = **中心設計は Apple の想定する標準形ではない**、という踏み込んだ話ができる
- **付け先が違うと静かに無効になる modifier がある**（2026-08-21 追加 / 骨子 T27）。`.appEntityIdentifier(forSelectionType:)` は **`List` に付けたときだけ効く**。`ScrollView { VStack { ForEach } }` に付けても no-op で、アプリの見た目は 1 ピクセルも変わらない

### D-2. 「ここを中心にすることはデザインにも通ずる」+「モデルベース UI デザインとの対応」（L84, L86）

L76–77 で既に核心を言えているので、**補強は写像表 1 枚**で足りる。

| ユースケース中心設計 | App Intents | このアプリでの例 |
|---|---|---|
| 誰が（Actor） | Entity | ユーザー |
| 何を（Object） | **AppEntity** | `TodoAppEntity` / `CategoryAppEntity` / `SubTaskAppEntity` |
| 行動できる（Action） | **AppIntent** | `AddTodoIntent` / `ToggleTodoCompletionIntent` / `SnoozeTodoIntent` |

- 効く言い方: **「ユースケース図が、そのまま Intent 定義のチェックリストになる」**
- デザイナーとの共通言語になる、という主張の具体例:
  - 「この画面にこのボタンを足したい」ではなく **「このアクションはどの面に出すべきか」**で会話できる
  - Action-Centered Design の**展開マトリクス**がそのまま使える:
    | コンテンツ / アクションの特性 | 出す面 |
    |---|---|
    | 毎日確認する情報 | ウィジェット |
    | 頻繁に変わる情報 | watchOS コンプリケーション |
    | 繰り返しのアクション | Shortcuts / Siri |
    | 常時追跡が必要 | ライブアクティビティ |
    | 素早いアクセス | コントロールセンター |
    | 物理トリガーが自然 | Action Button |
  - **設計は「最も制約の厳しい面」から始める**（Apple Watch → 本質的なアクションが残る → Intent 化 → 各面へ展開 → **メインアプリの画面設計は最後**）。これは「画面から設計する」習慣の逆で、聴衆にとって一番の持ち帰りになりうる
- 逆説的な補強として使えるカード: **Liquid Glass で標準 UI で十分になったので、カスタムスタイリングに投資する理由が減った。空いた分を Intent 定義に回すと、Apple Intelligence 連携が勝手についてくる**
- ⚠️ 用語の注意: **MVI（Model-View-Intent）の "Intent" とは別概念**。質疑で混ざりやすいので 1 行で切っておくと安全（詳細は [../APP_INTENT_DRIVEN_DESIGN.md](../APP_INTENT_DRIVEN_DESIGN.md)）

### D-3. 「みんなでトライしてみませんか？」（L88）

**最初の一歩を具体で示す（重い順ではなく軽い順）:**

1. **既にあるアクション 1 つを Intent に切り出して、UI からも `Button(intent:)` で呼ぶ**。この時点で Shortcuts / Spotlight に出る。Siri 対応の意思決定は不要
2. **`AppEntity` を 1 つ作って `@Property` を数個公開する**。Query を書くと Shortcuts に「検索」「フィルタ」アクションが自動で生える
3. **`AppShortcutsProvider` にフレーズを 1 つ書く**（枠は 10 件）。ここまでで Siri から呼べる
4. **`AppIntentsTesting` でテストを書く**（iOS 27〜）。UI テストバンドルに置く必要がある点だけ注意

**「今すぐ試せる」ネタとして強いもの（WWDC 2026 #310 What's new in Shortcuts）:**

- **Use Model の transcript inspector**: Shortcuts の「Use Model」アクションに自分のアプリの AppEntity を渡したとき、**モデルに実際に渡されているデータをそのまま覗ける**
  > "Use the model transcript inspector to evaluate the exact data that's passed to the model from your app's App Intent entities."
  - **これは掴みとして最高**。「自分の AppEntity が LLM にどう見えているかを、Shortcuts アプリで今日確認できます」→ **「Entity 設計 = AI に対するアプリの説明文」**という主張が体感で伝わる
- **新しいオートメーション 3 種（スクリーンショット / キーボード接続 / 通知）**。特に**通知オートメーション**はキーワードでフィルタして起動できるので、「自分のアプリの通知が他アプリのトリガーになる」時代の話ができる
- **Storage**（Get / Set / グローバル値が iCloud 同期）と、**「AppEntity には device-consistent な安定 id を使え」**（= `SyncableEntity`）
- 出典: `docs/references/wwdc/wwdc2026-310-whats-new-in-shortcuts.md`

**締めに使えるメッセージ候補:**

> 「App Intents 中心設計は **Siri 対応のための設計ではありません**。**アプリの機能を、どこからでも呼べる形に保っておくための設計**です。出口は毎年勝手に増えます。増えたときに何も書かなくていい状態にしておく、という投資です。」

---

## E. 尺の目安（40 分枠 / 発表 35 分 + 質疑 5 分 想定）

| 区間 | 内容 | 目安 |
|---|---|---|
| L4–13 | 挨拶・自己紹介・会社紹介 | 5:00 |
| L14–23 | アンケート（3 問挙手） | 2:00 |
| L25–36 + **B** | App Intents とは / SiriKit との関係 / 詳細ゾーン | 8:00 |
| L41–53 + **C-1** | Liquid Glass の仮説 | 5:00 |
| L55–71 + **C-2** | 中心設計の定義と先行例 | 4:00 |
| L73–79 + **C-3** | アーキテクチャ | 4:00 |
| **D-1** | つまずき・乖離（3 本 + 締め） | 5:00 |
| **D-2** | デザインとの接続 / モデルベース UI デザイン | 3:00 |
| **D-3** | みんなでトライ / 締め | 2:00 |
| — | 質疑 | 5:00 |

- 削るなら **D-1 を 3 本 → 2 本**（② と ③ を残す。① はメタデータの話が前提知識を要求するので落としやすい）
- アンケート結果で「知らない」が多かったら **B-1 を必ずやる**、「バリバリ」が多かったら B は 1 分で流して **D-1 に寄せる**

---

## F. 想定 Q&A

| 質問 | 答えの骨 |
|---|---|
| 小規模アプリでもやる意味ある？ | **アクション 1 つからでいい**。ウィジェットやコントロールを作る予定があるなら確実に元が取れる。逆に「アプリの外に出す面が今後もゼロ」なら過剰 |
| テストどうしてる？ | Apple 自身が **検証の梯子**を示している（AppIntentsTesting → Shortcuts アプリ → Spotlight → Siri）。**4 段目は自動化できない**（`AppIntentsTesting` の公開 API に phrase / siri に相当するシンボルは 1 つも無い）。加えて **UI 経路は UI テストで押さえる必要がある**（対話 Intent の件） |
| ロジックを Intent に置くと肥大しない？ | する。だから `TodoService` に集約して Intent は接続点に薄く保つ。**「UseCase を廃止」≠「ロジックの置き場をなくす」** |
| MVI の Intent と同じ？ | 別概念。MVI の Intent は状態変更イベント、AppIntent はシステム連携のプロトコル |
| 毎年 API が変わって追従つらくない？ | つらい。4 年で非推奨 7 個。ベータごとの追従も実在する（`.reminders` 有効化 → watchOS で unavailable 化 → SDK バグ回避…）。ただし**非推奨の方向は一貫している**（Bool フラグ → 意味のある宣言 / アシスタント専用 → App Intents 本体へ統合） |
| Apple Intelligence / Siri AI 対応は必須？ | 必須ではない。**App Schema 適合は任意**で、適合しない自前 Intent も普通に動く。本プロジェクトはコア entity のスキーマ適合を **SDK 側のバグでブロックされて保留**しているが、それでも Siri 連携自体は成立している |
| CloudKit と併用するときの注意 | `@Attribute(.unique)` は enforce されない / リレーションは全部 optional / プロパティはデフォルト値か optional。あと**マイグレーションを走らせるプロセスはアプリ本体だけに固定する**（更新直後はウィジェットが先に起動しうる） |

---

## 発表前にやること

- [ ] **A-1 / A-2 の 2 箇所を直す**（事実誤り。ここだけは必須）
- [ ] **A-6** の 2 層整理で F. 想定 Q&A を差し替える + `#8011 3:09` を視聴して逐語確認
- [ ] Group Lab カードを使うなら [03-group-lab-evidence.md](03-group-lab-evidence.md) の「組み込み案」を見る。逐語取りの優先度は **`45:38`（固定スキーマの理由）> `8:18`（オーケストレーター）> `3:09`**
- [ ] A-3 / A-5 は言い方の調整（任意だが安い）
- [ ] C-1 のまさかり対策の言い換えを入れるか決める
- [ ] D-1 で使うスクショを撮る（Control Center の `2` → `1`、削除ボタンが無反応、Spotlight の snippet）
- [ ] 数字を発表直前のコードで再カウント（Intent 24 ファイル / 型 23 / Entity 4 / Query 4 / AppShortcut 8）
- [ ] WWDC の引用は `?time=<秒>` 付き URL をスライドのノートに入れて、その場で飛べるようにする
