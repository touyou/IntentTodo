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
- DI制約と共有ModelContainerパターン
- AppEntity / IndexedEntity / EntityQuery
- App Shortcuts（`AppShortcutsProvider`、フレーズのパラメータ型制限）
- Intent統合のベストプラクティス（重複Intentの検出と統合）
- AppEnum

### [04. UI層とIntent統合](insights/04-ui-integration.md)

- `Button(intent:)` の使用とプラットフォーム対応
- `@Observable` + `@MainActor`パターン
- App Intents vs ViewModelの役割分担
- コード簡素化パターン

### [05. Extension とデータ共有](insights/05-extensions-and-data-sharing.md)

- WidgetBundle の明示的登録
- App Groups によるデータ共有（SharedModelContainer）
- UserDefaults の App Group 対応
- Intent → UI へのコミュニケーション（IntentAppState）
- WidgetKit 更新パターン（WidgetReloader）

### [06. Control Widget と iOS 26](insights/06-control-widget-ios26.md)

- `openAppWhenRun` → `supportedModes` / `OpenIntent` への移行
- Control Widget の制約（SetValueIntent非互換、ConfigurationIntentフィードバック制限）
- **iOS 26 トラブルシューティング: Control Widget からアプリを開く問題**
  - 10パターンの検証結果と全て失敗の記録
  - `import TodoAppIntents` の影響範囲（`.background`は正常、foregroundのみ不可）
  - 採用した解決策: `.background` + 通知パターン
  - Home Widget `Link(destination:)` はApple公式推奨パターン
  - `ControlWidgetButton` の OpenIntent 用 initializer が公式ドキュメントに存在するがiOS 26で動作しない

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

- 2026-03-19: 18セクションを7ファイルに分割・整理
  - 重複の統合（App Groups、Extension制約、IntentAppState関連）
  - 矛盾の修正（`import TodoAppIntents`の影響は`.background`では問題なし）
  - 古い情報の更新（セクション18の「未解決」→ 通知パターンで解決済み）
  - 最新の発見を反映（Home Widget `Link`は公式推奨、OpenIntent initializerの存在）
