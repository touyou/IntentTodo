# iPhone Duo に合わせてツールバーを揃えた（2026-10-12）

#197 の洗い出し（Tech Talk "Raise the bar with iPhone Duo" の指針との差分 10 件）を直した。
#197 はコードを読んだだけの洗い出しだったので、ここでは**シミュレータで見て分かったこと**を残す。
現在のルールは [04-ui-integration](../insights/04-ui-integration.md) の「項目にはタイトル・placement・role を必ず付ける」。

## 直したもの

- `ToolbarActionLabel` が iOS で素の `Image` を返していたのを icon-only の `Label` にした
  （追加 / 編集 / リスト保存の 5 か所がこれで直る）。リスト作成と Query Calls の全消去も `Label` に
- キャンセルに `role: .cancel`、保存 / 追加に `role: .confirm`、全消去に `role: .destructive`
- 設定の閉じるを `.confirmationAction` から `.cancellationAction` + `role: .close` へ。
  通常の iPhone / iPad では × が右上から左上へ移る
- 一覧と詳細の自前 ⋯ メニューを、iOS では `ToolbarOverflowMenu` にした

## #197 の「確認したいこと」への答え

- **`Button(intent:)` に role を付ける書き方**: `Button(role:intent:label:)` が `_AppIntents_SwiftUI` にある
- **Duo で縦のバーへ移るか**: 移る。一覧（📁 / ＋ / ⋯ / 検索）も、シートのツールバー（× / ✓）も縦のバーに入った
- `.bottomBar` の追加ボタン（レギュラー幅）と `safeAreaInset` のバナーは、Duo を開いた状態を
  シミュレータで作れず見ていない。#30 に残した

## 測って分かったこと

Xcode 27.1 RC（27A9275）+ iPhone Duo シミュレータ（iOS 27.1）/ iPhone 18 Pro / iPad Air 11-inch（iOS 27.0）。

- **Duo シミュレータは `simctl io screenshot` だと今も真っ黒**。XCUITest の `XCUIScreen.main.screenshot()` は
  正しく撮れ、メニューを開いた状態も写る。操作も XCUITest からなら通った
- `ToolbarOverflowMenu` の中の `Picker` / 入れ子の `Menu` / `Divider` はそのまま出る。並びは「📁 ＋ ⋯」になり、
  ⋯ が ＋ の後ろへ回る
- iPad 縦のリスト列（320pt）でも 📁 ― タイトル ― ⋯ ― ▥ に収まった。
  [2026-09-19](2026-09-19-foldable-width-add-button.md) で測った「この幅のバーが持てるのは 2〜3 個」の範囲内
- メニュー内の項目の `accessibilityIdentifier` は階層に出ない。タイトルと記号の画像（`identifier: 'gearshape'`）は出る
- split view では一覧の ⋯ と詳細の ⋯ が同時に出る（ラベルはどちらも "More"）
- Duo で UI テスト 5 本 + `ScreenshotTests` をまとめて流した 1 回目は失敗し、2 回目は無出力のまま 10 分止まった。
  シミュレータを起動し直して UI テスト 5 本だけ流したら通った。原因は切り分けていない

## 見送ったもの

- 絞り込み表示を残すために「フィルタのアイコンの自前メニュー + 設定だけ ⋯」に分ける案。
  リスト列の trailing が 2 個になり、2026-09-19 の実測（サイドバー切替と合わせて畳まれる）に当たるので試していない
- `visibilityPriority` / `axisBehavior`（27.1 SDK）。あふれる項目が無いので使っていない

## 提出まで（1.1.8）

- `MARKETING_VERSION` は `project.xcproj` を直接編集して上げた（4 行）。Xcode の MCP 経由で開くリクエストが
  承認待ちのまま進まず、本人が外出中だったので了承を得てそうした
- 設定画面のスクショにバージョン番号が写るので、iPhone / iPad は上げたあとに撮り直した。
  `asc screenshots upload --replace --confirm` で 4 セット入れ替え、iOS の 24 枚とも `sourceFileChecksum` がローカルの md5 と一致
- `asc versions create --copy-metadata-from`: iOS は 1.1.7、macOS は 1.1.6 から（`--exclude-fields whatsNew`）。
  macOS は 1.1.7 を出していないので、whatsNew はウィジェットのチェック、キーワードは iOS / visionOS の 1.1.7 に揃えた
- **visionOS 1.1.7 が審査待ちの間は app info が 2 つあり**（`WAITING_FOR_REVIEW` / `READY_FOR_DISTRIBUTION`）、
  `asc metadata apply` は `--app-info` の指定が要る。**`asc validate` は指定する手段が無く実行できなかった**
  （`failed to fetch age rating declaration: 2 app infos match`）。代わりに `asc review submit --dry-run` の
  `wouldSubmit: true` を見て出した
- production への push で Xcode Cloud run #55 が走り、iOS / macOS / visionOS とも成功
- iOS / macOS を build 55 で提出。visionOS は 1.1.7 が審査待ちなので出していない。
  ドラフト `40b194d5` は今回も「stale なのでスキップ」で迂回された

- #197 / #198 ツールバー / #199 1.1.8 bump とメタデータ

残り: Duo を開いた状態と実機での確認、macOS 1.1.8 の起動確認は #30

## 追記（同日）: 添付リンクの修正を 1.1.9 で 3 プラットフォームに出した

同じ日のセキュリティ点検で、やることの添付リンクをスキームを絞らずに開いていたのが見つかり、#201 で
web リンクだけ開くようにした。これを出そうとした時点で **iOS 1.1.8 は既に審査を通って公開されていた**ので、1.1.9 にした。

- 審査待ちだった macOS 1.1.8（build 55）と visionOS 1.1.7（build 54）は `asc submit cancel --id` で取り下げた。
  版の状態が `DEVELOPER_REJECTED` に変わるまで 1 分ほどかかり、その後 `asc versions update --version-id … --version 1.1.9` で
  **同じ版レコードを改名**した（メタデータとスクショはそのまま残る）。iOS だけ `asc versions create` で新規
- 取り下げ後は編集できる app info の ID が変わった（`metadata apply --app-info` に渡す値が変わる）。
  審査待ちが無くなったので app info は 2 つ（公開中 / 編集中）のまま
- macOS / visionOS の whatsNew は、届いていなかった前の版の内容に添付リンクの 1 行を足した
- iPhone / iPad は設定画面にバージョン番号が写るので撮り直し、24 枚とも `sourceFileChecksum` が一致
- Xcode Cloud run #56 が 3 プラットフォームとも成功。`asc review submit --dry-run` を見てから build 56 で 3 つ提出

- #201 添付リンク / #202 1.1.9 bump とメタデータ

残り: macOS / visionOS の 1.1.9 と、web 以外のリンクが文字で出ることの目視は #30
