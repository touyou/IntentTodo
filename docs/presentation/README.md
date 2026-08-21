# プレゼン素材

App Intents 中心設計についての登壇・発表用の素材置き場。

## ファイル構成

| ファイル | 内容 |
|---------|------|
| [01-app-intents-history.md](01-app-intents-history.md) | **スライド骨子①: App Intents の基本説明**。SiriKit（2016）から App Intents（2022〜2026）までを WWDC の時系列で辿る |
| [01-app-intents-history.script.md](01-app-intents-history.script.md) | 上記の想定スクリプト置き場（スライド ID 対応、本人が後で記入） |
| [02-constraints-and-craft.md](02-constraints-and-craft.md) | **スライド骨子②: 実践で見えた制約・工夫・コツ**。IntentTodo で実測した内容ベース |
| [02-constraints-and-craft.script.md](02-constraints-and-craft.script.md) | 上記の想定スクリプト置き場 |
| [99-script.md](99-script.md) | **本番スクリプト（iOSDC 40 分枠 / 本人執筆）** |
| [99-script.notes.md](99-script.notes.md) | 99 の補完メモ。事実確認（要修正 2 箇所）/ 詳細ゾーンの材料 / 各節の一次ソース / 残りアウトラインの材料 / 尺配分 / 想定 Q&A |

> **スライド ID の枝番について**: 骨子② の `T12b` / `T21b` / `T29b` は 2026-08-21（WWDC26 公式サンプルとの突き合わせ）で
> 後から足したもの。既存 ID と `.script.md` の対応を壊さないために枝番にしてある。最終構成では既存カードとの
> 差し替え候補として扱う。

## 使い方

- 骨子ファイルは **1 スライド = 1 見出し（`### S<番号>.`）**。`見せるもの` / `話の要点` / `出典` の 3 点セットで書いてある
- `.script.md` は同じスライド ID を並べただけの空ファイル。喋る想定の原稿はここに書き足す（骨子側に混ぜない）
- 骨子の内容は原則すべて既存ドキュメントに裏取りがある。参照元は各スライドの `出典` を見る
- ⚠️ マークは「一次ソース未確認 / 発表前に確認したい」項目。断定を避けるか、事前に確認して外す

## 元ネタ

| 元ドキュメント | 使っている場所 |
|--------------|--------------|
| [../WWDC_APP_INTENTS_SESSIONS.md](../WWDC_APP_INTENTS_SESSIONS.md) | 骨子① の 2022〜2026 部分（API 一覧・年別サマリー・非推奨タイムライン） |
| [../references/wwdc/](../references/wwdc/) | 骨子①②の引用（トランスクリプト＋タイムスタンプ） |
| [../insights/](../insights/) | 骨子② のほぼ全部 |
| [../devlog/](../devlog/) | 骨子② の「どう気づいたか」部分 |
| [../APP_INTENT_DRIVEN_DESIGN.md](../APP_INTENT_DRIVEN_DESIGN.md) | 骨子② の思想的背景（他概念との比較） |
| [../APP_INTENTS_CENTRIC_PLAN.md](../APP_INTENTS_CENTRIC_PLAN.md) | 骨子② の検証状況・不適合リスト |
