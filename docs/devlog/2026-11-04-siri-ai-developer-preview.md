# Xcode 27.3 beta の Siri AI Developer Preview に対応した件（`feature/siri-ai-tools`）

現在の結論は [docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md#siri-のツールtoolintent) /
[docs/APP_INTENTS_API_COVERAGE.md の 13 節](../APP_INTENTS_API_COVERAGE.md#13-siri-のツール273-beta-27c5020n) /
[skills/app-intents-system-surfaces](../../skills/app-intents-system-surfaces/references/siri-tools-and-app-skills.md) /
[skills/app-intents-testing](../../skills/app-intents-testing/references/siri-metadata-analyzer.md) にある。
ここには **何をどの順で測り、どこで判断したか**を残す。

## 環境

| | 値 |
|---|---|
| Xcode | **27.3 beta（27C5020n）**（`/Applications/Xcode-27.3.0-beta.app`、`DEVELOPER_DIR` で指定）と 27.2（27B52） |
| AppIntents `user-module-version` | 27.2 = `301.1.16` / 27.3 beta = `301.2.7.2` |
| Swift | どちらも 6.4.2（swiftlang-6.4.2.1.9） |
| シミュレータ | iOS 27.3（24C5037i）/ watchOS 27.2 / visionOS 27.2 |

実測日 2026-11-04。main は f8e7b17。ブランチは `feature/siri-ai-tools`（27.3 正式版まで main に入れない）。

## 1. Xcode が書き出す公式スキルと SDK 差分

- `xcrun agent skills export <dir>` で 27.3 beta のスキルを書き出すと 14 本（27.2 は 11 本）。増えたのは
  `siri-app-integration` / `siri-evaluations` / `macos-touch-gestures`。`xcrun agent skills list` は無い
- iOS の `AppIntents.swiftinterface` は 27.2 → 27.3 beta で **追加だけ**（+402 / −3 行、削除の 3 行はヘッダと
  宣言位置の移動）。足されたのは `ToolIntent` / `AppIntentTraits` / `GenerableEntity` / `AppEntityTraits` /
  `IntentVisibility` / プロパティの `description:` 系 init、それにスキルに説明の無い `.video` ドメイン /
  `SnippetRepresentableEntity` / `DeleteIntent.Target` / `EntityCollectionSearchCriteria`

## 2. ツール 0 本のベースライン

コードを変えずに 27.3 beta でクリーンビルドし（iOS Sim / macOS とも警告 0）、アナライザにかけた。

- iOS `Intento.app`: 34 intents / 0 tools / 9 entities、**`SMA109`（info）1 件だけ**。macOS（35 intents）、
  Widget 拡張、Live Activity 拡張、watch アプリも同じ 1 件。終了コードはすべて 0
- JSON の `toolbox` は空、`--language ja` では「0 of 0 texts translated」。**ツールが無いと他のルールは何も見ない**。
  「指摘 0 件」をメタデータの質が良いと読むのは誤り
- 製品名は `Intento.app`（スキーム名の `IntentTodo.app` ではない）

## 3. 3 本だけツールにしたスパイク

`ToggleTodoCompletionIntent` / `SnoozeTodoIntent` / `ShowTodosIntent` に gated extension で `ToolIntent` を足した。

- 27.3 beta: iOS Sim / macOS / visionOS Sim / watchOS Sim すべて成功（警告 0）
- **27.2: 失敗**（`cannot find type 'ToolIntent' in scope`）。`#if compiler(>=…)` は両者とも Swift 6.4.2 なので
  使えない。**`#if canImport(AppIntents, _version: 301.2)` は区別できる**（リポジトリ外の検証用ファイルで、27.2 が
  `#else`、27.3 が ToolIntent 側に入ることを `#error` / `#warning` で確かめた）
- アナライザ（en）: warning 5 / suggestion 8。`SMA202 ShowTodosIntent.filter`、**`SMA206` ×4（"placeholder text
  ('todo')"）**、`SMA203` ×8（`TodoAppEntity` のプロパティ）。ja では SMA206 が出ない（部分適用のルール）
- `extract.actionsdata` の差分は 3 本の `systemProtocols` / `systemProtocolMetadata(V2)` に
  `com.apple.link.systemProtocol.ToolIntent` が足されただけ
- **`AddTodoIntent`（`.reminders.createReminder`）に `ToolIntent` を足すとビルドエラー**で、
  `appintentsmetadataprocessor` が「no AppIntents metadata have been exported」と出してターゲットの
  メタデータを丸ごと書き出さなかった。試したあと戻した

## 4. 本対応で決めたこと

- **ツールは 12 本**。外した Intent と理由は `ToolIntentConformances.swift` の冒頭と insights の表。
  候補だった 14 本で一度アナライザを回し、`DeleteTodoIntent` と `ShowTodoCountIntent` を外した。
  前者は `.reminders.deleteReminders` と仕事が重なる（アナライザは `SMA701` を出さなかったが、重なりは
  アナライザの対象外）、後者は Get Todo Summary と同じ問いに答える
- **`SMA206` は誤検知として抑止した**。アナライザの中にある語のリストに `todo` が入っていて、単数の "todo" を
  含む説明が全部引っかかる（複数形の "todos" は通る）。説明文を書き換えると 3 つの catalog のキーが全部変わり、
  アプリの語彙（"todo"）も崩れるので、`scripts/sirimetadataanalyzer-config.json` に理由つきで 10 件抑止した
- **`SMA701 RenameTagIntent`（`files.renameFile` に近い）も抑止した**。タグの改名でファイルではなく、
  説明に "tag" と書いてある
- **`SMA202` は直した**。`ShowTodosIntent.filter` に description を足し、3 つの catalog（app / Live Activity /
  watch。共有の Intent コピーが載っているもの）に ja 訳を `needs_review` で入れた。パラメータ名と型は変えていない
- **`SMA203`（13 件）は直さない**。`@Property(description:)` は 27.0 からも出す entity では使えず、
  deployment target は上げない（27.0〜27.2 の利用者を切らない）。上げる判断は SDK 更新の #57 で扱う
- **`GenerableEntity` は使わない**。ツールが受け取るプレーンな値（計画・下書き・時間枠）が無い
- **app skill を 1 本**（`tidy-lists-and-tags`）。リストとタグの整理は 5 本のツールの使い分けと
  「todo は消さない」「消す前に確認」が要るので、スキルの条件（複数ツールの順序 / 聞くべき場面 / 禁止事項）に当たる。
  アプリターゲットが同期フォルダなので `IntentTodo/Skills.skillsbundle` に置くだけで
  `Metadata.appintents/Skills.skillsc` ができた（プロジェクトファイルは触っていない）
- **スキルの書式の誤りはビルドを赤くする**: わざと `name: Tidy_Lists` で書くと `Invalid identifier format` と
  `The 'name' field must match the parent directory name` の 2 件のエラーで exit 65。無音ではない
- **AGENTS.md の「触る前に知っておくルール」には足さなかった**。この作業で出た落とし穴（schema 適合 Intent への
  `ToolIntent`、スキルの書式、27.2 でのビルド）は**どれもビルドが赤くなる**ので「壊れたことに気づけない」の
  基準に当たらない。無音になりうるのは「同期フォルダの外に置いたスキルバンドル」だけで、
  これは skills/ の reference に書いた
- **27.2 でビルドできるガードは入れない**。`canImport(_version:)` は下線つきの構文で、27.3 正式版を待てば
  要らなくなる。代わりにブランチを分け、正式版で main に入れる

## 5. 最終の測定

| 確認 | 結果 |
|---|---|
| 27.3 beta クリーンビルド（iOS Sim / macOS `CODE_SIGNING_ALLOWED=NO` / visionOS Sim / watchOS Sim） | すべて成功、警告 0。`Skills.skillsc` は iOS / macOS（`Contents/Resources/Metadata.appintents`）/ visionOS に入る |
| **27.2 クリーンビルド（iOS Sim）** | **失敗**。`cannot find type 'ToolIntent' in scope` のみ（ツール 12 本 × 2 行）。スキルバンドルは 27.2 でもエラーを出さない |
| テスト（27.3 beta、iPhone 18 Pro / iOS 27.3 シミュレータ） | `TEST SUCCEEDED`。XCTest 41 件 + Swift Testing 301 件（4 run） |
| `audit_intents.py --fail-on error` | 0 error / 6 warning（main と同じ） |
| `check_intent_copy_localization.py` | 欠落 0 / ja 未訳 0 |
| アナライザ（iOS、config あり、en / ja） | 12 tools / **0 error・0 warning・13 suggestion（すべて `SMA203`）**。config なしだと warning 10（`SMA206`）+ suggestion 14（`SMA203` 13 + `SMA701` 1） |
| アナライザ（macOS、config あり、en / ja） | 35 intents / 12 tools、iOS と同じ 13 suggestion |

実機の Siri からツールとスキルが呼ばれるかは確かめていない（#30）。
