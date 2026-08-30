# スライド骨子① App Intents とは何か — SiriKit から 10 年の変遷

> **狙い**: App Intents を「Siri 対応のための API」ではなく、**「アプリの機能をアプリの外へ出すための宣言的な言語」** として理解してもらう。
> そのために、なぜこの形になったのかを SiriKit からの流れで説明する。
>
> **想定尺**: 15〜20 分（S01〜S24。時間が足りなければ S05 / S08 / S19 を落とす）
> **想定聴衆**: iOS 開発者。Siri / Shortcuts は「知ってはいるが触っていない」層。
>
> 各スライド: `見せるもの` / `話の要点` / `出典`。⚠️ は発表前に確認したい箇所。

---

## 構成の全体像

```
第0部  問いの提示            S01–S02   「アプリの外」という問題
第1部  SiriKit 時代 2016–21  S03–S09   ドメインの檻と .intentdefinition
第2部  App Intents 誕生 2022 S10–S12   分水嶺：Swift だけで書けるようになった
第3部  拡張期 2023–24        S13–S16   ウィジェット、そして Apple Intelligence
第4部  成熟期 2025–26        S17–S20   見せ方・実行制御・つながり
第5部  10年の総括            S21–S24   3 つの軸で振り返る → 中心設計へ
```

貫くメッセージ（3 回言う: S02 / S21 / S24）:

> **「誰がアプリの語彙を決めるか」が、Apple から開発者へ移り、そしてシステム（AI）との共有語彙へ変わってきた。**

---

## 第0部 問いの提示

### S01. タイトル

- **見せるもの**: タイトル + 「SiriKit から App Intents まで、Apple が 10 年かけて出した答え」
- **話の要点**:
  - 今日は App Intents の話。ただし API の使い方から入らず、**「なぜこの形なのか」**を歴史から入る
  - 歴史を知ると、今の API の妙な制約が「そういう経緯か」で腑に落ちる
- **出典**: —

---

### S02. アプリ開発者がずっと持っていた問題

- **見せるもの**: 「アプリを開かずに、アプリの機能を使いたい」の 1 枚図。声 / ウィジェット / 検索 / 時計 / コントロール → アプリの中心にある機能
- **話の要点**:
  - アプリの機能は普通 UI の奥にある。UI を開かないと呼べない
  - でもユーザーは「アプリを開かずに使いたい」場面が多い（声・ホーム画面・検索・時計・車の中）
  - この 10 年、Apple はこの問題に **3 回、違う答え**を出している（SiriKit → Siri Shortcuts → App Intents）
  - 通底する問い: **アプリができることを、システムにどう伝えるか**（= 語彙の共有問題）
- **出典**: —

---

## 第1部 SiriKit 時代（2016–2021）「ドメインの檻」

### S03. 前史: Siri は開発者に閉じていた（2011–2015）

- **見せるもの**: 2011 iPhone 4S / Siri 登場 → 2016 まで開発者向け API なしのタイムライン
- **話の要点**:
  - Siri は 2011 年から存在したが、**5 年間サードパーティは一切繋げなかった**
  - つまり「アプリの機能を声で呼ぶ」は長らく Apple 純正アプリだけの特権だった
- **出典**: 一般に既知の事実（⚠️ 具体的な年号だけ確認）

---

### S04. 2016 / iOS 10 — SiriKit 登場

- **見せるもの**: `Intents.framework` + `IntentsUI.framework` / `INExtension` / `resolve → confirm → handle` の 3 段
- **話の要点**:
  - 実体は 2 つのフレームワーク: **Intents**（機能連携）と **IntentsUI**（Siri UI のカスタム表示）
  - 実装形態は **Intents App Extension**（`INExtension`）。アプリとは**別プロセス**、別サンドボックス
  - Siri が渡してくる `INIntent` オブジェクトを、`resolve`（パラメータを解決）→ `confirm`（確認）→ `handle`（実行）の 3 段で処理する
  - この 3 段構えは、実は今の App Intents（`requestValue` / `requestConfirmation` / `perform`）にそのまま受け継がれている
- **出典**: Apple 公式 [SiriKit / Creating an Intents App Extension](https://developer.apple.com/documentation/SiriKit/creating-an-intents-app-extension) / wwdc2022-10032 `0:33`「In iOS 10, we introduced the SiriKit Intents framework」

---

### S05. 2016 の決定的な制約: ドメイン

- **見せるもの**: 6 ドメインを並べた図（通話 / メッセージ / 支払い / 写真検索 / 配車 / ワークアウト）+ その外側に「あなたのアプリ」
- **話の要点**:
  - SiriKit では、できることが **Apple が定義した「ドメイン」の中だけ**に限られていた
  - iOS 10 時点のコアは 6 ドメイン: **VoIP 通話 / メッセージ / 支払い / 写真検索 / 配車 / ワークアウト**（加えて CarPlay・レストラン予約などは条件付き）
  - **Todo アプリは、この 6 つのどこにも入らない**。つまり当時 Siri 対応は物理的に不可能だった
  - 「Apple がドメインを追加してくれるのを待つ」モデル。これが最大の構造的制約
- **出典**: Apple 公式 [SiriKit](https://developer.apple.com/documentation/SiriKit) / iOS 10 期の各種解説（⚠️ ドメインの数え方は資料によって 6〜10 と揺れる。「コア 6 + 条件付き」と言うのが安全）

---

### S06. 2017 / iOS 11 — ドメインを増やす、という延命

- **見せるもの**: ドメインが少し増える図（リスト・メモ、ビジュアルコード、支払い拡張 …）
- **話の要点**:
  - Apple の対応は「ドメインを足す」。リスト＆メモ（`INCreateNoteIntent` 等）などが追加された
  - つまり Todo/メモ系は「ようやく入口ができた」が、**Apple が定義した形にアプリを合わせる**必要がある
  - スケールしないモデルであることが誰の目にも明らかになった年
- **出典**: ⚠️ iOS 11 の追加ドメイン一覧は一次ソース未確認。発表前に Apple の SiriKit ドメイン一覧で確認する

---

### S07. 2018 / iOS 12 — Siri Shortcuts（構造転換その 1）

- **見せるもの**: 2 経路の図。「① `NSUserActivity` を donate する軽量経路」「② Custom Intents（`.intentdefinition`）で自分で語彙を定義する経路」+ Shortcuts アプリのアイコン
- **話の要点**:
  - ここが 1 回目の大転換。**Apple が定義したドメインの外に出られるようになった**
  - 軽量経路: `NSUserActivity` を donate すると、Siri が「またこれやりますか？」と提案してくれる
  - 本格経路: **Custom Intents**。Xcode の `.intentdefinition` ファイル（GUI エディタ）でアクションとパラメータを定義し、`INIntent` サブクラスが**コード生成**される
  - 同時に **Shortcuts アプリ**が標準搭載（2017 年の Workflow 買収の帰結）。アプリのアクションが「ユーザーが組み合わせられる部品」になった
  - **「アプリの語彙を決めるのが Apple から開発者に移った」のがこの年**
- **出典**: WWDC 2018 session 211「Introduction to Siri Shortcuts」/ Apple 公式 [Donating Shortcuts](https://developer.apple.com/documentation/SiriKit/donating-shortcuts) / [Soup Chef](https://developer.apple.com/documentation/SiriKit/soup-chef-accelerating-app-interactions-with-shortcuts)（wwdc2025-260 の関連リソースに今も載っている）

---

### S08. 2019 / iOS 13 — パラメータと会話

- **見せるもの**: 「会話するショートカット」の図。Siri が聞き返す → ユーザーが答える → 実行
- **話の要点**:
  - 2018 の後で開発者からの最大の要望が「**パラメータ**が欲しい」だった。それに答えたのが iOS 13
  - **Conversational Shortcuts**: アプリ側が会話を制御して、足りない情報を Siri に聞き返させられる
  - Dynamic Options で候補リストを返すと、Siri がそれを**自動で曖昧解消のプロンプト**にする
  - Xcode 11 でカスタム型を定義できるようになり、**アクションの出力を次のアクションに渡す**（チェーン）が可能に
  - → 今の `@Parameter` / `requestDisambiguation` / `ReturnsValue` の直接の先祖
- **出典**: WWDC 2019 session 213「Introducing Parameters for Shortcuts」

---

### S09. 2020–2021 — Intent が「Siri 用」から「システムの設定言語」へ

- **見せるもの**: 2020: ウィジェット設定画面 ← `IntentConfiguration` / 2021: Mac の Shortcuts アプリ
- **話の要点**:
  - **2020 / iOS 14**: WidgetKit 登場。ウィジェットを設定可能にする仕組みが **SiriKit の Custom Intent** だった。`StaticConfiguration` → `IntentConfiguration`、`TimelineProvider` → `IntentTimelineProvider`
    - ここで Intent の役割が変わる。**もう Siri のためだけのものじゃない**。「システムがアプリに問い合わせるための共通言語」になった
  - **2021 / macOS Monterey**: Shortcuts が Mac へ。iOS でカスタム Intent を実装していればそのまま Mac の Siri / Shortcuts で使える。AppKit アプリでも Intents で参加できた
  - SiriKit 世代の到達点。ただし土台は 2018 年の `.intentdefinition` のまま
- **出典**: WWDC 2020 session 10194「Add configuration and intelligence to your widgets」/ 10073「Empower your intents」/ WWDC 2021 session 10232「Meet Shortcuts for macOS」/ Apple 公式 [Making a configurable widget](https://developer.apple.com/documentation/WidgetKit/Making-a-Configurable-Widget)（"Prior to iOS 17 … configurable widgets used SiriKit Intents"）

---

### S10. まとめ: SiriKit 世代が抱えていた 5 つの負債

- **見せるもの**: 5 項目の箇条書き（できれば「痛かった順」）
- **話の要点**:
  1. **ドメインの檻**（2018 で緩和されたが、システムドメインとの二重構造は残る）
  2. **`.intentdefinition` という別言語**。Swift ではなく GUI エディタ + コード生成。差分が読めない、レビューできない
  3. **別プロセスの Extension が必須**。`INExtension` を作り、ターゲット構成を組む
  4. **`Info.plist` への登録が必要**（`IntentsSupported` 等）。宣言が複数箇所に散る
  5. **型が生成物**。自分の Swift の型システムの中に住んでいない
  - → **「Swift で普通に書いた型が、そのままシステムに見える」ようにできないか？** これが 2022 の答え
- **出典**: 上記各スライドの出典 + wwdc2022-10032 の SiriKit 比較部分

---

## 第2部 App Intents 誕生（2022 / iOS 16）

### S11. 2022 / iOS 16 — App Intents（構造転換その 2）

- **見せるもの**: Before/After のコード比較。左: `.intentdefinition` のスクショ + `INExtension` / 右: 20 行の Swift `struct`
- **話の要点**:
  - **3 つの構成要素**だけ: **Intents（動詞）/ Entities（名詞）/ App Shortcuts（フレーズ）**
    > "Intents are actions built into your app that can be used throughout the system. Intents use entities to represent your app's concepts. App Shortcuts wrap your intents to make them automatic and discoverable."（wwdc2022-10032 `1:08`）
  - 負債の解消が、そのまま特徴になっている:
    - `.intentdefinition` → **Swift の `struct` だけ**
    - Extension 必須 → **不要**（アプリ本体に書ける）
    - `Info.plist` 登録 → **不要**。**ビルド時に Swift コンパイラがメタデータを抽出**して `Metadata.appintents` を生成
    - 生成された型 → **自分が書いた型**
  - `AppShortcutsProvider` にフレーズを書くだけで、**インストール直後から Siri で呼べる**（ユーザー側の設定ゼロ）。Spotlight にも自動で出る
- **出典**: wwdc2022-10032「Dive into App Intents」`0:33`–`1:26`, `29:12`

---

### S12. 2022 時点の移行方針（Apple 自身の指示）

- **見せるもの**: 2 分岐の図。「システムドメイン（メッセージ / メディア）/ ウィジェット設定 → SiriKit のまま」「カスタム Intent → App Intents へ」
- **話の要点**:
  - Apple はこの時点では **併存**を明言していた:
    > "if you adopt intents to integrate with widgets, or domains like messaging or media, you should keep using the SiriKit Intents framework. But if you add custom intents for Siri and Shortcuts, you should go ahead and upgrade to App Intents."（wwdc2022-10032 `29:29`）
  - つまり 2022 の App Intents は「**カスタム Intent の置き換え**」であって、まだ全部ではなかった
  - 移行は Xcode の **Convert to App Intent** ボタン（`.intentdefinition` から変換）
  - **この「まだ全部じゃない」が、以降 4 年かけて埋まっていく**のが 2023〜2026 の物語
- **出典**: wwdc2022-10032 `29:29`–`29:48`

---

## 第3部 拡張期（2023–2024）

### S13. 2023 / iOS 17 — ウィジェットが「動く」ようになった

- **見せるもの**: ウィジェット上のチェックボックスをタップして完了になるアニメ or 図
- **話の要点**:
  - **`Button(intent:)` / `Toggle(isOn:intent:)`**。ウィジェットの中から Intent を直接実行、アプリを開かずに完結
  - システムは `perform()` が返った瞬間にタイムラインをリロードすることを**保証**する
    > "As soon as your perform returns, the system will immediately initiate a reload"（wwdc2023-10028 `13:47`）
  - **ウィジェット設定も App Intents 側へ**移行（`WidgetConfigurationIntent` / `AppIntentConfiguration`）。S09 で SiriKit だった領域が回収された
  - **`AppIntentsPackage`**: Swift Package に Intent を置くのが正式サポート（→ 骨子② の構成の前提）
  - パラメータの表現力も上がる: `EnumerableEntityQuery`（全件列挙）/ `IntentParameterDependency`（パラメータ間の依存）
  - 「Intent は Siri のための API」から「**UI からも呼ぶ実行経路**」へ。これが App Intents 中心設計の技術的な出発点
- **出典**: wwdc2023-10028「Bring widgets to life」`10:02`/`13:47` / wwdc2023-10103「Explore enhancements to App Intents」`3:18`–`5:45`

---

### S14. 2024 / iOS 18 — Apple Intelligence と App Intent Domains

- **見せるもの**: 12 ドメインのグリッド（Photos / Mail / Books / Camera / Spreadsheets …）
- **話の要点**:
  - Apple Intelligence（LLM）が Siri に入る。App Intents が「**アプリと Apple Intelligence を繋ぐ手段**」として位置づけられた
    > "We did this by investing deeply in the App Intents framework as a means of connecting the vast world of apps to Apple Intelligence."（wwdc2024-10133 `2:43`）
  - **App Intent Domains（assistant schemas）**: `@AssistantIntent(schema:)` / `@AssistantEntity(schema:)`。iOS 18 で 12 ドメイン
  - ここが面白いポイント: **「ドメイン」という 2016 年の発想が、App Intents 側に戻ってきた**
    - ただし意味が違う。2016 のドメインは**檻**（外に出られない）、2024 のスキーマは**共通語彙**（適合すると AI が意味を理解する。適合しなくても自前 Intent は Shortcuts / Spotlight / ウィジェット等で普通に動く）
    - ⚠️ **「任意適合」と言い切らない**。2026 の Group Lab で **「新しい Siri AI との統合にはスキーマ適合が必要」**と明言されている（#8011 `3:09`）。S21 と揃えて **2 層**で話す（[03-group-lab-evidence.md](03-group-lab-evidence.md)）
  - `IndexedEntity` で Spotlight のセマンティック検索へ。「ペット」で犬・猫の写真が出る、の類
  - **ControlWidget**（コントロールセンター）も追加。Intent の出口がまた増えた
- **出典**: wwdc2024-10133「Bring your app to Siri」`1:03`–`3:21` / wwdc2024-10134 / wwdc2024-10157

---

### S15. 2024 時点での SiriKit の立ち位置

- **見せるもの**: 2 分岐の図（S12 と同じ形、判断基準だけ変わっている）
- **話の要点**:
  - Apple の言い方はこの年もまだ併存:
    > "SiriKit domains are still the best ways for you to enable these kinds of features"
    > "If your App does not overlap with an existing SiriKit Domain, App Intents is the right framework for you."（wwdc2024-10133 `1:03`/`1:24`）
  - つまり判断基準は「**あなたの機能が SiriKit のドメインと重なるか**」だけになっていた
  - そして重ならないアプリ（＝大多数）は App Intents 一本
- **出典**: wwdc2024-10133 `1:03`–`1:40`, `21:04`

---

### S16. 【任意】ここまでの「出口」の増え方

- **見せるもの**: 年次で出口が増える積み上げ図。Siri → Shortcuts → ウィジェット → Spotlight → コントロール → ライブアクティビティ → Action Button → Visual Intelligence → Apple Intelligence
- **話の要点**:
  - 1 つの Intent を書くと、繋がる先が毎年勝手に増えていく
  - **これが App Intents の最大の投資効率**。「今すぐ Siri 対応したいか」は本質ではない
  - 骨子② の主張への橋: だから**最初から Intent で書く**（App Intent Driven Development）
  - ⭐ **「既に書いてあるものが、新しい出口に何も書かずに乗った」実例が 2 つある**。この主張の一番強い証拠:

    | 出口 | 何が起きたか | 出典 |
    |---|---|---|
    | **Apple Pencil Pro のスクイーズ**（2024 / iOS 18） | **既存の App Shortcuts がそのまま動いた**。「去年 Action Button で自動的に動いたのと同じ」と Apple 自身が言っている | wwdc2024-10210 `22:30` / `4:34`、wwdc2024-10134 `0:11`、wwdc2025-244 `9:04` |
    | **HomePod** | 新しい Siri AI は非対応だが、**App Shortcuts は以前から動いている** | #8011 `35:40` |

    - Apple の言い回し: Spotlight と Siri は自動、Action Button と Apple Pencil Pro はユーザーが設定すれば使える
      → **「1 つのコードで 4 つの機能」**（wwdc2024-10210 `22:11`）
    - ⚠️ **「タップ」ではなく「スクイーズ（squeeze）」**。#8011 の字幕は口語の粗起こしで "tap on an Apple Pencil" と
      なっているが、正しくは **Apple Pencil Pro の squeeze**
    - ⚠️ CLAUDE.md の展開マトリクス「物理的なトリガーが自然 → Action Button」の行に **Apple Pencil Pro squeeze が抜けている**
- **出典**: [../APP_INTENT_DRIVEN_DESIGN.md](../APP_INTENT_DRIVEN_DESIGN.md)（SwiftLee: "By defining actions as app intents by default, you allow them to be connected to any system-service in the future."）

---

## 第4部 成熟期（2025–2026）

### S17. 2025 / iOS 26 — 「見せ方」と「実行制御」が入った

- **見せるもの**: Interactive Snippet のスクショ（ボタン付きの Siri 応答）+ `supportedModes` の 4 モード表
- **話の要点**:
  - **Interactive Snippets**: Siri の応答が「読み上げ」から**操作できる SwiftUI** になった。スニペット内の `Button(intent:)` で次のアクションが打てる（押すたびシステムが `SnippetIntent` を再実行して最新化）
  - **`supportedModes`（`IntentModes`）**: `.background` / `.foreground(.immediate)` / `.foreground(.dynamic)` / `.foreground(.deferred)`。`openAppWhenRun`（Bool 1 個）が、意味のある 4 択に整理された
  - **Visual Intelligence**: `IntentValueQuery` + `SemanticContentDescriptor`。カメラ / スクショの内容からアプリのコンテンツを返せる
  - **`requestChoice`**: `requestConfirmation`（yes/no）の多分岐版。`perform()` を中断して選ばせる
  - **`@DeferredProperty`**: Entity のプロパティを必要時だけ非同期取得
  - 見え方の話: OS のバージョン番号が iOS 26 に統一された年
- **出典**: wwdc2025-275「Explore new advances in App Intents」/ wwdc2025-281「Design interactive snippets」/ wwdc2025-244「Get to know App Intents」

---

### S18. 2026 / iOS 27 — Siri AI と App Schemas

- **見せるもの**: 「Siri AI」のキービジュアル + `@AppEntity(schema: .reminders.list)` のコード
- **話の要点**:
  - iOS 27 の Siri は「**Siri AI**」として作り直された（専用アプリ、会話履歴、より自然な言語理解）
  - **App Schemas**: `@AssistantIntent` / `@AssistantEntity` / `@AssistantEnum` が **`@AppIntent(schema:)` / `@AppEntity(schema:)` / `@AppEnum(schema:)` にリネーム**。「アシスタント専用の別物」から「App Intents の一部」へ、名前の上でも統合された
  - スキーマが欠けていると **Xcode がコンパイルエラー + Fix-It** で足りない宣言を出してくれる
  - **`AppIntentsTesting`**: Intent / Entity / Query を**ライブのアプリプロセスで実行してテストできる**フレームワーク（骨子② で詳述）
  - **`SyncableEntity`**: デバイス間で Entity の id が一貫していることを宣言。Siri の会話がデバイスを移っても対象を追える
  - **`EntityCollection` / `LongRunningIntent` / `CancellableIntent`**: 大量処理と長時間処理
  - この年のテーマは **API の厚みより「つながり」**（クロスアプリ・クロスデバイス・検証可能性）
- **出典**: wwdc2026-121 / wwdc2026-240「Build intelligent Siri experiences with App Schemas」/ wwdc2026-295 / wwdc2026-343 / wwdc2026-345 / [../WWDC_APP_INTENTS_SESSIONS.md](../WWDC_APP_INTENTS_SESSIONS.md) 年別サマリー

---

### S18b. なぜ「固定スキーマ」なのか — Apple 自身の設計判断（2026-08-22 追加）

> 骨子① の主題「なぜこの形なのか」に最も直接答える回答が Group Lab（#8011 `45:38` / `21:47`）にある。
> **「MCP や function calling のように動的にすればいいのでは」は本発表で必ず出る質問**なので、
> ここで先に潰しておくと質疑が楽になる。全材料は [03-group-lab-evidence.md](03-group-lab-evidence.md) §2-11。

- **見せるもの**: 「動的な skill 記述 vs 固定スキーマ」の 2 列比較 + 理由 8 点
- **話の要点**:
  - 質問（Apple 公開の逐語）: *"Why go for hard-coded schemas instead of a dynamic approach like GPT or Claude — e.g. Markdown-described skills that reference App Entities? Wouldn't that be more flexible?"*（`45:38`）
  - Apple の答えは 8 点:

    | # | 理由 | 位置 |
    |---|---|---|
    | 1 | **一貫性とプライバシー**。Apple Intelligence は「あなたに閉じた personal intelligence」という立場 | `45:38` |
    | 2 | **プラットフォーム横断で標準化された体験を「保証」できる** | `46:21` |
    | 3 | **ドメイン内で操作感が転移する** — messaging で Siri の使い方を一度覚えたら、同じドメインのスキーマに適合した他アプリでもそのまま通じる | `46:28` |
    | 4 | **安全性が型に組み込まれる** — 「送金なら確認を挟むべき」をシステム側が判断できる | `47:02` |
    | 5 | **所有権を推論して振る舞いを変えられる** — 自分だけの予定は黙って削除、共有中の予定は確認を出す（`EntityOwnership`） | `47:32` |
    | 6 | **ローカライズを Apple が肩代わりする** — モデルの学習も自然言語のフレーズも Apple 側で用意済み。API に適合するだけで多数のロケールにスケールする | `48:32` |
    | 7 | **サンプルフレーズとモデル学習が付いてくる**（App Shortcuts は自分でフレーズを書く必要がある） | `21:47` |
    | 8 | **書くコードが減る** — カスタム Intent で用意すべきものの一部が不要になり、**スキーマを足すとコードを消せる** | `21:47` |

  - ⭐ **一番効くのは 6 と 8**。「型に嵌めると自由度が下がる」という直感を、**Apple が実利で反転させている**
  - ⭐ **この論法は骨子② の中心設計とまったく同型**:
    - 中心設計 = 「**Intent** という固定の型に落とすと、ウィジェット / コントロール / Siri / Spotlight が全部ついてくる」
    - Apple = 「**スキーマ**という固定の型に落とすと、一貫性・安全性・所有権推論・ローカライズ・コード削減が全部ついてくる」
    - → **どちらも「表現力を捨てて型に嵌めることの見返り」**。S24 への橋として使える
  - **オチ候補**: 「**"表現力を捨てて型に嵌める" のは制約ではなく、Apple 側が肩代わりできる範囲を広げるための取引だった**。これは今日の話全体に通じる構図です」
- ⚠️ **引用の注意**: #8011 はページに編集済みトランスクリプトが無く、上記は**自動生成キャプション由来**。
  スライドに逐語を出すなら発表前に `45:38`–`49:20` を視聴して確認する（[03-group-lab-evidence.md](03-group-lab-evidence.md) §0）
- **出典**: [03-group-lab-evidence.md](03-group-lab-evidence.md) §2-11 / §2-6

---

### S19. 【任意】2026 で SiriKit はどうなったのか

- **見せるもの**: 「2026 の App Intents セッション 6 本で "SiriKit" という語は 0 回」というスライド
- **話の要点**:
  - 事実として言えること:
    - Apple 公式ドキュメント上、**SiriKit（Intents / IntentsUI）はまだ存在する**。移行支援の `CustomIntentMigratedAppIntent` も現役
    - 一方で **WWDC 2026 の App Intents 系セッション（240/295/297/343/344/345）には "SiriKit" が一度も出てこない**（ローカル控えを全文検索して 0 件）。2022 と 2024 は必ず言及していた
  - 解釈: 「非推奨だから触れない」ではなく、**もう前提として App Intents しか語られなくなった**、と読むのが素直
  - ⚠️ ネット上には「WWDC 2026 で SiriKit が正式に deprecated」という記述が複数あるが、**Apple の一次ソースで確認できていない**。断定して話さない。話すなら「App Intents に寄せるのが唯一の前向きな選択肢である」までにする
- **出典**: `docs/references/wwdc/` 全文検索（`grep -ric sirikit wwdc2026-*.md` → 0）/ Apple 公式 [SiriKit](https://developer.apple.com/documentation/SiriKit) / [CustomIntentMigratedAppIntent](https://developer.apple.com/documentation/AppIntents/CustomIntentMigratedAppIntent)

---

### S20. 非推奨タイムライン（1 枚表）

- **見せるもの**: 表をそのまま出す

| API | 移行先 | 非推奨化 |
|-----|--------|---------|
| SiriKit `INIntent`（Shortcuts 系のカスタム Intent） | `AppIntent` | 2022（App Intents 登場と同時に移行推奨） |
| `confirmBeforeRunning` | `requestConfirmation(for:dialog:)` | 2022 |
| `openAppWhenRun` | `supportedModes` | 2025 |
| `ForegroundContinuableIntent` | `.foreground(.dynamic)` + `continueInForeground()` | 2025（公式ドキュメントに deprecated 明記） |
| `needsToContinueInForegroundError()` | `continueInForeground()` | 2025 |
| `@AssistantIntent` / `@AssistantEntity` / `@AssistantEnum` | `@AppIntent(schema:)` / `@AppEntity(schema:)` / `@AppEnum(schema:)` | Xcode 27 でリネーム |
| `.system.search`（スキーマ名） | `.system.searchInApp` | Xcode 27 beta 3 |

- **話の要点**:
  - 非推奨の方向は一貫している: **Bool フラグ → 意味のある宣言**、**プロトコル → モード指定**、**アシスタント専用 → App Intents 本体へ統合**
  - 4 年で 7 個。ベータ SDK 追従のコストは正直ある（骨子② で触れる）
- **出典**: [../WWDC_APP_INTENTS_SESSIONS.md](../WWDC_APP_INTENTS_SESSIONS.md#非推奨化タイムライン-まとめ)

---

## 第5部 10 年の総括

### S21. 軸① 誰がアプリの語彙を決めるか

- **見せるもの**: 3 段の変化図
- **話の要点**:
  - **2016**: Apple が決める（ドメイン）。開発者は当てはまるかどうかだけ
  - **2018–2022**: 開発者が決める（Custom Intent / App Intents）。自由だが、システムからは「よく分からない何か」
  - **2024–2026**: **共有語彙**（App Schemas）。自分で決めた語彙のうち、意味が公共的なものはスキーマに適合させる。AI が意味を理解できるようになる
  - ポイント: 2024 以降のスキーマは**檻ではなく辞書**。ただし **2 層で話す**（言い切りは危ない）:

    | 層 | 要るもの | 届く先 |
    |---|---|---|
    | **App Intents（スキーマ不要）** | `AppIntent` / `AppEntity` / `Query` / `AppShortcutsProvider` | Shortcuts / Spotlight / ウィジェット / コントロール / ライブアクティビティ / 従来の Siri フレーズ |
    | **App Schema 適合** | + `@AppEntity(schema:)` / `@AppIntent(schema:)` | **新しい agentic Siri**（多ターン会話・自然な言い回し・確認や所有権の自動処理・ローカライズ） |
  - 2026 の Group Lab は **「Siri AI との統合にはスキーマ適合が必要」**（#8011 `3:09`）と言う一方、**「advantage（優遇）という捉え方は違う」**（`21:47`）とも言っている。矛盾ではなく、**スキーマは Siri AI への入場券であって、既存 Intent を格下げするものではない**
  - **檻との違いは残る**: 2016 は「当てはまらなければ不可能」、2026 は「部分一致でいい / `system` ドメインでいい / App Shortcuts でもいい」と**逃げ道が複数用意されている**（`3:09` / `7:08` / `58:01`）
- **出典**: S05 / S07 / S14 / S18 の各出典 / [03-group-lab-evidence.md](03-group-lab-evidence.md)（#8011 `3:09` / `21:47`）

---

### S22. 軸② どこで実行されるか

- **見せるもの**: プロセスの変化図（別 Extension → アプリ本体 → 状況次第）
- **話の要点**:
  - **SiriKit**: 必ず `INExtension`（別プロセス）。だからアプリの状態を触れず、共有の作り込みが必要だった
  - **App Intents 初期**: アプリ本体に書ける。`@Dependency` でアプリの状態を直接触れる
  - **現在**: 呼出元によって**どのプロセスで走るかはシステムのヒューリスティクス**（アプリ起動中なら本体優先、未起動なら Extension を起動）。固定したければ `allowedExecutionTargets` で明示する
  - つまり「Extension が消えた」のではなく「**意識しなくてよくなった代わりに、意識すべき時に難しくなった**」。骨子② の一番の落とし穴がここ
  - **2026 でもう 1 段増えた: システムオーケストレーター**（#8011 `8:18`）。
    **複数アプリの App Intents を横断して実行する主体がシステム側に立った**。
    アプリ同士が直接呼び合う API は提供されず、**プライバシーと安全性のために経路がここに集約されている**
    → 実行主体の変遷は **`INExtension`（別プロセス）→ アプリ本体 → システムが状況で選ぶ → システムが横断で選ぶ**
    の 4 段になった。⚠️ ただし横断するのは**アクションであってデータではない**（`53:53`）
- **出典（追加）**: [03-group-lab-evidence.md](03-group-lab-evidence.md) §2-3 / §2-12
- **出典**: [WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) `15:59`–`16:55` / [../insights/03-app-intents-core.md](../insights/03-app-intents-core.md)

---

### S23. 軸③ 何を宣言するか

- **見せるもの**: 宣言する対象の増加。動詞 → 名詞 → 表示 → 文脈
- **話の要点**:
  - **動詞（Intent）** 2016〜: できること
  - **名詞（Entity）** 2022〜: 扱っている概念。`@Property` で公開、Query で探せる
  - **表示（DisplayRepresentation / Snippet / Dialog）** 2023〜25: どう見せる・どう読み上げる
  - **文脈（Onscreen Entities / RelevantEntities / 通知への entity 付与）** 2025〜26: **いま何を見ているか / 何が関係あるか**
  - 「アプリの機能を公開する」から「**アプリの世界観をシステムに説明する**」に広がってきた
  - ⭐ **この整理は Apple 自身の 2026 の説明とほぼ一致する**。#240 `1:51` が「今年 Siri が強くなる 3 つの方向」として
    挙げているのが **① entities へのアクセス ② intents によるアクション実行 ③ onscreen context の理解** の 3 つ
    （Group Lab `33:11` が「3 本柱のひとつ」と呼んでいたのはこの ③）
    - → **「名詞 / 動詞 / 文脈」という自分の整理を、Apple の言葉で裏打ちできる**
    - #240 `9:41`–`11:59` の言い方も使える: **スキーマは App Intents の "specialization"**（別物ではない）、
      **ドメインは「アプリと Siri の間の契約のカテゴリ」**
- **出典**: [../WWDC_APP_INTENTS_SESSIONS.md](../WWDC_APP_INTENTS_SESSIONS.md) 各年 / wwdc2026-343 / wwdc2026-240 `1:51`–`2:37`, `9:41`–`11:59` / [03-group-lab-evidence.md](03-group-lab-evidence.md) §4-4

---

### S24. だから「App Intents 中心設計」になる（→ 骨子② へ）

- **見せるもの**: 「Intent = 唯一の実行経路」の構成図（UI / Widget / Control / Live Activity / Siri / Spotlight → Intent → Service → Repository）
- **話の要点**:
  - ⭐ **Apple 自身による「App Intents に統合するとは何をすることか」の定義**（#8011 `8:18`）:
    **① アプリのアクションをシステムに差し出す ② コンテンツを App Entity としてモデル化する**。
    → **中心設計の 3 原則を言う直前に置くと、「これは自分の設計思想ではなく Apple の説明です」と言える**
  - 10 年の結論を実装方針に落とすと 3 行:
    1. **アクションは全部 Intent として定義する**（出口は後から増える）
    2. **UI からも `Button(intent:)` で同じ Intent を呼ぶ**（ロジックを二重に書かない）
    3. **アクション（動詞）と情報（名詞）が設計の原子単位**。UI とプラットフォームは二次的
  - Liquid Glass で UI クロームが薄くなった時代とも符合する。**残るのはコンテンツとアクション**
  - 「じゃあ実際やるとどうなるのか」→ 骨子②（制約・工夫・コツ）
- **出典**: [../CLAUDE.md](../../CLAUDE.md) 設計思想 / [../APP_INTENT_DRIVEN_DESIGN.md](../APP_INTENT_DRIVEN_DESIGN.md) / [Liquid Glass と App Intents 中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents)

---

## 発表前チェック

チェックリストは **[#67](https://github.com/touyou/IntentTodo/issues/67)** に移した
（S03 / S05 / S06 / S17 / S19 の裏取り、S14 / S21 の「スキーマ適合は任意」の逐語確認、S18 の構成判断、引用 URL の `?time=` 付与）。
ドキュメントには `- [ ]` を残さない運用のため
（[AGENTS.md の「ドキュメント運用」](../../AGENTS.md#ドキュメント運用現在のルール--経緯--残タスク-の三分割)）。
