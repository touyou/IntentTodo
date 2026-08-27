# 2026-08-28: docs の残タスクを issue に逃がし、役割分担を「現在のルール / 経緯 / 残タスク」の三分割にした

## きっかけ

`docs/` を全走査したら、**ドキュメントの中に生きたタスクが残っている**箇所が複数あった。

- `docs/presentation/` の 3 ファイルに「発表前チェックリスト」が計 30 項目以上（`- [ ]` のまま）
- `docs/APP_INTENTS_CENTRIC_PLAN.md` の「未着手の候補」表 — 判断が決着した項目（#52 / #53 / #54）が
  取り消し線つきで残り、生きている候補と混ざっていた
- `docs/devlog/06-control-widget-ios26.md` の「**残タスク**: `.promptsForUserConfiguration()` と失敗時の
  エラー通知は通っていない」— 前者は翌日のエントリで確認済みになっていたが、**後者は誰も追っていなかった**

とくに最後のものが問題で、devlog は追記のみの時系列ログなので、**そこに書いたタスクは
読み返さないと発掘されない**。実際に 2 週間以上放置されていた。

## 決めたこと

置き場を 3 つに分け、同じ情報を 2 箇所に書かない。

| 書くもの | 置き場 |
|---------|-------|
| 現在のルール・結論 | `AGENTS.md` / `docs/insights/` など |
| 経緯（過去形・追記のみ） | `docs/devlog/` |
| **残タスク（これからやること・未検証・判断待ち）** | **GitHub issue** |

- **`docs/` に `- [ ]` を残さない**。タスクが出たら issue を立て、docs にはポインタを 1 行
- devlog に「残タスクとして残した」と書くときも、その場で起票してポインタを併記する
- 「やらない」で決着した判断は**理由つきで docs 側に残す**（同じ検討を半年後にもう一度させないため）

ルール本文は `AGENTS.md`「ドキュメント運用」と `docs/devlog/README.md` に置いた。

## やったこと

1. **issue へ移送**
   - #67: 登壇準備の残タスク（骨子① / 骨子② / 99-script のチェックリストを統合）。
     解決済みだった 2 件（Apple Pencil Pro squeeze の追記 / Group Lab 未調査 4 件）は移送時に落とした
   - #68: 未採用 API の候補から次の拡張を決める
   - #30 にコメントで H 節を追加（Control の失敗通知 / `MissedFeedback` / LA 無効時の 3 項目）
2. **`docs/APP_INTENTS_API_COVERAGE.md` を新設**。App Intents（+ WidgetKit / Spotlight）の API を
   1 行ずつ並べ、✅ 採用済み / ⬜ 未採用候補 / ⏸ 意図的不使用 / 🚫 対象外 / ⏳ ブロック中 で分類した。
   判定はドキュメントの記憶ではなく **`.swift` 全走査での実測**（`grep` でシンボルごとにヒットファイルを取る）。
   これで「使っていない API を眺めて次を考える」入口が 1 つになり、PLAN / AGENTS.md から重複していた
   「未着手の候補」「意図的不使用」リストを畳めた
3. **数字の実測を取り直した**（ドキュメントが古い値を持っていた）
   - Intent ファイル / 型: 24 / 23 → **25**（`TodoFocusFilterIntent` の追加分）
   - `isDiscoverable = false`: **6**、AppShortcut: **8**、AppEntity **4** / AppEnum **3** / Query **4**
   - AppIntentsTesting: **23 テスト**（`IntentTodoUITest/AppIntents/` の 3 ファイル）
4. **明確に誤っていた記述を訂正**
   - `docs/AGENTS.md`「AppShortcutsProvider はパッケージ内で定義可能。メインアプリから `@_exported import`
     で再エクスポート」→ **逆**。アプリターゲット直下必須（パッケージに置くと `autoShortcuts: 0`）。
     2026-08-12 に判明していたが、`docs/AGENTS.md` 側だけ直っていなかった
   - `docs/AGENTS.md`「テスト戦略」が AppIntentsTesting 導入前の記述だった → 3 層（SPM / AppIntentsTesting / XCUITest）に更新
   - `docs/insights/01-swift-package-design.md` の `@_exported import` は**現在使っていない**（コードに 1 件も無い）
   - `docs/PLAN.md` の「iOS 26 では Control からのアプリ起動が動作しない」→ 現在は
     `ControlWidgetButton` + `.foreground(.immediate)` で動く
   - `docs/insights/04-ui-integration.md` / `AGENTS.md` の「iOS 26.4 以降 / 〜26.3」の場合分け →
     deployment target が 27 なので不要。`.onAppIntentExecution` は現在使っていないという事実に置き換え
   - README.md の Intent 一覧が 9 本（実際は 25 本）、パッケージが 4 つ（実際は 7 つ）、
     App Shortcuts が 4 フレーズ（実際は 8 件）だった
5. **`AGENTS.md` に混ざっていた長い経緯をポインタに畳んだ**（`AppIntentsPackage` 重複宣言の根拠 3 点、
   Primary / FromExtension 分離の撤去、Control の dialog / snippet 比較、二重登録の役割分離、
   watchOS の assistant schema フォールバック）。**自分のルールを自分が破っていた**形

## 残っている判断

`docs/presentation/` の骨子は「発表用の素材」なので、`⚠️ 一次ソース未確認` のマークは本文に残した
（スライドに出す文言の性質に関わる注記であって、タスクではないため）。タスク性のあるものだけ #67 に移した。
