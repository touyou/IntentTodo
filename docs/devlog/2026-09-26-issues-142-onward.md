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
