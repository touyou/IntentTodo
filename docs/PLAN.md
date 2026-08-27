# App Intents中心設計に基づいたマルチプラットフォームTodoアプリ

## 設計思想

本プロジェクトは**App Intents中心設計**を採用しています。これは以下の概念を統合したアプローチです：

- **App Intent Driven Development**: アクションをデフォルトでApp Intentとして定義
- **Action-Centered Design**: アクションと情報を設計の原子単位とする
- **モデルベースUIデザイン**: ユースケース中心設計（誰が何を行動できる）との自然な写像

### 核心原則

> アプリは「アクションのクラスター」である。UIやプラットフォームは二次的であり、**アクション（Intent）と情報（Entity）が本質**。

これにより：
- デザイン（ユースケース）と実装（Intent）の間に自然な対応関係が生まれる
- 一度定義したアクションが複数のプラットフォームで再利用可能になる
- Apple Intelligenceとの統合が自然に実現される

## Todoアプリ自体の要件

- ベースは単純なToDo
- 完了、削除、お気に入り、検索、期限、ソート、カテゴリ分類、詳細、サブタスクなどがある
- 基本のUIは標準UIで作る（Liquid Glass時代ではUIクロームより**コンテンツとアクションが本質**）

## 設計要件

- 全てのアクションはApp Intentとして定義されること
- xcodeprojにしか存在できない中核となるファイル以外はSwift Package Managerで管理されること
- パッケージはレイヤーごと + 表示先別の葉ノード: **Domain, Repository, TodoAppIntents, UI, LiveActivity, WidgetUI, WatchUI** の 7 パッケージ（UseCase 層はパッケージとして持たず、宣言を Intent / 実装を `TodoService` が担う。対比: [APP_INTENT_DRIVEN_DESIGN.md](APP_INTENT_DRIVEN_DESIGN.md#layered--clean-architecture-との対比)）。各 Extension ターゲットは `@main` / `WidgetBundle` / `ActivityConfiguration` などのスキャフォルドのみで、View 層・状態管理・データ取得は SPM 側に配置する
- SwiftUIのView自体にはなるべくロジックを書かず、ViewModelに記述する（ただしViewModelはUI状態管理のみ）
- コンポーネントはデータ単位で分けて、何か更新があった際に再レンダリングの範囲がそのViewに絞られるような形にできると良さそう
- App Intentsで定義したアクションはButton(intent:)でなるべく直接実行できるように。その他にもApp Intentsを呼び出すようにしてなるべく二重でロジックを書かないようにする

## マルチプラットフォーム展開計画

Action-Centered Designの指針に従い、アクション/情報の特性に応じて展開先を決定：

### 展開マトリクス

| 機能/情報 | iOS App | ウィジェット | watchOS | visionOS | ライブアクティビティ | コントロールセンター | Shortcuts/Siri |
|----------|---------|-------------|---------|----------|------------------|-------------------|----------------|
| Todo一覧表示 | ✅ メイン | ✅ 今日分 | ✅ 簡易版 | ✅ 空間UI | - | - | ✅ |
| Todo詳細表示 | ✅ | - | ✅ | ✅ 空間UI | - | - | - |
| Todo追加 | ✅ | ✅ Large | ✅ | ✅ | - | ✅ | ✅ |
| 完了切り替え | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| お気に入り切り替え | ✅ | - | ✅ | ✅ | - | - | ✅ |
| 削除 | ✅ | - | ✅ | ✅ | - | - | ✅ |
| 未完了数 | ✅ | ✅ | ✅ コンプ | ✅ | - | ✅ | - |
| 期限1時間以内 | ✅ | ✅ | ✅ | ✅ | ✅ 自動表示 | - | - |
| スヌーズ | - | - | - | - | ✅ 30分延長 | - | - |
| 検索 | ✅ | - | - | ✅ | - | - | ✅ Spotlight |

### プラットフォーム別詳細

#### iOS/iPadOS メインアプリ
- NavigationStackによるリスト→詳細遷移
- フィルター・ソート・検索機能
- 期限の日時設定対応

#### ホーム画面ウィジェット (Small/Medium/Large)
- **Small**: 未完了数 + Todo一覧（3件）
- **Medium**: Todo一覧（4件）+ 残り件数表示
- **Large**: Todo一覧（5件）+ クイック追加ボタン

#### watchOS
- **アプリ**: 期限間近・未完了一覧、簡易追加
- **コンプリケーション**:
  - Circular: 未完了数
  - Corner: 進捗ゲージ
  - Rectangular: 次の期限Todoプレビュー
  - Inline: 未完了数と次の期限

#### visionOS
- **空間UI**: ガラス素材、Ornament、ホバーエフェクト
- **NavigationSplitView**: サイドバー+詳細のデュアルペイン
- **インタラクション**: 視線追跡・ハンドジェスチャー対応

#### ライブアクティビティ (Dynamic Island / Lock Screen)
- **トリガー**: 期限1時間以内のTodo（自動開始）
- **表示**: タイトル、残り時間カウントダウン
- **アクション**: 完了マーク、30分スヌーズ
- **終了**: 完了時または期限15分経過後

#### コントロールセンター
- **クイック追加**: `ControlWidgetButton(action:)` + `.foreground(.immediate)` の `LaunchAppIntent` で追加画面へ
- **Todo数表示**: `ControlValueProvider` で未完了数を供給し、コントロール面に表示
- **完了トグル**: `ControlWidgetToggle(isOn:action:)` + `SetTodoCompletionIntent`。対象 Todo は
  `AppIntentControlConfiguration` で固定し、`.promptsForUserConfiguration()` で未設定のまま置かせない

> **Control では dialog も snippet も出ない**（実機確認済み）。成功のフィードバックはコントロール自身の
> 再描画で、失敗時のみローカル通知。詳細は [insights/06-control-widget-ios26.md](insights/06-control-widget-ios26.md)

#### Action Button / Apple Pencil Pro
- 物理ボタン（Action Button）/ Apple Pencil Pro のスクイーズでクイック Todo 追加。
  **既存の App Shortcuts が何も書かずにそのまま出口として増える**

### 設計フロー

1. **最小スクリーンから設計**: Apple Watchで本質的なアクションを特定
2. **Intent化**: 特定したアクションをApp Intentとして定義
3. **プラットフォーム展開**: 上記マトリクスに従って各プラットフォームに実装
4. **メインアプリUI**: アクションをクラスター化してスクリーン設計

## 拡張可能性（Future Enhancements）

> このセクションは**方向性だけ**を書く。API ごとの採用状況は
> [APP_INTENTS_API_COVERAGE.md](APP_INTENTS_API_COVERAGE.md)、
> 「これからやる」ものは GitHub issue（未採用 API の消化は #68）にある。
> WWDC 2026 要素の検証結果は [APP_INTENTS_CENTRIC_PLAN.md](APP_INTENTS_CENTRIC_PLAN.md)。

### すでに入っているもの（当初の「将来フェーズ」から昇格）

Entity 強化（`@ComputedProperty` / `@DeferredProperty` / `@Property(indexingKey:)`）、
Interactive Snippets、Visual Intelligence（`IntentValueQuery` + `SemanticContentDescriptor`）、
Onscreen Entities（単一 / コレクション）、Intent Modes（`.background` / `.foreground(.immediate)` /
`.foreground(.deferred)`）、`UISceneAppIntent` + `AppIntentSceneDelegate`（cold start）、
`URLRepresentableEntity`（ディープリンク）、集中モード連携（`SetFocusFilterIntent`）、
`UndoableIntent`、`LongRunningIntent` + `CancellableIntent`、`SyncableEntity`、AppIntentsTesting。

### 次に効きそうな方向

1. **アプリ内の発見性** — `SiriTipView` は入れてあるので、`ShortcutsLink` で Shortcuts アプリへの導線を足す
2. **フィードバック経路の拡張** — Control は dialog も snippet も出ないため、`.controlWidgetStatus(_:)` が
   実際に出るなら通知に頼らない経路が 1 本増える
3. **提案** — `RelevantIntent` は donation なしで成立する（`PredictableIntent` は donation ゼロだと出ない）
4. **visionOS ウィジェット強化** — `supportedMountingStyles` / `widgetTexture` / `levelOfDetail`
5. **多言語化（ja）** — `knownRegions` / 4 パッケージ catalog / Intent コピーの bundle 決定 /
   `AppShortcuts.xcstrings` を通しでやる（#70）。**現状はアプリ全体が英語のみ**で、catalog は
   「抽出できる状態」であって翻訳の実体は無い。フレーズだけ訳す形では成立しない

### 対象外と決めたもの

- **Apple Intelligence 統合（FoundationModels）** — `GenerateTodosIntent` のような LLM 前提の Intent、
  および `SpotlightSearchTool` + `LanguageModelSession` による会話型検索は **#52 でスコープ外に決着**。
  前提となる Spotlight への entity 寄付は済んでいるが、残りの作業主体が App Intents から離れ、
  本リポジトリが示したい「App Intents を設計の中心に据えるとどう組み立てられるか」に寄与しない
- **UI タップ由来の donation** — #53 で不採用（「UI も `Button(intent:)` で Siri と同じ経路を通す」原則を崩す）
- **`.foreground(.dynamic)` / `continueInForeground`** — #55 で「適所なし」と結論

## SwiftUI, Swiftなどについて

- docs/referencesに最新の知識を置いておくので、そちらをまず見ること
- その上でわからないことはWeb検索し、なるべく最新のベストプラクティスに従うこと

## 参考資料

- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - 設計思想の背景
- [Action-Centered Design](https://blog.viditb.com/action-centered-design/) - Vidit Bhargavaによるフレームワーク
- [App Intent Driven Development](https://www.avanderlee.com/swift/app-intent-driven-development/) - SwiftLeeによる実装ガイド
