# プレゼン素材

App Intents 中心設計についての登壇・発表用の素材置き場。

---

## ファイル構成

| ファイル | 内容 |
|---------|------|
| [01-app-intents-history.md](01-app-intents-history.md) | **スライド骨子①: App Intents の基本説明**。SiriKit（2016）から App Intents（2022〜2026）までを WWDC の時系列で辿る |
| [01-app-intents-history.script.md](01-app-intents-history.script.md) | 上記の想定スクリプト置き場（スライド ID 対応、本人が後で記入） |
| [02-constraints-and-craft.md](02-constraints-and-craft.md) | **スライド骨子②: 実践で見えた制約・工夫・コツ**。IntentTodo で実測した内容ベース |
| [02-constraints-and-craft.script.md](02-constraints-and-craft.script.md) | 上記の想定スクリプト置き場 |
| [03-group-lab-evidence.md](03-group-lab-evidence.md) | **Apple Intelligence Group Lab（WWDC26 #8011）全内容の抜き書き**。全 27 問マップ / App Intents 関連 15 問の詳細 / それ以外も記録用に全件 / 既存メモの要修正点 / 反証カード / 骨子①②への組み込み候補。**尺は考慮せず判明分を全部書いてある** |
| [99-script.md](99-script.md) | **本番スクリプト（iOSDC 40 分枠 / 本人執筆）** |
| [99-script.notes.md](99-script.notes.md) | **99 へのフィードバック**（2026-08-30 全面改稿 / 対象は 99 の L22–209）。尺の実測と削り候補 / 事実確認 / 流れの組み直し候補 / 締めの候補 6 案 / スライド任せの面への 1 行 / 想定 Q&A / 一次ソース逐語 |
| [99-keynote.notes.md](99-keynote.notes.md) | **Keynote 実物（118 面）へのフィードバック**（2026-09-06）。通しの実測尺 / 99-script.notes.md の決定が実物に入っているかの反映状況 / 事実と整合性 / 論理の弱点 / 版面 / **`.key` をレビューする手順** |

> **スライド ID の枝番について**: 骨子② の `T12b` / `T21b` / `T29b` は 2026-08-21（WWDC26 公式サンプルとの突き合わせ）、
> `T07b` は 2026-08-25（Layered / Clean Architecture との対比）で後から足したもの。既存 ID と `.script.md` の
> 対応を壊さないために枝番にしてある。最終構成では既存カードとの差し替え候補として扱う。
>
> `T07b` は `99-script.notes.md` の `C-3x` と同じ内容。両方使うなら役割を分ける
> （99 側 = なぜ Intent にしたか / T07b = 従来の層とどう対応するか）。経緯: [../devlog/2026-08-25-layering-vs-clean-architecture.md](../devlog/2026-08-25-layering-vs-clean-architecture.md)

---

## 使い方

- **発表前にやることは [#67](https://github.com/touyou/IntentTodo/issues/67) に集約**（数字の再カウント / 一次ソースの裏取り /
  スクショ / 言い方の判断）。骨子ファイルにチェックリストは置かない
- ⭐ **投影される実物は Keynote（`iosdc2026_appintents_centric.key` / iCloud Drive）で、原稿より先に進んでいる**
  （`99-script.md` は 83 面・第 2 部が `TBD`、Keynote は 118 面で第 2 部まで入っている）。
  **内容の確認は Keynote を正とする**。`.key` は protobuf なので、読むには
  [99-keynote.notes.md の F](99-keynote.notes.md#f-レビューのやり方再現手順)（PDF 書き出し + `text items` / `presenter notes` ダンプ）を使う
- 骨子ファイルは **1 スライド = 1 見出し（`### S<番号>.`）**。`見せるもの` / `話の要点` / `出典` の 3 点セットで書いてある
- `.script.md` は同じスライド ID を並べただけの空ファイル。喋る想定の原稿はここに書き足す（骨子側に混ぜない）
- 骨子の内容は原則すべて既存ドキュメントに裏取りがある。参照元は各スライドの `出典` を見る
- ⚠️ マークは「一次ソース未確認 / 発表前に確認したい」項目。断定を避けるか、事前に確認して外す

---

## 元ネタ

| 元ドキュメント | 使っている場所 |
|--------------|--------------|
| [../WWDC_APP_INTENTS_SESSIONS.md](../WWDC_APP_INTENTS_SESSIONS.md) | 骨子① の 2022〜2026 部分（API 一覧・年別サマリー・非推奨タイムライン） |
| [../references/wwdc/](../references/wwdc/) | 骨子①②の引用（トランスクリプト＋タイムスタンプ） |
| [../insights/](../insights/) | 骨子② のほぼ全部 |
| [../devlog/](../devlog/) | 骨子② の「どう気づいたか」部分 |
| [../APP_INTENT_DRIVEN_DESIGN.md](../APP_INTENT_DRIVEN_DESIGN.md) | 骨子② の思想的背景（他概念との比較）+ **T07b / C-3x の元ネタ**（Layered / Clean Architecture との対比） |
| [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md) | 骨子② の検証状況 |
| [../APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md) | 骨子② の「適合しなかったもの / 使っていないもの」リスト（採用状況の一次情報） |
