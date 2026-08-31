# 9 本目（設計セッション）を足し、audit に `--gap` を付けた経緯

2026-08-31。「App Intents を棚卸しして、ユースケース中心設計を対話しながらやって、そのプロジェクトに
合った Intent を導く skill があるといいのでは」という発案から。まず**既存 8 本に無いのか**を確かめた。

## 既にあったもの / 無かったもの

| ある | どこ |
|---|---|
| 動詞＝Intent / 名詞＝Entity のユースケース文ルール | `app-intents-centric-design/references/actions-and-intents.md`（表 3 行） |
| 既存アプリのレトロフィット棚卸し表（ViewModel / URL ハンドラ / メニュー → 何になるか） | 同 `adoption-levels.md` |
| 導入レベル 0–3 と各レベルの exit criteria | 同上 |
| サーフェスに出す前の 4 問・smallest surface outward の順序 | `app-intents-system-surfaces/SKILL.md` |
| 到達サーフェスの棚卸し | `audit_intents.py --coverage` |

無かったのは**進行**だった: 何を順に聞くか、1 セッションで何を決め切るか、成果物をどう残すか。
さらに `--coverage` は「今コードにあるもの」しか見えないので、「あるべきアクションとの差分」が出せない。

## 入口を厚くするのではなく 9 本目にした

既存 8 本は「参照とルール」で揃っている。進行役（質問セット・司会の作法・成果物テンプレ）を入口に
混ぜると入口の性質が変わるので、`app-intents-design-session` として分けた。発火は
`app-intents-centric-design` の description と一部重なるが、**入口側の振り分け表に 1 行足して
「一緒に考えてほしいならこちら」と回す**形にした。skill の分割は発火で決める、という既存の方針どおり。

skill 本体が持っているのは手順だけで、ルールは各 skill にポインタを置いた。特に:

- 成果物 4 点（ユースケース表 / Intent・Entity 集合 / サーフェス割当 / 名前とコピー）
- 4 ラウンド（アクション → 動詞と名詞 → サーフェス → 名前）の進行と、各ラウンドの終了条件
- 司会の作法（1 ターンに 1〜2 問 / 空欄でなく選択肢 / 画面の話を動詞に言い換えて返す /
  重要度でなく頻度を聞く / 推薦にはコストを併記 / 専門用語を質問に出さない）
- ラウンド 3 が設計作業であること（静止時に何を見せるか / 実行後に誰が気づくか /
  失敗が「何も起きない」と区別できるか / どの既存 Intent を再利用するか）

## `--gap`: 実装済み Intent ↔ 届いていないアクション

`audit_intents.py --gap` を追加した。出すもの:

- Intent 型一覧（App Shortcut 登録 / schema / `isDiscoverable = false` のマーク付き）
- Entity 一覧と `@Property` 数（0 件は Shortcuts / Siri / Spotlight から見えない）
- App Shortcut 枠の使用数（このリポジトリは 8/10）
- **どの Intent からも呼ばれていないアクションメソッド**（`*Service` / `*Store` / `*ViewModel` /
  `*Manager` 型の、動詞で始まる非 private メソッド）
- アクションが隠れている他の場所（URL ハンドラ / `NotificationCenter` post / メニュー /
  quick action / 手書きの deep link / `intent:` に繋がっていない `Button`）

作りながら削ったノイズ:

- `@AppEntity(schema:)` マクロで宣言された entity が拾えていなかった（`TodoAppEntity` /
  `CategoryAppEntity` が一覧から丸ごと落ちていた）。conformance 一覧だけ見ていたのが原因
- `@Property` 数をファイル単位で数えていたので、1 ファイルに 2 entity あると同じ数が出た。
  宣言行から次の宣言行までに区切った
- `favoriteCount()` のような「動詞＋名詞」の読み取り専用メソッドが gap に出た。
  `Count` / `Text` / `Label` / `Icon` / `Color` / `Description` / `Predicate` / `Formatter` /
  `Descriptor` 終わりを除外
- 破壊的操作の `Button(role: .destructive)` が全部候補に出た。確認 → 確認なし版という正しい形なので、
  クロージャの走査窓を 4 行から 6 行に広げて `showing…` 代入を拾えるようにした

それでも grep 品質なので、**候補側は過剰包含のまま**にして「4 分類（本物のアクション / 配管 /
既に Intent があるのに UI が直呼び / ローカル UI 状態）に人と一緒に仕分ける」ことを
`references/gap-analysis.md` の中心に置いた。既知の誤検知も同じファイルに列挙してある。
出力の末尾でも「これは欠陥一覧ではない」と明示している。

このリポジトリに当てた結果は、gap 2 件（`TodoLiveActivityManager.startActivity` /
`updateActivities` — 分類は「配管」）と UI 候補 7 件（フォーム内の追加ボタンと破棄、
破壊的操作の確認ボタン）。**分類 3「既に Intent があるのに UI が直呼び」は 0 件**だった。

## 併せて見つけたが直していないもの

`--fail-on error` で UI テストの `conditional-assert` が 3 件出ている
（`IntentTodoUITest.swift:340`、`IntentTodoWatchAppUITest.swift:131,147`）。
`if el.waitForExistence(...) { XCTAssert… }` の形で、要素が出なければ無言で緑になる。
`docs/TESTING.md` が禁じている形そのものなので、この skill の作業とは分けた。残り: #113。
