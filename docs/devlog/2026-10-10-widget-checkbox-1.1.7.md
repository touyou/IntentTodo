# ウィジェットのチェックを実機で通して 1.1.7 を出した（2026-10-10）

#192 で付けた「ウィジェットの行の丸をタップして完了」を TestFlight の実機（iPhone / 大サイズ）で確かめたら、
3 回直すことになった。build 50 → 52 → 53 → 54。

## build 50: 完了にはなるが、表示がアプリを開いて戻るまで変わらない

書き込みはアプリのプロセス（`.main` 固定）で保存まで終わり、`TodoService.dataDidChange()` から
`reloadAllTimelines()` も呼ばれていた。読む側の拡張が、プロセスが生きている間ずっと同じ
`sharedWidgetModelContainer.mainContext` から取得していて、既に読み込んだ行の古い `isCompleted` を
返していると見て、タイムライン / コントロールの値取得ごとに `ModelContext` を作り直した（#193）。

build 52 では「少し待つと反映される」になった。ただしこの 1 回では、#193 が効いたのか、たまたま
リロードが早く届いたのかは切り分けられていない。

## build 52: 反映までの間、タップが効いていないように見える

アプリのプロセスで書いてからリロードが届くまでの時間。`Button(intent:)` を `Toggle(isOn:intent:)` +
専用の `ToggleStyle` にして、システムがタップ時に `isOn` を先に反転するようにした（#194）。
Intent は同じ `ToggleTodoCompletionIntent`。同時に、取り消し線がまだ変わらないタイトル側へ
`invalidatableContent()` を付けた。

## build 53: タイトルをタップしても詳細が開かず一覧に着地する

「やることを追加」のリンクは効く。アプリが開いている状態でも同じ。

切り分けは iOS 27 シミュレータ（iPhone 18 Pro）で、一時的な UI テストから行った（コミットしていない）:

- `XCUIDevice.shared.system.open` で `intenttodo://todo/<id>` を開く → 詳細が開く。完了済みで一覧に
  出ていない todo でも開く。**アプリ側の URL 処理は正常**
- SpringBoard を操作してホーム画面に大サイズのウィジェットを置き、行のタイトルをタップ → 一覧（実機と同じ）
- タイトル側の `invalidatableContent()` を外して同じ操作 → 詳細が開く

`Link` の中身に `invalidatableContent()` が付いていると、その `Link` が URL を渡さず、ウィジェット全体の
タップ（アプリを開くだけ）になっていた。外した（#195）。無効化表示は実機で「もう少し控えめでいい」
という感触でもあったので、作り直さずに無くした。

## 提出まで

- 最初の production への push（run #50 / #51）は Xcode Cloud の書き出しが 3 プラットフォームとも失敗した。
  ログは `Communication with Apple failed`（ポータルへの `listTeams` が 502）。同じ日に他のアプリでも
  出ていて、数時間後に同じコミットを再実行したら通った（run #52）
- その間に手元でアーカイブして上げる道も試したが、CLI から Xcode のアカウントが使えず
  （`missing Xcode-Token`）、書き出しの署名で止まった。使わなかった
- build 54 を iPhone 実機で確かめた: タイトルのタップで詳細が開く / 丸がタップと同時に切り替わる
- `asc metadata plan` は iOS / visionOS とも差分なし。`asc validate` は errors 1（ビルド未添付）/
  warnings 1（サブタイトル未設定）で、`asc review submit --build-id` が添付まで行う
- iOS / visionOS を build 54 で提出。Vision Pro の実機確認は待たずに出した。macOS は 1.1.6 が
  審査中なので出していない。ドラフト `40b194d5` は今回も「stale なのでスキップ」で迂回された

- #193 拡張側の ModelContext / #194 トグル化 / #195 invalidatableContent を外す

残り: Vision Pro での確認（丸のタップ / 離れたときの簡略表示）と、#193 が効いているかの切り分けは #30
