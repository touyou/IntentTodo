# `Button(intent:)` の実行はシステムに donate されている（#53 / #98 / #99）

「App Intents 中心設計の趣旨なら `Button(intent:)` より `callAsFunction(donate:)` では。あるいは
`Button(intent:)` の内部で donate されている可能性はない？」という問いを確かめた記録。

**答えは後者**だった。アプリは `donate()` を一切呼んでいないのに、`Button(intent:)` のタップは
システム側の donation に記録されている。これで `#53`（donation 不採用）の理由が更新された。
現在のルールは [AGENTS.md](../../AGENTS.md) と
[docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md) にある。

載せ替えの判断は `#99`、残りの検証は `#98`。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f） |
| シミュレータ | iPhone 17 Pro Max / iOS 27.0 |
| 実測日 | 2026-08-30 |

## 1. 観測経路

donation には列挙用の公開 API が無い（`deleteDonations` はあるが read が無い）ので、シミュレータの
データコンテナにある Biome ストリームを直接読んだ。

```
<device>/data/Library/Biome/streams/restricted/
    IntelligenceEngine.Interaction.Donation   # donation。遅れて書かれる
    App.Intents.Transcript                    # intent 実行。即時・呼出元 bundle id 付き
```

読み方は `skills/app-intents-testing/scripts/inspect_donation_stream.py`
（`--snapshot` / `--diff` で「呼出元だけ変えて同じ intent を走らせる」差分実験ができる）。

## 2. 測ったこと

スナップショット → 操作を 1 つだけ → 差分。時刻は UTC。

| 呼出元 | Donation | Transcript |
|---|---|---|
| 何もしない（negative control） | +0 | +0 |
| アプリ内 `Button(intent: AddTodoIntent)` ×1 | **+1**（12:33:05） | +1 |
| アプリ内 `Button(intent: ToggleTodoCompletionIntent)` ×3 | **+3**（12:33:05 / :07 / :09） | +3 |
| Spotlight の App Shortcut から `ShowTodosIntent`（positive control） | **+2**（12:39:54 / :55） | +2 |
| Widget / Control 起点 | 測れず（§5） | — |

## 3. 結論

**アプリ内 `Button(intent:)` の実行は、システムが donation として記録する。**

アプリは `fdd7b5b`（2026-08-21）以降 `donate()` をどこからも呼んでいない（`grep` で残るのは
`deleteDonations` だけ）。それでも記録されるので、システム側が記録している。

したがって `#53` の結論は変わらないが、**理由が入れ替わった**。「規約違反になるから」ではなく、
**アプリ内 UI が全部 `Button(intent:)` である限り、donate すべき「intent を通らない UI 操作」が
存在しない**から。公式サンプル 4 本が明示 donate を必要とするのは UI が Manager を直接呼んで
いるからで（`Button(` 94 件のうち `Button(intent:)` は **0 件**）、前提が違う。

> 「ストリームに載る」＝「学習に使われる」とまでは公式に書かれていない。ストリーム名
> （`IntelligenceEngine.Interaction.Donation`）と WWDC 2026 #343 `6:22–9:46` の Interaction
> Donations の説明が一致することからの推定である。

## 4. 2 回、逆の結論を出した

この結論に至る前に**逆の判断を 2 回書いている**。原因はどちらも読み方で、覚えておく価値がある。

1. **`mtime` を信じた**。Donation ストリームのセグメントは mtime が 7 月なのに中身は 8 月末まで
   入っている（mmap 書き込みで mtime が更新されない）。→ **中身の時刻を見る**
2. **`+0` を「書かれていない」と読んだ**。Donation は派生ストリーム
   （`Library/Biome/compute/sessions/*/subscriptions/` に購読がある）で**生成が遅れる**。
   実測で 4 分後は未反映、80 分後は反映済み。→ **`+0` を見たら待つ**。intent が走ったかどうかは
   即時反映される `App.Intents.Transcript` で見る

加えて、記録の近傍に bundle id が入らないものがあるため、**bundle でフィルタすると取りこぼす**
（判定は `--bundle ""` で行う）。

positive control（システムが走らせる経路で出ることの確認）を先に置く、というのは
`06-control-widget-ios26.md` の教訓どおりだったが、**「待つ」が抜けていると positive control
自体が偽陰性になる**。

## 5. Widget / Control 起点は測れていない（#98 A4）

シミュレータでは次のとおり手が尽きた。同じ道を通らないために残す。

- Control Center に `ToggleTodoControl` / `QuickAddTodoControl` を**追加はできた**
- しかし**合成タップでコントロールが発火しない**。Transcript が +0 なので intent 自体が
  走っていない
- `ToggleTodoControl` の設定シート（`AppIntentControlConfiguration` の todo ピッカー）も
  合成タップで開かなかった
- ホームウィジェットは行が `Link`（公式推奨どおり）なので `Button(intent:)` が無く使えない

次に試すなら実機か、Live Activity のボタン経由。

## 6. 出荷コードでは使わない

このパスは非公開で、OS 更新で消えうる。**検証専用**であって、`deleteDonations` のような公開 API の
代わりに使ってよいものではない。`__appSchemaEntity` の手書き適合を撤去した
（[2026-08-29-schema-vs-watch-target.md](2026-08-29-schema-vs-watch-target.md)）のと同じ線引き。
