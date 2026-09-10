# macOS の操作導線を直した件（サイドバー開閉の位置 / 削除 / ショートカット）

日付: 2026-09-10
関連: [docs/insights/07-platform-specific.md](../insights/07-platform-specific.md#macos-の操作導線ツールバー--キーボード--コンテキストメニュー)

Mac で触ってもらったフィードバックが 3 つ。

1. サイドバーの開閉ボタンの位置がおかしい。**開閉の導線がサイドバーの開閉で動くべきではない**
2. 削除が大変（詳細を開いて Delete Todo → 確認、しか経路が無い）
3. ショートカットが 1 つも無い

## 1. サイドバーのトグルはどこに居たのか

実物を撮って確かめた（ウィンドウだけを `screencapture -l <CGWindowID>` で撮る）。ツールバーの並びは

```
[信号機] [+] [フィルタ⌄] [サイドバートグル] │ Intento …… [検索フィールド]
                          ^^^^^^^^^^^^^^ サイドバーの trailing 端
```

`+` とフィルタは**サイドバー側セクションの先頭**に居るので、サイドバーを畳んでもウィンドウ左端に
寄るだけで見かけの位置は変わらない。動くのは既定のトグルだけだった。`NavigationSplitView` が付ける
トグルはサイドバー幅の右端に張り付くため、サイドバー幅が 0 になった瞬間に左へワープする。

`.toolbar(removing: .sidebarToggle)` で既定を外し、自前のトグルを置いた。置き場所は 2 回試した。

| placement | 結果 |
|---|---|
| `.navigation` | **detail 側セクションの先頭**（タイトルの手前）に出た。サイドバー幅ぶん動くので却下 |
| `.automatic`（`+` より前に宣言） | サイドバー側セクションの先頭 = 信号機の右隣。採用 |

`.navigation` のドキュメントは "leading edge of the toolbar ahead of the inline title" とあるが、
split view では **どの column の `.toolbar` に書いたか**ではなく detail 側に載る。これは推測ではなく、
撮って確認している。

畳んだ状態の確認は、クリックを合成せずに `columnVisibility` の初期値を一時的に `.detailOnly` にして
起動 → 撮影 → 戻す、という手でやった。開いた状態と畳んだ状態で

```
[信号機] [トグル] [+] [フィルタ⌄] …
```

の並びと x 座標が一致することを確認した（この確認のためだけの変更はコミットに含めていない）。

## 2. 削除の経路を 3 つに増やした（実行は 1 つに収束させる）

Mac には swipe action が無いので、一覧から削除する手段が存在していなかった。増やしたのは経路で、
実行する Intent は増やしていない。

- **⌫ / ⌦**: `List` に `.onDeleteCommand`
- **行の右クリック**: `.contextMenu`（完了トグル / お気に入り / 削除）
- **メニューバー**: やること ▸ やることを削除（⌘⌫）

`keyboardShortcut(.delete, modifiers: [])` を隠しボタンに当てる案は捨てた。メニューのキー等価は
フィールドエディタより先に評価されるので、検索フィールドで backspace が効かなくなる。
`.onDeleteCommand` はレスポンダチェーン経由なので、テキスト入力中は入力側が先に食う。

`.onDeleteCommand` はクロージャで `Button(intent:)` にできない。ここで `TodoService` を直接呼ぶと
（`persistReorder` の前例はある）snapshot → undo 登録 → donation 削除まで写経することになり、
削除の意味が 2 か所に分かれる。なので **クロージャは「確認を頼む」だけ**にして、実行は
`.confirmationDialog(_:item:)`（SwiftUI 27 の新 API）の中の
`Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo:))` に任せた。
3 経路とも同じダイアログ・同じ Intent に収束する。

確認を挟んでも「詳細を開く」より速いし、`UndoableIntent` なので ⌘Z も効く。

## 3. ショートカットとメニューバー

`TodoCommands: Commands` を `Packages/UI` に置き、`WindowGroup` に `.commands { }` で付けた
（`#if os(macOS)`）。中身は insights の表のとおり。

判断が要ったのは**対象 Entity の渡し方**。`NavigationModel` は App 側に居るので
`TodoCommands(navigationModel:)` で渡せば `selectedTodo` も読めるが、`Commands` の body が
`@Observable` の変更で必ず組み直される保証を確認していない。組み直されなければ**古い選択に対して
Intent が走る**（＝別の todo が消える）。読み違いの代償が大きいので、選択は `focusedSceneValue` /
`@FocusedValue` に載せた。これは「フォーカスに依存するメニュー項目」のために用意された仕組みで、
更新は SwiftUI が保証する。

提示だけの項目（⌘N の追加シート、⌘E の編集シート、⌘⌫ の確認）はクリック時に
`NavigationModel` のメソッドを呼ぶので、そもそも陳腐化しない。

`SidebarCommands()` は入れた（⌃⌘S）。自前の `columnVisibility` と同じ split view を動かすので
状態は 1 つのまま。

## 確認

こちらで自動確認できたのは、ビルドとメニューの生成（やること メニューがバーに出て、項目と
ショートカットが並ぶ）まで。クリックを合成しない方針（`osascript` でのキー送出は使わない）なので、
**メニュー項目の `Button(intent:)` が実際に intent を実行するところ**は本人に依頼し、
#30 に B-6 として起票した。

同日中に手で確認してもらい、8 項目すべて問題なしだった。**`Button(intent:)` は `Commands` の中
（macOS のメニューバー）でも intent を実行する**が実測で取れたことになる。`@FocusedValue` 経由の
対象解決も、選択を変えながら ⌘↩ / ⇧⌘F を叩いて期待どおりだった。

iPhone 17 / iOS 27 では全 302 件パス。My Mac 宛に走らせると `IntentTodoUITest` の 17 件が落ちるが、
これは iOS 向けの UI テストを Mac 宛に走らせているためで、この変更前でも同じ 17 件が同じメッセージで
落ちる（stash して確認した）。
