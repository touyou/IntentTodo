# システムが query を呼んだ記録をアプリに残した（#141 / #142）

外部サンプル [kntkymt/ios-app-intents-sample](https://github.com/kntkymt/ios-app-intents-sample) を
読んで、**App Schema 周りのデバッグに使える仕掛け**を 1 つ取り込んだ記録。

取り込んだのは `app-schemas/` にある「query が呼ばれたことをアプリ内に残す」仕組み
（`Log.swift` + `Screens/LogScreen.swift`）。`#function` と件数を `UserDefaults` に追記して
タブで読むだけの、公開 API しか使わない形である。

現在のルールは [docs/TESTING.md](../TESTING.md#query-が呼ばれたかどうかを見る) と
[skills/app-intents-testing/references/query-call-log.md](../../skills/app-intents-testing/references/query-call-log.md)。

## 環境

| | |
|---|---|
| Xcode | 27.0 RC（27A266a） |
| 実測日 | 2026-09-12 |

## 1. なぜ欲しかったか

ここまでの観測手段は 2 つあって、どちらも**「query が呼ばれたか」には答えない**。

| 既存の経路 | 見えるもの | 見えないもの |
|---|---|---|
| `inspect_appintents_metadata.py`（rung 0） | ビルドがシステムに何を伝えたか | 実行時に何が起きたか |
| `inspect_donation_stream.py`（Biome） | intent の**実行** | query の呼び出し |

`os_log` はライブでしか読めず、呼出元が extension だと拾いにくい。AppIntentsTesting は
**自分が呼んだ** query しか見ない。結果として「ピッカーが空」「検索に出ない」「entity が解決しない」を
見たとき、**呼ばれていないのか、呼ばれて 0 件返したのか**が分からない。この 2 つは直し方が逆
（前者は登録とメタデータ、後者は query の中身とストア）なので、切り分けが最初に来るべきだった。

## 2. 入れたもの

`QueryCallLog`（`TodoAppIntents`、DEBUG のみ）が App Group の `UserDefaults` に 1 行ずつ追記する。
17 か所の query メソッド（`entities(for:)` / `entities(matching:)` / `suggestedEntities()` /
`allEntities()` / `displayRepresentations(for:)` / `reindexEntities` / `reindexAllEntities` /
`IntentValueQuery.values(for:)`）から呼んでいる。読み口は 2 つ:

- アプリ内の **設定 → Debug → Query Calls**（DEBUG のみ）
- 外から `skills/app-intents-testing/scripts/dump_query_call_log.py`

元サンプルから**変えた点が 4 つ**あり、どれも「見たい形」に寄せたもの:

1. **`requested` と `returned` を分けた**。元は `count` 1 本だが、探しているのは
   `3 → 0`（システムは聞いたのにアプリが何も返していない）という形で、1 本だと潰れる。
   入力件数が無い `suggestedEntities()` / `allEntities()` は `0` ではなく `nil` にした
2. **`process` を足した**。`ProcessInfo.processName`。どのプロセスが答えたかで
   `@Dependency` の登録場所も `allowedExecutionTargets` の妥当性も変わる
3. **上限 200 件**（古い方から捨てる）。全体を毎回再エンコードするので、
   無制限だと診断が診断対象より重くなる
4. **日付は ISO 8601 文字列**。アプリの外から読む方が多いので、
   `timeIntervalSinceReferenceDate` の double では `plutil` で読めない

呼出側に `#if` を撒かないために、`record` の**本体**だけを `#if DEBUG` にした（Release では空関数）。

## 3. 外から読む経路は 2 回変えた

最初は `xcrun simctl get_app_container <udid> <bundle> <group>` でコンテナを引いて
`Library/Preferences/<group>.plist` を直接読む実装にした。**2 つの理由で捨てた**。

1. **Mac では TCC で開けない**。`~/Library/Group Containers/` は保護されていて、
   `plutil` も Python も `Operation not permitted` になる（パスは合っているのに読めない）。
   フルディスクアクセスを要求するのは道具として筋が悪い
2. **`UserDefaults` の書き込みは cfprefsd が遅延フラッシュする**。ファイルを直接読むと、
   直前の呼び出しが載っていないことがある。`+0` を「呼ばれていない」と読む事故は
   [2026-08-30-donation-observability.md](2026-08-30-donation-observability.md) で 1 度やっている

置き換えた先は `defaults export <group> -`（シミュレータは `xcrun simctl spawn <udid>` 経由）。
どちらも cfprefsd に聞くので上の 2 つを回避でき、`--bundle` も不要になった。

差分実験は既存の donation スクリプトと同じ語彙（`--snapshot` / `--diff`）に揃えた。id が UUID
なので、印を付けて 1 回だけ呼んで、増えた分だけ見られる。

## 4. skill 側にも入れた

`app-intents-testing` skill に:

- `scripts/dump_query_call_log.py`（他プロジェクトでも使えるよう `--group` 必須の汎用形）
- `references/query-call-log.md`（**アプリ側に何を実装するか**。この skill で唯一
  「アプリのコードを足す」ことを求める道具なので、実装の形と 4 つの判断理由まで書いた）
- 「症状 → 段」の表に 1 行、および**「query が返した値を疑う前に、呼ばれたことを確定させる」**
  の 1 段落

## 5. 同じサンプルから出た残タスク

コードとして取り込んだのは上だけで、**残りは issue に落とした**。

| 見つけたもの | 行き先 |
|---|---|
| `.system.open` を複数宣言すると Siri から動かない（外部再現報告）。**このリポジトリは 2 本ある** | **#141** |
| `.reminders.reminder` の `urls` が空配列だと Spotlight の Cascade 索引が失敗（FB23563297）。うちの `urls` は通常空 | **#142** |
| `.camera.openInCaptureMode` が Siri から動かない（FB23562640） | 題材にカメラが無いので `docs/APP_INTENTS_API_COVERAGE.md` に 🚫 + 1 行 |
| 共有 Intent がどのプロセスで走るかの実測（evidence 動画つき） | #30 にコメント（実機検証時の対照として） |

## 6. 出た行と出なかった行は非対称

**行が出れば「そのプロセスで呼ばれた」証拠になるが、行が無いことは証拠にならない。**
DEBUG 限定・App Group を持つプロセス限定・上限 200 件で古い方から消える・同時書き込みは
取りこぼす。「呼ばれていない」と結論する前に、確実に届く経路（Shortcuts のパラメータピッカー）で
positive control を取る必要がある — これは
[06-control-widget-ios26.md](06-control-widget-ios26.md) 以来同じ教訓である。
