# 開発ログ: docs/INSIGHTS.md / insights/ 整理の変遷

`docs/INSIGHTS.md` と `docs/insights/` 配下がどう再編されてきたかの更新履歴。

- 2026-08-13: `04-ui-integration.md` の取り残しを訂正。「削除確認は App Intent の `requestConfirmation` 経由なので `confirmationDialog` / `alert` の使用箇所ゼロ」は 2026-08-12 の修正（`requestConfirmation` がアプリ内 `Button(intent:)` から失敗する件）で実態と食い違っていたため、「削除確認の現状」節を新設し、`item:` オーバーロードの評価も「当て先が無い」→「当て先はあるが現状 `isPresented:` で足りる」に更新。
- 2026-04-15 (2): `IntentDependencies` / `IntentAppState` 削除、`TodoEntityQuery` を `@Dependency` 化、Control Widgets を `ControlValueProvider` パターンに、`TodoItem.didSet` 撤去 + `TodoActions` で明示更新、AppShortcuts 8 件に整理、Widget/Complication `kind` の reverse-DNS 統一、通知タップの `NotificationHandler.navigationModel` 注入方式、主要 3 View を `private struct` 抽出。insights ドキュメントを全面的に最新化。
- 2026-04-15: Extension 内の View を 3 パッケージ（`LiveActivity` / `WidgetUI` / `WatchUI`）に分離し、Extension はターゲット固有のスキャフォルドのみに絞る構成に移行。macOS native ビルド対応（`AppDelegate` / `MacAppDelegate` を `#if os(...)` で分離し `NotificationHandler` を共通化）。visionOS ビルド修復（`#Predicate` の Optional UUID 回避、`Button(intent:role:)` 引数順、ControlWidget の `#if !os(visionOS)` ガード）。`Domain.DueDateStatus` を導入して overdue/dueSoon 判定の重複を解消。
- 2026-04-13: Shortcuts Intent ルーティング問題の根本原因（`IntentTodoAppIntentsPackage` のメインターゲット重複宣言）が判明。誤った知見（`.background + 通知ワークアラウンド`、`IntentAppState` フォールバック、`IntentDependencies.shared` パターン）を削除し、`@Dependency + AppDependencyManager` パターンを標準として記述更新。
- 2026-03-19: 18セクションを7ファイルに分割・整理
