# 2026-09-06 Keynote の実物をレビューできるようにした

登壇スライド（`iosdc2026_appintents_centric.key` / 118 面）は iCloud Drive にあり、これまで
**中身をレビューできていなかった**。`docs/presentation/` にあるのは骨子と原稿（`99-script.md`）だけで、
**実際に投影されるものは誰も突き合わせていない**状態だった。今回そこを読める形にして、原稿レビュー
（[99-script.notes.md](../presentation/99-script.notes.md)）の決定が実物に入っているかを確認した。

結果は [99-keynote.notes.md](../presentation/99-keynote.notes.md)。ここには経緯と、途中で間違えたことを残す。

## 1. `.key` は protobuf なので、AppleScript で 2 つ吸い出した

`.key` はディレクトリパッケージで、本文は `Index.zip` の中の IWA（protobuf）。テキストとして
grep できない。Keynote が起動していれば AppleScript が使えるので、

1. **PDF 書き出し** → 版面をページ画像として読む
2. **`text items` + `presenter notes` の全面ダンプ** → 文言と喋る内容をテキストで読む

の 2 経路にした。手順は 99-keynote.notes.md の F にまとめた。ダンプで詰まったのは 2 点:

- `default title item` / `default body item` は**このテンプレートでは常に空**。
  マスター由来ではなく自由配置のテキストボックスなので、**`text items` を回さないと何も取れない**
- `export ... with properties {skipped slides:false}` を書くとき、
  AppleScript 側のローカル変数名に `skipped` を使うと `-10006`（「skipped を false に設定できません」）で
  落ちる。予約語衝突。変数名を変えれば通る

## 2. ⭐ 原稿より Keynote のほうが進んでいた

**これが一番大きい発見**。`99-script.md` は 83 面で L211 が `TBD`（第 2 部が未執筆）。ところが
**Keynote には第 2 部相当が `S91`–`S118` として既に入っていた**（つまづき 3 本 / donation の答え合わせ /
App Schema / Skills 配布 / まとめ）。

つまり `99-script.notes.md` の D-7 (e) はほぼそのまま Keynote 側で実装されていて、**原稿だけが古い**。
レビュー対象としてどちらを正とするかで結論が変わるので、**Keynote を正**として扱うことにした
（原稿は直接編集しない運用のため、原稿側は追従させない）。

## 3. B-0 の「Keynote のノートも更新済み」は一部が事実ではなかった

`99-script.notes.md` B-0 は「原稿側はこの表の内容で書き換え済み。**Keynote の発表者ノートも本人が
更新済み**」と書いていた。実物と突き合わせたら、B-1 / B-2 / B-3 / B-4 / B-5 / B-10 は入っていたが、

- **B-8（誤字 `SiirKit` / `App Intelligence`）は Keynote 側だけ直っていなかった**
- **C-7（2020 の伏線回収を `S31` に足す）が入っていなかった**

の 2 件が漏れていた。**「原稿を直した」と「Keynote を直した」を同じ行に書いたのが原因**で、
片方だけ済んでいても表の上では区別できなくなっていた。→ 今後は反映状況を**原稿と Keynote で
別の列にする**（99-keynote.notes.md の B は Keynote 専用の表にした）。

C-7 の漏れは単独では小さいが、**`S117`（まとめ）の「2020 年から」が浮く**という形で表に出ていた。
伏線（`S20`）は張られていて、回収（`S31`）が無く、参照（`S117`）だけが残っていた。

## 4. 尺の見積もりを 2 回間違えた

1. **1 回目（このセッションの最初）**: 発表者ノート 10,811 字を **330 字/分**で割って「33〜39 分。
   40 分枠の余白はゼロ」と書き、歴史パートの圧縮を提案した。→ **本人の通し実測が 34 分 28 秒**で、
   余白が 5.5 分あることが判明。提案は取り下げた
2. **前提の取り違え**: `99-script.notes.md` A-1 には **496 字/分**の実測（原稿の音読）が既にあったのに、
   一般値の 330 を使っていた。そして実際の通しは **314 字/分**だった

**素読みの話速（496）と本番の実効話速（314）は別物**で、後者はノートどおりに喋らないぶん
（間・言い換え・スライドを見せる時間）を含む。**原稿の字数から尺を出すなら 314 を使う**。
教訓としては、**尺は推定せず通しを計る**のが正しく、推定するなら**どちらの話速か**を明示する。

## 5. 直したもの

Keynote 実ファイル（機械的な誤りだけ。編集前に `ditto` でバックアップを取った）:

| 面 | 内容 |
|---|---|
| `S19` ノート | `SiirKit` → `SiriKit` |
| `S33` ノート | 「App Intelligence が発表されたこの年」→ 「Apple Intelligence が…」 |
| `S113` ノート | `S105` のノートのコピペ残りが入っていた。暫定文に差し替え（本人の言い方に書き直す前提） |
| `S114` 本文 | `gh skill install` のダッシュが **em dash + ハイフン**（U+2014 + U+002D）。写して打つと動かないので `--` に修正 |

`S114` は **Keynote のスマート置換が `--` を em dash に変えていた**もの。書式（Menlo-Bold 65.0）が
均一だったので `objectText` を丸ごと差し替えても崩れないと確認してから置換し、置換後は
`id of character` で U+002D（45）になっていることを確かめた。

ドキュメント側:

- **devlog に残っていた古い skill パス 2 件**。skill 名の改称（`intent-centric-architecture` →
  `app-intents-*` 系への分割）に追従していなかった。**`S103` の裏取りを辿る途中で 1 件目を踏み、
  grep して 2 件目が出た**

  | ファイル | 直した先 |
  |---|---|
  | [2026-08-30-donation-observability.md](2026-08-30-donation-observability.md) | `skills/app-intents-testing/scripts/inspect_donation_stream.py` |
  | [2026-08-28-intent-copy-localization.md](2026-08-28-intent-copy-localization.md) | `skills/app-intents-localization/scripts/check_intent_copy_localization.py` |

## 6. 残り

判断が必要なもの（`S117` の直し方 2 択 / Codex 経路の検証 / D の 1 行を入れるか / 版面調整 /
演出込みの尺の再計測）は **[#67](https://github.com/touyou/IntentTodo/issues/67)** に寄せた。
