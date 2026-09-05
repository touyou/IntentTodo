# Intent のコピーが ja 化されていなかった件（#73 §1）

現在のルールは [docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md#intent-のコピーはどこから引かれるか)
と [AGENTS.md](../../AGENTS.md) 側にある。ここには**どう間違っていて、どう確かめたか**だけを残す。

## 2026-08-28 出発点は「dialog と description だけ抜けている」という読み

#70 で ja を通したあと、#73 に「`IntentDialog` 15 箇所・`IntentDescription` 20 箇所が
どの catalog にも抽出されていない」と書いた。そのとき立てた仮説は
**「AppIntents のメタデータ経由でアプリターゲットの catalog に載るのは `title` /
`parameterSummary` / `@Parameter(title:)` だけ」**。AGENTS.md にも同じ趣旨で
「Intent の `title` / `parameterSummary` はリンク先ターゲットそれぞれの catalog に
複製抽出される」と書いてあった。

**この前提が両方とも間違っていた。**

## 実測: 抜けていたのは 113/134 で、`title` も抽出されていなかった

ビルド済みの `IntentTodo.app/Metadata.appintents/extract.actionsdata` から、システムが
引こうとしているキーを全部数えて `IntentTodo/Localizable.xcstrings` と突き合わせた。

| 種別 | catalog にある | 欠けている |
|---|---|---|
| intent `title` | 7 | 16 |
| `IntentDescription` | 0 | 20 |
| `@Parameter(title:)` | 0 | 19 |
| `@Parameter(description:)` | 0 | 17 |
| `parameterSummary` | 14 | 0 |
| `categoryName` / `searchKeywords` | 0 | 27 |
| entity・enum の `DisplayRepresentation` | 1 | 27 |

`title` の 7 件は `IntentTodo/TodoAppShortcuts.swift` の `shortTitle` 8 件と文字列が
一致していただけで、intent title として抽出されたものではなかった。
catalog にあった 22 キーの内訳を辿ると:

- `Objects-normal/*/TodoAppShortcuts.stringsdata` — アプリターゲットに直書きした `shortTitle` 8 件
- `Objects-normal/*/ExtractedAppShortcutsMetadata.stringsdata` — `parameterSummary` 14 件

の 2 つしかなく、`TodoAppIntents.build/` には `.stringsdata` が 1 つも無かった。
つまり**このモジュールでは文字列抽出そのものが走っていなかった**（`defaultLocalization` も
resources も無いため）。

## 「パッケージに catalog を持たせれば直る」は半分だけ正しかった

`defaultLocalization: "en"` + `resources: [.process("Resources")]` を足して空の
`Localizable.xcstrings` を置いてビルドしたら、**201 キーが一気に抽出された**
（`IntentDialog` の実行時文言も含む）。ここで「これが正解」と思いかけたが、解決先が別だった。

- `TodoAppIntents_TodoAppIntents.bundle/ja.lproj/Localizable.strings` に訳は入る
- しかし `LocalizedStringResource("Complete Todos")` は既定で `Bundle.main` を引くので当たらない
- `bundle: .atURL(Bundle.module.bundleURL)` を明示すると引ける（`RunCodeSnippet` で確認:
  素のリテラルは `Complete Todos`、bundle 明示は `やることをまとめて完了`）
- ただし **intent の `title` に `bundle:` を付けるとコンパイルエラー**:
  `AppIntents requires 'LocalizedStringResource' to use the main bundle`

メタデータ側も `{"alternatives": [], "key": "..."}` しか持たず bundle / table を記録しない。
**メタデータ経由の文言は main bundle 一択**というのが確定した。パッケージ側の catalog は
抽出の道具としては使えるが、置いたままにすると「訳したのに引かれない」死んだ catalog になるので
戻した。

## 採った形

1. 各ターゲットの `Localizable.xcstrings` に手動キー（`extractionState: "manual"`）として入れる。
   アプリ +180 / watch アプリ +177 / LiveActivity +187（watch のものは Widget と共有）
2. 漏れ検出は `skills/app-intents-localization/scripts/check_intent_copy_localization.py`。
   メタデータのキー全部が catalog にあるかを 4 ターゲット分見る
3. `%@`（`DisplayRepresentation(title: "\(title)")` の補間）は `shouldTranslate: false`
4. 大文字小文字だけ違うキー（`todo` / `Todo` など）でシンボル生成が衝突したので、4 ターゲットとも
   `STRING_CATALOG_GENERATE_SYMBOLS = NO`（生成シンボルはどこからも使っていなかった）

### 途中で見つけた別の壊れ方: dialog が英語の文法を Swift で組み立てていた

```swift
// ShowTodosIntent（修正前）
let categoryLabel = "incomplete todo"          // String リテラル。catalog に載らない
IntentDialog(full: "You have no \(categoryLabel)s.")
```

キーは `You have no %@s.` になるので訳せるが、`%@` に入るのは英語のまま。訳すと
「incomplete todoはありません。」になる。`GetTodoSummaryIntent` は
`count == 1 ? "is" : "are"` まで組み立てていた。単複を訳文側に持たせる形と
`^[...](inflect: true)` に直した（`ShowTodosIntent` / `ShowTodoCountIntent` /
`GetTodoSummaryIntent`）。

## 未確認

システムが本当に main bundle の `Localizable` テーブルを引いているかは、**同じ形の
`shortTitle` / `parameterSummary` が現に ja で出ている**ことからの推論。実機の Shortcuts で
`Update Todo` などが ja になっているかの確認は #30 に足した。

## 参照

- テスト 39 件（UI 16 + AppIntents 23）は変更後も全緑
- #73（この作業の親）/ #30（実機確認）
