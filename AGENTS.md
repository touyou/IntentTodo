# IntentTodo — Agent Guide

**App Intents 中心設計**（アプリでできること全部を App Intent として定義し、そこから Siri /
Shortcuts / ウィジェット / コントロール / Spotlight / Apple Intelligence に届ける）を実証する
マルチプラットフォーム Todo アプリ。

このファイルは**常に読み込まれる**ので、**目次と、読む前に知らないと事故るルールだけ**を置く。
理由・実装形・落とし穴は各ドキュメントにあり、**同じ説明を 2 か所に置かない**。

## 環境

- iOS / iPadOS / macOS / watchOS / visionOS **27.0+**（`.reminders` 系 assistant schema が 27+ 限定のため
  27 世代で揃えている）/ Xcode 27+ / Swift 6.0+
- macOS は Catalyst ではなくネイティブ
- ビルドは Xcode の `BuildProject`、速い確認は `XcodeRefreshCodeIssuesInFile`

```
IntentTodo/            アプリターゲット（App.init で AppDependencyManager 登録 / AppShortcutsProvider は必ずここ）
IntentTodoWidget/      ホーム画面ウィジェット + コントロールセンター
IntentTodoLiveActivity/ ライブアクティビティ
IntentTodoWatchApp/    watchOS アプリ + コンプリケーション
IntentTodoUITest/      XCUITest + AppIntentsTesting
Packages/              Domain ← Repository ← TodoAppIntents ← UI / LiveActivity / WidgetUI / WatchUI
```

Extension ターゲットは `@main` / `WidgetBundle` / `ActivityConfiguration` などの**スキャフォルドのみ**。
View・状態管理・データ取得は SPM 側に置く。詳細:
[docs/insights/01-swift-package-design.md](docs/insights/01-swift-package-design.md)

## 触る前に知っておくルール

App Intents は**無音で失敗する**（ビルド緑・診断ゼロ・機能だけが存在しない）。
下は「知らずに触ると壊すが、壊れたことに気づけない」ものだけ。各行の詳細はリンク先にある。

1. **アクションは App Intent として定義し、UI からも `Button(intent:)` で実行する。**
   手で `perform()` を呼ばない（`@Dependency` はシステム dispatch 経由でしか注入されない）
2. **ビジネスロジックは `TodoService`**、Intent は宣言と接続点。データ変更の後処理は
   `TodoService.dataDidChange()` の 1 か所に集約する（Intent 側に書かない）
3. **SwiftData を書き換える Intent は `allowedExecutionTargets = [.main]`**。
   読み取り系は固定しない（`IntentExecutionTargetsTests` が宣言漏れを検出）
4. **`@Dependency` は使うプロセスごとに登録が必要**（`App.init()` / `WidgetBundle.init()` /
   watch アプリ）。登録漏れはクラッシュせず「何も起きない」になる
5. **`AppShortcutsProvider` はアプリターゲット直下**（パッケージに置くと `autoShortcuts: 0` になり、
   App Shortcut がビルドエラー無しで消える）
6. **`requestConfirmation` / `requestChoice` を含む Intent をアプリ内 `Button(intent:)` から呼ばない**
   （応答する面が無く、エラー表示も出ずに何も起きない。UI 側で確認して確認なし版を呼ぶ）
7. **`parameterSummary` は Shortcuts 編集画面の allowlist**。載せ忘れたパラメータは編集できない
8. **App Shortcut に登録した Intent の `@Parameter` に system value 型を置かない**
   （`PlaceDescriptor` / `LinkMetadata` / `AudioSearch` / `PHAsset`。SDK バグ FB24548956 で
   音声理解の学習アセットが丸ごと消え、ローカルは `BUILD SUCCEEDED` のまま）
9. **App Schema は watchOS / tvOS に存在しない**。watch 用は**別の型名**を与える
   （同じ型名だと iOS の出荷メタデータが watchOS スライスに上書きされる。FB24570185）
10. **UI コピーは `LocalizedStringResource`**。パッケージでは `.copy(_:)` を通す。
    文言を足したら 12 catalog 全部を埋める
11. **`project.pbxproj` を直接編集しない**（`git checkout` での復元も含む）。
    言語追加や catalog のターゲット追加は `LocalizationPlanner` に任せる
12. **確認はビルドの成否ではなくメタデータで行う**。「どの面が何を提示するか」は
    **呼出元だけ変えて同じ Intent を走らせて**確定させる（肯定リストから推論しない）

## ドキュメント運用

**置き場を 3 つに分け、同じ情報を 2 か所に書かない。**

| 書くもの | 置き場 | 性質 |
|---|---|---|
| **常に必要な地図** | `AGENTS.md`（このファイル）/ 各 `README.md` | 目次と、読む前に知らないと事故るルールだけ。**説明は置かない** |
| **現在のルール・結論** | `docs/*.md` / `docs/insights/` / `skills/` | **最新の事実と why** だけ。履歴・失敗した仮説・不要なアンチパターンは混ぜない |
| **経緯・実験の記録** | `docs/devlog/` | いつ何を試して何が間違っていて、どのコミットで直したか。過去形・追記のみ |
| **残タスク** | **GitHub issue** | 状態が変わるもの。ドキュメントに置くと必ず腐る |

- **ドキュメントに `- [ ]` を残さない**。未完了が出たら issue を立て、docs 側は「詳細は #NN」の 1 行
- 参照ドキュメント側に「以前は〜」「当時の判断」を書かない。代わりに
  `経緯: docs/devlog/xxx.md` のポインタを 1 行置く
- **未検証 / 実機確認が必要**なものは **#30**、SDK 更新にぶら下がるものは **#57** に集約
- **未採用の API** は個別 issue にせず [APP_INTENTS_API_COVERAGE.md](docs/APP_INTENTS_API_COVERAGE.md)
  に 1 行（**状態の地図**であってタスクリストではない）。やると決めた時点で issue にする（消化は #68）
- 判断が「やらない」で決着したら、**理由つきで docs 側に残す**（`⏸ 意図的不使用` / `🚫 対象外`）。
  同じ検討を半年後にもう一度させないことがこの記録の目的
- devlog に「残タスクとして残した」と書くときも、**同時に issue へ起票してポインタを併記**する

**コードコメントは英語**で、実装中に本当に必要な情報だけ（ドキュメントへのリンクも置かない）:
[docs/CODING_GUIDELINES.md](docs/CODING_GUIDELINES.md#コード内コメント)

## Git 運用

- 機能単位でコミットし、**テストが通る状態でのみ**コミットする
- メッセージは `<type>: <subject>`（types: feat, fix, refactor, test, docs, chore）+ 必要なら body
- `docs/references/` は gitignore（参照ドキュメントは各自で用意）
- **コミット前にブランチを確認する**（別エージェントがワークツリーを切り替えていることがある）

## 目次

**設計と規約**

| ファイル | 中身 |
|---|---|
| [docs/AGENTS.md](docs/AGENTS.md) | **App Intents 中心設計ガイド**（思想 / 核心原則 / 実装時に確認すること） |
| [docs/APP_INTENT_DRIVEN_DESIGN.md](docs/APP_INTENT_DRIVEN_DESIGN.md) | 関連概念の比較、Layered / Clean Architecture との対比（砂時計図） |
| [docs/CODING_GUIDELINES.md](docs/CODING_GUIDELINES.md) | Swift / SwiftUI / SwiftLint / UI コピー / SwiftData / コメント方針 |
| [docs/TESTING.md](docs/TESTING.md) | TDD / テストの 3 層 / 緑になる嘘テスト / 静的チェック |
| [docs/PLAN.md](docs/PLAN.md) | 要件とマルチプラットフォーム展開マトリクス |

**実装知見（このリポジトリ固有）** — 目次は [docs/INSIGHTS.md](docs/INSIGHTS.md)

| ファイル | 中身 |
|---|---|
| [01-swift-package-design](docs/insights/01-swift-package-design.md) | 7 パッケージの依存設計 |
| [02-swiftdata-concurrency](docs/insights/02-swiftdata-concurrency.md) | CloudKit 制約 / `@Model` の罠 / Strict Concurrency |
| [03-app-intents-core](docs/insights/03-app-intents-core.md) | **Intent / Entity / Query / DI / 実行プロセス / App Schema / Spotlight**（最大） |
| [04-ui-integration](docs/insights/04-ui-integration.md) | `Button(intent:)` / ナビゲーション / cold start / ローカライズ |
| [05-extensions-and-data-sharing](docs/insights/05-extensions-and-data-sharing.md) | App Group / ウィジェット更新 |
| [06-control-widget-ios26](docs/insights/06-control-widget-ios26.md) | コントロール / フィードバック経路（dialog・snippet・通知） |
| [07-platform-specific](docs/insights/07-platform-specific.md) | watchOS / macOS / visionOS / Live Activity |

**API の地図**

- [docs/APP_INTENTS_API_COVERAGE.md](docs/APP_INTENTS_API_COVERAGE.md) — 採用 / 意図的不使用 / 対象外 / 未採用候補
- [docs/WWDC_APP_INTENTS_SESSIONS.md](docs/WWDC_APP_INTENTS_SESSIONS.md) — セッション別 API 一覧と非推奨タイムライン
- [docs/APP_INTENTS_CENTRIC_PLAN.md](docs/APP_INTENTS_CENTRIC_PLAN.md) — WWDC 2026 要素をどこまで検証したか

**経緯・残タスク・その他**

- [docs/devlog/](docs/devlog/README.md) — 各ルールが決まるまでの調査・失敗・再検証
- [docs/feedback/](docs/feedback/) — Apple へ提出した Feedback の内容
- **GitHub issues** — これからやること（#30 実機検証 / #57 GM SDK 棚卸し / #67 登壇準備 / #68 未採用 API）
- [docs/presentation/](docs/presentation/README.md) — 登壇用のスライド骨子とスクリプト
- [skills/](skills/README.md) — App Intents 中心設計を他プロジェクトへ持ち出す形（9 skill + スクリプト）。
  エージェント別のインストールと公開手順は [skills/INSTALL.md](skills/INSTALL.md)
- `docs/references/` — 最新の技術参照（gitignore 対象。WWDC 書き起こしは `references/wwdc/`）
- `~/Developer/Private/wwdc26-app-intents-samples/` — WWDC26 公式サンプル 4 本（**リポジトリ外に置く**。
  `docs/` 配下だと Xcode がサンプルの `.xcodeproj` を `project.pbxproj` へ書き込む）
