# 幅の広い iOS で追加ボタンが消えていた件と 1.1.4 の提出

iPhone Duo（折りたたみ iPhone）を開いた状態で「追加ボタンが無くなる」という報告から始まった。
iPad の縦向きでも同じだった。**原因は 3 つ重なっていて、3 つ目は指摘されるまで見つけられなかった。**

ここには**どの仮説を実測で捨てたか**と、**リリースまでに踏んだ 4 つ**を残す。
現在の形は `Packages/UI/Sources/UI/Views/TodoList/TodoListView.swift`。

## 1. 原因は 3 つ重なっていた

Duo を開くと 951x669pt / regular width になる。起動直後の UI 階層はこれだけだった。

```
NavigationBar {{0,24},{951,58}}
  Button label: 'Show Sidebar'
StaticText 'Select a Todo'
```

| # | 何が起きていたか |
|---|---|
| 1 | `columnVisibility` が `.automatic` のままで、この幅ではシステムが `.detailOnly` を選ぶ。ツールバー項目は全部リスト列に付いているので**まとめて画面から消える** |
| 2 | リスト列を出しても 320pt のバーに 設定 / リスト / 追加 / フィルタ の 4 項目は入らず、システムのオーバーフローに畳まれる。**タイトルまで押し出されていた** |
| 3 | **アイコンだけのツールバーボタンはオーバーフローメニューに載らない。**畳まれる代わりに消える |

3 は自力では出せなかった。`asc` でも階層ダンプでもオーバーフローメニューの中身は読めず
（Duo シミュレータはスクショが真っ黒で返る）、「オーバーフローの中にフィルタだけ残って追加が消える」
という**利用者側の観察**が決め手になった。フィルタだけが
`Label(.copy("Filter"), systemImage:)` で、残り 3 つは `Image(systemName:)` + `accessibilityLabel`
だった。タイトルの無い項目はメニュー行を描けないので、メニューに入れずに捨てられる。

> **ツールバーのボタンは `Label` + `.labelStyle(.iconOnly)` で書く。**
> 見た目は同じで、狭いときの退避先ができる。`accessibilityLabel` はこの穴を埋めない。

## 2. 実測で捨てた 3 案

いずれも Duo（27.1）と iPad Air 11-inch 縦で階層ダンプを取って確かめた。

| 案 | 結果 |
|---|---|
| `ToolbarItem(placement: .bottomBar)` | **リスト列では何も描画されない。**`Toolbar` ノードは出るが子が空。`toolbarVisibility(.visible, for: .bottomBar)` を足しても変わらない |
| `.topBarPinnedTrailing` | `+` は残る。ただし席を確保するぶん**設定 / リスト / フィルタとタイトルが全部オーバーフローに落ちる** |
| `.visibilityPriority(.high)` | 効かない。優先度は**リージョン内の順序**でしかなく、trailing はシステムのサイドバー切替が 1 席使っているので、`+` とフィルタの 2 つを置くと優先度に関係なく両方畳まれる |

ついでにフィルタを leading へ移して trailing を `+` だけにする案も試したが、
今度は leading が 3 個になって**全部オーバーフローに落ちた**。

つまりこの幅のバーが持てるのは**システムのサイドバー切替を含めて 2〜3 個**で、
項目数を減らす以外に手が無い。HIG の Toolbars / Best practices も
「デフォルトでオーバーフローするレイアウトを避ける」「狭くなったときに何が退避するかを自分で定義する」
と書いている。

## 3. 落としどころ

- リスト列のバーを **📁リスト ―「やること」― ⋯ ― ▥** の 2 コントロールに。
  設定はフィルタ / タグ / 並び順と同じ ⋯ メニューの行へ移した（絞り込み中のアイコン変化は ⋯ 側が引き継ぐ）
- iOS では `columnVisibility` を `.all` で起動する
- **レギュラー幅では追加をバーから外し、詳細列の右下に prominent な丸 `+` を置く。**
  リスト列を閉じても届く。コンパクト幅（iPhone、Duo 折りたたみ）は従来どおりバーの `+`

最初は Reminders に寄せてリスト列の下に「＋ やることを追加」のラベル付きカプセルを置いたが、
**リスト列を閉じると消える**ので詳細列の右下へ移した。ラベルは落とした
（詳細のコンテンツに重なるので小さいほうがよく、`+` は説明が要らない）。

## 4. 検証でつまずいたところ

**iPhone Duo シミュレータ（27.1）はスクリーンショットが全面黒で返り、タップも途中から効かなくなる。**
判断は UI 階層ダンプだけで行った。選択状態やサイドバーを閉じた状態の確認は、
同じ regular width の iPad Air 11-inch 縦で代替した（そちらはスクショもタップも正常）。

## 5. リリース（1.1.4）で踏んだ 4 つ

| 踏んだもの | 中身 |
|---|---|
| **Mac のスクショが撮れない** | `IntentTodoUITest` の `SUPPORTED_PLATFORMS` に `macosx` が無く `Cannot test target on My Mac` で落ちていた。#161 の `project.xcproj` 変換より前から欠けていて（変換前の `project.pbxproj` にも無い）、`Screenshots/mac/` は 9/10 のまま止まっていた。README が書いている撮り方と食い違っていたので戻した（#164） |
| **macOS の UI テストは認証が要る** | 戻したあとも `The test runner failed to initialize for UI testing (認証はキャンセルされました)` で落ちる。実行時に認証ダイアログが出るので、手元で承認してもらうしかなかった |
| **スクショが二重になった** | `asc versions create --copy-metadata-from 1.1.3` は**スクショもコピーする**。`metadataCopy.selectedFields` にはテキスト項目しか並ばないので気づかず、追記アップロードして iPhone が 8 枚になった。`--replace --confirm` で撮り直し、全 10 セットをローカルとチェックサム比較して確かめた |
| **提出が Xcode のバージョンで弾かれた** | `Build SDK build is not yet supported. / Build Xcode build is not yet supported.`。Xcode Cloud のワークフローが Xcode 27.2 beta（27B5019j）を指していた。**`project.xcproj` 変換が原因ではない**（[2026-09-19-xcproj-conversion.md](2026-09-19-xcproj-conversion.md) で Xcode 27.0 / 27.1 beta とも新形式を読めると実測済み）。`asc` はワークフローの `xcodeVersion` を返さないので、ASC の Web で確認して戻してもらった |

Xcode を戻して production を再ビルドし（run #42）、iOS / macOS / visionOS の 1.1.4 を build 42 で提出した。

`asc validate` は 3 つとも errors 0 / warnings 0 だったが、**1 回目の提出失敗のときも validate は緑だった**。
公開 API から見えない理由で弾かれるのは 1.0.0 のとき（[2026-09-11-app-store-submission.md](2026-09-11-app-store-submission.md)）と同じ形で、
今回はそれがビルドの toolchain だった。

なお、失敗した提出が残したドラフト `40b194d5` は `Resource is not in cancellable state` で
`asc submit cancel` から消せず、2 回目は「stale なのでスキップした」と言われて迂回された。

## 関連

- #162 追加ボタンの修正 / #163 1.1.4 bump とメタデータ / #164 UI テストの macOS 対応
