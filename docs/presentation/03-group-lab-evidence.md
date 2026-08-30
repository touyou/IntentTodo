# Apple Intelligence Group Lab（WWDC26 #8011）全内容の抜き書き

> 出典: [WWDC26 Session 8011 — Apple Intelligence Group Lab](https://developer.apple.com/videos/play/wwdc2026/8011/)
> ローカル控え: [../references/wwdc/wwdc2026-8011-apple-intelligence-group-lab.md](../references/wwdc/wwdc2026-8011-apple-intelligence-group-lab.md)
> 登壇: Ernie Sabella（司会 / AI ML Evangelist）、James、Dan、Rob ほか App Intents / Foundation Models / Apple Intelligence チーム
> 全 27 問 + イントロ / 約 64 分

**このファイルの方針**: 尺を考えずに**判明していることを全部書く**。構成の取捨選択は本人が行う前提。
App Intents に直接効かないもの（Foundation Models / Evaluations / Image Playground）も、**後から
「あれ何だっけ」を防ぐために全部残す**。

---

## 0. 引用する前に必ず読む（まさかり対策）

### 0-1. このセッションには「編集済みトランスクリプト」が存在しない

ページの Transcript タブは空。ただし **Developer アプリには文字起こしが出る**。その正体は
**動画の HLS 字幕トラック**（`cmaf.m3u8` → `subtitles/en/prog_index.m3u8`、639 セグメント / 1,353 キュー）。
`docs/references/wwdc/_refresh.sh` にフォールバックを実装して復元してある（2026-08-22）。

ローカル控えに入っているのは **3 種類の別物**。**混ぜて引用すると事故る**:

| 種類 | 何か | スライドでの扱い |
|---|---|---|
| **チャプター見出し（= 質問文）** | Apple がページに公開しているテキスト | ✅ **逐語で出せる。一番安全** |
| **Summary（Apple 提供）** | Apple が各回答を要約した編集済み文章 | ⭕️ 「Apple の公式サマリーによると」なら可。**パネリストの発言として引用符に入れるのは NG** |
| **トランスクリプト（字幕由来）** | **自動生成キャプション** | ❌ **そのまま貼らない**。裏取り用の作業資料として使う |

字幕由来テキストで実際に確認されている崩れ:

- `WWDC` → `Wwdc`
- `Siri's` → `series`
- `EntityOwnership` → `enter entity ownership`
- 話者交代が区切られない（James と Dan の発言が地続きになる）
- 相槌（`Yeah.` `Right.` `That's great.`）が本文に混ざる
- 質問文の読み上げと回答が連続していて境界が曖昧

以下、英文はすべて字幕由来の粗起こしなので **`≈`** を付けてある。

---

### 0-2. 一番強い出し方

> **「質問文（逐語・Apple 公開）」＋「回答の要旨（自分の言葉）」＋「`?time=` URL」**

Group Lab は Q&A なので、**開発者が何を不安がっていて Apple が何と答えたか**という構図そのものが論拠になる。
逐語がなくても十分効く。逐語が欲しいカードだけ、発表前に該当タイムスタンプを視聴して取る。

---

### 0-3. 逐語を取りに行く優先度

| 優先 | 箇所 | 理由 |
|---|---|---|
| 1 | `45:38`–`49:20`（固定スキーマを選んだ理由） | 質疑で必ず使う。内容が濃く、サマリーに無い情報が多い |
| 2 | `8:18`–`10:20`（システムオーケストレーター） | 中心設計の根拠として最も直接的 |
| 3 | `3:09` 付近（Siri AI にはスキーマ適合が必要） | **既存メモの記述を訂正する根拠**なので、断定するなら裏取り必須 |
| 4 | `27:24`（IndexedEntity とスキーマは相補的） | Spotlight 周りの実装判断の根拠 |

---

## 1. 全 27 問マップ（何が聞かれたか / 誰向けか）

`AI` = App Intents 関連 / `FM` = Foundation Models / `EV` = Evaluations / `IP` = Image Playground / `—` = その他

| # | 位置 | 分類 | 質問の要旨 | 本ファイルでの扱い |
|---|---|---|---|---|
| 1 | `1:43` | — | v27 の API と設計変更を学ぶのに一番役立つ Apple のリソースは？ | §2-0 |
| 2 | `3:09` | **AI** | どのスキーマにも当てはまらない。近い型を使うべきか、当面見送るべきか（時間管理アプリ） | **§2-1** |
| 3 | `7:08` | **AI** | コアの entity / アクションがどのドメインにも写像しない。今何をすべきか | **§2-2** |
| 4 | `8:18` | **AI** | アプリが自分でオーケストレーターになれるか。それとも Siri/Shortcuts 経由必須か | **§2-3 ★** |
| 5 | `10:23` | **AI** | iOS 27 の新 Siri で、サードパーティアプリは多ターン会話に参加できるか | **§2-4** |
| 6 | `12:08` | **AI** | 非スキーマの Entity/Intent と、異なるドメインのスキーマを同一アプリで混ぜてよいか | **§2-5** |
| 7 | `13:26` | FM | バックグラウンド 1 回の起床での実務的な時間 / 作業量の予算は？ | §3 |
| 8 | `14:47` | FM | throttling / 過負荷 / 熱 / クォータ枯渇 / モデル不在 のエラー種別。再試行可能なのはどれか | §3 |
| 9 | `16:01` | FM | `guardrailViolation` を避けるには。問題のないプロンプトでも頻発する | §3 |
| 10 | `17:38` | FM | iOS 27 で動画を扱えるか。マルチモーダル入力は静止画だけか | §3 |
| 11 | `21:47` | **AI** | スキーマ適合は Siri に対する「優遇」になるのか。金融ドメインが無いが | **§2-6 ★** |
| 12 | `26:00` | IP | Image Playground でフォトリアルな画像をアプリ内生成できるか | §3 |
| 13 | `27:24` | **AI** | `IndexedEntity` と `AppSchema.BooksEntity` 等の違いが分からない | **§2-7** |
| 14 | `30:15` | EV | Evaluations framework を学術研究（査読論文の証拠収集）に使う想定はあるか | §3 |
| 15 | `33:11` | **AI** | CarPlay 画面のコンテキストを Siri は理解するか。画面上アクションは効くか | **§2-8** |
| 16 | `35:40` | **AI** | HomePod / audioOS で App Intents は使えるか | **§2-9** |
| 17 | `36:14` | **AI** | watchOS の App Intents の応答は iOS と 1 対 1 で一致すると期待してよいか | **§2-10** |
| 18 | `38:31` | IP | Image Playground はネット接続必須になったか。オンデバイスへフォールバックするか | §3 |
| 19 | `38:59` | — / **AI** | Apple Intelligence の更新で各自が一番楽しみにしているものは | **§2-15** / §3 |
| 20 | `45:38` | **AI** | なぜ GPT / Claude のような動的な skill 記述ではなく固定スキーマなのか | **§2-11 ★★** |
| 21 | `49:22` | EV | Evaluations framework で自分のツールが呼ばれたか確認できるか | §3 |
| 22 | `51:01` | FM | オンデバイスと大型サーバーモデル間でコンテキストを渡すときの意味的エントロピーの緩和 | §3 |
| 23 | `52:54` | EV | Evaluations framework は Foundation Models と併用必須か | §3 |
| 24 | `53:53` | **AI** | 同一開発者・同一 App Group の別アプリの donated content を retrieval できるか | **§2-12** |
| 25 | `55:33` | **AI** | スキーマ適合 entity は相互変換できるか（FileEntity ↔ PhotoEntity） | **§2-13** |
| 26 | `58:01` | **AI** | 連絡先リストを `.messages.messagePerson` に寄せるのは許容されるか | **§2-14** |
| 27 | `1:00:09` | FM | 画像入力が入っても 4096 トークン。他の入力に制約はあるか | §3 |

**App Intents 関連は 27 問中 11 問**（`1:43` を含めれば 12。`38:59` は雑談枠だが
**回答の中身は App Intents / スキーマのエコシステム像**なので §2-15 で別途扱う）。
**そのうち 4 問（`3:09` / `7:08` / `21:47` / `58:01`）が「うちのアプリは当てはまらない」という同じ不安**。

---

## 2. App Intents 関連の全回答（詳細）

### 2-0. `1:43` — 学習リソース

- **質問（逐語）**: *"What are the most useful Apple resources for learning and applying the new v27 APIs and design changes — sample projects, migration guides, design kits, or documentation?"*
- **回答の要旨**:
  - WWDC ビデオ / ドキュメント / サンプルアプリ / 技術記事。**ドキュメントページに専用の sample セクションがある**
    ≈ *"dedicated sample section of the documentation page"*
  - **今年 App Intents はセッション 5 本**（本プロジェクトが数えている「指定 6 セッション」とは数え方が違う。パネリストの発言は 5）。**複数のサンプルアプリを出し、セッションの多くがそれを使っている**ので、どう作られどう使われるかを見られる
    ≈ *"on App Intents this year, I think we had five sessions … a few different sample apps that we put out. A lot of the sessions used them in the talk"*
  - **今年ドキュメントに大きく投資した**。API の説明だけでなく「どう使うか / ユーザーにどう役立つか」を書いている
    ≈ *"the docs are not just 'here is the API', it's how to use the API, how it benefits your users"*
  - **セッションビデオに出てきたものは sample セクションに載る**
  - 過去年の WWDC も基礎教材として有効
- **使い所**: 骨子② T29b（公式サンプルを読む）の**動機づけ**として直接使える。「Apple 自身が『サンプルを見ろ』
  と言っていて、実際サンプルにしか書いていないことがあった」という流れが作れる

---

### 2-1. `3:09` — どのスキーマにも当てはまらない（時間管理アプリの例）★重要な訂正材料

- **質問（逐語）**: *"My app doesn't fit any predefined schema types. Should I use the closest related types or not support schemas for now? My time-tracking app has timer and calendar types that don't quite fit."*
- **[?time=189](https://developer.apple.com/videos/play/wwdc2026/8011/?time=189)**

**回答（Dan / James）**:

1. **app schemas は今年の新機能で、Apple が設計・ファインチューンしたもの**。システム体験に統合するために作られている
   ≈ *"schemas that are fine tuned and designed by Apple to integrate with our great system experiences"*
2. **合うものを選んで採ればいい**。timer / calendar のスキーマはあるので、**アプリの能力に合うアクションだけ**採る
3. **スキーマ外の機能はカスタム App Intent と組み合わせればいい**。App Intent を書けばそのアクションは
   **Shortcuts / Spotlight などシステム各所で使えるようになる**
   ≈ *"when you write an app intent, that action becomes available in many places across the system — the Shortcuts app, Spotlight, and more"*
4. ⭐ **「ただし、新しい Siri AI 統合のためには、スキーマのどれかを採用する必要がある」**
   ≈ *"it's important to note that for the new Siri AI integration — for integration with that — you do need to adopt one of our app schemas"*
   → **§4-1 の訂正材料。サマリーには一切書かれていない**
5. **`system` ドメインという汎用の逃げ道がある**:
   - **`system.search`** — e コマース / フードデリバリーなど検索空間のアプリ向け。
     「お気に入りのマーケットアプリで自転車を注文して」→ **アプリの検索機能へディープリンク**して、
     そこから注文フローを続けられる
   - **`system.open`** — Spotlight に donate した entity を **Siri が直接アプリで開ける**
6. **それでも合わないなら App Shortcuts**（James）:
   - 以前からある API。Intent にフレーズを付けると、**Siri / Shortcuts / Spotlight ほか数カ所で自動的に使える**
   - **iPad の Apple Pencil のタップにも割り当てられる**（← 本プロジェクトの資料に無かった出口）
   - 向いているのは「**これだけは呼ばせたい**」という**ヒーローユースケース**。フレーズが必須なので、
     覚えやすい言い回しがあるアクションに向く
7. **締めの言い回しが良い**:
   ≈ *"it's kind of a choose your own adventure. Start with the schemas. If something makes sense, use it. And then there's a ton of other experiences as well."*
8. **今年のドキュメントを見ろ**（何がスキーマで使えるか / App Shortcuts はどう動くか）

---

### 2-2. `7:08` — コアの entity / アクションがどのドメインにも写像しない

- **質問（逐語）**: *"My app's core entities and actions don't map to any predefined schema domain. What's the best way to bring them to the agentic Siri today and be ready as the platform evolves?"*
- **[?time=428](https://developer.apple.com/videos/play/wwdc2026/8011/?time=428)**

**回答（James）** — `3:09` の続きという扱いで短い:

- スキーマを見て、**ドメインの一部だけを選んで採る**
- 意味が通るなら **entity スキーマに適合させ、donate し、Spotlight とやり取りする**
  ≈ *"implement it by conforming to an entity schema and kind of donating and interacting with Spotlight"*
- ⭐ **intent のどれかが自分のアプリに合わなくても、他の恩恵は得られる**。
  **Siri AI にコンテンツについて質問させたり、新しい view annotation API でアクションさせたりできる**
  ≈ *"even if maybe one of the intents doesn't make sense in your application, you still can use Siri AI to ask questions about the content of these, or take action on it using any of our new view annotation API"*

**中心設計への効き方**: 「Intent が合わなくても Entity だけでも価値がある」= **Entity ファーストで始めてよい**
という許可。骨子② T30 の「コア entity のスキーマ適合は保留中だが list 適合 + 自前 Intent で成立している」
という本プロジェクトの状態が、**まさにこの助言どおり**。

---

### 2-3. `8:18` — システムオーケストレーター ★★中心設計の最強カード

- **質問（逐語）**: *"There's no API for a third-party app to invoke another app's intents directly — Siri/Shortcuts is the orchestrator. Can an app act as its own orchestrator, or must cross-app action route through Siri/Shortcuts?"*
- **[?time=498](https://developer.apple.com/videos/play/wwdc2026/8011/?time=498)**

**回答（Dan）** — 4 段構成:

1. **今年からシステムオーケストレーターが、複数アプリの App Intents を横断してアクションを実行できる**
   ≈ *"new this year, we have a system orchestrator that can take action from app intents from many different apps across the system"*
2. **これはプライバシーと安全性のための意図的な設計**。Apple Intelligence の中核概念は
   「**あなたに対してパーソナルかつプライベートな AI**」
3. ⭐ **App Intents に統合するとは何をすることなのかの定義**:
   ≈ *"When you integrate with App Intents, you're basically making actions from your app available to the system, and you're also modeling content in the form of app entities."*
   → **アクションをシステムに差し出す** + **コンテンツを App Entity としてモデル化する**、の 2 つ
4. **セマンティックインデックス / Spotlight 統合の性質**: index したコンテンツは
   **システムに対してのみ**利用可能になる。**他アプリからアクセスされる形でデータを共有しているわけではない**
   ≈ *"it's all sandboxed to you and the system and the system alone"*
5. **アプリ間のデータ受け渡しは `Transferable`**:
   - 開発者が採用して**何を共有するかを制御する** API
   - **双方向性**をサポート。**export したいデータ / import したいデータをそれぞれ選べる**
   - **自分のアプリが所有するデータと、他所から取り込めるデータの境界を明確にする**

**なぜ最強か**:

- 中心設計の主張「App Intents は Siri 対応の API ではなく、**アプリの機能をシステムに差し出す口**」を、
  Apple が**アーキテクチャの説明として**言っている
- 「アプリ間 API は提供しない、経路はここしかない」と**代替経路の不在まで明言**している。
  → 「やるかやらないか」ではなく **「やらないと参加できない」**
- **1 枚のスライドで対にすべき対比**: **「アクションは横断する / データは横断しない」**。
  ここを混ぜると誤解を招く（§2-12 の `53:53` と同じ話）

---

### 2-4. `10:23` — 多ターン会話に参加できるか

- **質問（逐語）**: *"With the new Siri in iOS 27, can my third-party app take part in a multi-turn conversation, or am I limited to discrete actions and entities I expose through App Intents?"*
- **[?time=623](https://developer.apple.com/videos/play/wwdc2026/8011/?time=623)**

**回答（James）**:

- **答えは Yes。これがスキーマが提供するもの**
- **できること 3 つ**: ① アプリからアクションを実行 ② **entity について質問** ③ **フォローアップ**
- ⭐ **「あなたのアプリ、あなたのコンテンツだから Siri が深く理解している」**。自然な質問と追い込みができる
- **ベータで自分のアプリで試せ**

**回答（Dan の補足）** — ここが技術的に一番重要:

- **中核に LLM が入って入力を処理している**
- ⭐ **「以前はコマンドが非常に具体的で、決まった形に嵌める必要があった。app schemas ならユーザーの
  言い回しの自由度がずっと高く、モデルが解析して適切なアクションを選ぶ」**
  ≈ *"Previously, the commands had to be very specific to form into a shape. Now with app schemas, you have a lot more flexibility into how your users can phrase requests and have our model sort of parse that information and pick the right action"*

**中心設計への効き方**: **Entity 設計の投資対効果が格上げされた**。`@Property` を丁寧に公開する意味が
「Shortcuts の変数」から「**Siri が会話で扱える語彙**」になった。
→ 99-script.notes.md D-3 の「Entity 設計 = AI に対するアプリの説明文」に直結。
→ **Shortcuts の Use Model transcript inspector（#310）で「AI から自分の Entity がどう見えているか」を
実際に覗ける**という掴みと組み合わせると強い。

---

### 2-5. `12:08` — 混ぜてよいか

- **質問（逐語）**: *"Is it OK to mix-and-match non-schema App Entities/Intents with some that match different schemas from different domains, all in the same app?"*
- **[?time=728](https://developer.apple.com/videos/play/wwdc2026/8011/?time=728)**

**回答（Dan）**:

- **絶対に Yes**。意図がまさに「**アプリの能力に合うスキーマを選んで採る**」こと
- カレンダーもリマインダーもできるアプリなら、**どちらのドメインからも選んでよい**。
  **混ぜられるし、協調して holistic な体験を届ける**

**回答（James の補足）** — こちらのほうが引用向き:

- ⭐ **「スキーマを使うか App Shortcuts を使うか search-in-app を使うか、という二者択一ではない。
  仲良く共存する」**
  ≈ *"this is not a binary choice where you have to use schemas or you have to use app shortcuts or search in app or something. They play nicely together."*
- ⭐ **「スキーマを少し、App Shortcuts を少し、という形になることを我々は想定している」**
  ≈ *"We expect people to have little bits of schema, little bits of app shortcuts."*
- **アプリの開発者が自分のユーザーを理解しているのだから、判断は開発者がする**

**中心設計への効き方**: 本プロジェクトの構成そのもの（`.reminders.list` + `.reminders.listType` +
`.system.searchInApp` + `.visualIntelligence.semanticContentSearch` + 自前 Intent 20 数本 +
App Shortcut 8 件）の**公式お墨付き**。しかも Apple が**それを想定している**と言っている。

---

### 2-6. `21:47` — スキーマは「優遇」なのか（金融ドメインが無い件）★

- **質問（逐語）**: *"Do app intent schemas give your intents an 'advantage' when integrating with Siri, or can any intent/entity be discovered by Siri AI the same way? (Notably, there's no finance schema.)"*
- **[?time=1307](https://developer.apple.com/videos/play/wwdc2026/8011/?time=1307)**

**回答（James）**:

1. ⭐ **「advantage は適切な捉え方ではない」**。
   **スキーマは、AI があなたのアプリのアクションと entity を推論するための手段**
   ≈ *"using schemas is the way that AI can reason about the actions and entities in your application"*
2. **似た質問として「Siri に影響を与えるにはどうするか」があるが、それには新しい API 群がある**
3. ⭐ **新しい intent donation の仕組み**（今年の新機能）:
   - ユーザーがアプリ内で操作しているとき、対応する App Intent がある操作をしたら donate する
   - donate されたものは **Siri が学習に使う一時的な transcript** に入る
   - 例: いつも同じ人にメッセージしていると、「Dan にメッセージして」と言ったときに
     **Siri が「Unicorn Chat の Dan にメッセージしたいのでは」と学習する**
   - ⚠️ **本プロジェクトは donation をしていない**（`perform()` が呼出元を判別できないため。骨子② T21b）
     → **この回答は T21b の代償の重さを増す材料**

**回答（Dan の補足）** — スキーマ側の利点 3 つ:

4. **App Shortcuts は自分でフレーズを書く必要がある**。一方 **スキーマなら Apple が heavy lifting 済み** —
   **サンプルフレーズの提供とモデルの学習**をやってある
   ≈ *"Apple has done the heavy lifting of essentially providing those sample phrases, of training the model"*
5. ⭐ **ドメイン内での体験の一貫性**: 純正 Messages でも、スキーマに適合したサードパーティのメッセージ
   アプリでも、**どれを使っても一貫した体験になる**
6. ⭐ **システムがユーザーの習慣を学ぶ**: 特定の同僚には特定のアプリで連絡する、という習慣を学習して、
   **iMessage を使おうとせず、いつものアプリを使う**

**回答（James の追い足し）** — 開発者向けの利点:

7. ⭐ **「App Intents を書くのはそれなりの作業。プロパティをたくさん定義するし、書くコードも多い。
   app schemas を使うと、書くコードが少し減る」**。カスタム Intent で自分が用意すべきものの一部が
   **Apple 側でやってあるので不要になる**
8. ⭐ **「スキーマを足すと、いらなくなったコードをごっそり消せる。開発者はコードを消すのが好き」**
   ≈ *"when they add the schema to their app intents, they get to delete a bunch of code … developers love deleting code"*

**ワークショップでの観察（雑談だが良い挿話）**:

- App Intents のワークショップで、初めて触る開発者が「腑に落ちる瞬間」がある。
  ≈ *"you converted my device into … the device knows so much more about my app now"*
  → **「デバイスが自分のアプリのことを知っている状態になる」**という表現は、中心設計の効能の
  言い換えとしてそのまま使える

**中心設計への効き方**:

- **スキーマ適合の有無で Intent が格下げされるわけではない**。押すべきは
  **Intent / Entity を定義すること自体**
- ただし `3:09` の「Siri AI にはスキーマが要る」と**セットで話す**（§4-1）
- **金融ドメインが無いという指摘は否定されなかった** → スキーマのカバレッジは未完成

---

### 2-7. `27:24` — `IndexedEntity` とスキーマの違い

- **質問（逐語）**: *"I'm confused by the difference between IndexedEntity and defined entities like AppSchema.BooksEntity. Should IndexedEntity be used for everything that isn't a book, calendar event, etc.?"*
- **[?time=1644](https://developer.apple.com/videos/play/wwdc2026/8011/?time=1644)**

**回答（Dan）**:

1. **スキーマは「コンテンツの形」を定義する**。持ちうるプロパティを定義する
   （本なら: 本文 / タイトル / 著者 …）
2. **`IndexedEntity` は別の API** で、**そのコンテンツをシステムのセマンティックインデックスに索引する**。
   「特定の著者の本を読みたい」のようなリクエストで **Siri AI が取り出せるようにする**
3. ⭐ **相補的**。**スキーマに適合し、かつ `IndexedEntity` に準拠し、実行時に index する呼び出しをして
   初めて最良の Siri AI 体験になる**

**回答（James の補足）**:

4. **`IndexedEntity` はカスタム entity にも使える**。Spotlight に donate すると:
   - **Spotlight の検索結果に出る**
   - **`system.open` intent と組み合わせると、結果をタップしてアプリの該当箇所へディープリンクできる**

**回答（Dan の追い足し）** — ★ここが実装判断に効く:

5. ⭐ **Spotlight を触ったことがあれば indexing key の面倒さを知っているはず。
   「本のタイトルは display name」といった対応付けを、スキーマなら Apple が全部やってある**
   ≈ *"if you've worked with Spotlight before, you have these indexing keys … the title of a book is the display name. For app schemas we've done all that work for you"*
6. **1 つの API で donate すれば、裏側は Apple が処理する**
7. **開発者がやるのは最小限の適合だけ** — entity を定義し、スキーマに適合させ、
   **プロパティに値を入れるだけ**

**中心設計への効き方 / 本プロジェクトへの示唆**:

- 骨子② **T12b（`attributeSet` と `indexingKey` の二重書きで本文が入れ替わる）と直結する**。
  Dan の 5 は「**そのキーの対応付けで悩まないで済むのがスキーマの利点**」と言っている。
  つまり **T12b でハマったのは、まさにスキーマが肩代わりしてくれる領域を手で書いていたから**
  → **T12b のオチを強化できる**: 「Apple はこの面倒さを認識していて、スキーマで肩代わりすると言っている。
    自分は肩代わりされない側（コア entity 未適合）にいたのでハマった」
- 「Entity を定義して終わり」ではなく **索引まで含めて 1 セット**

---

### 2-8. `33:11` — 画面上のコンテキスト / CarPlay

- **質問（逐語）**: *"Can Siri understand context on the CarPlay screen when connected, and can it perform on-screen actions (like 'play song on row 2, col 1') on CarPlay too?"*
- **[?time=1991](https://developer.apple.com/videos/play/wwdc2026/8011/?time=1991)**

**回答（James）**:

1. ⭐ **「画面上のコンテンツを理解して、その文脈に基づいてアクションする、というのは
   新しい Siri AI の 3 本柱のひとつ」**
   ≈ *"it's one of the three pillars of the new Siri AI — Siri can understand the content that's visible on your screen and take action based on that relevant context"*
   - ⚠️ **3 本柱の残り 2 つはこの場では明示されなかった**。他セッション（#121 / #240 / #343）と
     突き合わせる必要がある。**「3 本柱のひとつ」とだけ言うのが安全**
2. **API は 2 つ**:
   - **既存の user activity API** と直接統合する
   - **新しい view annotations API** で、**画面上のコンテンツをスキーマ適合 entity で注釈する**
3. ⭐ **体験の説明が良い**: **「SwiftUI の View を作り、entity を持ち、それらを結びつけ、喋り始めると、
   まさに思ったとおりに動く」**
   ≈ *"you build a SwiftUI view, you have your entities, you attach them, you start speaking and it does exactly what you want"*

**CarPlay について**:

4. **明言されなかった**。「具体的に欲しいものがあれば feedback / enhancement request を出してほしい」
5. **運転中は画面ではなく道路に集中してほしい**という安全側の言及。
   「**安全機能込みで** CarPlay 対応をリクエストしてほしい」
6. **開発者コミュニティからの入力を優先順位付けに真剣に使っている**、という一般論
7. （場が和む冗談: 「運転しながら feedback を出さないでください」）

**中心設計への効き方**:

- **Onscreen entities が「おまけ」ではなく柱**だと Apple が位置づけている
- ⭐ **骨子② T27 と鋭い対比になる**: **柱と言われている機能なのに、
  `.appEntityIdentifier(forSelectionType:)` は `List` に付けたときだけ効き、
  `ScrollView { VStack { ForEach } }` に付けても黙って no-op で、アプリの見た目は 1 ピクセルも変わらない**。
  → 「**柱なのに、壊れても見た目で分からない**」という 1 行が作れる
- 本プロジェクトは**詳細画面 1 本だけ annotation をテストしていて、リストのコレクション annotation は未テスト**。
  公式サンプル CosmoTunes は**面ごとに 6 本**持っている

---

### 2-9. `35:40` — HomePod / audioOS

- **質問（逐語）**: *"Are we going to be able to use App Intents with HomePod/audioOS? There's currently no beta for it."*
- **[?time=2140](https://developer.apple.com/videos/play/wwdc2026/8011/?time=2140)**

**回答**:

- **新しい Siri AI が使えるのは iPhone / iPad / Mac / visionOS。HomePod では使えない**
  ≈ *"The new Siri AI is available on iPhone, iPad, Mac, and visionOS. It is not available on HomePod."*
- ⭐ **ただし既存の App Shortcuts は以前から HomePod で動いている**。
  **アプリを呼び出す選択肢は残っている**
  ≈ *"your existing app shortcuts have worked on HomePod for a while, so we still have options for you to call into your app"*

**中心設計への効き方**: 締めの「**面は毎年増える。増えたときに何も書かなくていい状態にしておく投資**」
の実例になる。**App Shortcuts のほうが先に HomePod に届いていた**という時間差が効く。
（= 新しい面に乗るのは新 API とは限らない。既に書いてあるものが先に届くこともある）

---

### 2-10. `36:14` — watchOS のパリティ

- **質問（逐語）**: *"Can we expect watchOS responses to App Intents to match up one-to-one with iOS?"*
- **[?time=2174](https://developer.apple.com/videos/play/wwdc2026/8011/?time=2174)**

**回答（James）**: 基本 Yes。ただし **各体験をテストしていることを確認してほしい**

**回答（Dan）**:

- **新しい Siri AI は多くのプラットフォームで使える**。新旧いずれの API を採用するときも
  **サポートする全デバイスで体験をテストしてほしい**
- ⭐ **「AirPods を含めて。AirPods を忘れる人が多い」**
  ≈ *"including AirPods, you know, a lot of people forget about AirPods"*
- **走っているとき AirPods で Siri にクイックアクションをさせるのは非常に便利**

**回答（James の追い足し）** — ★実装に直結する:

- ⭐ **「あまり使われていない API がある」**として **`IntentDialog(full:supporting:)`** を挙げている
- **AirPods 使用時は画面が無いので、もう少し饒舌にしたい**。
  **iPad で snippet が綺麗に出るなら、テキストは短くしたい**
  ≈ *"when you're using your AirPods, you don't have a screen in front of you. You might want to be a bit more verbose … you're using your iPad and we have a nice snippet and you might want a shorter version of the text"*
- **`AppIntentsTesting` も今年出ている**、という言及
- **Antonio のセッション（#343）に Siri 体験のカスタマイズ / intent dialog のコツが詰まっている**ので推奨

**中心設計への効き方**:

- ⭐ **本プロジェクトの `IntentDialog(full:supporting:)` 使い分けルール（CLAUDE.md「Dialog vs 通知の
  使い分け」）が、この助言と完全に一致している**。「Apple があまり使われていないと言っている API を
  ちゃんと使っていた」という形で自慢できる、かつ**聴衆への持ち帰り**にもなる
- 「多面展開は書けば動く」ではなく **面ごとの実測が要る** = 実践パートの主題そのもの。
  **Apple 自身が「確かめろ」と言っている**のが強い
- 本プロジェクトの実例: **watchOS で assistant schema が unavailable**（Xcode 27 beta 2 で発生、
  beta 6 でも継続）。`CategoryAppEntity` / `TodoListType` は素の `AppEntity` / `AppEnum` にフォールバックし、
  `ShowTodoSearchResultsIntent` は `#if !os(watchOS)` で丸ごと除外。**まさに「1 対 1 ではなかった」実例**

---

### 2-11. `45:38` — なぜ固定スキーマなのか ★★★ 単独で 2〜3 枚の価値がある

- **質問（逐語）**: *"Why go for hard-coded schemas instead of a dynamic approach like GPT or Claude — e.g. Markdown-described skills that reference App Entities? Wouldn't that be more flexible and solve a lot of the other questions mentioned?"*
- **[?time=2738](https://developer.apple.com/videos/play/wwdc2026/8011/?time=2738)**
- 前置きの雑談が良い: ≈ *"I'm loving all the schema questions. Keep them coming."*
  → **この日の質問の中心がスキーマだったことをパネル自身が認識している**

**回答（Dan）**:

1. ⭐ **「我々が目指しているのは一貫性とプライバシー」**
   ≈ *"we're striving for consistency and privacy"*
2. ⭐ **「Apple Intelligence に対する Apple の立場は、それが personal intelligence であり、
   あなたとそれを使う人々にとって private であること」**
   ≈ *"Apple's take on Apple Intelligence is that it's personal intelligence and private to you and the people who use it"*
3. ⭐ **「スキーマによって、holistic でありながらプラットフォーム全体で標準化された体験を
   事実上保証できる」**
   ≈ *"with schemas, we're able to effectively guarantee an experience that is holistic but also standardized across the platform"*
4. ⭐ **ドメイン内での操作感の転移**（これが一番わかりやすい利点）:
   - あるドメイン（例: messaging）でスキーマを採用したアプリと Siri を使うと、
     **同じドメインのスキーマを採用した他のアプリへ自然に移行できる**
   - **「特定ドメインでの Siri の使い方を一度覚えれば、他の種類のアプリとの統合も自然に感じられる」**
     ≈ *"once you learn how to interact with Siri in a specific domain, you will just feel natural integrating with all these other kinds of apps"*

**回答（James）** — 安全性の話:

5. ⭐ **スキーマはセキュリティ上の利点も提供する**。
   **例: 誰かに送金する場合、Siri にいきなり送金させる前に確認したいはず**
   ≈ *"if you're sending money to somebody, for instance, you probably want to confirm before you're actually just having Siri send money to someone"*
6. ⭐ **「スキーマならそういうセキュリティ機能が最初から組み込まれているので、
   一貫した安全な体験が得られる」**
   ≈ *"with schemas, you get all these security features built right in so that you get a consistent, safe experience on our platforms"*
7. ⭐ **entity ownership API**（Antonio のセッション #343 で詳説されている、と名指し）:
   - アプリ内の特定のアイテム / entity は**他のユーザーと共有されていることがある**
   - **カレンダーやイベントは自分のものかもしれないし、他人と共有されているかもしれない**
   - ⭐ **「スキーマを使えばシステムがそれを知り、推論できるので、振る舞いを変えられる。
     自分だけのイベントなら削除される。他の人と共有されているなら確認を追加したい」**
     ≈ *"if it's just your event, maybe it gets deleted, but if it's shared with other people, then maybe we want to add that confirmation"*
8. **「スキーマがこの力を与えてくれる、と我々は強く感じている」**
9. **多くの開発者にとって、この種のシステムと統合するのは初めての経験になる。
   だから API を作るときは常に可能な限り安全側に倒したい**
10. **「それが trust と safety の作り方」**

**回答（司会 Ernie が拾った論点）** — ★サマリーに一切無い:

11. ⭐ **「二人ともローカライズに触れなかったが、これをやる理由の大きな部分は
    他言語へのローカライズのサポートを組み込むことだと知っている」**
12. **計画を明示的に話してはいないが、他言語へ広げようとしているのは驚きではないはず**

**回答（Dan）** — ★ここが最重要:

13. ⭐ **「それが API の力。Apple がすべてのモデル学習と自然言語文字列を提供するという heavy lifting を
    済ませている」**
    ≈ *"Apple has done the heavy lifting in terms of providing all of the model training, the natural language strings"*
14. ⭐ **「ローカライズの話でいえば、Apple はこれらの統合すべてを多数のロケールにわたって
    スケールさせられる。開発者は単に API を採用するだけで、heavy lifting は我々が引き受ける」**
    ≈ *"Apple can scale all of these integrations across many different locales … you simply adopt our API and we take care of all that heavy lifting for you"*
15. **「これからも良くしていく。それが約束」**（James）

**まとめ: 固定スキーマを選んだ理由（6 + `21:47` の 2 = 8 点）**

| # | 理由 | 出典位置 |
|---|---|---|
| 1 | **一貫性とプライバシー** — personal intelligence をユーザーに閉じておく | `45:38` |
| 2 | **プラットフォーム横断で標準化された体験を「保証」できる** | `46:21` |
| 3 | **ドメイン内で操作感が転移する** — 一度覚えれば他アプリでも通じる | `46:28` |
| 4 | **安全性が型に組み込まれる** — 送金なら確認を挟む、をシステムが判断できる | `47:02` |
| 5 | **所有権を推論して振る舞いを変えられる** — 自分の予定は削除、共有中は確認 | `47:32` |
| 6 | **ローカライズを Apple が肩代わりする** — モデル学習も自然言語文字列も提供済み | `48:32` |
| 7 | **サンプルフレーズとモデル学習が提供される**（App Shortcuts は自分で書く） | `21:47` |
| 8 | **書くコードが減る / 消せる** | `21:47` |

**なぜこれが発表で効くか**:

- 「**なぜ Apple は MCP / function calling のようにしなかったのか**」は**この発表で必ず出る質問**。
  それに対する **Apple 自身の設計判断の説明**が手に入る
- ⭐ **中心設計の思想と構造が同型**:
  - 中心設計 = 「Intent という固定の型に落とすと、ウィジェット / コントロール / Siri / Spotlight が
    全部ついてくる」
  - Apple = 「**スキーマという固定の型に落とすと、一貫性・安全性・所有権推論・ローカライズ・
    コード削減が全部ついてくる**」
  - → **どちらも「表現力を捨てて型に嵌めることの見返り」という同じ論法**
- 特に **6（ローカライズ）と 8（コードが減る）は「制約に従うと楽になる」の具体例**として強い。
  「型に嵌めると自由度が下がる」という直感を、Apple が**実利で反転させている**

**スライド化するなら**:

> **「動的な skill 記述ではなく固定スキーマを選んだ理由」**
> ① 一貫性とプライバシー ② 標準化された体験の保証 ③ ドメイン内で操作感が転移する
> ④ 確認などの安全性が型に組み込まれる ⑤ 所有権を推論して振る舞いを変えられる
> ⑥ **ローカライズを Apple が肩代わり** ⑦ サンプルフレーズとモデル学習が付いてくる ⑧ **書くコードが減る**
>
> **オチ**: 「**"表現力を捨てて型に嵌める" のは制約ではなく、Apple 側が肩代わりできる範囲を広げるための
> 取引だった**。これは今日の話全体に通じる構図です」

---

### 2-12. `53:53` — retrieval のサンドボックス境界

- **質問（逐語）**: *"Can one of my apps' Foundation Models sessions retrieve another of my apps' IndexedEntity content via SpotlightSearchTool (same developer, shared app group), or is retrieval sandboxed to the donor?"*
- **[?time=3233](https://developer.apple.com/videos/play/wwdc2026/8011/?time=3233)**

**回答**:

1. ⭐ **retrieval はアプリのサンドボックス内に限られる**。他アプリの donated content は引けない
   ≈ *"retrieval is limited to your app sandbox only"*
2. **ただし App Group の話が出ているので**: 同一開発者の 2 アプリが同じ App Group に入れば
   **ファイルやデータを共有する道はある**。「文字どおりサンドボックスを越える」わけではないが、
   **別の手段で共有する方法は見つけられるだろう**
3. ⭐ **App Intents 的な考え方では `Transferable` がその答え**:
   - **異なるファイル形式間の相互運用に最適な方法**
   - **最高忠実度から最低忠実度へ、段階的（progressive）に動作する**
   - 両アプリが似たデータ形式を共有していれば、`Transferable` でアプリ間を行き来できる
4. ⭐ **`Transferable` の安全性の説明が良い**:
   - **データ転送に明示的にオプトインする形**
   - **「アプリの小さな射影だけを共有したい、全内容ではなく、と言える」**
     ≈ *"I want to share maybe a small projection of my app, but not all the contents of my app"*
   - **開発者が、何を誰と共有するかを常に制御している**

**中心設計への効き方 / 限界カードとして**:

- **「App Intents に出しておけばシステム全体で使い回せる」の射程の限界**。
  横断するのは §2-3 の**オーケストレーター経由の「アクション実行」であって「データ取得」ではない**
- **アクションは横断する / データは横断しない / データを渡したいなら `Transferable` で明示的に**、
  という 3 段の整理が作れる

---

### 2-13. `55:33` — スキーマ適合 entity の相互変換

- **質問（逐語）**: *"Are schema-bound entities interchangeable — can an app's FileEntity become a PhotoEntity and vice versa, e.g. through Transferable?"*
- **[?time=3333](https://developer.apple.com/videos/play/wwdc2026/8011/?time=3333)**
- （質問者自身が `Transferable` だと推測していて、パネルが「その通り」と肯定する形）

**回答（Dan）**:

1. **`Transferable` の面白さは、アプリがサポートするデータ変換を全部指定できること**
2. ⭐ **Unicorn Chat（ダウンロード可能な公式サンプル）が実例**:
   - メッセージが**テキストにもなれば、添付を含むこともできる**
   - アプリは **テキストの export をサポートし、ファイルも写真も export できる**
3. ⭐ **ペイロードの型に応じて動的に transferability を提供することもできる**
4. ⭐ **その先の効果が重要**: **メッセージを写真として export すると、その写真は
   Photos アプリにも import できるし、`.photos` スキーマを採用した任意のサードパーティ写真アプリにも
   import できる**
   ≈ *"when you export a message as a photo … this photo can now be imported into the Photos app, but it can also be imported into any other third party photo app that adopts our photo schemas"*
   → **スキーマ適合が「相互運用のプロトコル」として働いている**という、一番わかりやすい例

**回答（James の補足）**:

5. ⭐ **`FileEntity` プロトコルがあり、すべての App Entity で使える**。
   ファイルベースの形式が必要なときのために設計されている。詳細はドキュメント参照
   - ⚠️ **本プロジェクトの資料に `FileEntity` の記述が無い**。未調査項目

**中心設計への効き方**: 本プロジェクトの `Transferable` + `ValueRepresentation` 検証（#44）と同じ話。
公式サンプル読み合わせ（骨子② T29b）との接続点。
**「スキーマ = 相互運用のプロトコル」という読み筋は §2-11 の理由 ③（ドメイン内での転移）と同じ構造**。

---

### 2-14. `58:01` — 不完全な一致（`.messages.messagePerson`）

- **質問（逐語）**: *"I manage a list of contacts; a close but imperfect match is the .messages.messagePerson schema. Is that acceptable to participate in the new Siri?"*
- **[?time=3481](https://developer.apple.com/videos/play/wwdc2026/8011/?time=3481)**

**回答（Dan）**:

1. **絶対に Yes**
2. **この API の良さは、アプリがサポートする機能と能力を、我々が用意したスキーマに基づいて
   選んで採れること**
3. ⭐ **`messagePerson` スキーマは、メッセージ機能をサポートするためにアプリから連絡先を
   export するためのもの**。**Unicorn Chat がこれを使っている**ので、サンプルコードで
   「スキーマを使ってコンテンツをどうモデル化し、Siri と Apple Intelligence に露出させるか」を見られる
4. ⭐ **どのスキーマも合わないなら、より汎用的な `system.search` がある**。
   アプリの検索機能を Apple Intelligence に露出できる。
   **e コマース / フードデリバリーなどに向く**
5. ⭐ **さらに App Shortcuts も常に使える**。より汎用的に App Intents を統合する方法
6. ⭐ **ただし App Shortcuts はカスタムなので、自分のアプリの体験に合うサンプルフレーズを
   提供する必要がある。そこが app schemas との違いで、スキーマなら Apple が heavy lifting をするので
   フレーズを用意しなくていい**

**回答（James）**: **この質問が何度も出てきているのは良いこと。みんなが考えている証拠**

**中心設計への効き方**: 「うちは当てはまらない」への 3 段の逃げ道が最も整理された形で出ている:
**① 不完全でも近いスキーマに寄せる → ② `system.search` などの汎用ドメイン → ③ App Shortcuts**。
**本プロジェクトはこの 3 段を全部使っている**（`.reminders.list` に寄せる / `.system.searchInApp` /
App Shortcut 8 件）。

---

### 2-15. `38:59` — 「一番楽しみなもの」に現れるエコシステム像 ★「Apple がこれを重要視している」が一番素直に伝わる箇所

- **質問（逐語）**: *"What are each of you most excited about regarding the updates to Apple Intelligence?"*
- **[?time=2339](https://developer.apple.com/videos/play/wwdc2026/8011/?time=2339)**（App Intents の話が出るのは **`43:36` 以降**）

**位置づけ**: 雑談枠の質問なので、**論拠の強さは §2-3（システムオーケストレーター）に劣る**。
一方で §2-3 が「**構造としてそこしか経路が無い**」を示すのに対し、ここは
「**Apple がどういう状態を到達点として思い描いているか**」が最も素直に出る。**両者を対にすると
「構造」＋「意志」の両輪になる**。

**Dan の回答（`43:36`–`44:30`）**:

1. 今年の Siri の進歩と、**開発者が採用するための API 群**という並べ方をしている
   ≈ *"we have a lot of great APIs this year for developers to adopt and bring Siri to their app"*
2. ⭐ **エコシステム像**（ここが本命）:
   ≈ *"I can't wait to see how we'll eventually get to this ecosystem where you have all of these apps
   that are deeply integrated with Siri and Apple Intelligence providing content to the semantic index,
   so that people can ask natural questions about content from all these different kinds of apps and
   get answers instantly."*
   → **「全アプリがセマンティックインデックスにコンテンツを供給している状態」を到達点として語っている**
3. ⭐ **`44:16` — "bicycle for the mind"**:
   ≈ *"when you integrate with intent schemas, Siri taking actions on a variety of apps across many
   different domains — I'm just really excited to see sort of like the bicycle for the mind. You get
   this ecosystem that is deeply integrated in Siri, taking action across many different apps."*
   → Apple の歴史的レトリックを、**App Intents / スキーマの到達点に対して使っている**
4. ⭐ **`44:49`**: ≈ *"I can't wait for all my favorite apps to adopt our APIs and then just be able to
   have Siri perform all these actions."*
   → ⚠️ **話者は断定しない**。直前（`44:30`）で別のパネリストが *"I want to change my answer to that"* と
   割り込んでおり、**字幕は話者交代を区切っていない**

**同じトーンの補強（セッション終盤で 2 回繰り返される）**:

- **`59:45`** ≈ *"I can't wait to see what people build with these integrations and these APIs."*
  （§2-14 の直後、Dan / 司会）
- **`1:03:32`** ≈ *"we can't wait to see what you build"*（クロージング）

**引用上の注意**:

- ⚠️ **全文が字幕由来の粗起こし**。スライドに載せるなら `?time=2616` / `?time=2656` を視聴して逐語確認する
- ⚠️ **Apple 提供 Summary はこの回答を「通話中に Mail からフライト確認番号を引く」の一行に圧縮していて、
  エコシステム像は落ちている**（§3 の `38:59` 行）。つまり **Summary 経由では絶対に出てこない材料**で、
  字幕を復元していないと拾えない
- ⚠️ **"bicycle for the mind" を引くなら、意図的な引用だと分かる形にする**。Apple の文脈を知らない聴衆には
  唐突に見える

**使い所**:

- **骨子① S24（中心設計へ）の導入か締め**。§2-3 の「App Intents に統合するとは、アクションを
  システムに差し出し、コンテンツを Entity としてモデル化すること」（構造の定義）に、
  **「そうしたアプリが揃った状態を Apple は到達点と呼んでいる」**（意志）を重ねる
- **想定 Q&A「なぜ今やるのか / 様子見でいいのでは」への回答**。§2-1 / §2-2 / §2-14 の
  「完璧を待つな、今始めて後で広げろ」（§5-2 の 3）と同じ方向を、**パネリストの動機の側から**言える

---

## 3. App Intents 以外の回答（記録用 / 参考）

App Intents 中心設計には直接効かないが、質疑で振られる可能性と、後から探し直す手間を省くために残す。
**以下は Apple 提供 Summary ベース**（字幕からの深掘りはしていない）。

| 位置 | 論点 | 要旨 |
|---|---|---|
| `13:26` | FM のバックグラウンド予算 | **フォアグラウンドではオンデバイスモデルにレート制限は無い**（事実上無制限）。バックグラウンドでは負荷が高いときシステムが throttling する。**固定の予算値は無い**ので、**rate-limited エラーを catch して**（それがシステムが負荷を知らせる方法）作業を分割 / 延期する |
| `14:47` | FM のエラー分類 | 今年の `LanguageModel` プロトコルが共通の `LanguageModelError` を定義（rate limiting / refusals など）。**PCC モデルには quota-usage プロパティ**があり上限への近さを確認できる。加えてモデル固有のエラーが投げられるので、再試行可能か終端かを区別できる |
| `16:01` | guardrail 誤爆 | **Evaluations framework の model-judge evaluator** で安全性ルーブリック（例: 1–4 スケール）を作り、どのプロンプトが guardrail に触るかを系統的に評価する。オンデバイスモデルが過剰反応するなら、**より高性能な PCC モデルにチェックを回して**何が flag されるか理解しプロンプトを改善する |
| `17:38` | 動画入力 | モデルは `LanguageModel` プロトコルで能力を宣言し、**vision もそのひとつ**（今年オンデバイス / PCC 両方が画像入力に対応）。**PCC モデルは light / moderate / deep の推論レベルを持つ**。**組み込みの動画入力は無い**が、**custom segment API でカスタムモダリティに対応**するか、**Vision framework 等で動画をテキストの transcript に前処理**して食わせる |
| `26:00` | Image Playground | **`ImagePlaygroundStyle.all` でフォトリアルなスタイルにアクセスできる**。**PCC 上で動く**のでより強力なモデル。専用の WWDC ビデオとドキュメントあり |
| `30:15` | Evaluations の学術利用 | **言語モデルに限らず任意の確率的システムを評価できる**ように設計されている。線形回帰や分類器のような従来型 ML にも適用可。**研究指標にも使える** |
| `38:31` | Image Playground のオフライン | **常にインターネット接続が必要**（PCC のサーバーモデルを使うため）。**オンデバイス生成にフォールバックしない** |
| `38:59` | 各自が楽しみなもの | 個人的な推しを共有。**目玉は通話中に出るインテリジェンス機能** — 通話しながら Mail からフライトの確認番号を引っ張ってくるなど。⚠️ **Summary はここで打ち切っているが、字幕には `43:36` 以降に App Intents のエコシステム像がある** → **§2-15** |
| `49:22` | ツール呼び出しの評価 | **Yes**。設定済み `LanguageModelSession` の transcript を渡して **tool-call evaluator** を使う。**期待値 / アサーションの仕組みで、ツールが呼ばれたか・順序・プロパティ・値まで検証できる** |
| `51:01` | 意味的エントロピー | Foundation Models の dynamic profiles と context window の違いに関係する。**オンデバイスのシステムモデルは 4K、PCC モデルは 32K**。フレームワークが**モデル間の context の運び方を管理**して情報を保持する |
| `52:54` | Evaluations と FM の依存 | **不要**。任意の確率的システムを評価できる。**例外は tool-call evaluator** で、現状 Foundation Models の transcript が必要（他プロバイダ向けのより汎用的な変換は作業中）。それ以外は任意の言語モデルで評価できる |
| `1:00:09` | トークン予算 | **オンデバイスモデルの 4096 トークン予算は画像対応でも変わらない**。**画像 1 枚がおよそ 200 トークン**（Instruments で測れる）。残りを instructions とプロンプトに使える。**大きな入力 + 小さな出力でも、その逆でも、好きに配分してよい** |

---

## 4. 既存メモの修正が必要な発見

### 4-1. ★「新しい Siri AI との統合にはスキーマ適合が必要」と明言している

`3:09` の回答の中に、**Apple 提供 Summary には書かれていない**一文がある:

> ≈ *"it's important to note that for the new Siri AI integration — for integration with that — you **do need to adopt one of our app schemas**."*

これは以下と**衝突する**:

- [99-script.notes.md](99-script.notes.md) F. 想定 Q&A —「Apple Intelligence / Siri AI 対応は必須？
  → **必須ではない。App Schema 適合は任意**」
- CLAUDE.md 拡張ロードマップ節の同趣旨の記述

**正しい整理は 2 層**:

| 層 | 必要なもの | 届く先 |
|---|---|---|
| **App Intents（スキーマ不要）** | `AppIntent` / `AppEntity` / `EntityQuery` / `AppShortcutsProvider` / `IndexedEntity` | Shortcuts / Spotlight / ウィジェット / コントロールセンター / ライブアクティビティ / Apple Pencil / 従来の Siri フレーズ / Visual Intelligence |
| **App Schema 適合** | 上記 + `@AppEntity(schema:)` / `@AppIntent(schema:)` / `@AppEnum(schema:)` | **新しい agentic Siri（Siri AI）** — 多ターン会話・自然な言い回し・確認や所有権の自動処理・ローカライズ・ドメイン横断の一貫性 |

- ⚠️ **`21:47` の「advantage という捉え方は違う」と矛盾しない**。
  **スキーマは Siri AI への入場券であって、既存 Intent を格下げするものではない**
- ✅ **Q&A 回答の差し替え案**:
  > 「**App Intents 自体はスキーマ無しで十分価値があります**（Shortcuts / Spotlight / ウィジェット /
  > コントロール / ライブアクティビティ…）。ただし **新しい agentic Siri に参加するにはスキーマ適合が
  > 要る**と Group Lab で明言されています。なので "任意" ではなく **"どこまで行きたいかで決まる"** が
  > 正確です。本プロジェクトは list 適合まで行って、コア entity は SDK 側の都合で保留中です。」
- ⚠️ **根拠が字幕由来**。スライドに断定で書くなら `3:09` を視聴して逐語確認する

---

### 4-2. 骨子① S14 / S21 の「任意適合」の言い切り

上記と同じ理由で修正済み（2026-08-22）。**「檻ではなく辞書」という line は残せる**。
2016 との本質的な違いは「**逃げ道が複数用意されていること**」（`3:09` / `7:08` / `58:01` の 3 段）。

---

### 4-3. 骨子② T21b（donation）の代償が重くなった

`21:47` で Apple は **新しい intent donation を「Siri に影響を与える主要な手段」として押している**。
ユーザーの操作を donate すると Siri が学習し、「いつもこのアプリでこの人に連絡する」を覚えて
**純正アプリではなくそのアプリを選ぶ**ようになる。

→ **中心設計を徹底すると、Apple が今年一番推している導線を 1 本落とすことになる**。
T21b のオチをこう変えられる:

> 「これはバグではなく、設計を徹底したことの帰結です。しかも Apple は今年、この donation を
> **『Siri に影響を与える主要な手段』として推している**。つまり中心設計は、**今年一番の推し機能を
> 1 本諦める**ことになります。そこまで引き受けるかどうか、という話です」

---

### 4-4. 資料に無かった項目 → **全 4 件、調査完了（2026-08-22）**

#### ① 新しい Siri の「3 本柱」— **判明**

Group Lab（`33:11`）が「3 本柱のひとつ」と言っていたものの正体は、**#240 の冒頭で明示されている**:

> **`1:51`** *"This year, Siri becomes more powerful in three key ways."*
> — wwdc2026-240「Build intelligent Siri experiences with App Schemas」`1:51`–`2:37`

| # | 柱 | 内容 | 例（Apple のデモ） |
|---|---|---|---|
| **①** | **entities へのアクセス** | アプリの中の**意味のある実コンテンツ**に到達する。「何が meeting なのか」「どの meeting が関連するか」「どのプロパティを返すか」をアプリの定義から理解する | 「次のミーティングはいつどこ？」に **Siri が直接答える** |
| **②** | **intents によるアクション実行** | アプリがサポートするアクション・必要なパラメータ・**いつ実行して安全か**を Intent が記述する。**言語理解は Siri が担当し、アプリはアクションに集中する** | 「最新のレポートを Mary に送って」 |
| **③** | **onscreen context の理解** | 画面上に見えているものを理解し、その文脈でアクションする | Group Lab `33:11` が語っていたのはこれ |

⭐ **これは骨子の主張とそのまま一致する**: **Entity（名詞）+ Intent（動詞）+ 文脈**。
つまり Apple は **「Siri が強くなる 3 つの方向」を Entity / Intent / Onscreen で説明している**。
**骨子① S23（何を宣言するか: 動詞 → 名詞 → 表示 → 文脈）の裏付けとして直接使える。**

- ⚠️ Group Lab は "three pillars"、#240 は "three key ways" と言い方が違う。**#240 のほうが一次ソースとして強い**
  （編集済みトランスクリプトがある / セッションの構成そのものがこの 3 分割になっている）
- 併せて #240 `9:41`–`11:59` に **「Intent と App Schema の関係」の最良の説明**がある:
  - Intent を定義するだけで **Shortcuts / Spotlight / ウィジェットなどに出る。Siri 無しでも価値がある**
  - **スキーマは App Intents の "specialization"**。≈ *"They're still App Intents, but shaped in a way that Siri knows how to process."*
  - **ドメインは「アプリと Siri の間の契約のカテゴリ」** ≈ *"categories of contracts between your app and Siri"*
  - → **§4-1 の 2 層整理を、Apple 自身の言葉で説明できる**。「スキーマは別物ではなく App Intents の特殊化」

#### ② `FileEntity` — **判明。ただし 2024 の API で、本アプリには非該当**

- **初出は WWDC 2024**（#10134 `9:01`–`10:40`）。**2026 の新機能ではない**
- 現行の宣言（公式ドキュメント）:
  ```swift
  protocol FileEntity: AppEntity where Self.ID == FileEntityIdentifier
  ```
  - **`static var supportedContentTypes: [UTType]` の提供が追加要件**
  - **`id` は `FileEntityIdentifier` でなければならない**。URL から作るか、ファイル未作成なら **draft identifier** として作る
  - ⭐ **`FileEntityIdentifier` は URL の bookmark data を使うので、ファイルが移動・改名されても entity は有効なまま**
- 効能: ≈ *"Siri and Shortcuts can facilitate secure access to your file in other apps, allowing them to directly access the file"*（#10134 `10:05`）。
  例として「別アプリの `RotateImageIntent` が、自分の `PhotoEntity` の裏にあるファイルに安全にアクセスして回転させる」
- ⭐ **`files` ドメインのスキーマが存在する**（`@AppEntity(schema: .files.file)`）。
  **本プロジェクトの資料はこのドメインの存在自体を把握していなかった**。対応する system experience は **Siri / Shortcuts**
- **`IntentFile` は別物**。ディスク上 / メモリ上のデータをパラメータとして渡すための型（`init(data:filename:type:)` / `init(fileURL:filename:type:)`）
- **本アプリへの適用**: ❌ **非該当**。Todo はファイルベースのコンテンツを持たない（`FileEntity` はドキュメント系 / ファイル管理系アプリ向け）。
  **「未着手の候補」ではなく「対象外」に分類するのが正しい**
- **発表での使い所**: Group Lab `55:33` の「スキーマ = 相互運用のプロトコル」の具体例として。
  **メッセージを写真として export すると、`.photos` スキーマを採用した任意のサードパーティ写真アプリに import できる** ——
  この「アプリ間でコンテンツが流通する」話の下回りが `FileEntity` / `Transferable`

#### ③ `EntityOwnership` / `OwnershipProvidingEntity` — **判明。用途は「確認ダイアログの出し分け」**

公式ドキュメントで用途がはっきりした:

```swift
protocol OwnershipProvidingEntity: AppEntity {
    var ownership: EntityOwnership { get }
}
```

- **`EntityOwnership` は OptionSet 的なフラグ**: **`.public`（公開）/ `.shared`（特定の共同編集者と共有）/ `.unknown`（不明・未指定）**。
  組み合わせ可（`[.shared, .public]`）
- ⭐ **公式の説明**: 削除・更新のような破壊的 / センシティブな操作について、アプリ側が確認を求められるのに加え、
  **Apple Intelligence と Siri も確認を求めうる**。`OwnershipProvidingEntity` に準拠すると、
  **共有 / 公開されている entity にアクションするとき、システムが適切な文脈つきの確認ダイアログを出す**
- 公式サンプルは `@AppEntity(schema: .photos.album)` に対して `isSharedWithFamily` / `isPublicAlbum` から
  `ownership` を組み立てている
- **Group Lab（`45:38`）の説明と一致**: 「自分だけのイベントなら削除される。他の人と共有されているなら確認を追加したい」
- ⭐ **骨子② への効き方が大きい**:
  - **T20（`requestConfirmation` を含む Intent はアプリ内 `Button(intent:)` から呼べない）と対になる**。
    `requestConfirmation` が**アプリが明示的に取る確認**なのに対し、`OwnershipProvidingEntity` は
    **システムが所有権を見て自動で出す確認**。**「確認を取る」に 2 系統ある**という整理ができる
  - **§2-11 の理由 ⑤（所有権を推論して振る舞いを変えられる）の実体がこれ**。
    「スキーマに嵌めると、確認を出すかどうかの判断までシステムが肩代わりする」の具体
- **本アプリへの適用**: ⚠️ **現状は非該当**。Todo は個人利用主体で共有機能が無いため `ownership` は常に
  `.unknown`（または空）になる。**「優先度低」の判断は妥当だったが、理由が変わる** ——
  「用途が分からないから低」ではなく **「共有機能が無いから該当しない」**。
  **共有 Todo を実装するなら真っ先に必要になる**、と言い切れる

#### ④ Apple Pencil — **判明。ただし Group Lab の言い方が不正確**

- Group Lab の字幕は ≈ *"you can even use it on the iPad if you want to tap on an Apple Pencil"*（`3:09`）だが、
  **実際の機能は「タップ」ではなく `Apple Pencil Pro` の「スクイーズ（squeeze）」**
- 一次ソース:
  - wwdc2024-10134 `0:11` — Action Button と並んで **"the new Apple Pencil squeeze"**
  - wwdc2024-10210 `4:34` — 「今年は Camera capture、**Apple Pencil Pro: squeeze** を追加」
  - wwdc2025-244 `9:04` — App Shortcuts は **"the Action Button or Apple Pencil squeeze"** から実行するよう設定できる
- ⭐ **一番強い事実**（wwdc2024-10210 `22:11`/`22:30`）:
  - Spotlight と Siri は**自動**。ユーザーはアプリを入れる以外に何もしなくていい。
    カスタマイズしたければ **Action Button と Apple Pencil Pro でも App Shortcuts が使える**。
    ≈ *"So that's four features for one piece of code."*
  - ⭐ **「既に App Shortcuts があるなら、Apple Pencil Pro でもう動いている。去年 Action Button で
    自動的に動いたのと同じ」** ≈ *"if you have existing App Shortcuts? They already work with Apple Pencil Pro, same as they automatically worked with the Action button last year."*
- **発表での使い所**: **骨子① S16「出口は毎年勝手に増える」の最良の実例**。
  **「新しい出口が増えたとき、既に書いてあるものが何も書かずに乗った」**という証言が Apple 自身から出ている。
  HomePod（`35:40`、App Shortcuts が先に届いていた）と**同じ構図が 2 回起きている**
- ⚠️ **本プロジェクトの資料（CLAUDE.md 展開マトリクス / 骨子① S16）に Apple Pencil が入っていない**。
  「物理的なトリガーが自然 → Action Button」の行に **Apple Pencil Pro squeeze** を足すべき
- ⚠️ **スライドで「タップ」と書かない**。Group Lab の字幕は口語の粗起こしで、正しくは **squeeze**

---

## 5. 全体としての読み筋

### 5-1. 数字で言えること

- 全 27 問中 **App Intents / スキーマ関連が 11 問**（`3:09` / `7:08` / `8:18` / `10:23` / `12:08` /
  `21:47` / `27:24` / `33:11` / `35:40` / `36:14` / `53:53` / `55:33` / `58:01` — 重複を除くと 13 だが
  `35:40` / `36:14` はプラットフォーム質問なので分類次第）
- **そのうち 4 問（`3:09` / `7:08` / `21:47` / `58:01`）が「うちのアプリは当てはまらない」という同じ不安**
- パネル自身が言及: ≈ *"I'm loving all the schema questions"* / *"this question … has come up a few times"*
  → **この日の開発者の関心の中心がスキーマ適合の可否だった**

---

### 5-2. Apple の回答は 5 つの方向に収束している

1. **経路はここしかない** — システムのオーケストレーターに参加する手段が App Intents（`8:18`）
2. **固定スキーマは制約ではなく取引** — 一貫性・安全性・所有権推論・ローカライズ・コード削減を
   Apple が肩代わりする見返りに、型に嵌める（`45:38` / `21:47` / `27:24`）
3. **完璧を待つな** — 部分一致でいい、`system` ドメインでもいい、App Shortcuts でもいい。
   **今始めて後で広げろ**（`3:09` / `7:08` / `58:01`）
4. **混ぜてよい** — スキーマ / App Shortcuts / 自前 Intent の併存が想定されている（`12:08`）
5. **面ごとに確かめろ** — パリティは目標であって前提ではない。AirPods を忘れるな（`36:14`）

---

### 5-3. 反証・限界として正直に置いておくもの

| 事実 | 位置 | 意味 |
|---|---|---|
| **「advantage（優遇）」という捉え方は違う**とわざわざ否定している | `21:47` | 「スキーマに適合すれば Siri で有利」という煽り方はできない。⚠️ ただし `3:09` では「Siri AI にはスキーマが要る」とも言っている。**2 層に分けて話す** |
| **金融ドメインのスキーマは存在しない**（質問者の指摘。否定されなかった） | `21:47` | スキーマのカバレッジは未完成。だから「スキーマ無しでも discoverable に保て」が回答になっている |
| **CarPlay の on-screen 対応は明言されなかった**（feedback を出せ、運転中は道路に集中） | `33:11` | 「どこでも動く」は言い過ぎ。**面ごとに未対応がある** |
| **HomePod は新 Siri AI の対象外** | `35:40` | 同上。ただし App Shortcuts は届いている |
| **retrieval はアプリのサンドボックス内に閉じる** | `53:53` | **アクションは横断する / データは横断しない**。データを渡すなら `Transferable` で明示的に |
| **watchOS のパリティは「目指す」であって保証ではない** | `36:14` | 本プロジェクトの watchOS assistant schema unavailable が実例 |

---

### 5-4. 発表用の 1 行候補

> **「Apple は今年、"アプリの機能をシステムに差し出す口" を App Intents に一本化した。そのうえで
> 開発者に繰り返し言っていたのは "完璧に当てはまらなくても今から出せ" だった。」**

別案（固定スキーマの話を軸にするなら）:

> **「"表現力を捨てて型に嵌める" のは制約ではなく、Apple 側が肩代わりできる範囲を広げるための取引。
> App Intents 中心設計も同じ論法で、だから相性がいい。」**

---

## 6. 各骨子への組み込み候補（尺は考慮していない / 全部列挙）

### 骨子① への追加候補

| 挿入先 | 使う材料 | 内容 |
|---|---|---|
| **S14 / S21** | §4-1 / §4-2 | **修正済み**。スキーマ適合を 2 層で話す |
| **S18（2026 / iOS 27）** | §2-11 | **固定スキーマを選んだ 8 つの理由**。「なぜこの形なのか」を歴史で説明する骨子① の主題そのもの。**S18 の後に 1 枚足すのが自然** |
| **S18 or 新カード** | §2-4 | **「以前はコマンドを決まった形に嵌める必要があった。今は言い回しの自由度が高い」** — SiriKit 時代のフレーズ登録との対比になる |
| **S16（出口の増え方）** | §2-9 / §4-4 | **HomePod には App Shortcuts が先に届いていた** / **Apple Pencil のタップにも割り当てられる** — 「出口は毎年勝手に増える」の実例が 2 つ増える |
| **S22（どこで実行されるか）** | §2-3 | **システムオーケストレーターの登場**は「実行主体」の軸に新しい段を足す。2016 = INExtension / 2022 = アプリ本体 / 2026 = **システムが横断的に選ぶ** |
| **S23（何を宣言するか）** | §2-3 / §2-7 | 「アクションを差し出す + コンテンツを Entity としてモデル化する」という Apple 自身の定義。**「アプリの世界観をシステムに説明する」への裏付け** |
| **S24（中心設計へ）** | §2-3 | **「App Intents に統合するとは、アクションをシステムに差し出し、コンテンツを Entity としてモデル化すること」** — 中心設計の 3 原則の直前に置くと橋渡しになる |
| **S24 の締め** | §2-15 | **「全アプリがセマンティックインデックスにコンテンツを供給している状態」を Apple が到達点として語っている**（`43:36` / *"bicycle for the mind"*）。§2-3 の「構造」に「意志」を重ねる |

---

### 骨子② への追加候補

| 挿入先 | 使う材料 | 内容 |
|---|---|---|
| **T12b（Spotlight 二重書き）** | §2-7 | **Apple 自身が「indexing key の対応付けはスキーマなら肩代わりする」と言っている**。→ ハマったのは肩代わりされない側にいたから、というオチの強化 |
| **T18 / T27（フィードバック / 検証）** | §2-10 | **`IntentDialog(full:supporting:)` を Apple が「あまり使われていない API」として名指しで推奨**。本プロジェクトの運用と一致している |
| **T21b（donation）** | §4-3 | **代償が重くなった**。今年一番の推し機能を 1 本諦めることになる |
| **T27（onscreen annotation）** | §2-8 | **「3 本柱のひとつ」なのに、付け先が違うと黙って no-op** という対比 |
| **T22–T24（プラットフォーム）** | §2-10 | Apple 自身が「1 対 1 と仮定せず全デバイスでテストしろ / AirPods を忘れるな」と言っている |
| **T29b（サンプルを読む）** | §2-0 | Apple が「**ドキュメントに専用の sample セクションがある / セッションで使ったサンプルはそこに載る**」と案内している。**サンプルを読むのは公式の推奨経路** |
| **T30（効能と代償）** | §2-3 / §5-3 | 効能に「**システムオーケストレーターに参加できる（他に経路が無い）**」、代償に「**アクションは横断するがデータは横断しない**」を足せる |
| **新カード候補** | §2-11 | **「なぜ固定スキーマなのか」を第8部の総括に置く**。中心設計の論法と同型であることを示して締める |

---

### 想定 Q&A への追加

| 質問 | 材料 |
|---|---|
| なぜ MCP / function calling ではないのか | §2-11 全体 |
| なぜ今やるのか / 様子見でいいのでは | §2-15（Apple の到達点の語り）＋ §2-3（他に経路が無い）＋ §5-2 の 3（完璧を待つな） |
| Apple Intelligence 対応は必須か | §4-1 の 2 層整理 |
| 他アプリのデータを使えるのか | §2-3 + §2-12（アクションは横断 / データは横断しない / `Transferable`） |
| スキーマに適合できないアプリはどうすれば | §2-1 / §2-2 / §2-14 の 3 段の逃げ道 |
| HomePod / CarPlay / Watch は | §2-8 / §2-9 / §2-10 |
| 自分の Entity が AI にどう見えているか確認したい | #310 の Use Model transcript inspector（99-script.notes.md D-3） |
