# 2026-09-17: リスト / タグの管理場所を作り、UI のフィードバック 5 件に答えた

TestFlight の 1.1.1 を触ったフィードバック 6 件。1 件目が機能追加、残りが見た目と情報設計。

> リストやタグが設定はできるものの管理する場所がどこにもありません。特にリストはそのせいで重複が
> 結構ある状態になってしまってそうなので、管理できる画面や検索に活用できるようにしてほしいです。

## 1. 「リストは設定できる」の実体を確かめたら、作る経路がどこにも無かった

フォーム（`TodoFilingSection`）は `@Query(sort: \Domain.Category.name)` で**既存のリストを
選ばせる**だけ。production のコードで `Domain.Category(name:)` を呼んでいるのは
`ScreenshotFixture` だけだった（残りは全部テスト）。つまり:

- リストを**新規作成する経路がアプリにもインテントにも無い**
- したがって Shortcuts / Siri から `list` に未知の名前を渡すと `TodoService.resolveCategory` が
  `notFound` を投げて終わる
- 重複の出どころは**リストではなくタグ**の可能性が高い。タグは自由入力で、`isSameTag`
  （大文字小文字 + 濁点を無視）での重複排除は **1 つの Todo の中でしか効いていなかった**。
  Todo A に `Work`、Todo B に `work` は両方残る

`docs/APP_INTENTS_API_COVERAGE.md` には `.reminders.createList` が ⬜ で #139 が立っていた。
**「リスト作成の Intent が無い」はすでに地図に載っていた穴**で、フィードバックがその穴を
ユーザー側から踏んだ形。

### 採った形: 6 本の Intent を足して、画面はその呼び出し元にした

| Intent | スキーマ | 備考 |
|---|---|---|
| `CreateListIntent` | `.reminders.createList` | #139 の createList をここで消化 |
| `UpdateListIntent` | — | 名前 + 色。`valueState` で 3 状態（未指定 / 設定 / 明示的に消す） |
| `DeleteListIntent` | — | Todo は残る |
| `MergeListsIntent` | — | 重複の直し方そのもの |
| `RenameTagIntent` | — | 既存タグへの改名 = 統合 |
| `DeleteTagIntent` | — | Todo は残る |

`CreateListIntent` は**同名を渡したら既存を返す**。バリデーションエラーにしなかったのは、
リストがユーザーから見えるところ（フォームのピッカー、Siri の「Work のリストに」、Shortcuts の
エディタ）では**名前でしか識別されない**ため。同名が 2 本あると、どの面でも区別できないまま
Todo が静かに分かれる。

**削除系に `requestConfirmation` を付けなかった**。これまでの家の作法（`DeleteTodoIntent` +
`DeleteTodoImmediatelyIntent` の 2 本立て）を踏まなかったのは、リストもタグも**削除して失う
Todo が 1 件も無い**から（`TodoItem.category` は nullify、タグは配列から外れるだけ）。取り消し
可能な操作なので 1 本で Siri とアプリ内ボタンの両方に出せる。確認は画面側の
`.confirmationDialog`。

### 画面は設定の中に置いた

一覧画面の 1 カラムは Todo 自身なので、2 つ目の階層（リスト → Todo）を差し込むと
NavigationSplitView の設計ごと変わる。設定が寂しいというフィードバックも同時に来ていたので、
設定に「整理」セクションを足してそこから `ListManagementView` / `TagManagementView` へ。

**macOS にも `Settings` シーンを足した**（⌘,）。それまで `SettingsView` は
`#if os(iOS) || os(visionOS)` でファイルごと落としていたが、Mac に無いのは `ShortcutsLink`
だけなので、そのセクションだけ条件付きにすれば画面は共有できた。

- `Settings` シーンは `WindowGroup` の environment を継承しない。`.modelContainer` を付け直す
  まで、Mac の管理画面は**リスト 0 件・タグ 0 件で正常に見えていた**
- `#if os(macOS)` を `.commands { }` の後ろに続けて `Settings { }` を書くと
  `Unexpected tokens in '#if' expression body`。修飾子チェーンに掛かっている条件の中に
  2 つ目のシーンは挿し込めないので、シーンごと別の `#if` にする

### 確認ダイアログは `Button(intent:)` と相性が良い

`Button(intent:)` は完了を教えてくれないので、シートを出すと閉じる手段が無い（`AddTodoView` は
`NavigationModel` 経由で intent に閉じさせている）。リスト作成とタグ改名は **`.alert` の中の
`TextField` + `Button(intent:)`** にした。アラートはどのボタンを押しても自分で閉じるので、
閉じる責任がどこにも要らない。

統合先の選択は `.confirmationDialog` に候補を並べる形。**ダイアログのアクションのラベルは
`Text` でないと黙って消える**（iOS / tvOS / watchOS）ので、`Label` を使わない。

### タグで絞り込むために `TodoItem.tags` を読んではいけない

一覧の絞り込みにタグを足そうとして、02-swiftdata-concurrency に書いてある罠に正面から当たった:
**削除済みの `@Model` からコレクション属性を読むと trap する**。`@Query` の結果は削除後 1
フレームだけ削除済みオブジェクトを含むので、`todoItems` を回して `tags` を見る実装は「削除した
瞬間だけ落ちる」ものになる。

`#Predicate` に `tags.contains` を押し込む案も検討したが、**fetch 経由なら削除済みは返って
こない**という既知の事実で足りた。`TodoService.organizeSnapshot()` が `fetchAll()` から
タグ所属・リスト所属・セクション数を 1 回で作り、`@Query` は**変更検知の合図としてしか使わない**
（`TodoStoreDigest` はスカラーしか読まない）。

digest に**リスト名と色を入れる必要があった**のは、リスト名の変更が Todo を 1 件も触らないため。
件数と `modifiedAt` の最大値だけだと、名前を変えても管理画面が古いまま表示される。

## 2. 詳細ヘッダの「下だけ余白が大きい」は空の `HStack` だった

```swift
VStack(alignment: .leading, spacing: 12) {
    HStack { checkbox; title }
    HStack(spacing: 8) { /* バッジ。0 個のこともある */ }
}
.padding(.vertical, 4)
```

バッジが 0 個でも `HStack` は子として存在するので、**`VStack` の spacing 12 がタイトルの下に
残る**。上は padding 4 だけ、下は 12 + 4 で、セルが下に重い。`if hasBadges` で行ごと作らない
ようにして解決。

## 3. Siri ヒントは降ろした

> Siriヒントはやっぱり出方も変なので出さなくていいかもと思いました。

`SiriTipBanner` / `SiriTipModel` / `SiriTipModelTests` を削除。2026-08-28 に「常設をやめて
文脈のある瞬間だけ」に直した（[04-ui-integration.md](04-ui-integration.md#2026-08-28-siritipview-を一覧の一等地から降ろしshortcutslink-を設定に置いた)）ものだが、**タイミングを直しても出方の違和感は残っていた**。

降ろす判断にした理由は 3 つで、どれも調整では消えない:

- 一覧の上端に割り込んで**高さを変える**。兄弟の `FocusFilterBanner` /
  `MissedFeedbackBanner` は「今そういう状態だから出ている」が、Tip にはその説明が無い
- 3 回目の追加という内部カウンタは外から推測できないので、**出る / 出ないが確率的に見える**
- 教えたい相手（フレーズを知らない人）と出る相手（アプリ UI で追加を繰り返す人）がほぼ同じで、
  その人はすでにアプリ内で目的を達している

`NavigationModel.inAppAddCount` は Tip のためだけにあったので消した。`ShortcutsLink` は残す
（探しに来た人に見せるだけで、割り込まない）。

## 4. ツールバーを記号にした。ただし Edit は HIG が例外として名指ししている

> Prefer simple, recognizable symbols for items instead of text, **except for actions like *edit*
> that aren't well-represented by symbols**. — Apple: HIG, Toolbars

一覧のツールバーは元から全部アイコンだったので、対象はシートの確定 / 取消だった。Cancel →
`xmark`（HIG が Close を標準記号にすると名指し）、Add / Save → `checkmark`、設定の Done →
`xmark`。**詳細画面の Edit は文字のまま**——HIG が *edit* を例外に挙げているため。

**macOS だけ文字を残す**。Mac ではこれらがウィンドウのツールバーに並び、フォームの上の
ダイアログという扱いでタイトル付きプッシュボタンが期待される面になる。`ToolbarActionLabel`
1 つに分岐を閉じて、追加シートと編集シートが別々に変わらないようにした。

## 5. 「完了」バッジは消し、バッジのアイコンと文字を詰めた

> 完了後に完了のタグのようなものが出るところがアイコンと文字の間隔あきすぎて微妙です。あと完了を
> 示すものが近くに密集しすぎて無駄に感じるのでもはやいらないかも

同じ 1 セルの中で完了が 3 回言われていた: チェックボックスが塗られる / タイトルに取り消し線 /
「完了」バッジ。**バッジを消した**（iOS と visionOS の両方）。残る Favorite / Overdue /
Due Soon は「タイトル行が語っていないこと」なので残す。

間隔は `Label` の既定のギャップが body 相当の行を想定した幅で、caption + capsule の中では
開きすぎる。`TightLabelStyle`（`LabelStyle`、`HStack` 直書きではない）で 3pt / 5pt に詰めた。
スタイルにしたのは**1 つのアクセシビリティ要素のまま**にしたいから。

## 6. 診断を TestFlight でも見えるようにした

> 設定画面が今さびしいのでアプリの情報やデバッグメニューなどもう少し機能を増やしたいです。

設定に「整理 / Siri & Shortcuts / このアプリについて / やることの状況 / Diagnostics」の 5 節。
Diagnostics を `#if DEBUG` のままにしなかったのは、**ここで見たい壊れ方が App Store Connect を
通った後にしか起きない**から（`AppIntentsPackage` の件がまさにそれで、Xcode 経由のインストール
では再現しなかった）。debug ビルドにしか無い診断は、そのために書いた失敗を観測できない。

`DiagnosticsAvailability.isEnabled` が 1 か所で決める（DEBUG または
`appStoreReceiptURL` が `sandboxReceipt`）。`QueryCallLogView` は release にもコンパイルされる
ようになったが、文言は `Text(verbatim:)` のまま（読者は開発者で、App Store 版からは到達できない）。
`QueryCallLog.record` も同じフラグで黙るので、App Store 版は何も書かない。

## 検証

- 4 プラットフォーム（macOS / iOS / visionOS / watchOS）ビルド緑
- パッケージテスト: 新規 `TodoOrganizeTests` 17 件 + `TodoListViewModelTests` 追加 6 件を含めて
  168 件緑
- **クリーンビルドで統合メタデータを確認**（AGENTS #12）。`inspect_appintents_metadata.py` が
  `CreateListIntent -> reminders.CreateListIntent` を報告し、`checks: all clear`。
  `CategoryAppEntity -> reminders.ListEntity` などの既存適合も維持
- `check_intent_copy_localization.py`: 3 ターゲット × 0 missing / 0 untranslated (ja)。
  新しい Intent コピー 36 キーは手動キーとして 3 catalog に入れた（抽出に載らないため）

## 未確認

- 配布ビルドで Diagnostics が実際に出るか（`sandboxReceipt` 判定）は TestFlight まで通さないと
  分からない → #30
- Shortcuts アプリ上で新しい 6 本のタイトル / 説明が ja になっているか → #30

---

# 追記（同日、TestFlight 1.1.2 (38) のフィードバック）

配信した 38 を英語設定の iPhone で触ったフィードバック 3 件。

## 7. `^[0 todo](inflect: true)` が生で表示されていた

リストの一覧にマークアップがそのまま出た。原因は**パッケージのバンドルに `en.lproj` が無い**こと。

```
$ ls Intento.app/UI_UI.bundle
Info.plist  _CodeSignature  ja.lproj        ← en.lproj が無い
$ ls Intento.app            # アプリターゲット側
en.lproj  ja.lproj
```

カタログの `sourceLanguage` は `en` だが、`en` の localization を持つキーが 1 つも無いので
Xcode は `en.lproj` を作らない。結果、英語では `.copy("…")` が**キーそのもの**に落ちる。
素のコピーならキー = 英語なので無害で、これまで誰も気づかなかった。マークアップを入れた瞬間に
可視化した。

アプリターゲット側の `en.lproj/Localizable.strings` は
`"Completed ^[%lld todo](inflect: true)." => "Completed ^[%lld todo](inflect: true)."`
とマークアップを**展開せずに**持っている。つまり展開は実行時で、ルックアップが成功する限り
動く。パッケージだけが踏む罠だった。

**ウィジェットの「残り n 件 / ほか n 件」も同じ状態で出荷済みだった**（`WidgetUI_WidgetUI.bundle`
も `ja.lproj` のみ）。日本語で使っていたので露出していなかった。

直し方はマークアップを捨ててカタログに複数形を持たせる形:

- キーを素の `%lld todos` / `%lld sections` / `%lld lists` に変更
- `en` に `plural.zero` / `plural.one` / `plural.other` を入れる →
  `UI_UI.bundle/en.lproj/Localizable.stringsdict` が生成されるのをビルド生成物で確認
- `%lld remaining` / `%lld more` は単複で形が変わらないので `en` を足す必要すら無い
- 古い `^[…]` キーは `extractionState: stale` になるので削除（[[xcstrings-keys-are-owned-by-extraction]] の順序どおり）

守りは `PackageCopyKeyTests`。4 パッケージのカタログにマークアップ入りキーが無いことを見る。

## 8. 検索でタグが当たったことが分からない

検索対象をタイトル / 説明 / リスト名 / タグに広げた結果、**タグで当たった行が何も当たっていない
行と見分けが付かなくなっていた**（タイトルで当たった場合も同様）。

- タイトルは一致部分を `inlinePresentationIntent = .stronglyEmphasized` で強調。背景色にしなかった
  のは、行がすでに色（期限 / お気に入り）を持っていて選択状態とも競合するため
- タイトル以外で当たったときだけ `TodoSearchReason` をキャプションに出す（タグはチップ 2 つ + `+N`、
  リストはフォルダ記号、説明は「説明に一致」）
- 判定は絞り込みと同じ `localizedStandardContains(_:)`。**行がフィルタの使っていない理由を
  主張しない**ようにしている

## 9. リストは「閲覧」と「管理」を別画面にした

> リストはリスト画面を純正リマインダーみたいに作ってもいいかもなー / 設定画面はあくまで管理で、
> 一覧は別というのがわかりやすいかも

`TodoListsBrowseView` を新設し、一覧のツールバー（`folder`、leading）から push する。

- 「すべてのやること」「未分類」＋マイリスト。件数と選択中のチェックマーク付き
- 選ぶと `dismiss()` で一覧に戻り、**ナビゲーションタイトルがそのリスト名になる**
- **フィルタメニューからリストの絞り込みを外した**。フィルタ（状態）とタグは「同じものをどれだけ
  絞るか」だが、リストは「何を見ているか」を変える軸で、タイトルが変わるものをメニューの 1 行に
  畳むと変化の理由が見えない
- 設定側は「管理」セクションに改名し、フッターで「リストごとに見るには一覧のフォルダボタン」と
  やらないことを明示（両方が "Lists" という同じ語を使うため）

純正リマインダーのようにリストをルートにする案は採らなかった。このアプリのルートはやること一覧
そのもの（デモの中心）で、ルートを差し替えるとナビゲーション設計ごと変わる。閲覧の入口を 1 つ
足すだけで「一覧は別」は満たせている。

## 検証（追記分）

- 4 プラットフォームビルド緑 / SwiftLint エラー 0
- `PackageCopyKeyTests` 4 件 + 既存 45 件、計 49 件緑
- **シミュレータのテストは環境要因で一度落ちた**。`CoreSimulator.framework was changed while
  the process was running`（Xcode 更新中にプロセスが生きていた）で、コードとは無関係。
  実行先を My Mac に変えて走らせた

---

# 追記（同日、1.1.2 を提出）

39（1.1.2）で問題なしの確認が取れたので、3 プラットフォームとも App Store に提出した。

## 1.1.1 は公開済みだったので `versions create` が通った

1.1.0 のときは **in-flight なバージョンがあると次を作れない**ため取り下げ → 改名という手順を
取った（[2026-09-12-release-1.1.0.md](2026-09-12-release-1.1.0.md)）。今回は 1.1.1 が
3 プラットフォームとも `READY_FOR_DISTRIBUTION`（= in-flight ではない）だったので、普通に作れた。

```bash
asc versions create --app 6788623037 --version 1.1.2 --platform IOS \
  --copy-metadata-from 1.1.1 --exclude-fields whatsNew
```

`--copy-metadata-from` で説明文・キーワード・URL が 2 ロケール分コピーされ（`copiedFieldUpdates: 10`）、
**スクリーンショットも引き継がれた**（3 表示タイプ × 2 ロケールがそのまま付いていた）。
`whatsNew` だけ除外して `metadata/*/version/1.1.2/` から入れる形になる。

## `asc localizations upload` は使えない

`metadata/` の JSON は `asc metadata` 系のためのもので、`localizations upload` は
**`.strings` ファイルを期待する**（`Error: no .strings files found`）。既存手順どおり
plan → approve → apply を 3 回まわす。

**`plan` は `.asc/metadata/review/plan.json` を毎回上書きする**ので、プラットフォームごとに
plan → approve → apply を通しで回す必要がある（3 つ plan してからまとめて apply はできない）。

## 提出

| | version id | build | state |
|---|---|---|---|
| iOS | `af525f68…` | 39 | `WAITING_FOR_REVIEW` |
| macOS | `87c3cd97…` | 39 | `WAITING_FOR_REVIEW` |
| visionOS | `13e57821…` | 39 | `WAITING_FOR_REVIEW` |

`asc validate` は 3 つとも **errors 0 / blocking 0**。warning 2 件は 1.1.1 から続く既知のもの
（en-US の subtitle 未設定 / キーワードにアプリ名の語が含まれる）で、info 1 件は App プライバシーの
公開状態が API から確認できないという注記。

## 残っているもの

- **スクリーンショットは 1.1.1 のものを引き継いでいる**。詳細画面のバッジとツールバーが変わり、
  リスト / タグの画面は 1 枚も無いので、次の機会に `scripts/capture_screenshots.sh` で撮り直す → #158

---

# 追記 2（同日、1.1.3）

1.1.2 を提出した直後に、**検索理由のチップが「完了」バッジと同じ崩れ方をしている**と指摘された。

## 同じ欠陥を新しい場所で作っていた

`StatusBadge` は `TightLabelStyle` で直したのに、`TodoSearchReason` のチップは素の `Label`
のままだった。**直し方をローカルな修正として書いたので、次に同じ形を作ったときに再発した。**

`TightLabelStyle` をファイルごと切り出し、`.labelStyle(.tight)` / `.tightProminent` として
使えるようにした。素の `Label` が正しい場所（リストの行、メニュー項目、コンテキストメニュー、
`ContentUnavailableView`、ツールバー）と、詰めるべき場所（カプセル / キャプションの中の
インラインラベル）を型の名前で区別する。

指摘された箇所以外も見直して、`TodoDetailTimeRemainingLabel`（期限の下のキャプション）も
同じ種類だったので直した。3 分岐で重複していた `.font(.caption)` も外側に出した。

見た目は `#Preview("Search reasons")` を足して `RenderPreview` で確認した（**シミュレータが
死んでいる状態でも My Mac 宛なら描画できる**）。

## リリースは 1.1.3 として出した

1.1.2 は提出済みで、**macOS だけ先に審査を通って配信済み**だった。ビルドを差し替えるには
提出の取り下げが要り、macOS はもう配信されている。番号を上げるほうが安いので 1.1.3 にした。

| platform | 1.1.2 の状態 | 1.1.3 の扱い |
|---|---|---|
| macOS | `READY_FOR_DISTRIBUTION`（配信済み） | in-flight ではないので新レコードを作れる |
| iOS | `WAITING_FOR_REVIEW` | **in-flight なので 1.1.3 を作れない**。1.1.2 の審査が終わるのを待つ |
| visionOS | `WAITING_FOR_REVIEW` | 同上 |

取り下げれば今すぐ 1.1.3 にできるが、審査の順番を失う。iOS / visionOS は 1.1.2 を通してから
1.1.3 を出す（利用者が一度だけ間延びしたチップを見るが、取り下げの代償より安い）。

## 1.1.3 の提出で分かった 2 つ

**`asc metadata plan` / `apply` は `--app-info` が要る**（審査中のものがあるとき）。提出中の
submission が app info をもう 1 つ作るので、`multiple app infos found` で止まる。
`READY_FOR_DISTRIBUTION` 側（= 公開中の app info）を渡す。

```
Error: multiple app infos found for app "6788623037"
  (1322b3ab…[state=WAITING_FOR_REVIEW], db49654b…[state=READY_FOR_DISTRIBUTION])
```

**`asc validate` は `--app-info` を受け取らない**ので、この状態では走らない（`failed to fetch
age rating declaration`）。代わりに `asc review submit --dry-run` で `wouldSubmit: true` を見る。

もう 1 つ踏んだのは自分のミス: `plan` の出力を `/dev/null` に捨てたまま `approve` したので、
**前のプラットフォームの plan を承認していた**（`planHash` が visionOS のものだった）。
`approve` は plan の中身を見ないので黙って通る。**plan の出力は毎回読む。**

| platform | 1.1.3 | build |
|---|---|---|
| macOS | `WAITING_FOR_REVIEW` | 40 |
| iOS | 1.1.2 の審査待ちのため未作成 | — |
| visionOS | 同上 | — |
