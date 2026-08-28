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

### 一度目は通しで回せなかった

`testNewTodoIsIndexedInSpotlight()` が単体で 114 秒かかり（CoreSpotlight のインデックス完了を
ポーリングする）、並列ビルドと重ねると待ちを超えて落ちた。このとき `WidgetRenderer_Default` が
`0x8BADF00D`（scene-create の 10 秒ウォッチドッグ、CPU 統計 97%）で落ちたが、読み込まれた
イメージにプロジェクトのものが 1 つも無く、マシン飽和によるシミュレータ側の事象だった。
同時刻に一斉 SIGKILL されたシステムデーモン群はシミュレータのシャットダウンによるもの。
**重いテストと並列ビルドを重ねない**。

### 通しで回したら UI テストが 2 件落ち、3 件が「何も検証せず緑」になっていた

マシンが空いた状態で回し直したら、`testAppLaunches()` と `testDeleteTodo()` が
アサーション失敗した。**これは ja 追加による回帰**で、原因はアプリではなくテスト側。

ホストの macOS が `ja-JP` なので、シミュレータのアプリも ja で起動する。ja を入れる前は
en にフォールバックしていたため英語ラベルで引けていたが、ja が入った瞬間に外れた。

```swift
app.navigationBars["Todos"]        // 実際は「やること」
app.buttons["Delete todo"]         // 実際は「やることを削除」
```

**落ちた 2 件より、落ちなかった 3 件の方が問題だった**。
`testToggleTodoCompletion` / `testToggleFavorite` / `testEmptyStateShowsAddButton` は
条件付き assert（`if element.waitForExistence(...) { XCTAssert... }`）で書かれていて、
ラベルが引けないと中身が一度も実行されないまま緑になる。AGENTS.md が禁じている形が、
06-control-widget-ios26.md の「削除がまったく動いていないのを長期間見逃した」と同じ壊れ方を
再現したことになる。

対処（ed422a0）:

- `setUpWithError()` の `launchArguments` に `-AppleLanguages (en)` / `-AppleLocale en_US` を
  足し、**テスト対象アプリの言語を en に固定**した。ラベル引きが 7 箇所あり、個別に直すより
  言語を固定する方が確実
- `testToggleTodoCompletion` / `testToggleFavorite` の条件付き assert を外した
- `testEmptyStateShowsAddButton` は「todo が 0 件のときだけ」を意図した条件分岐で、
  テスト間でストアを共有している以上そのままでは無条件化できない。空のストアを用意する
  仕掛けが要るので #73 に送った

結果、39 件（AppIntents 23 + UI 16）すべて緑。UI テスト 16 件で約 307 秒。

## Extension の catalog 共有はこのままにすると決めた

Widget Extension は自前の catalog を持たず、`IntentTodoWatchApp/Localizable.xcstrings` を
`membershipExceptions` 経由で共有している（Localization Planner がこの形にした）。

分割する案を検討したが**採らない**と決めた。理由:

- 機能上の問題が無い。両ターゲットのバンドルに `ja.lproj/Localizable.strings` が正しく生成され、
  それぞれの main bundle から引ける
- 分割すると共有 Intent コピー 15 キーの訳が両方に重複し、直すときに 2 箇所直す羽目になる
  （このコミットで一番手間だったのが、まさにこの「重複したコピーを揃える」作業だった）
- 解くには `project.pbxproj` の編集（Target Membership のチェック外し）が必要で、
  エージェントからは安全に触れない

代わりに「ファイルの置き場とターゲットは 1:1 ではない、widget の文言はここを見る」を
[docs/insights/04-ui-integration.md](../insights/04-ui-integration.md#ja-を入れて分かった-catalog-の配置)
に明記した。

## 残したもの

- 翻訳の state が全件 `machine_translated`。`StringCatalogEdit` がこの state しか書かないため
  （ツールの仕様）。Xcode 上では「要レビュー」バッジが付く。human review パスは未実施 → #73
- Siri のフレーズルーティング（実際に日本語で話しかけて正しい Intent に入るか）は自動化できない → #30
- `testEmptyStateShowsAddButton` の条件付き assert（空のストアを用意する仕掛けが要る）→ #73
- テストの実行コストの見直し（`parallelizable = "YES"` によるシミュレータのクローン、
  毎テストのアプリ起動、固定 `sleep(1)`、Spotlight テストの 114 秒）→ #73
- 翻訳中に見つかった記述の誤り: `ToggleUrgentTodoIntent` は urgent フラグを立て下げする Intent
  ではなく、`TodoService.toggleMostUrgentTodo()` で**期限が最も近い未完了 Todo の完了状態**を
  トグルする。`IntentDescription` は "Toggles completion of the most urgent todo" と正しく書いて
  あり、ずれていたのは `title` の "Toggle Urgent Todo" と AGENTS.md の機能一覧の
  「緊急フラグ」という記述だけだった。AGENTS.md は本コミットで直した。ja の title は実装に
  合わせて「急ぎのやることの完了を切り替え」にしてある

---

## 2026-08-28（追記）Siri 発話の語彙を散らした（#77 の 2）

一次レビューで「`Delay ${todo}` の訳が `[0]` と `する` の有無しか違わず、発話バリエーションとして
機能していない」と挙げていた件（#73 の h → #77 の 2）。洗い直したら**同じ壊れ方が 5 キーに
広がっていた**。

| キー | 元の ja | 何が同じだったか |
|---|---|---|
| `Snooze ${todo}` | 〜をスヌーズ / 〜をスヌーズする | `する` の有無 |
| `Delete ${todo}` | 〜の〜を削除 / 〜から〜を削除 | 助詞 |
| `Star ${todo}` | 〜をお気に入りに追加 / 〜をお気に入りにする | 語尾 |
| `Complete ${todo}` | 〜を完了 / 〜を完了にする | 語尾 |
| `Add a todo` | やることを追加 / 新しいやることを追加 | 修飾語だけ |

原因は **en 側が別語彙で経路を増やしていることを訳に写せていなかった**こと
（`Snooze` / `Delay`、`Star` / `Favorite`、`Delete` / `Remove`）。日本語では自然に訳すと
同じ語彙に寄る。語彙を明示的に散らす形へ直した:

```
スヌーズ / 後回しにする / 先送り
削除 / 消す
お気に入りに追加 / スターを付ける
完了 / 終わらせる / 済みにする
追加 / 作成 / 登録
```

重複判定は**パラメータ構成が同じものだけを比べる**。`${filter}` 入りと無しでどちらも
「やることを表示」なのは意図的（パラメータ無しのフレーズを 1 つ残して Siri が聞き返せる
ようにする AGENTS.md のルール）。最初に書いた素朴なチェックはここを重複と誤検出した。

ビルド後の `IntentTodo.app/ja.lproj/AppShortcuts.strings` に 26 発話が載り、
`Metadata.appintents/nlu/nlu.lzfse`（ja の NLU 学習データ）も再生成されることを確認した。
実際に話しかけて通るかは自動化できないので #30 の H-3。
