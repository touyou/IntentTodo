# 2026-08-28: ja 対応を通しでやった（#70）

前日 `AppShortcuts.xcstrings` を「最優先の穴」から降格し、ja 対応を #70 として切り出した
（経緯: [2026-08-28-appshortcuts-localization-reeval.md](2026-08-28-appshortcuts-localization-reeval.md)）。
その #70 を通しで実施した記録。現在のルールは
[docs/insights/04-ui-integration.md](../insights/04-ui-integration.md#ja-を入れて分かった-catalog-の配置) にある。

## 着手前の状態

issue #70 に書いたとおり、アプリ全体が英語のみだった。

| 対象 | 状態 |
|---|---|
| `knownRegions` | `en, Base` |
| 4 パッケージの catalog | 191 キー / 翻訳ロケール 0 件 |
| アプリターゲット | `Localizable.xcstrings` が無い |
| `AppShortcuts.xcstrings` | 無い |

## Xcode の Localization Planner に土台を作らせた

`knownRegions` への `ja` 追加と catalog の新規作成は手で書かず、`LocalizationPlanner`
（`xcode-integration:translation-coordinator` スキル経由の MCP ツール）にやらせた。
**`project.pbxproj` を直接編集すると Xcode 側がクラッシュしうる**ため、pbxproj に触る操作は
すべてこのツールに寄せる必要がある。

一度目の実行と二度目の実行で結果が違った（一度目は Extension 3 ターゲットが
`IntentTodoLiveActivity/Localizable.xcstrings` 1 ファイルを共有する形、二度目は
LiveActivity が自前を持ち Widget が `IntentTodoWatchApp/Localizable.xcstrings` を借りる形）。
Xcode 側のキャッシュ状態に依存するらしい。採用したのは二度目。

途中で pbxproj を `git checkout` で戻してしまい、これも「直接編集」に当たるので二度目の
Planner 実行で復旧した。**pbxproj は読む以外のことをしない**。

## 分かったこと 1: 抽出はターゲット単位で、共有パッケージの文言は全ターゲットに複製される

`TodoAppIntents` は 7 ターゲットにリンクされているので、`Intent` の `title` /
`parameterSummary` が**リンク先ターゲットそれぞれの catalog に同じキーで入る**。
`Add todo titled ${title}` のような 14 キーは 6 catalog に重複して現れ、合計 88 件。

これを別々に訳すと表記がぶれる。先に 1 バッチで確定させてから他 catalog に横展開する順序にした。

## 分かったこと 2: パッケージ側に catalog は要らなかった

`TodoAppIntents` は catalog を持たない。実行時にどの bundle から引かれるのか（issue #70 の
3 つ目のチェック項目）は、ビルド成果物を見れば分かった。

```
IntentTodo.app/ja.lproj/Localizable.strings            ← Intent の title / parameterSummary
IntentTodo.app/ja.lproj/AppShortcuts.strings           ← Siri フレーズ（String Set）
IntentTodo.app/ja.lproj/nlu.appintents                 ← ja の NLU 学習データ
IntentTodo.app/UI_UI.bundle/ja.lproj/…                 ← .copy(_:) 経由の UI コピー
IntentTodo.app/PlugIns/…Widget…appex/ja.lproj/…        ← Extension 自身の Intent コピー
IntentTodo.app/Watch/IntentTodoWatchApp.app/ja.lproj/… ← watch アプリの分
```

各ターゲットの main bundle に落ちる。`TodoAppIntents` に catalog を足す必要はなく、
`.copy(_:)` パターンの対象にもならない。

## 分かったこと 3: `en` しか無いと `.lproj` が生成されない、は ja を入れると解消する

insights に「en しか無い状態では `UI_UI.bundle` に `en.lproj/Localizable.strings` は入らない」と
書いてあった。ja を入れたら `ja.lproj/Localizable.strings` は生成された。前の記述は
「翻訳が 1 つも無い言語には `.strings` が生成されない」という一般則の観察で、間違ってはいなかった。

## 翻訳の進め方

288 件を 15 件前後のバッチに割り、`xcode-integration:translation` スキルを持つサブエージェントに
分割委譲した（Apple のスキルが指定している手順）。用語集（`Todo` → やること、`Intento` は DNT、
`urgent` → 急ぎ、など）をバッチ全部に同じ文面で渡して表記を揃えた。

`AppShortcuts.xcstrings` は最後。8 キーすべてが String Set（1 アクションに複数の言い回し）で、
訳ではなく**日本語話者が実際に言う言い方**を並べる必要がある。語順も変わる
（`Add a todo in ${applicationName}` → `${applicationName}でやることを追加`）。

## 検証

- 機械チェック 288 件: プレースホルダ欠落 / 書式指定子欠落 / XML エンティティ混入 /
  全角英数字 / 半角カナ / `${applicationName}` 欠落 いずれも 0
- `xcodebuild -exportLocalizations -exportLanguage ja` で 290 unit 中、未翻訳は空文字の
  `NSHumanReadableCopyright` 2 件のみ（`ja.xliff` の数え方では String Set が 1 unit、
  device variation が 2 unit になるので catalog のキー数 288 とはずれる）
- iOS / macOS / watchOS / visionOS すべてビルド緑
- `inspect_appintents_metadata.py`: shortcuts 8 / phrases 26 / `reminders.ListEntity` 健在
- 既存 4 catalog は `ja` が増えただけで `en` / source 値は 1 バイトも変わっていないことを
  HEAD との差分で確認

テストプランは通しで回していない。`testNewTodoIsIndexedInSpotlight()` が単体で 114 秒かかり
（CoreSpotlight のインデックス完了をポーリングする）、並列ビルドと重ねると待ちを超えて落ちる。
このとき `WidgetRenderer_Default` が `0x8BADF00D`（scene-create の 10 秒ウォッチドッグ、
CPU 統計 97%）で落ちたが、読み込まれたイメージにプロジェクトのものが 1 つも無く、
マシン飽和によるシミュレータ側の事象だった。同時刻に一斉 SIGKILL されたシステムデーモン群は
シミュレータのシャットダウンによるもの。**重いテストと並列ビルドを重ねない**。

## 残したもの

- 翻訳の state が全件 `machine_translated`。`StringCatalogEdit` がこの state しか書かないため
  （ツールの仕様）。Xcode 上では「要レビュー」バッジが付く
- `IntentTodoWidget` が自前の catalog を持たず `IntentTodoWatchApp/Localizable.xcstrings` を
  membership exception で借りている。動作はするが場所が誤解を招く。直すには pbxproj 編集が要る
- Siri のフレーズルーティング（実際に日本語で話しかけて正しい Intent に入るか）は自動化できない → #30
- 翻訳中に見つかった記述の誤り: `ToggleUrgentTodoIntent` は urgent フラグを立て下げする Intent
  ではなく、`TodoService.toggleMostUrgentTodo()` で**期限が最も近い未完了 Todo の完了状態**を
  トグルする。`IntentDescription` は "Toggles completion of the most urgent todo" と正しく書いて
  あり、ずれていたのは `title` の "Toggle Urgent Todo" と AGENTS.md の機能一覧の
  「緊急フラグ」という記述だけだった。AGENTS.md は本コミットで直した。ja の title は実装に
  合わせて「急ぎのやることの完了を切り替え」にしてある
