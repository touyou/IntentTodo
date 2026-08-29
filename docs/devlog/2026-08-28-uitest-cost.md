# UI テストの実行コストを測って削った件（#73 §3）

現在のルールは [AGENTS.md](../../AGENTS.md) の「テスト構成」にある。ここには**測った数字と、
issue に書いてあった見立てのどれが外れていたか**を残す。

## 出発点（#73 に記録した見立て）

| 要因 | 当時の記録 |
|---|---|
| scheme の `parallelizable = "YES"` | シミュレータのクローンが OS ごと起動する |
| `setUpWithError()` が毎テストで launch | 16 回のコールドローンチ。1 件 8〜26 秒 |
| 固定 `sleep(1)` が 4 箇所 | 状態変化を固定秒で待っている |
| `testNewTodoIsIndexedInSpotlight` の `pollUntil` | **単体 114 秒** |

合計 307 秒。

## 実測して分かったこと

### Spotlight テストは既に速い。分離の必要は無かった

| テスト | 実測 |
|---|---|
| `testNewTodoIsIndexedInSpotlight` | **0.99 秒** |
| `testDeletedTodoIsRemovedFromSpotlight` | 10.3 秒 |

114 秒という記録は、並列実行でシミュレータのクローンを取り合っていたときの数字だったと見られる。
`pollUntil` の timeout は 10 秒 / interval 0.5 秒で妥当なので、**timeout の見直しも別テストプランへの
分離もやらないことにした**。後者（de-index 待ち）が 10 秒使い切っているのは CoreSpotlight の削除
反映そのものが遅いためで、詰めると flaky になる側に振れる。

### 並列実行は「速くする」方向に効いていなかった

`parallelizable` を外して直列にしたところ、AppIntents 系のスイートが速くなった。

| スイート | 並列 | 直列 |
|---|---|---|
| `TodoIntentExecutionTests`（10 件） | 11.98 秒 | **2.00 秒** |
| `TodoSystemIntegrationTests`（5 件） | 17.42 秒 | **6.33 秒** |
| `IntentTodoUITest`（16 件） | 274.6 秒 | 256.7 秒 |

UI テストクラスが 1 つしかないので、並列にしても**クラス内は分割されない**。クローンの起動コストと
取り合いだけが乗っていた。`docs/devlog/2026-08-28-ja-localization.md` に書いた
「重いテストを並列で回してシミュレータがウォッチドッグで落ちた」もこれで消える。

### 直列にしたら、隠れていた待ちの甘さが出た

`sleep(1)` を `waitForNonExistence(timeout: 5)` に置き換えた直後、直列実行の通しで
`testNavigateToTodoDetail` が「Add sheet should dismiss」で落ちた。単体では通る。

原因は**テスト間でストアが積み上がること**だった。共有ストア（App Group）はプロセスを跨いで
残るので、通しで走らせると後半のテストは数十件の todo を抱えた一覧の上で動く。シートを閉じた
あとの再描画が遅くなり、5 秒に収まらなくなる。固定 `sleep(1)` の時代はここを「たまたま通って
いた」のではなく、**シート閉じを待つ assert 自体が無かった**ので落ちようがなかっただけ。

timeout を伸ばすのではなく、原因を消す方を採った。`-uitest-ephemeral-store` を渡したときだけ
`SharedModelContainer.createInMemoryContainer()` を使う（DEBUG 限定）。これで:

- `testEmptyStateShowsAddButton` の条件付き assert を無条件にできた（空状態が保証される）
- 上の flake が消えた
- テストが実行順に依存しなくなった

AppIntents 側のテストにはこの引数を渡していない。実運用と同じ共有ストアの上で entity 解決と
Spotlight index を見たいため。

## 結果

| | 変更前 | 変更後 |
|---|---|---|
| 全 39 件 | — | **267.6 秒** |
| `IntentTodoUITest` 16 件 | 307 秒 | **256.7 秒** |

残る支配項は 16 回のコールドローンチと `testLaunchPerformance`（43.5 秒）で、これは XCTest の
UI テストが 1 件ごとにアプリを起こす構造そのもの。削るなら「1 件あたりの launch をやめる」しか
無く、テストの独立性とのトレードオフになるので今回は触っていない。

## 追記: パッケージのユニットテストを scheme に入れた（2026-08-29 / #84）

上の 267.6 秒は **`IntentTodoUITest` バンドルだけ**の数字だった。`IntentTodo.xcscheme` の
`TestAction` に入っている `TestableReference` が `IntentTodoUITest` 1 つしか無く、SPM パッケージの
テストターゲットが 1 つも入っていなかったため。

実害は #83 で出ていた。`TodoAppEntity.dueDate` を `Date?` → `DateComponents?` に変えたとき
`TodoAppIntentsTests` の 4 箇所がコンパイルできない状態のまま main にマージされている。
**テストが「落ちる」のではなく「存在しないことになる」**ので赤くならない。

### 追加した 4 ターゲット

ローカルパッケージの `TestableReference` は `ReferencedContainer = "container:Packages/<名前>"`、
`BuildableName` は `.xctest` を付けないターゲット名で書く（プロジェクト内ターゲットと綴りが違う）。
`parallelizable` は引き続き付けない。

### 見立てが外れていた点: 「0.2 秒程度」ではなく約 20 秒

issue #84 には「パッケージのユニットテストは実測 0.2 秒程度」と書いていた。これは
`swift test` の数字で、Xcode のテストアクション経由では**バンドルごとのインストールと起動**が乗る。

| ターゲット | 件数 | テスト実行 |
|---|---|---|
| `DomainTests` | 19 | 0.076 秒 |
| `RepositoryTests` | 30 | 0.424 秒 |
| `TodoAppIntentsTests` | 137 | 0.512 秒 |
| `UITests`（`UI` パッケージ） | 55 | 0.072 秒 |
| 4 つ合計（実行のみ） | 241 | **1.08 秒** |
| 4 つ合計（xcodebuild 実測 elapsed） | | **19.9 秒** |

差の約 19 秒はテスト実行ではなく、4 バンドル分のインストール / 起動オーバーヘッド（1 本あたり 5 秒前後）。

| | 変更前 | 変更後 |
|---|---|---|
| `IntentTodoUITest` のみ | 288.7 秒（40 件） | 288.7 秒（40 件） |
| 通し（elapsed） | 288.7 秒 | **321.2 秒**（281 件） |

+32.5 秒 / +11%。241 件のユニットテストが常時走るようになる対価としては安いので、
テストプランを分けたり `-only-testing` で切ったりはしないことにした。

### 入れた瞬間に 11 件落ちた（ホスト言語が ja のため）

`TodoFilterTests.displayNames()` / `TodoSortOrderTests.displayNames()` が
`String(localized: TodoFilter.all.displayName) == "All"` の形で書かれていた。テスト側のコメントには
「en では key がそのまま返る」とあったが、**ホストの優先言語が ja なのでシミュレータ上では
ja で解決される**（`"すべて"`）。`swift test` では通るので、scheme に入れるまで表に出なかった。

`resource.locale = Locale(identifier: "en")` でソース言語に固定してから解決する形に直した。
`TodoAppIntentsTests` 側の `String(localized:)` は落ちていない（`TodoAppIntents` は catalog を
持たないのでキーがそのまま返る）。

同種の事故は `docs/devlog/2026-08-28-ja-localization.md`（UI テストの英語ラベル引き）でも起きている。

## 参照

- #73 §3 / `docs/devlog/2026-08-28-ja-localization.md`（並列実行でシミュレータが落ちた件）
- #84 / `docs/devlog/2026-08-29-attribute-write-paths.md` §5（scheme から外れていたことに気づいた経緯）
