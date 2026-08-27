# devlog — 開発ログ（経緯の記録）

`CLAUDE.md`（実体 `AGENTS.md`）、`docs/insights/`、`docs/APP_INTENTS_CENTRIC_PLAN.md` などのドキュメントは
「現在のルール・結論」だけを載せる方針にしている。それらのルールが**どういう調査・失敗・再検証を経て
今の形になったか**という経緯（いつ・何を試した・何が間違っていた・どのコミットで直した）は、ここに集約する。

各ドキュメントの該当箇所には `経緯: [docs/devlog/...](...)` という一行ポインタが付いている。
経緯を知りたくないときは元のドキュメントだけ読めば current な話に集中でき、経緯を知りたいときはここを見る。

## 置き場は 3 つ（現在のルール / 経緯 / 残タスク）

| 書くもの | 置き場 |
|---------|-------|
| 現在のルール・結論 | `AGENTS.md` / `docs/insights/` など |
| **経緯**（過去形・追記のみ） | **ここ（`docs/devlog/`）** |
| **残タスク**（これからやること・未検証・判断待ち） | **GitHub issue** |

詳しいルールは [AGENTS.md の「ドキュメント運用」](../../AGENTS.md#ドキュメント運用現在のルール--経緯--残タスク-の三分割)。

## 目次

- [02-swiftdata-concurrency.md](02-swiftdata-concurrency.md) — SwiftData / CloudKit 制約まわりの再検証履歴
- [03-app-intents-core.md](03-app-intents-core.md) — `AppIntentsPackage` 重複宣言・Primary/FromExtension 分離・実行プロセスの経緯（最大のログ）
- [04-ui-integration.md](04-ui-integration.md) — `onAppIntentExecution` / cold start / `UISceneAppIntent` の経緯
- [05-extensions-and-data-sharing.md](05-extensions-and-data-sharing.md) — Extension 間データ共有・WidgetReloader の経緯
- [06-control-widget-ios26.md](06-control-widget-ios26.md) — Control Widget の dialog 非表示・`ControlValueProvider` 等の経緯
- [07-platform-specific.md](07-platform-specific.md) — watchOS/macOS/visionOS/Live Activity のプラットフォーム別の経緯
- [app-intents-centric-plan.md](app-intents-centric-plan.md) — `APP_INTENTS_CENTRIC_PLAN.md` の beta 追従・SDK バグ対応の顛末
- [2026-08-11-constraint-recheck.md](2026-08-11-constraint-recheck.md) — WWDC 書き起こし全数突き合わせによる制約の再検証セッション（そのもの自体が調査ログ）
- [2026-08-25-layering-vs-clean-architecture.md](2026-08-25-layering-vs-clean-architecture.md) — 「UseCase 層は廃止」という説明をやめ、Layered / Clean Architecture との対比を明文化した経緯
- [2026-08-28-docs-role-split.md](2026-08-28-docs-role-split.md) — docs の残タスクを issue に逃がし、「現在のルール / 経緯 / 残タスク」の三分割に整理した経緯（+ そのとき見つかった古い記述の訂正一覧）
- [insights-changelog.md](insights-changelog.md) — `docs/INSIGHTS.md` / `insights/` 構成の再編履歴

## 運用方針

- 新しいドキュメントを書くときは、現在の結論だけを書く。調査の経緯・失敗した仮説・「以前は〜と記録していたが」
  という話は最初からここに書く（後から抜き出す二度手間を避ける）。
- **ここは過去形のログ。未来のタスクは書かない**。調査の途中で「残タスク」が出たら、その場で issue を立てて
  `残り: #NN` とポインタを添える。devlog を読み返してタスクを発掘する運用にはしない
  （実際に「残タスクとして残した」と書いたまま数週間気づかれない状態が起きていた）。
- コミットメッセージにも経緯は残るが、こちらは複数コミットにまたがる話をトピック単位で時系列にまとめてあるので、
  `git log` を掘るより早く「なぜ今の形なのか」を追える。
