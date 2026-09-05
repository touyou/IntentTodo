# テスト方針

App Intents は**無音で失敗する**（ビルドは緑、IDE も綺麗、機能だけが存在しない）。
このプロジェクトのテストは「壊れたときに他の手段では気づけない経路」を優先して押さえている。

## 開発フロー（TDD）

**Red → Green → Refactor**。機能実装前にテストを書き、通る最小限の実装をしてから整える。

1. **テスト作成（Red）**
2. **Entity 定義**: SwiftData モデル（`Domain`）
3. **Repository 実装**: Protocol + SwiftData 実装
4. **App Intent 実装（Green）**: 宣言は Intent、実装は `TodoService`
5. **リファクタ**
6. **UI 実装**: `Button(intent:)` で統合

## 3 層で分担する

`@Dependency` は `AppDependencyManager` 経由で解決されるため、**SPM テスト（ホストアプリなし）では
`perform()` を実行できない**。実経路の実行は AppIntentsTesting（UI テストバンドル必須）で押さえる。

| 層 | 場所 | 何を見るか |
|---|---|---|
| **SPM ユニットテスト** | `Packages/*/Tests/` | Repository / `TodoService` のビジネスロジック、Intent の静的メタデータ（`title` / `supportedModes` / `allowedExecutionTargets` / `parameterSummary`）、ヘルパー |
| **AppIntentsTesting** | `IntentTodoUITest/AppIntents/` | Intent の実経路実行（`makeIntent().run()`）、entity の id 解決 / `allEntities` / `suggestedEntities`、Spotlight index、`viewAnnotations()`、Intent の連鎖 |
| **XCUITest** | `IntentTodoUITest/` | UI 経路だけで壊れるもの（`requestConfirmation` を含む Intent が `Button(intent:)` から無言失敗する類） |

- **手で実機検証する前に、AppIntentsTesting に寄せられる観点かを先に検討する**。entity の id 解決 /
  候補提示 / Spotlight index / transient entity / onscreen annotation / 三状態のパラメータクリアは
  デバイスが要るように見えて、テストから届く
- **AppIntentsTesting では確認できない**システム UI の見え方（dialog の読み上げ / snippet の描画 /
  Control の表示）と Siri のフレーズルーティングは **#30** で手動追跡する。`run()` の成功は
  widget / control / Live Activity のボタン経路の成功を保証しない
- **watchOS では AppIntentsTesting の `run()` が落ちる**
  （`LNPerformActionPrebuiltErrorCodeActionNotAllowed` / code 4025）。前提データを作れないので
  watchOS 固有の観点は手動確認になる

検証の梯子（Apple が示す順序）と AppIntentsTesting の落とし穴:
[insights/03-app-intents-core.md](insights/03-app-intents-core.md#phase-6-テスト基盤295-appintentstesting) /
[skills/app-intents-testing](../skills/app-intents-testing/SKILL.md)

## 緑になる嘘テストを書かない

過去に実際に長期間見逃した形だけを挙げる。

- **条件付き assert を書かない**。`if element.waitForExistence(...) { XCTAssert... }` は、要素が
  見つからないと中身が一度も実行されず緑になる（この形で「削除がまったく動いていない」のを
  長期間見逃した。経緯: `devlog/06-control-widget-ios26.md`）
- **固定秒で待たない**。`sleep(1)` は状態が変わっていなくても時間が過ぎれば先に進む。
  待ちは `waitForExistence` / `waitForNonExistence` に置く（速いだけでなく、失敗が失敗として出る）
- **ローカライズ済みの文言を素の `String(localized:)` で assert しない**。ホストの優先言語が ja なので
  シミュレータ上では ja で解決され、`swift test` では通るのに Xcode のテストアクション経由でだけ落ちる。
  比較するなら `resource.locale = Locale(identifier: "en")` でソース言語に固定する
- **UI テスト対象アプリの言語は en に固定する**（`-AppleLanguages (en)`）。accessibility label で
  要素を引いている箇所が ja だと全部外れる

## 実行環境の決まり

- **UI テストは空のストアで起動する**。`IntentTodoUITest` は `-uitest-ephemeral-store` を渡し、アプリは
  DEBUG 限定でその引数を見て in-memory ストアを使う。共有ストアはプロセスを跨いで残るので、渡さないと
  todo がテスト間で積み上がり、空状態を前提にしたテストが書けなくなる。**AppIntents 側のテストは渡さない**
  （実運用と同じ共有ストアで entity 解決と Spotlight index を見たいため）
- **UI テストの並列実行はしない**（`IntentTodo.xcscheme` の `parallelizable` を外している）。
  シミュレータのクローンが OS ごと起動するぶんが乗るだけで、UI テストクラスが 1 つしかない本プロジェクトでは
  分割されない。実測と数字: `devlog/2026-08-28-uitest-cost.md`
- **テストターゲットを増やしたら `IntentTodo.xcscheme` の `TestAction` に足す**。パッケージのテスト
  ターゲットは足さない限り `xcodebuild test` でも ⌘U でも走らず、**コンパイルできなくなっても赤くならない**
  （「落ちる」ではなく「存在しないことになる」）。現在は `DomainTests` / `RepositoryTests` /
  `TodoAppIntentsTests` / `UITests` / `IntentTodoUITest` の 5 つ。ローカルパッケージの
  `TestableReference` は `ReferencedContainer = "container:Packages/<名前>"`、`BuildableName` は
  `.xctest` を付けないターゲット名
- **重いテストと並列ビルドを重ねない**。シミュレータがウォッチドッグで落ちて、自分の変更のせいに
  見えるノイズが出る

## ビルドを信じないための静的チェック

ビルドが緑でも機能が消える種類の失敗は、成果物を直接見るしかない。

```bash
# 24 ルールの静的監査 + どのシステムサーフェスに到達しているか（ビルド不要）
python3 skills/app-intents-centric-design/scripts/audit_intents.py . --fail-on error
python3 skills/app-intents-centric-design/scripts/audit_intents.py . --coverage

# システムが実際に読むメタデータ（autoShortcuts 0 件 / プロパティ 0 件の entity /
# 編集画面に出ないパラメータ / 登録されなかった schema / 同じ schema を主張する型が 2 つ）
python3 skills/app-intents-testing/scripts/inspect_appintents_metadata.py --find IntentTodo

# Intent コピーが catalog から漏れていないか
python3 skills/app-intents-localization/scripts/check_intent_copy_localization.py
```

**判定は必ずクリーンビルドで行う**。`Metadata.appintents` が変わらないと SSU タスクは再実行されず、
インクリメンタルのログは前回の出力を並べる（これで「直った」と読み違えたことがある）。
