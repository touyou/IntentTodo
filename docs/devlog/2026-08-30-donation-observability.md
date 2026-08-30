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

## 7. 訂正: positive control が取れず、2 と 3 の結論は成り立たない

同日、差分実験（#98）を回したところ **2 / 3 の解釈が支えを失った**。上の節は消さずに残すが、
**結論としては採らない**。

実験は「スナップショット → 操作を 1 つだけ → 差分」の形で、`inspect_donation_stream.py` の
`--snapshot` / `--diff` を使った。

| # | やったこと | Donation | Transcript |
|---|---|---|---|
| A2 | 何もしない（アプリ起動のみ） | +0 | +0 |
| A3 | アプリ内 `Button(intent: AddTodoIntent)` ×1 | **+0** | +1 |
| A3 | 続けて `Button(intent: ToggleTodoCompletionIntent)` ×3 | **+0** | +7（entity 記録込み） |
| A3 | 上記のまま 150 秒待って再測定（遅延書き込みの確認） | **+0** | +7 |
| A1 | **Spotlight の App Shortcut から `ShowTodosIntent`**（システム経由） | **+0** | +2 |

A1 が決定的だった。公式が「システムが走らせた intent は自動 donate される」と明言している
経路でも Donation ストリームは動かない。つまり **このデバイスでは今 Donation ストリームが
書かれていない**。したがって A3 の +0 も「`Button(intent:)` は donate されない」ことの
証拠にならない。**チャネルが盲目なだけ**である。

歴史データの最後の記録は 2026-08-29 01:17 で、Transcript 側は今日も書かれ続けている。
`com.apple.intelligenceplatformd` は動いており（pid あり）、`Library/IntelligencePlatform/` 配下も
今日書かれているのに、`Artifacts/donation/donation.db` は 8/28 以降更新されていない。
何が書き込みを止めているのかは分かっていない（Apple Intelligence の有効化状態などが候補）。

**この失敗が今回いちばん実になった部分**である。positive control を置かずに「出なかった」を
読むと、2 / 3 のような結論を自信を持って書いてしまう。#98 のチェックリストに
「A1 を最初に通す」と書いておいたのは正しかったが、**先にこの記録を書いてしまった**のが
順番の誤りだった。

## 8. それでも確定したこと

`App.Intents.Transcript` の側は生きていて、こちらは使える。

- アプリ内 `Button(intent:)` の実行が**即時**（数秒以内）に載る
- **呼出元プロセスが bundle id で区別できる**。アプリ内は `dev.touyou.IntentTodo`、
  Widget / Control は `dev.touyou.IntentTodo.IntentTodoWidget`
- 無操作では増えない（A2）

`App.Intents.Transcript` という名前は WWDC 2026 #343 `6:47` の *"stores these as
schema-conforming App Intents in a **temporary transcript**"* と一致する。ただし
**「transcript に載る」＝「学習に使われる」とは書かれていない**ので、そこは推測しない。
donation の有無を言うには Donation ストリーム側を生かす必要がある（#98）。

## 9. 訂正の訂正: §7 の「書かれていない」も誤り。flush 遅延だった

§7 で「Donation ストリームがこのデバイスで書かれていない」と書いたが、**これも誤り**だった。
`--bundle ""`（フィルタ無し）で見直したところ、§7 の実験で叩いた操作がすべて記録されていた。

| 記録の時刻（UTC） | 型 | 何をしたか |
|---|---|---|
| 12:33:05 | `AddTodoIntent` | アプリ内 `Button(intent:)`（21:32:33 JST にタップ） |
| 12:33:05 / :07 / :09 | `ToggleTodoCompletionIntent` ×3 | アプリ内 `Button(intent:)`（21:33:11 JST にタップ） |
| 12:39:54 / :55 | `ShowTodosIntent` / `LaunchAppIntent` | Spotlight の App Shortcut（positive control） |

**原因は書き込みの遅延**。12:36 JST に取ったスナップショットには 12:33 の記録が入っておらず、
あとから同じファイルに現れた。`Library/Biome/compute/sessions/*/subscriptions/` に
`IntelligenceEngine.Interaction.Donation` の購読があるとおり、これは**派生ストリーム**で、
生成が遅れる。観測できた範囲では **4 分後には未反映、80 分後には反映済み**。

§7 は「positive control を置け」までは正しかったが、**「待て」が抜けていた**。+0 を見たときに
疑うべきものが 2 つ（チャネルが死んでいる / まだ書かれていない）あるのに、前者だけを
確かめて結論を出している。

## 10. 確定した結論

**アプリ内の `Button(intent:)` の実行は、システムが donation として記録する。**

- アプリは `fdd7b5b`（2026-08-21）以降 `donate()` をどこからも呼んでいない
  （`grep` で残るのは `deleteDonations` だけ）
- それでも `AddTodoIntent` / `ToggleTodoCompletionIntent` のタップが Donation ストリームに載る
- negative control（無操作）では増えない
- positive control（Spotlight の App Shortcut）も載る = チャネルは生きている

つまり `#53` で donation を不採用にした判断は、**結果的に正しかった**。理由も更新される:
「規約違反になるから」ではなく、**アプリ内 UI がすべて `Button(intent:)` である限り、
donate すべき「intent を通らない UI 操作」が存在しない**から。公式サンプル 4 本が
明示 donate を必要とするのは、UI が Manager を直接呼んでいて（`Button(intent:)` が 0 件）
その実行がシステムに見えないからで、前提が違う。

> ただし「Donation ストリームに載る」＝「Apple Intelligence の学習に使われる」とまでは
> 公式に書かれていない。ストリーム名（`IntelligenceEngine.Interaction.Donation`）と
> WWDC 2026 #343 `6:22–9:46` の Interaction Donations の説明が一致することからの推定である。

## 11. まだ開いていること（#98 A4）

**別プロセス（Widget / Control）起点の `Button(intent:)` が donation に載るかは未確定。**

歴史データでは widget bundle（`dev.touyou.IntentTodo.IntentTodoWidget`）由来の記録が
Transcript に 13 件あって Donation に 0 件だが、その 13 件の時刻が取れていない（Transcript の
レイアウトでは時刻の拾い方が効かない）ため、Donation が生きていた時間帯と重なるか確認できない。

今回試して**駄目だった方法**も記録しておく:

- Control Center に `ToggleTodoControl` / `QuickAddTodoControl` を追加することはできた
  （`inspect` で `dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl` として見える）
- しかし**合成タップではコントロールが発火しない**。Transcript が +0 なので intent 自体が
  走っていない。編集モードを抜けたつもりでも変わらなかった
- `ToggleTodoControl` は `AppIntentControlConfiguration` の設定シートで対象 todo を選ぶ必要があり、
  そのピッカーも合成タップで開かなかった
- ホームウィジェットは行が `Link`（公式推奨に従っている）なので、`Button(intent:)` が無く使えない

次に試すなら実機か、Live Activity のボタン経由。
