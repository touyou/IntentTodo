# IntentTodo 開発インサイト集

このドキュメントは、IntentTodoアプリの開発中に得られた技術的なインサイトの目次です。
各トピックの詳細は個別ファイルを参照してください。

---

## 目次

### [01. Swift Package 設計](insights/01-swift-package-design.md)

- 依存関係設計（単方向依存、`@_exported import`）
- DevDock式パッケージ構成（独立Package.swift + 相対パス依存）
- ルートPackage.swift方式との比較

### [02. SwiftData と Concurrency](insights/02-swiftdata-concurrency.md)

- CloudKit対応の制約（`@Attribute(.unique)`禁止、optionalリレーション）
- `@Model`マクロと`Sendable`の競合
- Strict Concurrency対応（`@MainActor`パターン）
- Repository Protocol設計

### [03. App Intents コア設計](insights/03-app-intents-core.md)

- Intent = 「アプリの動詞」としての設計
- DI パターン（`@Dependency` + `AppDependencyManager`）
- AppEntity / IndexedEntity / EntityQuery
- App Shortcuts（`AppShortcutsProvider`、フレーズのパラメータ型制限）
- Intent統合のベストプラクティス
- AppEnum

### [04. UI層とIntent統合](insights/04-ui-integration.md)

- `Button(intent:)` の使用とプラットフォーム対応
- `onAppIntentExecution` と `AppDependencyManager + @Dependency + perform()` の使い分け
- `@Observable` + `@MainActor`パターン
- App Intents vs ViewModelの役割分担

### [05. Extension とデータ共有](insights/05-extensions-and-data-sharing.md)

- WidgetBundle の明示的登録
- App Groups によるデータ共有（SharedModelContainer）
- UserDefaults の App Group 対応
- Intent → UI コミュニケーション（主経路: `@Dependency` + NavigationModel）
- WidgetKit 更新パターン（WidgetReloader）

### [06. Control Widget と iOS 26](insights/06-control-widget-ios26.md)

- `supportedModes` の使い分け（`openAppWhenRun` と同等挙動の記述あり）
- `ControlWidgetButton(action:)` + `.foreground(.immediate)` パターン（kind は reverse-domain 形式必須）
- `ControlConfigurationIntent` の制約
- `.background` モードによるバックグラウンドアクションとローカル通知フィードバック

### [07. プラットフォーム固有の知見](insights/07-platform-specific.md)

- watchOS: `Button(intent:role:)` の API差異、ファイル分割指針
- LiveActivity: `LiveActivityIntent` vs `AppIntent`、自動管理View Modifier
- Widget: `Button(intent:)` 統合と `Link(destination:)` 公式推奨
- ファイル分割の一般的パターン

---

## 整理で削除した内容

以下の内容は CLAUDE.md に十分記載されているため、個別ファイルには含めていない:

- **SwiftLint設定**: CLAUDE.md「コーディング規約」セクション参照
- **TDD（テスト駆動開発）**: CLAUDE.md「テスト方針」セクション参照

## 更新履歴

- 2026-04-13: Shortcuts Intent ルーティング問題の根本原因（`IntentTodoAppIntentsPackage` のメインターゲット重複宣言）が判明。誤った知見（`.background + 通知ワークアラウンド`、`IntentAppState` フォールバック、`IntentDependencies.shared` パターン）を削除し、`@Dependency + AppDependencyManager` パターンを標準として記述更新。
- 2026-03-19: 18セクションを7ファイルに分割・整理
