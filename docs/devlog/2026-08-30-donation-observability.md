# donation を観測する経路を見つけた（#53 / #98 / #99）

「`Button(intent:)` は donate されるのか」を確かめた記録。

これまで docs には **「donation には観測用の公開 API が無い（`deleteDonations` はあるが列挙が
無い）ので AppIntentsTesting で押さえられない」**と書いてあり、それが `#53` で donation を
不採用にした 3 番目の理由だった。公開 API については今も正しいが、**シミュレータのデータ
コンテナからは読める**ことが分かったので、不採用の前提が 1 つ動いた。

きっかけは「App Intents 中心設計の趣旨を考えたら `Button(intent:)` にこだわるより
`callAsFunction(donate:)` の方が合っているのでは。あるいは `Button(intent:)` の内部で
donate されている可能性はない？」という問い。加えて「ログ以外でも検証できないか」という
提案から、`PredictableIntent` のような下流ではなく**記録そのもの**を探しに行った。

方針転換（載せ替え）は登壇への影響が大きいので **`#99` に切り出して保留**。この記録は
検証結果だけ。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f） |
| シミュレータ | iPhone 17 Pro Max / iOS 27.0（96DB9C38-5E4D-4AA4-B158-4735B88ACDEA） |
| 実測日 | 2026-08-30 |

## 1. 読める場所が 2 つある

シミュレータのデータコンテナに Biome のストリームがあり、どちらも IntentTodo の記録を持っていた。

```
<device>/data/Library/Biome/streams/restricted/
    IntelligenceEngine.Interaction.Donation   # donation
    App.Intents.Transcript                    # intent 実行（呼出元 bundle id 付き）
```

`App.Intents.Transcript` は WWDC 2026 #343 `6:47` が言う *"The system stores these as
schema-conforming App Intents in a **temporary transcript**"* の transcript と名前が一致する。

`data/Library/IntelligencePlatform/Artifacts/donation/donation.db` も存在するが
`donationSubgraph` テーブルは 0 行で、派生アーティファクト側らしく今回は使わなかった。

読み方は `skills/intent-centric-architecture/scripts/inspect_donation_stream.py` に置いた。
append-only の mmap セグメントで、オフセット順に時刻が単調増加する。protobuf 風だが
スキーマは非公開なので、型名 / bundle id の文字列と CFAbsoluteTime として読める double を
拾って対応付けるだけに留めている。

**引っかかった点**: ファイルの **mtime は当てにならない**。Donation ストリームのセグメントは
mtime が 2026-07-08 なのに、中身には 2026-08-29 の記録が入っている（mmap 書き込みで
mtime が更新されない）。最初これで「7 月以降 donate されていない」と読み間違えた。

## 2. アプリ内 `Button(intent:)` は donation に載る

アプリは `fdd7b5b`（2026-08-21）で `AddTodoIntent.perform()` 内の `donate()` を撤去して以来、
**どこからも donate していない**。それでも Donation ストリームには 8/28・8/29 の記録がある。

決め手は `DeleteTodoImmediatelyIntent` の 27 件。この intent は:

- `isDiscoverable = false`（Siri / Shortcuts / Spotlight に出ない）
- `AppShortcutsProvider` に未登録
- テストからも実行されない（`IntentExecutionTargetsTests` が静的プロパティを読むだけ）
- **呼出元は `UI` / `WatchUI` の `Button(intent:)` だけ**（`DeleteButton` / 詳細画面）

つまり「アプリ UI のボタンを押した」以外の経路が無い。**アプリが donate していないのに
記録がある** ので、`Button(intent:)` の実行はシステム側が記録している。

> `ToggleFavoriteIntent` / `ToggleTodoCompletionIntent` は AppIntentsTesting からも実行される
> ので単体では判別に使えない（システムが走らせた intent は公式に自動 donate される）。
> `DeleteTodoImmediatelyIntent` だけがこの交絡を持たない。

## 3. 別プロセス（Widget / Control）の `Button(intent:)` は載っていない

型ごとに両ストリームを数えると、はっきり分かれた。

| | Donation | Transcript |
|---|---|---|
| `SetTodoCompletionIntent`（Control 専用 = Widget Extension プロセス） | **0 件** | 5 件 |
| bundle id が `dev.touyou.IntentTodo.IntentTodoWidget` の記録 | **0 件** | 13 件 |
| `DeleteTodoImmediatelyIntent`（アプリ UI の `Button(intent:)` 専用） | 27 件 | 9 件 |

Transcript には widget / control プロセス由来の実行が 13 件並んでいるのに、Donation 側は 0 件。
**別プロセスから呼ばれた `Button(intent:)` は donation として記録されていない**方向の結果で、
「別プロセスで呼ばれたとき donate が効かないのが気になる」という懸念はこの範囲では裏付けられた。

## 4. どこまで確定で、どこからが未確定か

確定（実データがある）:

- 上記 2 つのストリームが存在し、IntentTodo の記録が読める
- アプリが donate していない期間にも `DeleteTodoImmediatelyIntent` の donation 記録がある

未確定（`#98` で詰める）:

- `SetTodoCompletionIntent` の 0 件が**構造的に載らない**のか、実行回数が少なくて偶然 0 なのか。
  Control の実行が 5 件しかないので、これだけでは断定できない
- ストリームのスキーマが非公開なので、「型名の文字列が近傍にある」ことをもって
  「その intent の donation である」と読んでいる。**間接的な解釈**である
- `callAsFunction(donate:)` 経由がどう記録されるか（未実行）

**判定は必ず「呼出元だけ変えて同じ intent を走らせる」差分実験でやる**（`06-control-widget-ios26.md`
で一度、肯定リストからの推論で設計を誤っている）。スクリプトに `--snapshot` / `--diff` を
付けたのはそのため。positive control（Shortcuts アプリから同じ intent を実行した分が
ちゃんと出ること）を先に確認しないと、「出なかった」がチャネルの盲目なのかアプリ側の
不発なのか分からない。

## 5. 出荷コードでは使わない

このパスは非公開で、OS 更新で消えうる。**検証専用**であって、`deleteDonations` のような
公開 API の代わりに使ってよいものではない。`__appSchemaEntity` の手書き適合を撤去した
（[2026-08-29-schema-vs-watch-target.md](2026-08-29-schema-vs-watch-target.md)）のと同じ線引きで、
**読むだけ / テストの外側で使う**に留める。

## 6. 設計上の含み

もし 2 の解釈が正しければ、**App Intents 中心設計は donation を構造的に不要にしている**ことになる。
公式サンプル 4 本（CometCal / UnicornChat / CosmoTunes / PhotosDomainExample）は
`Button(` 94 件のうち `Button(intent:)` が **0 件**で、UI は Manager を直接呼び、そのぶんを
明示 donate している。donation が要るのは「UI の操作が intent の実行になっていない」からで、
UI も intent を走らせている本アプリでは前提が違う。

一方で 3 が正しければ、**widget / control の操作だけが学習から漏れる**。`perform()` は呼出元を
判別できないので、この穴をアプリ側から埋める方法は現状ない（呼出元フラグ案が却下された理由は
[03-app-intents-core.md](../insights/03-app-intents-core.md) にある）。埋められないことが確定したら
FB を出す候補。

どちらも `#98` の結果を待って `AGENTS.md` / insights 側に反映する。**確定するまで
「現在のルール」側には書かない**。
