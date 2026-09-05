# devlog — 開発ログ（経緯の記録）

`CLAUDE.md`（実体 `AGENTS.md`）、`docs/insights/`、`docs/APP_INTENTS_CENTRIC_PLAN.md` などのドキュメントは
「現在のルール・結論」だけを載せる方針にしている。それらのルールが**どういう調査・失敗・再検証を経て
今の形になったか**という経緯（いつ・何を試した・何が間違っていた・どのコミットで直した）は、ここに集約する。

各ドキュメントの該当箇所には `経緯: [docs/devlog/...](...)` という一行ポインタが付いている。
経緯を知りたくないときは元のドキュメントだけ読めば current な話に集中でき、経緯を知りたいときはここを見る。

## 置き場は 4 つ

| 書くもの | 置き場 |
|---------|-------|
| 常に必要な地図（目次と非交渉ルールだけ） | `AGENTS.md` / 各 `README.md` |
| 現在のルール・結論（**最新の事実と why** だけ） | `docs/*.md` / `docs/insights/` / `skills/` |
| **経緯・実験の記録**（過去形・追記のみ） | **ここ（`docs/devlog/`）** |
| **残タスク**（これからやること・未検証・判断待ち） | **GitHub issue** |

詳しいルールは [AGENTS.md の「ドキュメント運用」](../../AGENTS.md#ドキュメント運用)。

## 目次

- [2026-09-05-reference-sdk-refine.md](2026-09-05-reference-sdk-refine.md) — beta 6 SDK と参照資料を照合し、skills の availability・診断手順・検証範囲を揃えた記録

- [02-swiftdata-concurrency.md](02-swiftdata-concurrency.md) — SwiftData / CloudKit 制約まわりの再検証履歴
- [03-app-intents-core.md](03-app-intents-core.md) — `AppIntentsPackage` 重複宣言・Primary/FromExtension 分離・実行プロセスの経緯（最大のログ）
- [04-ui-integration.md](04-ui-integration.md) — `onAppIntentExecution` / cold start / `UISceneAppIntent` の経緯
- [05-extensions-and-data-sharing.md](05-extensions-and-data-sharing.md) — Extension 間データ共有・WidgetReloader の経緯
- [06-control-widget-ios26.md](06-control-widget-ios26.md) — Control Widget の dialog 非表示・`ControlValueProvider` 等の経緯
- [07-platform-specific.md](07-platform-specific.md) — watchOS/macOS/visionOS/Live Activity のプラットフォーム別の経緯
- [app-intents-centric-plan.md](app-intents-centric-plan.md) — `APP_INTENTS_CENTRIC_PLAN.md` の beta 追従・SDK バグ対応の顛末 + **フェーズ別の実施記録**（Phase 0–11 を何のコミットでどう入れたか / 当時の判断。2026-08-31 に計画側から移送）
- [2026-08-11-constraint-recheck.md](2026-08-11-constraint-recheck.md) — WWDC 書き起こし全数突き合わせによる制約の再検証セッション（そのもの自体が調査ログ）
- [2026-08-25-layering-vs-clean-architecture.md](2026-08-25-layering-vs-clean-architecture.md) — 「UseCase 層は廃止」という説明をやめ、Layered / Clean Architecture との対比を明文化した経緯
- [2026-08-28-docs-role-split.md](2026-08-28-docs-role-split.md) — docs の残タスクを issue に逃がし、「現在のルール / 経緯 / 残タスク」の三分割に整理した経緯（+ そのとき見つかった古い記述の訂正一覧）
- [2026-08-28-appshortcuts-localization-reeval.md](2026-08-28-appshortcuts-localization-reeval.md) — `AppShortcuts.xcstrings` を最優先の穴から降格した経緯（「catalog 化済み」を多言語化済みと誤読していた件 + schema とフレーズの関係）
- [2026-08-28-ja-localization.md](2026-08-28-ja-localization.md) — ja 対応（#70）を通しでやった経緯（catalog の配置が「誰がリンクしているか」で決まると分かった件 + テストを重い並列実行で回して起きたこと）
- [2026-08-28-intent-copy-localization.md](2026-08-28-intent-copy-localization.md) — Intent のコピー（`title` / `IntentDescription` / `@Parameter` / `IntentDialog`）が ja 化されていなかった経緯（「`title` は複製抽出される」という前提が誤りだった件 + パッケージ catalog では引かれないと分かるまで）
- [2026-08-28-uitest-cost.md](2026-08-28-uitest-cost.md) — UI テストの実行コストを測って削った経緯（Spotlight 114 秒は並列実行のせいだった件 + 直列化して出た flake の原因がテスト間のストア共有だった件）
- [2026-08-28-xcode27-beta6-recheck.md](2026-08-28-xcode27-beta6-recheck.md) — Xcode 27 beta 6 で SDK 制約を棚卸しした経緯（SSU バグ / watchOS schema がどちらも未解消だった件 + インクリメンタルビルドの SSU ログを「直った」と読み違えかけた件 + visionOS の Spotlight 除外が SDK 制約ではなくこちらの誤りだった件）
- [2026-08-28-ssu-system-value-type-bug.md](2026-08-28-ssu-system-value-type-bug.md) — `AppIntentsSSUTraining` が system value 型で落ちる SDK バグ（FB24548956）の切り分けと、発火条件が「App Shortcut 登録済み Intent の `@Parameter` だけ」だと測り直した経緯
- [2026-08-29-entity-placedescriptor-restore.md](2026-08-29-entity-placedescriptor-restore.md) — entity の `@Property` は SSU バグを踏まないと分かり `TodoAppEntity.location` を `PlaceDescriptor` に戻した経緯
- [2026-08-29-reminder-schema-cost-remeasure.md](2026-08-29-reminder-schema-cost-remeasure.md) — `.reminders.reminder` 適合コストを probe で測り直し「SDK でブロックされている」を否定した経緯
- [2026-08-29-reminder-schema-conformance.md](2026-08-29-reminder-schema-conformance.md) — `TodoAppEntity` を `.reminders.reminder` に適合させた経緯（親の適合がサブエンティティの適合も要求する件 + `Calendar.RecurrenceRule` を SwiftData 属性にすると schema 初期化で trap する件 + 削除済みオブジェクトの配列属性が読めない件）
- [2026-08-29-attribute-write-paths.md](2026-08-29-attribute-write-paths.md) — reminders 属性（tags / urls / recurrence / locationTriggerEvent）の書き込み経路を Intent と UI に通した経緯（`parameterSummary` が Shortcuts 編集画面の allowlist だった件 + 詳細画面で同じ配列属性 trap を踏み直した件 + #83 が置いていった破損 3 件）
- [2026-08-29-schema-vs-watch-target.md](2026-08-29-schema-vs-watch-target.md) — 手書き `__appSchemaEntity` を撤去し `TodoAppEntity` を 2 系統に分けた経緯（App Schema 全 23 ドメインが watchOS / tvOS に無いと分かった件 + iOS アプリのメタデータに watchOS スライスが混ざるのをビルドログで確定した件 + const 抽出が typealias を通らない件）
- [2026-08-30-donation-observability.md](2026-08-30-donation-observability.md) — `Button(intent:)` の実行がシステムに donate されていると確かめた経緯（donation を読める経路をシミュレータの Biome ストリームに見つけた件 + 逆の結論を 2 回出した原因が mtime と書き込み遅延だった件）
- [2026-08-31-docs-refine.md](2026-08-31-docs-refine.md) — ドキュメントを 4 層（地図 / 現在のルール / 経緯 / 残タスク）に整理し、`AGENTS.md` を目次へ畳んだ経緯（+ そのとき実装と突き合わせて見つかった古い記述・矛盾の一覧）
- [2026-08-31-code-comments.md](2026-08-31-code-comments.md) — コードコメントを英語に統一し、履歴 / 将来の計画 / ドキュメントへのリンクを落とした経緯（同日に決めた「コードに `経緯:` ポインタを置く」ルールを撤回している）
- [2026-08-31-add-edit-form-parity.md](2026-08-31-add-edit-form-parity.md) — 追加画面と編集シートのフィールドを一致させた経緯（編集側が 11 フィールド中 4 つしか持っていなかった件 + `location` にそもそも更新経路が無かった件 + 場所名を変えたら座標を落とすと決めた理由 + `dismissalConfirmationDialog` が iOS のシートでは空振りすると測った件）
- [2026-08-31-skills-multi-agent-distribution.md](2026-08-31-skills-multi-agent-distribution.md) — 8 skill を Claude Code 以外（Codex / Gemini CLI / Copilot / Cursor）にも配れる形にした経緯（Agent Plugins の `$schema` を 1.0.0 で止めた理由 + `/plugin install touyou/IntentTodo` が元から成立していなかった件 + `source: "./"` で 4 GB コピーされた件）
- [2026-08-31-design-session-skill.md](2026-08-31-design-session-skill.md) — 9 本目（対話でユースケース → Intent 集合を導く進行役）を足し、`audit_intents.py` に `--gap`（実装済み Intent ↔ どの Intent も届いていないアクション）を付けた経緯（入口を厚くせず分けた理由 + マクロ宣言の entity が拾えていなかった件 + 候補側のノイズを削った過程 + そこで見つけた #113）
- [insights-changelog.md](insights-changelog.md) — `docs/INSIGHTS.md` / `insights/` 構成の再編履歴

## 運用方針

- 新しいドキュメントを書くときは、現在の結論だけを書く。調査の経緯・失敗した仮説・「以前は〜と記録していたが」
  という話は最初からここに書く（後から抜き出す二度手間を避ける）。
- **ここは過去形のログ。未来のタスクは書かない**。調査の途中で「残タスク」が出たら、その場で issue を立てて
  `残り: #NN` とポインタを添える。devlog を読み返してタスクを発掘する運用にはしない
  （実際に「残タスクとして残した」と書いたまま数週間気づかれない状態が起きていた）。
- コミットメッセージにも経緯は残るが、こちらは複数コミットにまたがる話をトピック単位で時系列にまとめてあるので、
  `git log` を掘るより早く「なぜ今の形なのか」を追える。
