# Apple Event 2026-09-09「Surprise and shine」— 登壇に使えるものの抜き書き

> 実測・調査日: 2026-09-10 / Xcode 27.0 RC（27A266a）
> このファイルの方針は [03-group-lab-evidence.md](03-group-lab-evidence.md) と同じ。
> **尺は考慮せず、判明分と「使えない理由」を全部書く。** 取捨選択は本人が行う前提。

**このファイルに原稿は書かない。** 骨子・スクリプトへの反映は本人の判断。

---

## 0. 引用する前に必ず読む（まさかり対策）

### 0-1. 発表内容と「開発者向け API」は情報源が別で、SDK の版も違う

| 種類 | 出典 | 引用時の扱い |
|---|---|---|
| **製品発表の事実**（サイズ / 価格 / 発売日 / 機能名） | Apple Newsroom / Apple Support | ✅ 逐語で出せる |
| **開発者向け API の設計指針** | Apple Developer Tech Talks（Duo 関連 6 本） | ✅ 出せる。ただし**セッションページに OS バージョンの明記がない**ものがある |
| **API が手元の SDK にあるか** | **本リポジトリで実測**（swiftinterface / ヘッダ / tbd） | ✅ 出せる。下の §3 が実測結果 |
| メディアのイベント速報 | TechRadar / Engadget ほか | ⚠️ 事前予想と発表内容が混ざっている。**数字はメディア間で食い違っていた**（内側 7.6" / 7.8"、外側 5.4" / 5.5" など）。Newsroom で取り直すこと |

### 0-2. ⚠️ Apple は iPhone Duo の文脈で「Liquid Glass」と言っていない

- [Apple Newsroom の iPhone Duo 発表](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/)に **"Liquid Glass" の語は出てこない**（nano-texture finish / Ceramic Shield 2 の記述はある）
- Tech Talk「Design for iPhone Duo」にも **Liquid Glass の語は出てこない**

**「Duo で Liquid Glass の本領が発揮されている」は解釈であって Apple の主張ではない。**
断定するとまさかりが飛ぶ。同じ結論を Apple の言葉で支える方法は §2-A にまとめた。

---

## 1. 発表された事実（Newsroom ベース）

### 1-1. iPhone Duo

| | |
|---|---|
| 内側ディスプレイ | 7.6 インチ |
| 外側ディスプレイ | 5.4 インチ |
| チップ | A20 Pro（iPhone 18 Pro と同じ） |
| 価格 | $1,999〜（256GB） |
| 予約 / 発売 | 2026-10-16 / 2026-10-23 |

Apple の逐語（software の説明）:

> "iOS seamlessly adapts to the new ways to use iPhone Duo — content reacts as it folds,
> reorients when turned to the side, and switches to the appropriate display when flipped over."

ヒンジについての逐語:

> "more than 100 components to precisely control opening and closing"
> "the precision hinge on iPhone Duo is designed to feel effortlessly smooth"

出典: [Apple Newsroom — Apple unveils iPhone Duo](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/)

### 1-2. Audio Intelligence（Apple Watch Series 12 / Ultra 4）

Apple の定義:

> "a brand-new class of Apple Intelligence features that use the microphones of Apple Watch,
> the power of Apple silicon, and on-device and cloud-based AI models"

4 機能:

| 機能 | 中身 |
|---|---|
| **Sound Recognition** | サイレン / アラーム / ドアベル / 赤ちゃんの泣き声。iPhone が手元になくても動く |
| **Live Rewind** | Digital Crown の 2 度押しで**直前 15 秒の会話**をテキストで表示。Siri に内容を聞ける / **Siri アプリに保存できる** |
| **Siri Recap** | 会話のあとに**タイトルと要点を自動生成して新しい Siri アプリに置く**。保存しなければ 7 日で自動削除 |
| **Shazam** | 近くの曲を検出して Smart Stack の Music Recognition ウィジェットに表示 |

プライバシーの設計:

- 音声の録音は作らず保存もしない。生の音声は **S11 チップの Secure Exclave** で処理し、使用後すぐ破棄
- Siri Recap はオプトイン。常時 / スケジュール（仕事中だけ・夜はオフ）を選べ、Control Center からトグルできる

⚠️ **提供時期**: Live Rewind / Siri Recap は **2026 年後半にベータ**、英語のみ、Apple Intelligence 対応
iPhone 16 以降（16e を除く）が必要、**EU では提供なし**。「もう使える」と言わないこと。

出典: [Apple Newsroom — Apple Watch Series 12](https://www.apple.com/newsroom/2026/09/introducing-apple-watch-series-12-with-the-all-new-health-sensing-system/) /
[Apple Support — About Audio Intelligence features](https://support.apple.com/en-us/148354)

### 1-3. Duo 向け Tech Talks（6 本）

| # | タイトル | 尺 |
|---|---|---|
| 111461 | [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) | 10:10 |
| 111462 | [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/) | 15:43 |
| 111463 | [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/) | 18:01 |
| 111464 | [Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/) | 7:17 |
| 111465 | [Build a great camera experience for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111465/) | 9:27 |
| 111466 | [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) | 10:45 |

⚠️ **6 本のどれにも App Intents / Shortcuts / Siri / ウィジェット / コントロールは出てこない。**
これは「Duo と App Intents は無関係」ではなく「**Apple は Duo を UI 適応の話として説明した**」という事実。
§2-B はこの前提の上に立てている。

---

## 2. 使える角度 3 つ

### A. 「UI の透明化」— Apple の言葉で支え直す

⚠️ §0-2 のとおり Liquid Glass という語は使われていない。**Liquid Glass に寄りかからず、
「クロームは固定された家具ではない」という主張そのものを Duo で例証する**のが安全。

Apple 自身が言っていること:

- Newsroom: 「content reacts as it folds, reorients when turned to the side, and switches to
  the appropriate display when flipped over」（**主語が content**。クロームではない）
- 「Design for iPhone Duo」: 外側ディスプレイでは**コントロールを外縁へ寄せる**
- 「Design for iPhone Duo」: ヒンジ中央から**インタラクティブ要素を自動で押しのける
  "fold avoidance" がシステム挙動として入っている**

**言い換えの候補**: 「透明化」を「透け感」ではなく「**クロームが content に場所を譲る**」と
定義しておくと、Duo は「OS がその譲り方を肩代わりし始めた」いちばん強い実例になる。
透け感の話にすると §0-2 で崩れる。

### B. ヒンジ → App Intents は繋がらない。**scene の複数化**が正しいルート

繋がらない理由（3 つとも事実）:

1. Apple は「ヒンジ API は**インタラクションと効果のためであってレイアウトのためではない**」と
   明言している（角度からフレームを計算していたら API 選択が間違っている、という言い方）
2. Duo の Tech Talk 6 本に App Intents への言及がない（§1-3）
3. **`onHingeChange` / `UIHingeInteraction` は手元の Xcode 27.0 RC SDK に存在しない**（§3）。
   デモができない

代わりに立つ主張:

> **Duo は「1 アプリ = 1 画面」を壊し、scene が複数ある状態を常態にする。
> そこで効くのは「その Intent は *どの scene* に対して実行されるのか」で、
> これは App Intents 中心設計がすでに解いている問題である。**

このリポジトリに現物がある:

- `LaunchAppIntent: UISceneAppIntent` の `performNavigation(forScene:)`
  （`Packages/TodoAppIntents/Sources/TodoAppIntents/Intents/LaunchAppIntent.swift`）
- `applyNavigation()` を `perform()` と `performNavigation(forScene:)` の 2 経路で共有し、
  cold start（`UIScene.ConnectionOptions.appIntent`）まで通してある
- 根拠: [../insights/04-ui-integration.md](../insights/04-ui-integration.md) / [Apple: wwdc2025-275 23:52]

**しかも手元の SDK で動く**（§3 のとおり `UISceneAccessory` は iOS 27.0 available）。
ヒンジは 27.1 待ちで実演できないが、こちらは実演できる。

### C. Audio Intelligence → 「画面を見ない入力」と `isVoiceOnly`

2 つ効く:

1. **入力が「画面を見ない・手を使わない」方向へ寄っている**。
   このアプリは `systemContext.isVoiceOnly` を [APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md) で
   **⏸ 意図的不使用**にしているが、Audio Intelligence の文脈だとこの判断を**あえて見せる**価値が出る。
   「**呼出元は判別できないが、音声のみかは分かる**」は App Intents の設計制約のきれいな実例
   （RC SDK の `IntentSystemContext` は `preciseTimestamp` / `isVoiceOnly` / `locale` の 3 つだけ — §3）
2. **Siri Recap が「Siri アプリに entity が溜まる」形をとっている**。
   会話の要約という**アプリの外で生まれたもの**がシステム側の面に置かれ、そこから参照される。
   「システム側の面が増え続ける」という発表全体のテーマの、今年いちばん分かりやすい追加例

⚠️ Audio Intelligence は **Apple の 1st party 機能であって、サードパーティ向け API の発表ではない**。
「これで App Intents がこう書ける」とは言えない。**トレンドの根拠**として使うこと。

---

## 3. 実測: どの Duo API が手元の SDK にあるか

Xcode 27.0 RC（27A266a）の iPhoneOS SDK を直接引いた結果。**メディアや Tech Talk の記述ではなく、
declaration の有無で判定している**（本リポジトリの「確認はビルドの成否ではなくメタデータで行う」に合わせた）。

| API | 27.0 RC SDK | 判定の根拠 |
|---|---|---|
| `UISceneAccessory` | ✅ **ある** | `UISceneAccessory.h` に `API_AVAILABLE(ios(27.0))` |
| SwiftUI `sceneAccessory { }` | ✅ **ある** | `SwiftUI.swiftinterface` に `func sceneAccessory<C>(...)` |
| `SceneAccessoryContent` / `onAvailabilityChange` | ✅ **ある** | 同上 |
| `IntentSystemContext.isVoiceOnly` / `.locale` | ✅ **ある** | `AppIntents.swiftinterface`（`anyAppleOS 27.0`） |
| `ReservedRegion` | ⚠️ **シンボルはあるが公開されていない** | `SwiftUICore.tbd` に mangled symbol があるのに、`SwiftUICore.swiftinterface` には declaration が無い |
| `onHingeChange` | ❌ **無い** | SDK 全体で 0 ヒット |
| `UIHingeInteraction` | ❌ **無い** | 0 ヒット（`hinge` の全文検索で当たるのは MLCompute の hinge loss と SceneKit の hinge joint だけ） |
| `hinge.status == .partiallyOpen` | ❌ **無い** | `partiallyOpen` が SDK 全体で 0 ヒット |
| `CameraCaptureAccessory` | ❌ **無い** | 0 ヒット |

**この差がそのままスライド 1 枚になる**: `ReservedRegion` は**バイナリには入っているのに宣言が出ていない**。
`onHingeChange` は**シンボルごと存在しない**。「今日ダウンロードできる SDK に何が入っているかは、
セッションを見ても分からない。引いて確かめるしかない」という、このリポジトリの主張そのものの実例。

Tech Talk「Prepare your app for iPhone Duo」は **Xcode 27.1 / iOS 27.1 SDK** を要求している:

> "The iOS 27 SDK extends your app left of the status bar on the inner display;
> the iOS 27.1 SDK reaches the screen edge and lays standard navigation and toolbar buttons out vertically."
>
> "Download Xcode 27.1 and run your app in the iPhone Duo simulator using DeviceHub."

⚠️ この 2 つの引用はセッションページから取ったもので、**逐語であることを本人が再確認してから使う**。

---

## 4. 反証カード（聞かれたら答える用）

| 想定質問 | 答え |
|---|---|
| 「Duo で Liquid Glass が進化したって Apple 言ってました？」 | **言っていない。** Newsroom にも Design セッションにも語がない。自分の解釈だと明示する（§0-2） |
| 「ヒンジ角度で Intent を出し分けられますか？」 | **できない。** ヒンジ API は 27.0 SDK に無く、Apple はレイアウト用途を明示的に否定している。scene の話に寄せる（§2-B） |
| 「Audio Intelligence 向けの App Intents API は出ましたか？」 | **出ていない。** Apple の 1st party 機能。サードパーティ向けは今のところ既存の App Intents / App Schema のまま（§2-C） |
| 「Duo 対応は iOS 27 SDK でできますか？」 | **部分的に。** `UISceneAccessory` は 27.0。ヒンジと reserved region は 27.1 SDK / Xcode 27.1（§3） |
| 「Duo の実機・シミュレータで検証しました？」 | **していない。** SDK の declaration を引いただけ。Duo シミュレータは Xcode 27.1 の DeviceHub 側 |
| 「Siri Recap はもう使えますか？」 | **まだ。** 2026 年後半にベータ、英語のみ、EU 除外（§1-2） |

---

## 5. このイベントで**使えないと判断したもの**

同じ検討を後からもう一度させないために残す。

| 題材 | 使わない理由 |
|---|---|
| iPhone 18 Pro の可変絞り / 手動カメラ操作 | App Intents との接点が無い。カメラアプリの話になる |
| 内側ディスプレイの in-display カメラ | ハードウェアの話。「透明化」と語が被るが**別の意味**なので混ぜると事故る（§0-2 の 2 つの transparency） |
| AirPods 5 / AirPods Max 2 の Live Translation | 1st party 機能。App Intents の面が増えたわけではない |
| Apple Watch Ultra 4 | watchOS の App Intents 制約（App Schema 不在）は既存の話で、今回の発表で動いていない |
| iOS 27 の「customizable Liquid Glass」 | ⚠️ メディア speed run 由来で一次ソースを取れていない。**裏取りできるまで使わない** |

---

## 6. 元ネタ

| 出典 | 使っている場所 |
|---|---|
| [Apple Newsroom — iPhone Duo](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/) | §1-1 / §2-A |
| [Apple Newsroom — Apple Watch Series 12](https://www.apple.com/newsroom/2026/09/introducing-apple-watch-series-12-with-the-all-new-health-sensing-system/) | §1-2 |
| [Apple Support — Audio Intelligence](https://support.apple.com/en-us/148354) | §1-2 |
| [Tech Talks 111461 / 111464 / 111466](https://developer.apple.com/videos/tech-talks/) | §1-3 / §2-A / §2-B / §3 |
| Xcode 27.0 RC（27A266a）iPhoneOS SDK の実測 | §3 |
| [../insights/04-ui-integration.md](../insights/04-ui-integration.md) | §2-B（`UISceneAppIntent`） |
| [../APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md) | §2-C（`isVoiceOnly` の ⏸ 判断） |
