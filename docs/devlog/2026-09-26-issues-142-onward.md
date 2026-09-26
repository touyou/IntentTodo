# #142 以降の issue を片付けた（2026-09-26）

オープンだった #142 / #158 / #167 / #169 / #170 / #171 を順に当たった記録。

## #142 `urls` が空だと Cascade 索引が失敗するか — 当たらなかった

外部サンプルの報告（FB23563297）は「`@AppEntity(schema: .reminders.reminder)` を `indexAppEntities`
に渡すと、`urls` が空配列のときだけ `LNSpotlightCascadeTranslator` Code=5 で失敗する」。
このアプリの `urls` は通常空なので、URL を入れていない todo が Siri 側に届いていない可能性を疑った。

iPhone 17 Pro シミュレータ（iOS 27.1）で、アプリの UI から 2 件足して `log show` を見た:

| todo | 経路 | 結果 |
|---|---|---|
| `CascadeEmptyURL`（URL なし） | `reindexSpotlight`（1 件ずつ） | `Finished set donation <AppIntentsIndexedEntity…>` → `result: success` |
| `CascadeWithURL`（`https://example.com`） | 同上 | 同上 |
| 上の 2 件 | 次の起動の `indexAllForSpotlight`（batch） | 同上 |

`Code=5` / `field url` / `__EmptyArrayStorage` はどのプロセスからも 1 行も出なかった
（`siriactionsd` の `Code=6` は `com_apple_shortcuts_runnable` / `MDItemCachedViewData` のもので、
このアプリの属性ではない）。

後から考えれば当然で、**`urls` は `@DeferredProperty` なので index に値が載らない**。
サンプルは `urls` を computed の `var` で返していた。形が違うので同じ失敗にはならない。
Feedback は出していない。

測る途中で 2 回つまずいた:

- `xcrun simctl spawn <udid> defaults write <bundle id> …` は**アプリのコンテナではなく
  シミュレータ全体のドメイン**に書くので、`spotlight.needsFullReindex` を立てても効かない。
  コンテナの plist を直接書き換えても、cfprefsd がキャッシュを持っていて読まれない。
  結局 UI から todo を足して、差分 index と、次の起動の全件 index（client state が変わる）を起こした
- iPhone Duo シミュレータはデバイス操作のスクショが真っ黒で、タップも届かなかった（1.1.4 のときと同じ）

## #171 medium で開いた追加シートをキーボードが隠すか — 隠さなかった

同じシミュレータで測った（画面 402 × 874 pt）:

- 開いた直後（medium、シート上端 y=415）: タイトル / 説明 / 期限 / お気に入り / 「詳細」見出しまで見える
- タイトル欄をタップすると、**システムがシートを `.large` まで広げる**（上端 y≈60）。キーボード上端は
  y=538。タイトル欄（y 167–219）から「詳細」見出しまでの 5 行が見える

issue に書いていた「フォーカスしたら `presentationDetents(_:selection:)` で `.large` に上げる」は、
システムがすでにやっていた。コード変更なしで閉じた。初期フォーカスを入れると開いた瞬間に `.large` に
なるので入れていない（#169 で「続けて追加」したあとだけフォーカスを戻す）。

## #169 連続入力 — シートに「続けて追加」トグルを置いた

`AddTodoIntent.perform()` の呼び先を `NavigationModel.dismissAddTodo()` から `didAddTodo()` に変え、
閉じるか・空にして開いたままにするかを `keepsAddingTodos`（UserDefaults）で分けた。
「Intent が成功したらシートが次の状態に進む」の 1 対 1 は残る。

「追加」と「追加して次へ」のボタン 2 本にしなかったのは、どちらも同じ `Button(intent:)` になり、
押された側を `perform()` に渡すには UI 専用の公開パラメータが要るため。トグルなら状態が
`NavigationModel` に先に載っている。

トグルはタイトル / 説明のすぐ下に置いた（`TodoFormSections` に `afterTitle` の差し込み口を足した）。
medium の高さでも見える位置はここしかない。リスト / セクションは次の 1 件に引き継ぐ。

シミュレータで確かめた: ON で `KeepA` → `KeepB` と足すと、シートは開いたまま、タイトル欄が空になり、
フォーカスとキーボードが残る。OFF にして `KeepC` を足すと閉じる。

## #170 既存の todo の間への挿入 — 作らない（⏸）

位置に意味があるのは手動ソートのときだけで、その場合は追加してからドラッグすれば足りる。
`AddTodoIntent` に挿入位置を持たせると、Siri / Shortcuts からは意味の無い公開パラメータが増える。
理由は `docs/insights/04-ui-integration.md` に残した。

## #158 スクショの撮り直し

`scripts/capture_screenshots.sh` で全プラットフォーム × ja / en を撮り直した。iPhone / iPad には
5 枚目としてリスト閲覧画面（`05-lists`）を足した（App Store Connect の上限は 10 枚なので、
既存のカットは落としていない）。ASC への差し替えは確認してからにして、この時点ではやっていない。

## #167 Siri で一覧すると一部しか返らない — 未解決

本人のコメントで「Siri 経由で追加したタスクしか拾えない」が正確と分かった。最初は #142 と同じく
「アプリから足した todo が Cascade に入っていない」を疑ったが、上のとおり
アプリの UI から足した todo も、起動時の一括 index も Cascade への donate は成功していた。
Spotlight 索引の漏れではない。

`ShowTodosIntent` は `todoService.listTodos(filter:)` をストアから引くだけで、作った経路で絞る処理はない。
「Siri で作ったものだけ」になるなら、Siri がこの Intent を呼ばずに、自分が作った結果（transcript）から
答えている可能性が高い。実機でしか分からないので #167 に残した。

## 追記: スクショ用の一時ストアが iCloud と同期していた

撮影を回した後に本人から「しばらくすると同期されるようで、macOS の追加画面のスクショに写り込む。
同じデータなので、削除すると同じものがまとめて消える」と報告があった。

原因は `SharedModelContainer.createInMemoryContainer()` が `ModelConfiguration(schema:isStoredInMemoryOnly:)`
だけで作られていたこと。`cloudKitDatabase` の既定は `.automatic` なので、アプリのプロセス
（CloudKit の entitlement を持つ）で作ると in-memory でもミラーリングが動く。その結果:

- フィクスチャ（id が毎回同じ）が iCloud に上がり、DEBUG ビルドの入った他の端末に降りる。
  同じ `id` の行が撮影のたびに増えるので、1 つ消すと同じ `id` の行がまとめて消える
- 本物のデータが撮影中のストアに降りてきて、Mac のように画面ごとに起動し直すカットに写り込む
- フィクスチャは流し込む前にストアの todo とリストを全件消すので、降りてきた行を消して、
  その削除を上げうる

`cloudKitDatabase: .none` を明示して直した。iPhone 17 Pro シミュレータ（iCloud 未サインイン。
mirroring delegate は立ち上がってアカウント無しで止まるので、行数で比べられる）で
`com.apple.coredata:CloudKit` の行数を数えた:

| ビルド | ストア | `CoreData+CloudKit` の行数 |
|---|---|---|
| 修正前 | 一時ストア（`-uitest-ephemeral-store -uitest-screenshot-fixture`） | 11 |
| 修正後 | 一時ストア | 0 |
| 修正後 | 共有ストア（引数なし） | 11 |

Mac では対照を取らなかった。`/Applications` の App Store 版と DEBUG ビルドは同じ App Group の
ストアファイルを共有するので、DEBUG ビルドを共有ストアで起動すると、本番のストアを開発用の
CloudKit 環境で開くことになる。影響を受けたのは DEBUG ビルド（開発用 CloudKit 環境）の同期先で、
TestFlight / App Store 版（本番環境）には届いていないはず。すでに混ざったフィクスチャは本人に消してもらう。

## 追記: 1.1.5 を出した

#172 / #169 / #174 を 1.1.5 として 3 プラットフォームに提出した（Xcode Cloud run #43、build 43）。

- `production` へ main をマージして push し、Xcode Cloud に作らせた（5 分で完了）
- `asc versions create --copy-metadata-from 1.1.4` で作り、whatsNew だけ `asc metadata apply` で差し替えた。
  コピーされた 1.1.4 のスクショは 10 セットとも `--replace --confirm` で上げ直した
- **`screenshots upload` は 10 セット中 4 セットが途中の枚数で止まった**（出力も JSON として読めなかった）。
  同じコマンドを流し直すと通ったので一時的な失敗。上げたあとで `screenshots list` の
  `sourceFileChecksum` をローカルの md5 と突き合わせて 10 セットとも一致を確かめた
- `asc validate` は 3 つとも errors 0。warnings 2 件（サブタイトル未設定 / キーワードがアプリ名の語を含む）は
  1.1.4 から変えていない掲載情報についてのもので、そのまま提出した
- 1.1.4 のときの消せないドラフト `40b194d5` は今回も「stale なのでスキップ」で迂回された

## 追記: #167 は `ShowTodosIntent` が `.foreground` 専用だったことが効いていた

1.1.5 の TestFlight で本人が確かめた結果:

- Siri で一覧すると「something went wrong」。Query Calls には `TodoEntityQuery.entities(for:)` が
  1 件頼まれて 1 件返した行だけ（登録 todo は 2 件）
- Shortcuts で Show Todos を「実行時に開く」オフで走らせると `not allowed`

後者で原因が確定した。`ShowTodosIntent` だけが `supportedModes = .foreground` で、アプリを前面に
出せない実行経路では丸ごと拒否される。8/27（#55）に「`OpensIntent` との Intent 合成を保つ」ために
`.foreground(.dynamic)` を差し戻していたが、その結果、値を返すだけの経路が無くなっていた。

本人の判断で、3 案（`[.background, .foreground]` + `OpensIntent` を残す / バックグラウンド専用 /
`.foreground(.dynamic)`）のうち `.foreground(.dynamic)` から試す。`OpensIntent` は返り値の型に出るので
dynamic と両立せず、`NavigationModel.showList(filter:)` を直接呼ぶ形にした。`NavigationModel` は
Widget Extension に登録していないので、読み取り系だが `allowedExecutionTargets = [.main]` にした。

クリーンビルドの統合メタデータで `supportedModes: 9`（`.background` 1 + `.foreground(.dynamic)` 8）、
`openAppWhenRun: false` を確認。iOS シミュレータの `testAddThenShowChain` は緑。Mac で同じテストを
流すと Widget Extension が `0xdead10cc`（App Group の SQLite ロックを持ったまま停止して RunningBoard に
落とされる）で落ちて失敗した。スタックにアプリのコードは無く、この変更で Widget Extension は
`ShowTodosIntent` を走らせなくなっている。実機の Siri / Shortcuts での確認は TestFlight に回した。

## 追記: Siri は一覧の依頼を OmniSearch で答えていた / donation の漏れを埋めた

TestFlight（build 45）で本人に 2 回ログを取ってもらった（`sudo log collect --device-udid …`）。

**1 回目（リンクの無い todo を編集した直後）**: アプリのプロセスで Spotlight への donate と
Cascade（`AppIntentsIndexedEntity`）への set donation がともに `result: success`。
`LNSpotlightCascadeTranslator` の `Code=5` / `field url` はどのプロセスからも出なかった。
「リンク付きの todo しか認識されない」を見て一度「#142 に当たっていた」と訂正したが、それは誤りで、
#142 の結論（当たらない）はそのままでよかった。

**2 回目（「Intento で未完了のやることを表示」と話しかけた直後）**:

- `ShowTodosIntent` は実行されていない。`searchtoold`（OmniSearch）が Spotlight を横断検索し、
  Siri に 6 件を返した。内訳は Apple 純正リマインダー（`com.apple.reminders`）5 件と Intento の
  app entity 1 件。Intento 側は候補 13 件のうちキーワード一致（sparseScore 1.0）の 1 件だけが残った
- 「リンク付きだけ」は索引の漏れではなく、この順位付けの結果だった
- `linkd` は App Shortcuts を **en-JP** で補間していた（`Interpolating AppShortcuts for
  dev.touyou.IntentTodo:en-JP`）。本人の Siri が英語設定で、日本語の登録フレーズは照合に使われて
  いなかった。日本語で「Intento のやることを表示」と言って `ShowTodoSearchResultsIntent` に
  落ちたのも、これと合わせて読む必要がある

本人から「donation が効いていないだけでは」と指摘があり、UI の操作経路を洗った。
`Button(intent:)` を通らないのは、フィルタの選択、行の選択（詳細を開く）、ドラッグでの並び替えの 3 つ。
前 2 つを `UIActionDonation` で UI 側から `intent.donate()` するようにした（並び替えは ⏸）。
シミュレータで、フィルタを 3 回切り替えて行を 1 回開き、Transcript に `ShowTodosIntent` 3 件と
`OpenTodoIntent` 1 件が増えるのを確認した。陽性対照の `Button(intent: ToggleFavoriteIntent)` ×2 も
Transcript +2 で、Donation ストリームは対照を含めて +0（このシミュレータでは書かれていない）。

`Binding(get:set:)` は SDK 27 で `@isolated(any) @Sendable` のクロージャを取るので、非 Sendable な
Binding をキャプチャすると警告になる。拡張とクロージャを `@MainActor` にして消した。
