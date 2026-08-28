# IntentTodo 開発インサイト集

このドキュメントは、IntentTodoアプリの開発中に得られた技術的なインサイトの目次です。
各トピックの詳細は個別ファイルを参照してください。

- **各ルールがどういう経緯で決まったか** → [docs/devlog/](devlog/README.md)
- **これからやること（未検証・未採用の消化）** → GitHub issue（#30 / #57 / #68）
- **App Intents API ごとの採用状況** → [APP_INTENTS_API_COVERAGE.md](APP_INTENTS_API_COVERAGE.md)

> insights には**現在のルールだけ**を書く。経緯は devlog、残タスクは issue
> （[AGENTS.md の「ドキュメント運用」](../AGENTS.md#ドキュメント運用現在のルール--経緯--残タスク-の三分割)）。

---

## 目次

### [01. Swift Package 設計](insights/01-swift-package-design.md)

- 依存関係設計（7 パッケージ / 単方向依存 / `@_exported import` を使わない理由）
- DevDock式パッケージ構成（独立Package.swift + 相対パス依存）
- ルートPackage.swift方式との比較

### [02. SwiftData と Concurrency](insights/02-swiftdata-concurrency.md)

- CloudKit対応の制約（`@Attribute(.unique)`禁止、optionalリレーション）
- `@Model` プロパティで `didSet` を使わない（CloudKit マージ / KVC で発火しない）
- `Domain.DueDateStatus` による期限判定ロジック共有と `TimeRemainingView` overdue クラッシュ対策
- `@Model`マクロと`Sendable`の競合
- Strict Concurrency対応（`@MainActor`パターン）
- Repository Protocol設計

### [03. App Intents コア設計](insights/03-app-intents-core.md)

- Intent = 「アプリの動詞」としての設計
- DI パターン（`@Dependency` + `AppDependencyManager`）
- AppEntity / IndexedEntity / EntityQuery
- App Shortcuts（`AppShortcutsProvider`、フレーズのパラメータ型制限）
- Intent のコピーはどこから引かれるか（main bundle 強制 / 自動抽出は `parameterSummary` だけ）
- Intent統合のベストプラクティス
- AppEnum
- WWDC26 公式サンプル 4 本との突き合わせ（Phase 9）: 表示表現とローカライズ、Siri が読む subtitle、donation の置き場所、Spotlight 属性の二重書き、onscreen annotation の適用先

### [04. UI層とIntent統合](insights/04-ui-integration.md)

- `Button(intent:)` の使用とプラットフォーム対応（`Button(role:intent:)` は `role:` が先）
- 直接 `perform()` を呼ばない（`@Dependency` はシステム dispatch 経由でのみ解決）
- `onAppIntentExecution` と `AppDependencyManager + @Dependency + perform()` の使い分け
- View は struct 抽出、computed-property View は避ける
- `@Observable` + `@MainActor`パターン
- App Intents vs ViewModelの役割分担
- SPM パッケージの UI コピーと String Catalog（`LocalizedStringResource.copy(_:)` / `Bundle.module` / 抽出の確認方法）
- ja を入れて分かった catalog の配置（抽出はターゲット単位 / `TodoAppIntents` に catalog は不要 / `AppShortcuts.xcstrings` は String Set / pbxproj は Localization Planner に任せる）

### [05. Extension とデータ共有](insights/05-extensions-and-data-sharing.md)

- WidgetBundle の明示的登録（`AppDependencyManager` 同期登録 + ControlWidget は `#if !os(visionOS)`）
- App Groups によるデータ共有（SharedModelContainer）
- UserDefaults の App Group 対応
- Intent → UI コミュニケーション（主経路: `@Dependency` + NavigationModel、通知タップ経路は `NotificationHandler` への注入）
- WidgetKit 更新パターン（WidgetReloader）

### [06. Control Widget と iOS 26](insights/06-control-widget-ios26.md)

- `supportedModes` の使い分け（`openAppWhenRun` と同等挙動の記述あり）
- **Button と Toggle の使い分け**（Toggle には固定された対象と `SetValueIntent` が要る）
- `ControlWidgetButton(action:)` + `.foreground(.immediate)` パターン
- **`ControlValueProvider`** で値を供給するパターン（body 直 fetch より推奨）
- `kind` は reverse-DNS 形式 (`dev.touyou.IntentTodo.<Target>.<WidgetName>`) に統一
- `ControlConfigurationIntent` の制約とモジュール境界
- visionOS 非対応: `#if !os(visionOS)` ガード
- **Control では dialog も snippet も出ない** → 成功はコントロール自身の再描画、失敗のみローカル通知

### [07. プラットフォーム固有の知見](insights/07-platform-specific.md)

- watchOS: `Button(intent:role:)` の API差異、`WatchUI` パッケージ分離方針
- macOS native 対応: `@UIApplicationDelegateAdaptor` / `@NSApplicationDelegateAdaptor` の `#if` 分岐 + `NotificationHandler` 共通化
- LiveActivity: `LiveActivityIntent` vs `AppIntent`、`.task(id:)` を使った監視 Modifier
- Widget: `Button(intent:)` 統合と `Link(destination:)` 公式推奨
- プラットフォームガード指針 (`#if os(iOS) || os(visionOS)` / `#if !os(visionOS)` / `#if os(macOS)` の使い分け)
- `#Predicate` の Optional 比較回避
- `Button(intent:role:)` の引数順 (`role:` が先)

---

## 整理で削除した内容

以下の内容は CLAUDE.md に十分記載されているため、個別ファイルには含めていない:

- **SwiftLint設定**: CLAUDE.md「コーディング規約」セクション参照
- **TDD（テスト駆動開発）**: CLAUDE.md「テスト方針」セクション参照

## 更新履歴

このドキュメント・insights/ 配下の再編の経緯は [docs/devlog/insights-changelog.md](devlog/insights-changelog.md) を参照。
