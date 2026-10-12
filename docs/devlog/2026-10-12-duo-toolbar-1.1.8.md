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

- #197
