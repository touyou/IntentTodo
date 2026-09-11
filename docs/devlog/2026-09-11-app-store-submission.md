# 1.0 を 3 プラットフォーム提出した件（#132）

[提出前の下ごしらえ](2026-09-10-release-prep.md)の続き。`production` を `main` に追いつかせて
Xcode Cloud を回し直し、iOS / macOS / visionOS の 1.0.0 を審査に出すまでをやった。

ここには**「Xcode の正式版を待つ必要があるか」をどう確かめたか**と、
**提出が 2 回弾かれた理由**（どちらも公開 API から触れない項目）を残す。
現在の入力内容は [docs/APP_STORE_LISTING.md](../APP_STORE_LISTING.md) 側にある。

## 1. 「Xcode Cloud が RC でビルドしている」は待っても解決しなかった

出発点は「Xcode Cloud の Xcode が RC になっているので正式版で出し直したい」。
先に**正式版が存在するか**を確かめたら、まだ無かった（実測日 2026-09-11）:

| 見たもの | 結果 |
|---|---|
| `developer.apple.com/news/releases` の RSS | Xcode の最新は **`Xcode 27 RC (27A266a)`**。iOS / macOS / visionOS 27.0 も RC 止まり |
| `asc xcode-cloud xcode-versions` | 27 系は **RC と beta だけ**。`Latest Release` は `17F113`（= Xcode 26.6） |
| ローカル | `/Applications` に 27.0 RC のみ。`xcode-select -p` も RC を指している |

`Latest Release` に切り替えると SDK 27 が無く、deployment target 27.0 のこのアプリはビルドできない。
**RC ビルドは App Store の受付対象**（現に build 32 が `VALID` で上がっている）なので、
RC のまま出す判断にして、代わりに `production` を `main`（60452aa）へ fast-forward した。
Xcode Cloud は `production` の ref 変更で自動発火し、run #33 が 9 分半で `SUCCEEDED`、
iOS / macOS / visionOS の build 33 が 3 つとも `VALID` になった。

> 「プラットフォーム / バージョンの制約」と聞いたら、**まず本当にその選択肢が存在するかを確かめる**。
> ここでは RSS と `asc xcode-cloud xcode-versions` の 2 つで「正式版はまだ無い」と確定できた。

## 2. 提出は 2 回弾かれた。どちらも公開 API に無い項目

`asc validate` は 3 バージョンとも **errors 0 / blocking 0** だったのに、提出は通らなかった。
`asc validate` は公開 API で読めるものしか見ていないので、**緑でも提出は通らないこと**がある。

### (a) App プライバシー（データ使用）の公開

```
appStoreVersions with id '7c50...' is not in valid state.
Associated errors for /v1/appDataUsages/:
  - You must have published answers to your app's data usages.
```

`asc validate` はこれを `info` で「公開 API からは検証できない」と出していた（`blocking` には数えない）。
公開するには ASC の Web UI か `asc web privacy publish`（Apple ID + 2FA の Web セッション）が要る。

### (b) visionOS の `hasHighMotionLabel`

iOS / macOS が通ったあと、visionOS だけ別の理由で止まった:

```
You must provide a value for the attribute 'hasHighMotionLabel' with this request
```

visionOS 版のモーション（動きの激しいコンテンツの有無）申告。
`asc schema appStoreVersions.update` の `requestAttributes` に **この属性は無い**
（`copyright` / `downloadable` / `earliestReleaseDate` / `releaseType` / `reviewType` /
`usesIdfa` / `versionString` だけ）。`asc` 側にも Web セッションのラッパーが無いので、
**ASC の Web UI で答えるしかない**。答えたら通った。

> **提出でしか出てこない必須項目は、プラットフォームごとに違う。**
> iOS / macOS が通っても visionOS が通るとは限らない。3 つ別々に出して確かめる。

## 3. スクショを二重にした

`asc screenshots list` の戻りは `.data[]` ではなく **`.sets[].screenshots[]`**。
`.data[]` で読んで「ASC には 1 枚も無い」と誤読し、その前提でアップロードしたので
各セットが二重になった（iPhone 4 → 8 枚）。

`--skip-existing` も効かない。判定は **`sourceFileChecksum`（ファイルの md5）** なので、
`scripts/capture_screenshots.sh` を撮り直すとファイル名が同じでも中身が変わり、別物として上がる。
実際 mac だけは前回と同一バイトだったので `skipped` になり、そこで食い違いに気づいた。

直し方はローカルとの md5 照合。`md5 -q` の集合に無い asset を消すと、
ASC の中身がローカルの最新キャプチャと一致する（27 件削除 → 6 ロケール分すべて `unmatched=0`）。

## 4. 価格・配信地域で踏んだ 2 つ

- **`availability` はレコードごと無かった**（`app availability not found`）。`asc pricing availability create`
  には `--all-territories` が無く（`edit` 側にしかない）、`asc pricing territories list` で引いた
  **175 件を明示的に渡す**必要がある
- **価格スケジュールの開始日は「今日」だと弾かれる**:
  `Entire timeline must be covered for USA. The first interval has a start date 2026-09-11T00:00 in the future`。
  Apple 側は UTC で見ているので、JST の今日は未来になりうる。**前日を渡すと通る**

## 結果

| プラットフォーム | build | submission | 提出時刻 (UTC) |
|---|---|---|---|
| iOS | 33 | `0880b4da` | 2026-09-11T00:23:48Z |
| macOS | 33 | `1c7af8c7` | 2026-09-11T00:24:02Z |
| visionOS | 33 | `18837eca` | 2026-09-11T00:35:02Z |

3 つとも `WAITING_FOR_REVIEW` / `AFTER_APPROVAL`（審査通過後に自動公開）。
en-US のサブタイトルは空のまま出した（App 名 `Intento - Todo Anywhere` がタグラインを兼ねる形）。
