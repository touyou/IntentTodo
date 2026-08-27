# IntentTodo - Agent Guide

このプロジェクトはApp Intents中心設計に基づいたマルチプラットフォームTodoアプリです。

## プロジェクト概要

### 設計思想

本プロジェクトは**App Intents中心設計**を採用しています。これは以下の概念を統合した独自のアプローチです：

- **App Intent Driven Development** (SwiftLee): コード再利用とシステム統合
- **Action-Centered Design** (Vidit Bhargava): アクション中心のUXデザイン
- **モデルベースUIデザイン**: ユースケース中心設計との写像

#### 核心原則

1. **全てのアクションはApp Intentとして定義**されること
2. App Intentsで定義したアクションは`Button(intent:)`で直接実行
3. ロジックの二重実装を避け、App Intentsを唯一の実行経路とする
4. **アクションと情報（Entity）が設計の原子単位** - UIやプラットフォームは二次的

#### モデルベースUIデザインとの関係

> 「誰が何を行動できる」というユースケース中心設計は、App IntentsのEntity-Intentモデルに直接写像できる。
> - **Entity（名詞）** = ユースケースの「誰が」「何を」
> - **Intent（動詞）** = ユースケースの「行動できる」

これにより、デザインと実装の間に自然な対応関係が生まれます。

#### Liquid Glass時代の設計

UIクローム（装飾）が透明化し背景に溶け込む時代において、**コンテンツとアクションが本質**となります。
標準UIで十分となり、カスタムスタイリングへの投資は減少。代わりにIntent定義に注力することで、Apple Intelligenceとの統合が自然に実現されます。

### パッケージ構成（App Intents中心設計）
```
Packages/
├── Domain/           # SwiftData モデル、共通 Entity、DueDateStatus、ActivityAttributes
├── Repository/       # データアクセス層（Protocol + 実装）
├── TodoAppIntents/   # ★コア：Intent 定義 + ビジネスロジック + Shortcuts
├── UI/               # メインアプリ SwiftUI Views/ViewModels（iOS/iPadOS/macOS/visionOS）
├── LiveActivity/     # ActivityKit 管理 + ロック画面 View（iOS 限定）
├── WidgetUI/         # ホームウィジェット View（TodoWidgetEntryView / TodoWidgetRow）
└── WatchUI/          # watchOS View + Components + Complication（watchOS 限定）
```

### Extension ターゲット構成

各 Extension は「App/Bundle/Widget 宣言 + Info.plist + entitlements」のみに薄く保ち、View・状態管理・データ取得ロジックはすべて SPM パッケージに置く方針。

```
IntentTodoWidget/                   # ホーム画面ウィジェット + コントロールセンター
├── IntentTodoWidget.swift          # Provider + Widget 宣言（WidgetUI を import）
├── IntentTodoWidgetBundle.swift    # 全 Widget / Control をバンドル
├── Configuration/                  # WidgetConfigurationIntent
├── Controls/                       # ControlWidget 3 種（#if !os(visionOS)）
└── Helpers/WidgetModelContainer.swift

IntentTodoLiveActivity/             # ライブアクティビティ
├── IntentTodoLiveActivityBundle.swift
└── TodoLiveActivity.swift          # ActivityConfiguration（LiveActivity を import）

IntentTodoWatchApp/                 # watchOS アプリ
├── IntentTodoWatchApp.swift        # @main（WatchUI を import）
└── TodoComplication.swift          # コンプリケーション Widget 宣言
```

**ポイント**:
- **UseCase 層はパッケージとして持たない**。ユースケースの**宣言**（名前・引数・戻り値）を `AppIntent` が、
  **実装**（手続き・不変条件・副作用）を `TodoService` が受け持つ形に分かれている。
  「廃止」ではなく「宣言と実装に分裂した」と言うほうが実態に合う。
  Layered / Clean Architecture との対比（対応表・砂時計図・置き場の判定ルール）:
  [docs/APP_INTENT_DRIVEN_DESIGN.md](docs/APP_INTENT_DRIVEN_DESIGN.md#layered--clean-architecture-との対比)
- UI は Intent 実行トリガーと結果表示のみ
- Extension はターゲット固有のスキャフォルドのみ、View は SPM に移送してプレビュー再利用・テスト可能化
- Repository Protocol により Mock 可能、テスタビリティ確保

### マルチプラットフォーム展開指針（Action-Centered Design）

アクションと情報の特性に応じて、適切なプラットフォームに展開します：

| コンテンツ/アクションの特性 | 展開先 | 例 |
|---------------------------|--------|-----|
| 毎日確認する情報 | **ウィジェット** | 今日のTodo一覧、未完了数 |
| 頻繁に変わる情報 | **watchOSコンプリケーション** | 次の期限、進捗状況 |
| 繰り返しのアクション | **Shortcuts / Siri** | Todo追加、完了切り替え |
| 常時追跡が必要な情報 | **ライブアクティビティ** | 期限1時間以内のTodo |
| 素早いアクセスが必要 | **コントロールセンター** | クイック追加、緊急Todo完了 |
| 物理的なトリガーが自然 | **Action Button** / **Apple Pencil Pro（スクイーズ）** | 新規Todo作成 |
| 没入型・空間的な体験 | **visionOS** | 空間UI、ガラス素材 |

#### 実装済みプラットフォーム

- **iOS/iPadOS**: メインアプリ（リスト、詳細、追加）
- **macOS**: ネイティブビルド対応（`AppDelegate` (iOS/visionOS) と `MacAppDelegate` (macOS) を `#if os(...)` で分離、`NotificationHandler` を cross-platform 実体として共通化）
- **watchOS**: アプリ + コンプリケーション（Circular/Corner/Rectangular/Inline）
- **visionOS**: 空間UI（NavigationSplitView、Ornament、ホバーエフェクト）
- **ウィジェット**: Small/Medium/Large/ExtraLargePortrait サイズ対応（Todo一覧表示、アプリ起動は `Link(destination:)` を使用）

> **Widget でのアプリ起動**: [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) に "An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use `Link` and `widgetURL(_:)`" と明記。アプリを開くだけの用途には `Button(intent:)` より `Link` が公式推奨。
- **ライブアクティビティ**: Dynamic Island + ロック画面（期限1時間以内で自動表示、`LiveActivityIntent` 使用）
- **コントロールセンター**: アプリを開く / 単発アクションは `ControlWidgetButton(action:)`、2 状態の切り替えは `ControlWidgetToggle(isOn:action:)` + `SetValueIntent`（対象を固定するため `AppIntentControlConfiguration` で設定可能にする）

#### 設計プロセス

1. **最小のスクリーンから設計開始**: Apple Watch等、最も制約の厳しい環境で本質的なアクションを特定
2. **アクションをIntent化**: 特定したアクションをApp Intentとして定義
3. **プラットフォーム固有の実装へ拡張**: 上記の表に従って各プラットフォームに展開
4. **メインアプリUIは最後**: 複数のアクションをクラスター化してスクリーン設計

## 技術要件

### ターゲット
- iOS 27.0+ / iPadOS 27.0+
- macOS 27.0+
- watchOS 27.0+
- visionOS 27.0+
- Swift 6.0+

`.reminders` 系の assistant schema が iOS 27+ 限定のため、deployment target は 27 世代で揃えている。

### コーディング規約

#### SwiftLint
- **必須**: SwiftLintを導入し、スタイルの一貫性を保つ
- プロジェクトルートに`.swiftlint.yml`を配置
- CI/ビルド時に自動チェックを実行

#### Swift API Design Guidelines準拠
- [Swift.org API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)に従う
- 命名規則: 明確で曖昧さのない名前を使用
- メソッド名は副作用に基づいて命名（mutatingは動詞、non-mutatingは名詞）
- パラメータ名は文書化の役割を果たすように命名

#### Human Interface Guidelines (HIG)準拠
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)に従う
- 標準コンポーネントを適切に使用
- アクセシビリティを考慮した設計
- プラットフォーム慣習に沿ったUX

#### コード内コメント（経緯は書かない）

ドキュメントと同じ切り分けをコードにも適用する（[docs/devlog/README.md](docs/devlog/README.md) の運用方針）。

- **書く**: なぜこの形なのかという**現在の理由**、非自明な制約、公式ドキュメント / WWDC セッションの引用（`wwdc2026-345 16:30` のように位置まで）
- **書かない**: 調査の経緯、失敗した仮説、「以前は〜していたが」「かつては〜」という履歴。これらは `docs/devlog/` に書く
- 経緯を追えるようにするため、代わりに**ポインタを 1 行**置く: `経緯: docs/devlog/03-app-intents-core.md（2026-08-21 の …）`
- 現在のルールの詳しい説明が insights にあるなら `詳細: docs/insights/03-app-intents-core.md` を置き、コード側は要約に留める（同じ説明を 2 箇所で腐らせない）

```swift
// ❌ 経緯がコードに漏れている
// 以前は CSSearchableIndex.default() を使っていたが、公式が prototyping 専用と
// 言っているのに気づいたので 2026-08-21 に名前付きへ移した。

// ✅ 現在の理由 + ポインタ
/// 名前付き index を使う。公式: "use a named `CSSearchableIndex` type and not the
/// default index. Use the default index only for prototyping and testing".
/// 経緯: docs/devlog/03-app-intents-core.md（2026-08-21 の default index からの移行）
```

### テスト方針

#### TDD（テスト駆動開発）
- **Red → Green → Refactor** サイクルを遵守
- 機能実装前にテストを先に書く
- テストが通る最小限の実装を行い、その後リファクタリング

#### テスト構成
- **Unit Tests**: Testingフレームワーク使用（`@Test`構文）
- **UI Tests**: XCTest使用
- App Intents、UseCase、Repositoryは必ずユニットテストを作成
- **App Intents の実経路は AppIntentsTesting で押さえる**（`IntentTodoUITest/AppIntents/`）。
  entity の id 解決 / `allEntities` / `suggestedEntities` / Spotlight index / `TransientAppEntity` など、
  **落ちても他のテストでは捕まらない**経路を優先する。手作業の実機検証に行く前に、まずここで押さえられ
  ないかを検討する（詳細と落とし穴: `docs/insights/03-app-intents-core.md`）
- **条件付き assert を書かない**。`if element.waitForExistence(...) { XCTAssert... }` は、要素が
  見つからないと中身が一度も実行されず緑になる。実際にこの形で「削除がまったく動いていない」のを
  長期間見逃した（経緯: `docs/devlog/06-control-widget-ios26.md` 2026-08-12）

### Swift/SwiftUI ガイドライン

#### 必須ルール
- `@Observable`クラスには必ず`@MainActor`を付与
- Strict Swift Concurrencyを適用
- `ObservableObject`は使用禁止 → `@Observable`を使用
- `NavigationView`は使用禁止 → `NavigationStack`を使用
- `foregroundColor()`は使用禁止 → `foregroundStyle()`を使用
- GCDは使用禁止 → Swift Concurrencyを使用

#### SwiftUIベストプラクティス
- Viewにロジックを書かず、ViewModelに記述
- コンポーネントはデータ単位で分割（再レンダリング範囲の最適化）
- computed propertyでViewを分割しない → 新しいView structを作成
- `GeometryReader`より`containerRelativeFrame()`や`visualEffect()`を優先
- `AnyView`は必要最小限に

#### UI コピーは `LocalizedStringResource` で運ぶ（SPM パッケージでは `.copy(_:)` 経由）

- **文言を `String` 型のプロパティ / パラメータで運ばない**。`Text` / `Label` は `String` を渡すと
  verbatim 初期化子を選ぶため、リテラルが String Catalog に**抽出されない**（データの verbatim 表示
  ——`todo.title` など——は対象外）
- SwiftUI の `Text("Cancel")` 形は実行時に `Bundle.main` を引く。UI コピーを持つパッケージ
  （`UI` / `WatchUI` / `WidgetUI` / `LiveActivity`）は自前の catalog を同梱しているので、
  **必ず各パッケージの `LocalizedStringResource.copy(_:)` を通す**（`Text(.copy("Cancel"))`）。
  素のリテラルで書くと catalog に載っても実行時に引けない
- `\(date, style: .relative)` のような `LocalizedStringKey` 専用の補間だけは
  `Text("...", bundle: .module)` 形で書く。数値だけの表示は `Text(value, format: .number)`
- 抽出結果の確認は `xcodebuild -exportLocalizations`。詳細: `docs/insights/04-ui-integration.md`

#### SwiftData（CloudKit使用時）

[Apple 公式: Define a CloudKit compatible schema](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices#Define-a-CloudKit-compatible-schema) より:

- `@Attribute(.unique)` は CloudKit では enforce されない（"CloudKit is unable to enforce the unique property option"）。`#Unique<T>` マクロも同じメカニズムのため同様
- リレーションシップはすべて optional（"CloudKit requires all relationships to be optional"）。DeleteRule の `.deny` もサポート外
- プロパティはデフォルト値を持つか optional にする（同期時のコンフリクト対策）

## App Intents実装ガイド

### 基本パターン
```swift
struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Todo"

    @Parameter(title: "Title")
    var title: String

    func perform() async throws -> some IntentResult {
        // 実装
        return .result()
    }
}
```

### Swift Package内でのAppIntents

Swift Package 内で Intent を定義する場合は、パッケージに `AppIntentsPackage` を1つ宣言する（[Apple 公式ドキュメント](https://developer.apple.com/documentation/appintents/appintentspackage)が示す標準パターン）。

```swift
// パッケージ内で宣言
public struct TodoIntentsPackage: AppIntentsPackage { }
```

メインアプリ側は何も宣言しなくても、パッケージの Intent は自動的にアプリの Intent として登録される（`actions`/`entities`/`queries` はアプリの統合メタデータに集約される。`AppShortcutsProvider` だけは集約されないので別扱い、後述）。

複数ターゲット（アプリ + Widget / LiveActivity / watchOS App）で同じパッケージを再利用する場合、**利用側の各ターゲットでも `includedPackages` 付きで `AppIntentsPackage` を宣言する**（Apple 公式手順。wwdc2025-244 23:29–24:00 "You must register each target as an App Intents Package to ensure proper indexing and validation."）。

```swift
// 各ターゲットに 1 つずつ（IntentTodoAppIntentsPackage.swift 等）
struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
```

宣言先: `IntentTodo` / `IntentTodoWidget` / `IntentTodoLiveActivity` / `IntentTodoWatchApp` の 4 ターゲット。

> かつては「アプリ側にも宣言すると Shortcuts のルーティングが壊れる」として意図的に外していたが、2026-08-12 の再検証で採用に切り替えた。根拠:
> 1. 全バンドルの `Metadata.appintents` の件数が宣言の有無で**完全一致**（DerivedData ごと消したクリーンビルドでも `actions` 23 = intent 型数 23 で重複なし）
> 2. 宣言した状態で **AppIntentsTesting の全テストがグリーン**（Siri / Shortcuts / Spotlight と同じインフラを通る）
> 3. **Shortcuts アプリで実機確認済み**（アクション一覧・パラメータ表示が壊れていない）
>
> **未確認なのは App Shortcut の「フレーズ」ルーティング（Siri）のみ**。AppIntentsTesting は型名で intent を引くためフレーズ経路を通らず、これは Apple の想定どおり手動確認の領域（上記「検証の梯子」）。経緯: [docs/devlog/03-app-intents-core.md](docs/devlog/03-app-intents-core.md)

> **⚠️ 例外: `AppShortcutsProvider` はパッケージに置けない。** Intent / Entity / Query はパッケージから集約されるが、`AppShortcutsProvider`（App Shortcut のフレーズ登録）だけはアプリの統合メタデータに集約されず `autoShortcuts: 0` になる。App Shortcut がビルドエラー無しで Siri / Shortcuts / Spotlight に出ない、という形で顕在化する。**必ずアプリターゲット直下に置く**（本プロジェクトでは `IntentTodo/IntentTodo/TodoAppShortcuts.swift`、`import TodoAppIntents` で Intent を参照）。詳細は `docs/insights/03-app-intents-core.md`。

### 1 アクション 1 Intent が既定（呼出元ごとに複製しない）

同じアクションは呼出元が違っても**同じ Intent を使う**。Live Activity のボタンも Siri も `ToggleTodoCompletionIntent(todo:)` を呼ぶ。Live Activity が持っているのが id と title だけでも、`TodoAppEntity(id:title:)` で組んで渡せばよい（システムが `perform()` 前に `TodoEntityQuery.entities(for:)` で id から再解決する）。

> **経緯**: かつては「Primary（`TodoAppEntity` パラメータ）/ FromExtension（`String` パラメータ、`isDiscoverable = false`）」に分けていた。理由は entity の事前解決中に SwiftData が `EXC_BREAKPOINT` で落ちる実績があったこと。**2026-08-12 に iOS 27 で再現しないことを実測確認**（`entities(for:)` も `perform()` もメインアプリプロセスで走る。アプリ kill 済みの cold start でも、`LiveActivityIntent` 非準拠でも同じ）し、分離を撤去した。経緯: [docs/devlog/03-app-intents-core.md](docs/devlog/03-app-intents-core.md)

**別 Intent に分けてよいのは「振る舞いが違う」場合だけ**。現存する分岐は次の 2 つで、どちらも呼出元プロセスの都合ではなく**対話できるかどうか**が理由:

| Intent | 分けている理由 |
|--------|--------------|
| `SnoozeTodoIntent` / `QuickSnoozeTodoIntent` | 前者は `requestChoice` で期間を選ばせる。Live Activity のボタンは背景実行で問い合わせ先の UI が無いため、後者が既定 30 分で即実行する |
| `DeleteTodoIntent` / `DeleteTodoImmediatelyIntent` | 前者は `requestConfirmation` で確認を取る。UI は SwiftUI の `.confirmationDialog` で確認してから後者を実行する |
| `ToggleTodoCompletionIntent` / `SetTodoCompletionIntent` | 前者はトグル、後者は絶対値セット（`SetValueIntent`）。Control の `ControlWidgetToggle` は on/off を渡してくるのでトグルでは表現できない |

> **⚠️ `requestConfirmation` / `requestChoice` を含む Intent をアプリ内の `Button(intent:)` から呼んではいけない**。応答する面が無いため `LNPerformActionErrorCodeUnsupportedValueType` で失敗し、**エラー表示も出ずに何も起きない**（2026-08-12 実測）。Siri / Shortcuts / AppIntentsTesting 経由では成功するので、AppIntentsTesting では検出できず **UI テストが要る**。

内部用（`isDiscoverable = false`）の Intent は AppShortcuts に登録しない。

### 破壊的 / 不可逆な操作は `UndoableIntent` にする

削除系 3 Intent と `ToggleTodoCompletionIntent` は `UndoableIntent`。登録処理は
`TodoUndoRegistrar` に集約する（Intent 側に直接書かない。3 つある削除経路のどれかだけ直し忘れる）。

- **消す前に `TodoService.snapshot(todoId:)`**。`TodoItem` は SwiftData の `@Model` なので削除後は
  何も読めず、`Sendable` でもないため undo のクロージャに持ち越せない
- **同じ id で戻す**（`TodoService.restore(_:)`）。id が変わると Spotlight index / donation /
  ウィジェットが握っている参照がまとめて迷子になる。復元は idempotent
- 完了状態の undo は「逆トグル」ではなく**元の値を `setCompletion` で絶対値指定**する
- `undoManager` は呼出元が用意しなければ `nil`（ウィジェットの `Button(intent:)` など）。
  登録が no-op になるのは想定どおり

詳細と落とし穴: `docs/insights/03-app-intents-core.md`。

Live Activity の状態を触る Intent（`activity.end` / `activity.update`）は `#if os(iOS)` で `LiveActivityIntent` に準拠させる（`perform()` がアプリプロセスで走ることの公式保証を得るため）。

ビジネスロジックは `Services/TodoService.swift` (`@MainActor final class`) に集約し、各 Intent が `@Dependency var todoService: TodoService` で参照する。

### Dialog vs 通知の使い分け

Intent の実行結果をユーザーに伝える方法は呼出元で見え方が異なる:

| 呼出元 | `.result(dialog:)` | Snippet (`snippetIntent:`) | ローカル通知 |
|-------|------------------|--------------------------|------------|
| Siri | 読み上げ ✅ | 表示 ✅ | 表示 ✅ |
| Spotlight / Shortcuts | 結果欄に表示 ✅ | 表示 ✅ | 表示 ✅ |
| UI (`Button(intent:)`) | 表示なし | 表示なし | 表示 ✅ |
| Widget `Button(intent:)` | 表示なし | 表示なし | 表示 ✅ |
| **Control (`ControlWidgetButton` / `ControlWidgetToggle`)** | **表示なし** | **表示なし** | 表示 ✅ |

> Control の 2 つの「表示なし」はいずれも**実機確認済み**（dialog: 2026-04-14 / snippet: 2026-08-12）。snippet は、同一 Intent・同一 snippet を Spotlight から呼ぶと出て Control から呼ぶと出ない、という比較で確定させた（実行プロセスを `[.main]` に固定しても、Button / Toggle どちらの形でも出ない）。**ドキュメントの肯定リストから「Control は非対応」と推論するのは禁止** — 一度その推論で設計を誤っており、wwdc2025-275 1:40–1:59 の "control" 実演とも矛盾する。判断は必ず「呼出元だけ変えて同じ Intent を走らせる」比較で行う。経緯: [docs/devlog/06-control-widget-ios26.md](docs/devlog/06-control-widget-ios26.md)

使い分けルール:
- **Control から呼ばれる Intent** (`SetTodoCompletionIntent` 等): フィードバックの主経路は `perform()` 完了時の自動リロードによる**コントロール自身の再描画**。dialog も snippet も出ないので返さない。**失敗時のみローカル通知** (`ControlNotificationHelper.sendErrorNotification`) — 失敗すると前の状態のまま再描画されて「何も起きなかった」と区別できないため。読ませたい情報が主目的なら `LaunchAppIntent` でアプリの該当画面に送る
- **Siri / Shortcuts 前提の Intent** (`ShowTodosIntent`, `ShowTodoCountIntent`, `GetTodoSummaryIntent` 等): **Dialog + Snippet**。`IntentDialog(full:supporting:)` で音声単独用と視覚併用を分け、`snippetIntent:` でインタラクティブな結果表示を添える
- **UI Button 経由が中心の Intent** (Add/Toggle/Delete 等): Dialog も通知も不要 (UI が即座に反映するため)

### データ更新の後処理は `TodoService.dataDidChange()` に集約する

データを変える経路は必ず `TodoService` の変更メソッドを通り、そこの `defer { Self.dataDidChange() }` が 2 つの後処理をまとめて行う。**Intent 側には書かない**。

1. `WidgetReloader.reloadAllWidgets()` — `WidgetCenter.shared.reloadAllTimelines()` と `ControlCenter.shared.reloadAllControls()` の**両方**を呼ぶ（ホームウィジェットとコントロールは別 API で、前者だけではコントロールが更新されない）
2. `AppShortcutParameterUpdater.notifyEntitiesChanged()` — パラメータ入り App Shortcut フレーズ（"Complete \<todo\> in IntentTodo"）の候補をシステムに取り直させる（wwdc2023-10102 9:24）

```swift
// TodoService の変更メソッド
defer { Self.dataDidChange() }
try repository.update(item)
```

> Widget 内の `Button(intent:)` から呼ばれた Intent は、システムが `perform()` 完了時に自動でタイムラインをリロードすることを保証している（wwdc2023-10028 13:47/10:02）。手動呼び出しが本当に必要なのは Siri / Shortcuts / アプリ UI など Widget 起点でない経路のケース。全変更で無条件に呼ぶ現在のルールは判定を省いた安全側の運用（呼び出し重複はコスト的に無視できる。経緯: [docs/devlog/03-app-intents-core.md](docs/devlog/03-app-intents-core.md)）。

### App Shortcut のフレーズにはパラメータを埋める

`AppShortcutsProvider` のフレーズは、Intent が `AppEntity` / `AppEnum` のパラメータを持つなら `"Complete \(\.$todo) in \(.applicationName)"` のように埋め込む（埋め込めるのはこの 2 種のみ）。パラメータ無しのフレーズも 1 つ残して、Siri が聞き返せるようにする。

パラメータ入りフレーズは **`updateAppShortcutParameters()` が一度も呼ばれていないと機能しない**。本アプリでは `IntentTodoApp.init()` での登録 + 初回実行と、上記 `dataDidChange()` からの通知で配線済み。

### @Dependency + AppDependencyManager パターン

Intent がアプリの共有状態（`TodoService`、`NavigationModel`、`ModelContainer` 等）にアクセスする場合、`AppDependencyManager` に同期登録し Intent 側で `@Dependency` で取得する。Intent がビジネスロジックを触るときは **`TodoService` を直接受け取る**のが基本（Repository は内包済み）。

```swift
// App.init() で同期登録
@main
struct MyApp: App {
    let modelContainer: ModelContainer
    @State private var navigation: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }
}

// Intent で @Dependency から取得
struct AddTodoIntent: AppIntent {
    @Dependency var todoService: TodoService
    @Parameter(title: "Title") var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let entity = try todoService.create(title: title, ...)
        // ウィジェット更新と App Shortcut パラメータ更新は
        // TodoService 内の defer (dataDidChange) で自動呼出
        return .result(value: entity)
    }
}
```

`TodoService` / `ModelContainer` / `@Observable @MainActor` クラスはいずれも `Sendable` 要件を満たすため `@Dependency` で問題なく共有できる。ビジネスロジックを直接扱わない Intent (例: `ToggleUrgentTodoIntent` のように fetch + mutate を 1 つの操作としてまとめたい場合) は `TodoService` にメソッドを足す方針で、Intent 側に SwiftData 呼び出しを書かない。

### 実行プロセスと登録先

`supportedModes` は「フォアグラウンド遷移するか」を決めるだけで、実行プロセスそのものを固定しない。Intent/Entity/Query が複数ターゲット（アプリ + Widget Extension 等）にリンクされた共有パッケージにある場合、システムは**ヒューリスティクス**でプロセスを選ぶ（例: アプリが起動中ならアプリを優先し、そうでなければ Extension を起動。[WWDC 2026 #345](https://developer.apple.com/jp/videos/play/wwdc2026/345/) 15:59–16:55）。固定したい場合は `allowedExecutionTargets`（`.main` / `.appIntentsExtension` / `.widgetKitExtension`）で明示する。`@Dependency` はそのプロセス内の `AppDependencyManager` からのみ解決される。

**本プロジェクトのルール: SwiftData を書き換える Intent は必ず `allowedExecutionTargets = [.main]` を宣言する。** 共有パッケージが Widget Extension にもリンクされているため、未指定だとアプリ未起動時に Extension プロセスが同じストアの書き手になり得る（wwdc2026-345 16:30 が名指しで避けている構成）。読み取り系は逆に**固定しない**（アプリを起こさず Extension で応答できるほうが速い）。宣言漏れは `Packages/TodoAppIntents/Tests/TodoAppIntentsTests/IntentExecutionTargetsTests.swift` が検出する。

| 呼出元 | モード | 実行プロセス | 必要な登録 |
|-------|------|------------|-----------|
| Siri / Shortcuts | 全モード | メインアプリ | `App.init()` |
| UI の `Button(intent:)` | 全モード | メインアプリ | `App.init()` |
| Widget `Button(intent:)` | `.foreground(.immediate)` | **メインアプリ** | `App.init()` |
| Widget `Button(intent:)` / ControlWidget | `.background`（`allowedExecutionTargets` 未指定 = 読み取り系） | **ヒューリスティクスで決定**（アプリ起動中はメインアプリ優先、未起動なら Widget Extension を起動） | **両方**（`App.init()` と `WidgetBundle.init()`） |
| 同上 | `.background` + `allowedExecutionTargets = [.main]`（書き込み系はすべてこれ） | **メインアプリに固定** | `App.init()` のみ |
| Live Activity ボタン | `LiveActivityIntent` / 素の `AppIntent` | `perform()` はアプリプロセス（Apple 公式）。`TodoAppEntity` の事前 entity 解決 (`entities(for:)`) も**アプリプロセス**で走る（iOS 27 実測。cold start でも、`LiveActivityIntent` 非準拠でも同じ） | アプリ側 (`App.init()`) のみで足りる |

> 二重登録（`App.init()` と `WidgetBundle.init()` の両方）は**撤廃ではなく役割分離**。書き込み系を `[.main]` に固定した結果、Widget Extension 側の `TodoService` 登録は読み取り系 Intent・entity 解決・snippet 描画のためだけに残っている（詳細は `docs/insights/03-app-intents-core.md`、経緯: [docs/devlog/03-app-intents-core.md](docs/devlog/03-app-intents-core.md)）。

```swift
// Widget Extension 側でも同様に同期登録
@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: sharedWidgetModelContainer)
            AppDependencyManager.shared.add(dependency: todoService)
        }
    }

    var body: some Widget { /* ... */ }
}
```

プロセスごとに `AppDependencyManager.shared` は独立インスタンスなので、そのプロセスで `@Dependency` を使う Intent がある場合は、そのプロセスの起点（`App.init()` / `WidgetBundle.init()` 等）で登録する必要がある。

### Intent Modes

[Apple 公式 `supportedModes` ドキュメント](https://developer.apple.com/documentation/appintents/appintent/supportedmodes)より:

| モード | 動作 | 旧 API との対応 |
|--------|------|----------------|
| `.background` | アプリを開かずにバックグラウンド実行 | `openAppWhenRun = false` と同じ挙動 |
| `.foreground` / `.foreground(.immediate)` | パラメータ解決後すぐフォアグラウンド | `openAppWhenRun = true` と同じ挙動 |
| `.foreground(.dynamic)` | `perform()` 内で動的にフォアグラウンド化を決定 | **`ForegroundContinuableIntent` の後継**（下記注参照）|
| `.foreground(.deferred)` | 初期バックグラウンド → `perform()` 内 or 返却時に自動フォアグラウンド化 | 新 API |

> **`ForegroundContinuableIntent` は deprecated**: [Apple 公式ドキュメント](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent)が明記: "This protocol is deprecated, please include `.foreground(.dynamic)` in the `supportedModes` of your app intent instead."

```swift
struct MyIntent: AppIntent {
    // バックグラウンドで実行
    static var supportedModes: IntentModes { .background }

    // フォアグラウンドで実行（アプリを開く）
    // static var supportedModes: IntentModes { .foreground(.immediate) }

    // 動的切り替え（初期バックグラウンド + 必要時 foreground へ）
    // static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }
}
```

### onAppIntentExecution（iOS 26+ / Intent → UI連携）

`onAppIntentExecution(_:perform:)` は iOS 26 で追加された View modifier で、特定のシーンに対して AppIntent の実行をハンドリングする。`TargetContentProvidingIntent` を実装した Intent が実行されたとき、対応するシーンでクロージャが呼ばれる。

```swift
// Intentの定義（TargetContentProvidingIntent は AppIntent を継承するため AppIntent の明示は不要）
struct ShowTodoDetailIntent: TargetContentProvidingIntent {
    @Parameter(title: "Todo")
    var todo: TodoAppEntity

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// Viewでのハンドリング
NavigationStack {
    TodoListView()
}
.onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
    // Intent実行時にUIを更新（例: 該当Todoの詳細画面へ遷移）
    navigationPath.append(intent.todo)
}
```

**ポイント**:
- `perform()` が定義されている場合、アクションクロージャの**後に** `perform()` が呼ばれる（二重実行に注意、どちらか一方にナビゲーションを集約する）
- `supportedModes` の `.background` と組み合わせることで、UIハンドリングと`.background`処理を両立可能
- `AppIntentSceneDelegate` プロトコルでシーンレベルのハンドリングも可能
- **macOS / watchOS では使えない**。前提の `TargetContentProvidingIntent` が SDK 側で `@available(macOS, unavailable)` / `@available(watchOS, unavailable)`（Xcode 27 beta 5 で実測）。`_AppIntents_SwiftUI` フレームワーク自体は macOS SDK にも存在するので `canImport` では判定できない。準拠は `#if os(iOS) || os(visionOS)` でガードし、macOS では `@Dependency` + `perform()` パターンを使う

**iOS バージョンによる動作差**
- **iOS 26.4 以降**: cold start でも正常動作（ワークショップPDF "In iOS 26.4 and above this works as before"）
- **初期 iOS 26（〜26.3）**: cold start 時タイムアウトでナビゲーション失敗の可能性あり。その場合は `AppDependencyManager` + `@Dependency var navigationModel` + `perform()` でナビゲーション状態を書き込むパターンに切り替える（詳細は `docs/insights/04-ui-integration.md` 参照）

### LiveActivityIntent（Live Activity専用）

Live Activity からアクションを実行する場合は `LiveActivityIntent` を使用する（[Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities#Start-and-stop-Live-Activities-from-App-Intents) より "make sure it inherits from `LiveActivityIntent`"）。通常の `AppIntent` ではなく `LiveActivityIntent` を使うことで、Activity の状態操作が可能になる。

```swift
struct CompleteTodoFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Todo"

    @Parameter(title: "Todo ID")
    var todoId: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Todo完了処理 + Live Activity を終了
        return .result()
    }
}
```

[ActivityKit / Activity](https://developer.apple.com/documentation/activitykit/activity) より: "You can update or end a Live Activity while your app is in the background, but you can only start a Live Activity while the app is in the foreground, unless you adopt App Intents and start the Live Activity using a `LiveActivityIntent`."

さらに [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities#Add-an-app-intent-that-performs-the-action) が明記する実行プロセスの差：
> "If you adopt the `LiveActivityIntent` or `AudioPlaybackIntent` protocol, the system runs the app intent in the app's process. [...] If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target."

つまり `LiveActivityIntent` の `perform()` はアプリプロセスで実行される。通常の `AppIntent` を Widget 経由で呼ぶ場合の実行プロセスは固定ではなくヒューリスティクスで決まる（「実行プロセスと登録先」節参照）。なお `LiveActivityIntent` が公式に保証するのは `perform()` の実行プロセスだが、`TodoAppEntity` の事前 entity 解決も iOS 27 の実測ではアプリプロセスで走る（「1 アクション 1 Intent」参照）。

| Intent種別 | 用途 | 特徴 |
|-----------|------|------|
| `AppIntent` | Siri/Shortcuts/UI | 汎用的なアクション |
| `LiveActivityIntent` | Dynamic Island/ロック画面 | Activity状態の操作が可能 |
| `ControlConfigurationIntent` | コントロールセンター | Extension配置必須 |

### IndexedEntity（Spotlight連携）
```swift
struct TodoEntity: AppEntity, IndexedEntity {
    var id: String

    @Property(title: "Title")
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

`attributeSet` には **`@Property(indexingKey:)` で表現できない属性だけ**を書く。同じ
`CSSearchableItemAttributeSet` キーを両方から埋めるとどちらが勝つかは公式に定義がなく、
「セマンティック検索に載るはずの本文が固定文に置き換わる」形で静かに壊れる（2026-08-21 に
`contentDescription` の二重書きを撤去）。詳細: `docs/insights/03-app-intents-core.md`

### Entity の表示表現（実行時文字列・音声・検索一致）

- **実行時の値は `"\(value)"` の補間形式で渡す**。`LocalizedStringResource(stringLiteral: todo.title)`
  はランタイム文字列をそのままローカライズ**キー**として扱うため、存在しないキーの引きが毎回発生し
  String Catalog の抽出対象にもならない。表示すべき subtitle が無いときは空文字ではなく `nil`
- **Siri は subtitle を読み上げる**。`"5:00"` のような位置指定表記は「ご、コロン、ぜろ、ぜろ」と
  読まれるので、`Duration.formatted(.units(width: .wide))` / `Date.FormatStyle` の自然文表記を使う
- 件数を含む文言は `^[\(n) todo](inflect: true)` で inflection を効かせる
- `EntityStringQuery.entities(matching:)` は**システムが絞り込んでくれない**（自分でフィルタする）。
  比較は `localizedStandardContains(_:)`（`lowercased().contains()` はロケール非依存で、かな/カナや
  ダイアクリティカルマークを別物として扱う）

### donation はアプリ UI 起点の操作だけ（`perform()` の中では donate しない）

公式 (Donations and discovery): "Restrict your donations to direct interactions with your app's
interface, and **not to interactions started by Siri or the Shortcuts app**."

`perform()` は呼出元を判別できない（`IntentSystemContext` にあるのは `currentMode` / `isVoiceOnly`
だけで invocation source の API は無い）。よって `perform()` 内の donate は必ず Siri / Shortcuts
経由でも走り、規約違反になる。**本アプリは現在 donation を行っていない**（UI も `Button(intent:)` で
同じ Intent を走らせる設計のため、公式サンプルの 2 方式がそのままでは当てはまらない。再導入案は
`docs/APP_INTENTS_CENTRIC_PLAN.md` の未着手候補）。

一方 **`deleteDonations(matching:)` は呼出元に関係なく正しい**（消えた entity への提案を残さない
後片付け）。削除経路には必ず入れる。

### Onscreen annotation の適用先

`.appEntityIdentifier(forSelectionType:)` は **`List` に付けたときだけ効く**（CosmoTunes
`TimerView` のコメントで明言）。`ScrollView { VStack { ForEach } }` では行ごとの単一
`.appEntityIdentifier(_:)` に落とす。`Canvas` などビュー階層から bounds を推測できない描画は
`.appEntityUIElements { ... }` で明示する。

壊れても**アプリ内では正常に見える**経路なので、`AppEntityDefinition.viewAnnotations()` で
テストする（`IntentTodoUITest/AppIntents/TodoSystemIntegrationTests.swift`）。

## Todoアプリ機能要件

### 基本機能
- [x] Todo作成（AddTodoIntent）
- [x] Todo完了/未完了の切り替え（ToggleTodoCompletionIntent）
- [x] Todo削除（DeleteTodoIntent / DeleteTodosIntent バルク）
- [x] お気に入り機能（ToggleFavoriteIntent）
- [x] 緊急フラグ（ToggleUrgentTodoIntent）
- [x] スヌーズ（SnoozeTodoIntent — requestChoice でスヌーズ期間選択）
- [x] バルク完了（CompleteTodosIntent — LongRunningIntent + CancellableIntent）
- [x] 削除 / 完了の取り消し（UndoableIntent — TodoItemSnapshot で同じ id へ復元）

### 拡張機能
- [x] 検索（TodoListView + .searchable）
- [x] Todo + Category 横断検索（SearchEverythingIntent — @UnionValue）
- [x] 期限設定（TodoItem.dueDate）
- [x] ソート（TodoSortOrder）
- [x] 並び替え（ReorderTodosIntent — isDiscoverable=false, UI専用）
- [x] カテゴリ分類（Category model / CategoryAppEntity）
- [x] 詳細説明（TodoItem.todoDescription）
- [x] サブタスク（SubTask model / SubTaskAppEntity）
- [x] 統計情報取得（GetTodoSummaryIntent — TodoListSummaryEntity: TransientAppEntity）
- [x] カテゴリを開く（OpenCategoryIntent — Visual Intelligence macOS対応で追加）
- [x] 集中モード連携（TodoFocusFilterIntent — SetFocusFilterIntent。カテゴリ / 急ぎのみ / 完了を隠す。リストとウィジェットの両方に効く）

### マルチプラットフォーム
- [x] iOS/iPadOS メインアプリ
- [x] macOS ネイティブアプリ（Catalyst ではない）
- [x] watchOS アプリ + コンプリケーション
- [x] visionOS 空間UI
- [x] ホーム画面ウィジェット（Small/Medium/Large/ExtraLargePortrait）
- [x] ライブアクティビティ（Dynamic Island + ロック画面）
- [x] コントロールセンター（クイック追加/Todo数/緊急Todo）
- [x] Siri/Shortcuts（TodoAppShortcuts）

### 拡張ロードマップ（WWDC 2026 要素の検証）

Action-Centered DesignとApp Intents中心設計を深化させる WWDC 2026 要素を検証済み（指定6セッション網羅。深度 **B**=ビルド/型成立まで。R=実機 Siri/Visual Intelligence、U=実 run は手動/CI）：

| フェーズ | 機能 | 概要 | 状態 |
|---------|------|------|------|
| **Entity強化** | プロパティマクロ / 値表現 | @ComputedProperty, @DeferredProperty, @Property(indexingKey:)(#43), Transferable + ValueRepresentation→IntentPerson/PlaceDescriptor(#44) | ✅ |
| **Onscreen Entities** | 画面コンテンツ提供 | userActivity + appEntityIdentifier（単一）/ .appEntityIdentifier(forSelectionType:)（一覧, #46）/ 通知 appEntityIdentifiers(#46) | ✅ |
| **Interactive Snippets** | Siri応答強化 | インタラクティブボタン付きスニペット | ✅ |
| **App Schema** | reminders ドメイン適合 | @AppEntity(schema: .reminders.list) / @AppIntent(schema: .system.searchInApp)(#47) | ✅ list+search適合（watchOSは Xcode 27 beta 2 で非対応→フォールバック/除外）/ reminder本体は据え置き(#48) |
| **高度な Intent** | 対話/寄付/system/部分更新/取り消し | requestConfirmation, requestChoice, IntentDonationManager, OpenIntent, DeleteIntent, UndoableIntent, IntentDialog(full:supporting:), IntentParameter.valueState(#45) | ✅（RelevantEntities は不適合 / donation は撤去済み） |
| **大量・実行制御** | スケール/プロセス制御 | EntityCollection, LongRunningIntent, CancellableIntent, allowedExecutionTargets(.main/.appIntentsExtension/.widgetKitExtension, #42), @UnionValue, SyncableEntity | ✅ |
| **Visual Intelligence** | カメラ/スクショ連携 | IntentValueQuery, SemanticContentDescriptor, semanticContentSearch | ✅ |
| **テスト基盤** | Intent 実経路テスト | AppIntentsTesting (makeIntent/run, UIテストバンドル) | ✅ |
| **Intent Modes** | 動的実行制御 | .foreground(.dynamic)（適所を再選定中、#55） | 保留（`cab8e67` revert 済） |

> 検証は `xcode27` ブランチ（27 世代ベータ SDK 用）で行い、**2026-08-27 に `main` へマージ済み**。状態・コミット・残タスクは `docs/APP_INTENTS_CENTRIC_PLAN.md`、実装パターンと落とし穴は `docs/insights/03-app-intents-core.md` を参照。
> **不適合/保留**: `RelevantEntities`（todo/reminders 向け `AppEntityContext` が無い）、コア `TodoAppEntity` の `.reminders.reminder` スキーマ適合（#48 で再評価 → マクロ生成 init + 入れ子サブエンティティの再設計が必要なため据え置き、再評価は #56。list 適合 + 自前 Intent で新 Siri 連携は成立）、`OwnershipProvidingEntity` / `requestValue`（#47、個人利用主体で優先度低）、EventKit/Contacts 連携（別フレームワーク軸）。
> **意図的不使用（API は把握済み・このアプリに不要と判断）**: `DynamicOptionsProvider` / `IntentParameterDependency`（パラメータ間の動的依存が発生するユースケースがない。選択肢は `AppEnum` ベースの静的リストで十分）。
> **未着手の候補（着手すれば価値が出るもの）**: `SpotlightSearchTool`(wwdc2026-246、FoundationModels 前提でスコープ外。#52) / `requestValue` / UI タップ由来の donation 再導入(#53) / watchOS の onscreen annotation(#54)。理由と前提つきの一覧は [docs/APP_INTENTS_CENTRIC_PLAN.md の「未着手の候補」](docs/APP_INTENTS_CENTRIC_PLAN.md#未着手の候補2026-08-21-の全ソース走査で拾ったもの)。
> **watchOS での assistant schema 非対応 (Xcode 27 beta 2〜、beta 5 でも継続を実ビルドで確認)**: `reminders` / `system` ドメインの assistant schema は watchOS で unavailable。TodoAppIntents は watchOS でもコンパイルされるため、`@AppEntity(schema: .reminders.list)`（`CategoryAppEntity`）と `@AppEnum(schema: .reminders.listType)`（`TodoListType`）は `#if os(watchOS)` で素の `AppEntity`/`AppEnum` にフォールバック（マクロ付き宣言は `#if` で分割不可なので型を2系統で全書き。**フォールバック側は型名も変える** — `WatchCategoryAppEntity` / `WatchTodoListType` + `typealias`。同じ mangled type name にスキーマ付き / 無しの 2 形が居ると、iOS アプリの統合メタデータへのマージでスキーマ無し側が勝ち、出荷メタデータから `reminders.ListEntity` が消える。**フォールバック側には `@Property(title:)` も明示する**（マクロ変種はマクロが生成するが素の `AppEntity` は 0 件になる）。どちらもビルド緑で通るので `skills/intent-centric-architecture/scripts/inspect_appintents_metadata.py` で検出する）、`@AppIntent(schema: .system.searchInApp)`（`ShowTodoSearchResultsIntent`）は watchOS に検索遷移先が無いため `#if !os(watchOS)` で丸ごと除外。`.visualIntelligence.*` は元々 `#if canImport(VisualIntelligence)`（iOS 限定）で保護済み。

## 開発フロー（TDD）

1. **テスト作成（Red）**: 機能のテストを先に書く
2. **Entity定義**: SwiftData Model（Domain）
3. **Repository実装**: Protocol + SwiftData実装
4. **App Intent実装（Green）**: ビジネスロジック込みでIntent定義
5. **リファクタ**: コード品質改善
6. **UI実装**: Button(intent:)で統合

## Git運用

### コミット粒度
- 機能単位で適切な粒度でコミット
- Phase完了時、重要なマイルストーン時にコミット
- テストが通る状態でのみコミット

### gitignore
- `docs/references/` はgitignoreに追加（参照ドキュメントは各自で用意）

### コミットメッセージ形式
```
<type>: <subject>

<body>
```

Types: feat, fix, refactor, test, docs, chore

## 参照ドキュメント

- `docs/PLAN.md` - 開発計画
- `docs/APP_INTENTS_CENTRIC_PLAN.md` - WWDC 2026 セッション要素の検証計画と結果（セッション別チェックリスト + コミット + 残タスク）
- `docs/AGENTS.md` - App Intents中心設計の詳細ガイド
- `docs/APP_INTENT_DRIVEN_DESIGN.md` - 関連概念の整理と比較
- `docs/INSIGHTS.md` - 開発中に得られた技術的インサイト（目次）
- `docs/insights/` - インサイト個別ファイル（7トピック）
- `docs/devlog/` - 各ドキュメントの現在のルールがどういう経緯で決まったか（調査・失敗・再検証の記録）
- `docs/presentation/` - 登壇・発表用のスライド骨子と想定スクリプト（① WWDC 時系列での基本説明 / ② 実践で見えた制約と工夫）
- `docs/references/` - 最新の技術参照（gitignore対象、ローカル参照用）
- `~/Developer/Private/wwdc26-app-intents-samples/` - WWDC26 App Intents 公式サンプル 4 本（CometCal / UnicornChat / CosmoTunes / PhotosDomainExample）。**リポジトリ外に置く**（`docs/` 配下だと Xcode がサンプルの `.xcodeproj` を `project.pbxproj` へ書き込む）。取得元と突き合わせ結果は `docs/insights/03-app-intents-core.md` の Phase 9

## 設計思想の背景

本プロジェクトの設計思想については以下を参照：
- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - モデルベースUIデザインとの関係
