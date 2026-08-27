# 2026-08-28: `AppShortcuts.xcstrings` を「一番目立つ穴」から降格した経緯

`docs/APP_INTENTS_API_COVERAGE.md` の「いま空いている穴」1 位と `docs/PLAN.md`「次に効きそうな方向」
1 位、および #68 の第 1 項は、いずれも `AppShortcuts.xcstrings` を最優先の未着手項目として挙げていた。
理由として書いていたのは **「UI コピーは全パッケージで String Catalog 化済みなのに、Siri フレーズだけ
英語のまま」** という非対称。

WWDC 2026 で「App Schema を採用すればフレーズは Apple 側が持つ」という話があったはずという記憶から
再評価したところ、**2 つとも前提が違っていた**。

## 1. 「フレーズを書かなくてよくなった」のは App Schema の話で、App Shortcuts には効かない

`docs/references/wwdc/wwdc2026-8011-apple-intelligence-group-lab.md` が両者を明示的に対比している。

- `59:03` — "because app shortcuts are custom, it means that you have to provide sample phrases …
  And that's the cool thing about app schemas: when you integrate with a schema, Apple is doing the
  heavy lifting, so you don't have to provide those phrases"
- `23:33` — schema なら "Apple has done the heavy lifting of essentially providing those sample
  phrases of training the model"
- `5:55` — "app shortcuts does require a phrase"
- `4:28` — "for the new Siri AI integration … you do need to adopt one of our app schemas"

つまり新 Siri（LLM 経路）に乗る条件は schema 適合であり、そこではフレーズも翻訳も書かない。schema に
乗らない Intent は従来どおりロケール別のリテラル一致でしか音声から届かない。**`AppShortcuts.xcstrings`
の必要性が消えたのではなく、schema でカバーした分だけ不要になる**という関係だった。

このアプリの schema 適合は当時 `.reminders.list` / `.reminders.listType` / `.system.searchInApp` /
`.visualIntelligence.semanticContentSearch` のみで、追加・完了・削除といった中核動作は非 schema。
`.reminders.reminder` 本体適合は SSU バグでブロック中（#56）なので、恩恵が中核に届いていない状態だった。

## 2. そもそも「UI コピーは catalog 化済み」＝ 多言語化済み ではなかった

実測（`project.pbxproj` と 4 つの `Localizable.xcstrings` の中身）:

| 対象 | 実態 |
|---|---|
| `knownRegions` | `en, Base` のみ |
| `UI` / `WatchUI` / `WidgetUI` / `LiveActivity` | 計 187 キー、**翻訳ロケールは 0 件**（`sourceLanguage: en`、`localizations` が空。`WatchUI` だけ `en` エントリあり） |
| アプリターゲット | `Localizable.xcstrings` が無い。Intent 側のコピーは AppIntents メタデータ経由でここに集約される経路（[04-ui-integration.md](04-ui-integration.md) で実測済み）なのに受け皿が無い |

`docs/devlog/04-ui-integration.md` に書いた作業で入ったのは「**抽出できる土台**」であって、翻訳の
実体はどこにも入っていない。**非対称は存在せず、アプリ全体が英語のみ**だった。「catalog 化済み」という
言葉が「多言語化済み」に読み替えられ、そのまま 3 箇所のドキュメントと issue に転写されていた。

## やったこと

- `AppShortcuts.xcstrings` を穴リストから外し、状態を `⬜`（未着手）から `⏸`（単体では成立しない）に変更
- ja 対応を通しでやるエピックとして **#70** を起票（`knownRegions` → アプリターゲットの catalog →
  4 パッケージ catalog → `TodoAppIntents` のコピーの bundle 決定 → `AppShortcuts.xcstrings` の順）。
  順序に依存があるので「フレーズだけ訳す」形は選べない
- #68 の第 1 項を #70 へのポインタに差し替え
- `docs/PLAN.md`「次に効きそうな方向」は 1 位を `ShortcutsLink` に繰り上げ、多言語化を末尾に移した

## 併せて確認した #56（reminder 本体スキーマ）の状態

再評価の一部として「SSU バグが直っていれば中核動作が schema 経路に乗り、訳す対象自体が縮む」ことを
実ビルドで確かめようとしたが、**toolchain が測定済みのものと同一**だった（`Xcode 27.0 (27A5237l)` =
`docs/APP_INTENTS_CENTRIC_PLAN.md` の beta 5 行、コミット `647acb6`）。コード側の回避 `35d772f` も
入ったままなので結果は決定的に同じになる。クリーンビルドは回さず、#57（GM SDK 棚卸し）待ちのままとした。

**教訓**: 「catalog 化済み」「対応済み」のような語は、土台の導入と実体の投入を区別しない。優先度を
決める前に**実データを見る**（今回は `xcstrings` の `localizations` が空であることと `knownRegions`）。
ドキュメント間で理由を転写すると、元の 1 箇所の誤読が「3 箇所に書いてあるから確か」に化ける。
