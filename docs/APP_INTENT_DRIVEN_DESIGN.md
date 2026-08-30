# App Intent Driven Design - 概念整理

このドキュメントでは、App Intents中心の設計思想に関連する外部の概念を整理し、本リポジトリの思想との比較を行います。

## 目次

1. [概念の概要](#概念の概要)
2. [App Intent Driven Development (SwiftLee)](#app-intent-driven-development-swiftlee)
3. [Action-Centered Design Framework (Vidit Bhargava)](#action-centered-design-framework-vidit-bhargava)
4. [モデルベースUIデザインとユースケース中心設計](#モデルベースuiデザインとユースケース中心設計)
5. [MVI (Model-View-Intent) Architecture](#mvi-model-view-intent-architecture)
6. [本リポジトリの思想との比較](#本リポジトリの思想との比較)
7. [Layered / Clean Architecture との対比](#layered--clean-architecture-との対比)
8. [参考リンク](#参考リンク)

---

## 概念の概要

App Intentsを中心とした設計アプローチには、いくつかの異なる視点からの概念が存在します。

| 概念名 | 提唱者/出典 | 主な焦点 |
|--------|-------------|----------|
| App Intent Driven Development | Antoine van der Lee (SwiftLee) | コード再利用とシステム統合 |
| Action-Centered Design | Vidit Bhargava | UXデザインとマルチプラットフォーム |
| モデルベースUIデザイン | usagimaru理論 | ユースケース中心設計とIntent/Entityの写像 |
| MVI Architecture | Hannes Dorfmann (Android) | 状態管理と単方向データフロー |

---

## App Intent Driven Development (SwiftLee)

### 定義

Antoine van der Leeによって提唱されたアプローチで、**アクションやデータを最初からAppIntentプロトコルで定義する**開発手法です。

### 核心的な考え方

> "By defining actions as app intents by default, you allow them to be connected to any system-service in the future."

- **デフォルトでApp Intentとして定義**: 将来的なシステムサービス接続を見据えた設計
- **再利用性の強制**: AppIntentプロトコルとAppEntityプロトコルを使用
- **柔軟な拡張性**: 現時点でシステム連携が不要でも、将来に備えた構造化

### 技術的アプローチ

```swift
// EntityQuery実装による再利用
struct WidgetFavoritesGroupQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetFavoritesGroup] { ... }
    func suggestedEntities() async throws -> [WidgetFavoritesGroup] { ... }
    func defaultResult() async -> WidgetFavoritesGroup? { ... }
}
```

- ウィジェット設定用のIntentを定義
- メインアプリケーションで同じクエリロジックを活用
- ViewModelで`suggestedEntities()`を呼び出して一覧を生成

### 統合対象

- Shortcuts
- Siri
- Spotlight
- Action Button
- ウィジェット

### メリット

- コード重複の排除
- システムサービス対応の将来性確保
- テストと保守性の向上
- 一度定義したIntentを複数の文脈で活用

### デメリット

- 初期設計の複雑性増加
- 小規模アプリではオーバーエンジニアリングの可能性
- AppEntity・EntityQuery実装の追加作業

---

## Action-Centered Design Framework (Vidit Bhargava)

### 定義

デザイナー・開発者のVidit Bhargavaが提唱するフレームワークで、**アクションと情報を中心にアプリを設計する**アプローチです。

### 核心的な考え方

> "アプリは情報へのアクセスとプロセス実行を支援する**アクションのクラスター**"

従来のプラットフォーム中心の考え方から脱却し、アクションを原子単位として捉えます。

### 設計プロセス

1. **4つの基本質問から開始**:
   - 対象ユーザーは誰か
   - どの問題を解決するか
   - 目的は何か
   - どのコンテンツを含むか

2. **最小単位から設計**:
   - ウォッチなど最も小さなスクリーンから開始
   - 必須要素に焦点を当てる

3. **プラットフォーム固有へ拡張**:
   - 毎日確認する情報 → ウィジェット
   - 頻繁に変わる情報 → watchOSコンプリケーション
   - 繰り返しのアクション → ショートカット/Siri
   - 常時追跡情報 → ライブアクティビティ

### App Intentsとの関係

> "AppIntents allow developers to break down their app's actions into small chunks that can run independently but are also flexible enough to interface with other applications, much like lego bricks."

- **AppIntents** = アクション（レゴブロックのような独立した実行単位）
- **AppEntities** = 情報（検索可能なデータ）

### Apple Intelligenceとの関連

Apple Intelligenceは「アクションと情報を個別化された体験に統合する」概念を体現しており、Action-Centered Designの実装例と位置づけられています。

### 特徴

- UX/デザイン視点からのアプローチ
- マルチプラットフォーム対応を前提
- Apple Intelligenceとの親和性を重視

---

## モデルベースUIデザインとユースケース中心設計

### 定義

usagimaruによる理論的フレームワークで、**「誰が何を行動できる」という構造**を中心にUIを設計するアプローチです。

### 核心的な考え方

ユースケース中心設計は以下の構造で表現されます：

```
「誰が」（Actor/Entity） + 「何を」（Object/Entity） + 「行動できる」（Action/Intent）
```

この構造はApp IntentsのEntity-Intentモデルに**直接写像**できます：

| ユースケース要素 | App Intents要素 | 例 |
|----------------|----------------|-----|
| 誰が（Actor） | Entity | User, TodoItem |
| 何を（Object） | Entity | TodoItem, Category |
| 行動できる（Action） | Intent | AddTodoIntent, DeleteTodoIntent |

### App Intentsとの自然な対応

```swift
// ユースケース: 「ユーザーが」「Todoを」「追加できる」
struct AddTodoIntent: AppIntent {
    @Parameter(title: "Title")
    var title: String  // 「何を」

    func perform() async throws -> some IntentResult {
        // 「行動できる」の実装
    }
}
```

### Liquid Glass時代との関連

> UIクローム（装飾）が透明化し背景に溶け込む時代において、**コンテンツとアクションが本質**となる。

- UI、アプリ、デバイスの境界が曖昧化
- **アクション/情報へのアクセスが本質**として残る
- Intent定義に注力することで、Apple Intelligenceとの統合が自然に実現

### 特徴

- デザインと実装の間に**自然な対応関係**が生まれる
- ユースケース図がそのままIntent定義のガイドになる
- デザイナーとエンジニアの共通言語となりうる

### 参考

- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents)

---

## MVI (Model-View-Intent) Architecture

### 定義

Hannes Dorfmannによって提唱された（主にAndroid向けの）アーキテクチャパターンで、**単方向データフロー**を特徴とします。

### 核心的な考え方

```
User Action → Intent → Model → View → User sees change
```

> "No shortcuts. No backdoors. Completely predictable."

### コンポーネント

| コンポーネント | 役割 |
|---------------|------|
| Model | アプリケーションの状態を表現 |
| View | 状態を表示し、ユーザー入力を受け取る |
| Intent | 状態を変更するイベント（ユーザー操作など） |

### SwiftUIでの実装

```swift
// MVI Store
class Store<State, Intent> {
    @Published private(set) var state: State

    func send(_ intent: Intent) {
        // IntentをModelに反映
    }
}
```

### 注意点

**MVI の "Intent" と Apple の "AppIntent" は別概念です。**

- MVI Intent: 状態変更を表すイベント/アクション
- AppIntent: Appleのシステムサービスと連携するためのプロトコル

### メリット

- 予測可能な状態遷移
- デバッグの容易さ
- テスト性の向上

### デメリット

- シンプルなCRUD操作には過剰
- 学習コストが高い

---

## 本リポジトリの思想との比較

### IntentTodoの設計思想（再掲）

```
Packages/
├── Domain/           # SwiftDataモデル、共通Entity
├── Repository/       # データアクセス層（Protocol + 実装）
├── TodoAppIntents/   # ★コア：Intent定義（宣言）+ TodoService（実装）
└── UI/ WidgetUI/ WatchUI/ LiveActivity/   # 表示側の葉ノード（表示のみ）
```

- **全てのアクションはApp Intentとして定義**
- **独立したUseCase層パッケージを作らない** → 宣言はIntent、実装は`TodoService`に分かれる（[後述](#layered--clean-architecture-との対比)）
- **Button(intent:)で直接実行** → ロジックの二重実装を避ける

### 比較表

| 観点 | IntentTodo | App Intent Driven Dev | Action-Centered Design | MVI |
|------|------------|----------------------|------------------------|-----|
| **主目的** | ロジック一元化 | コード再利用・システム統合 | UXデザイン・マルチプラットフォーム | 状態管理 |
| **App Intentsの役割** | ユースケースの公開契約（宣言）。実装は `TodoService` | 再利用可能なアクション定義 | アクションの原子単位 | 関係なし |
| **UseCase層** | 層としては解体（宣言=Intent / 実装=Service） | 言及なし | 言及なし | 別途必要 |
| **Button(intent:)** | 必須 | 推奨 | 言及なし | 関係なし |
| **対象** | アーキテクチャ全体 | Intent定義のベストプラクティス | 設計プロセス全体 | 状態管理のみ |

### 共通点

#### IntentTodo と App Intent Driven Development

1. **App Intentsをデフォルトの実装手段とする**
   - 両者ともApp Intentsをオプションではなく、基本的な実装方法として位置づけ

2. **再利用性の重視**
   - システムサービス連携を見据えた設計
   - コード重複の排除

3. **EntityQueryの活用**
   - データ取得ロジックの一元化
   - ウィジェット・メインアプリでの共有

#### IntentTodo と Action-Centered Design

1. **アクション中心の設計思想**
   - アプリを「アクションのクラスター」として捉える点で一致

2. **マルチプラットフォーム対応**
   - ウィジェット、Shortcuts、Siriなど複数の接点を想定
   - **Action-Centered Designの展開指針を採用**: アクション/情報の特性に応じた展開先の決定

3. **Apple Intelligenceへの対応**
   - 将来的なAI統合を見据えた設計

#### IntentTodo と モデルベースUIデザイン

1. **ユースケースとIntentの写像**
   - 「誰が何を行動できる」= Entity-Intentモデル
   - デザインと実装の間の自然な対応関係

2. **Liquid Glass時代の設計観**
   - コンテンツとアクションが本質
   - UIクロームへの投資より、Intent定義に注力

### 差分・独自性

#### IntentTodo独自の特徴

1. **UseCase層を「層」として持たない**
   - 他の概念では言及されていない
   - UseCaseの**宣言**（名前・入力・出力）をApp Intentが、**実装**（手続き・不変条件・副作用）を`TodoService`が受け持つ形に分かれる（[後述](#layered--clean-architecture-との対比)）

2. **Button(intent:)の必須化**
   - UIからのアクション実行は必ずIntent経由
   - ロジックの二重実装を構造的に防止

3. **ViewModelの役割限定**
   - ViewModelは「表示のみ」に限定
   - ビジネスロジックはApp Intentsに集約

4. **明確なパッケージ構成**
   - レイヤー（Domain / Repository / TodoAppIntents）+ **表示先別の葉ノード**（UI / WidgetUI / WatchUI /
     LiveActivity）という 2 軸で 7 パッケージ。葉ノードは互いに依存しない
   - 各層の責務が明確（詳細: [insights/01-swift-package-design.md](insights/01-swift-package-design.md)）

#### 統合された独自性

IntentTodoは以下の概念を**統合**しています：

| 取り入れた概念 | 出典 | IntentTodoでの活用 |
|--------------|------|-------------------|
| デフォルトでIntent定義 | App Intent Driven Dev | UseCase層パッケージを持たず、Intentがユースケースの宣言を担う |
| アクション中心の設計 | Action-Centered Design | アプリ=アクションのクラスターという思想 |
| プラットフォーム展開指針 | Action-Centered Design | 特性に応じた展開先マトリクス |
| ユースケースとの写像 | モデルベースUIデザイン | Entity-Intentモデルとデザインの対応 |
| Liquid Glass時代の設計観 | モデルベースUIデザイン | コンテンツとアクションが本質 |

### 結論

IntentTodoの「App Intents中心設計」は、以下の点で独自の立場を取っています：

1. **概念の統合**: App Intent Driven Development、Action-Centered Design、モデルベースUIデザインを統合
2. **より徹底したIntent中心主義**: UseCase層をパッケージとして持たず、App Intentsをユースケースの公開契約として位置づける
3. **実装レベルの具体性**: Button(intent:)の必須化など、実装方法を明確に規定
4. **アーキテクチャ全体の再構成**: 従来のClean Architectureを、App Intents前提で再設計
5. **マルチプラットフォーム展開指針**: Action-Centered Designの考え方を採用

これは、複数の設計思想を参考にしつつ、**デザインから実装まで一貫した思想**を持つ独自のアーキテクチャと言えます。

---

## Layered / Clean Architecture との対比

「App Intents 中心設計」を Layered / Clean Architecture の語彙で説明しようとすると、**同心円の図がうまく描けない**。
以下はその理由と、代わりに使う整理。

### なぜ同心円に収まらないのか

Clean / Layered の図が成立しているのは、レイヤーが**1 本の軸（依存方向 = 抽象 ← 具体）だけ**で切られているから。
同心円は「層の順序が一意に決まる」ことに全面的に依存している。

App Intents 中心設計はそこに別の軸を持ち込む。

| | Clean Architecture | App Intents 中心 |
|---|---|---|
| 切っている軸 | 抽象度・依存方向 | **誰が呼ぶか（呼出面）** |
| 最外周の想定 | Presentation は「自分が書くドライバ」1 個 | UI / Siri / Spotlight / Widget / Control / Live Activity / 他アプリ の **N 個。しかも能力が違う** |
| 境界の性質 | 内部の継ぎ目（自由にリファクタできる） | **公開契約**（ユーザーのショートカットに焼き付く） |

軸が 2 本あるものを同心円 1 枚に押し込もうとしているので、`AppIntent` の置き場所が決まらない。
実際 `AppIntent` は Clean Architecture の語彙では 3 役を同時に担っている。

- **Controller**（入力アダプタ）: `@Parameter`、`EntityQuery` による解決、曖昧性解消
- **Presenter**（出力）: `IntentDialog` / Snippet / `DisplayRepresentation`
- **UseCase の入力ポート**（名前と signature、= ユースケースの同一性）

そして「UseCase の本体（手続き）」だけは `AppIntent` に入っていない。それが `TodoService`。

> **言い方の基準**: 「UseCase 層を廃止した」ではなく **「UseCase の宣言が Intent に、実装が Service に分かれた」**。
> `Packages/` に `UseCase/` が無いのは層が消えたからではなく、宣言側が `TodoAppIntents/Intents/`、
> 実装側が `TodoAppIntents/Services/TodoService.swift` に同居しているから。

### 対応表

| Clean Architecture | 本プロジェクトの実体 |
|---|---|
| Entity | `Domain`（`@Model TodoItem` / `Category` / `SubTask`） |
| UseCase の**宣言**（入力ポート・名前・引数） | `AppIntent` 型 + `@Parameter`（`ToggleTodoCompletionIntent` 等） |
| UseCase の**実装**（interactor の中身） | `TodoService` のメソッド（`toggleCompletion` / `snooze` / `toggleMostUrgentTodo`） |
| Controller | `perform()` の前半 + `EntityQuery` |
| Presenter / ViewModel | `IntentDialog` / Snippet / `DisplayRepresentation` / SwiftUI View |
| Gateway（Repository interface） | `TodoRepositoryProtocol` |
| DB / Framework | `SwiftDataTodoRepository`（+ `MockTodoRepository`） |

### 図は同心円ではなく砂時計（bowtie）にする

同心円は「リング」を強調するが、この設計の主張は**くびれ**なので形が合わない。

```
 UI  Siri  Spotlight  Widget  Control  LiveActivity  他アプリ   ← 呼出面（対等・能力が違う）
  \    \      |         |        |          /          /
   ────────── Intent + Entity ──────────                      ← くびれ = 公開契約（最も凍る）
                    │  ┊
              TodoService  ┊                                  ← 1 行為の不変条件・副作用
                    │      ┊ ← 読み取り（EntityQuery）は直通
           TodoRepositoryProtocol
                    │      ┊
              SwiftData / CloudKit
```

この形にすると、同心円では言えなかったことが 2 つ言える。

- **UI は特権的な最上層ではなく、Siri と対等な呼出面の一つ**（`Button(intent:)` を必須にしている理由が図から出る）
- **呼出面ごとに能力が違う**（Control は dialog も snippet も出ない / `requestConfirmation` はアプリ内 `Button(intent:)` から呼べない）。
  同心円だと「外側は全部同じ Presentation」に見えてしまい、この差が図から消える

### コードの置き場を決める 3 つの判定

図を「使える」ものにするのはこの判定ルール。

1. **ユーザーやシステムが名前で呼べる行為か** → Intent（宣言）
2. **「1 行為の完了」に紐づく不変条件・副作用があるか** → `TodoService`
3. **1 レコードの永続化の言い換えか** → Repository

よくある Layered の説明が「UseCase と Repository の使い分けが分からない」と言われるのは、例として
`createTodo()` → `repository.create()` という**素通し**を出してしまうから。素通しだけ見せると
「なぜ 2 段あるのか」に答えられない。差が出る実例で説明する。

| `TodoService` にあって Repository に置けないもの | 理由 |
|---|---|
| `toggleMostUrgentTodo()` | fetch + mutate の 2 呼び出しが、ユーザーには**1 行為** |
| `snapshot()` / `restore()` | 「**同じ id で**戻す」という undo の不変条件。Repository は id の意味論を知らない |
| `snooze()` | dueDate 計算 + Live Activity の更新。永続化の外側 |
| `dataDidChange()`（`WidgetReloader` + `AppShortcutParameterUpdater`） | **「1 行為が完了した」ことを知っているのは UseCase 層だけ**。Repository の `update()` は自分が行為の途中か終端か判別できない |

最後の `dataDidChange()` が、この継ぎ目が存在する理由の**単独で最も強い論拠**。
「トランザクション / 通知の境界 = UseCase の境界」は Clean Architecture でもそのまま通じる説明なので、対比として噛み合う。

### Clean Architecture と本質的に反転している 2 点

1. **凍る方向が逆**。Clean Architecture は「内側 = 安定した方針、外側 = 揺れる詳細」。
   App Intents 中心では、外周の Intent 型名・parameter 名・`AppEnum` の raw value が
   **ユーザーのショートカットに永続化されていて最もリファクタできない**。内側の `TodoService` のほうが自由に触れる。
2. **依存逆転の目的が違う**。Clean Architecture の「DB を差し替えられる」はほぼ使われない口実だが、
   ここでは `TodoRepositoryProtocol` が**プロセス境界**で効く（`allowedExecutionTargets`、
   Widget Extension とメインアプリで同じロジックが別プロセスに載る）。層の対価が実際に回収されている。

### 正直に残る非対称（読み取りは層を貫通する）

`TodoEntityQuery` / `CategoryEntityQuery` / `SubTaskEntityQuery` などの読み取り経路は
`@Dependency var modelContainer` で **`TodoService` も Repository も飛ばして**ストアに直接到達する。
書き込み経路は必ず `TodoService` を通る。

つまり実態は **書き込み側だけ層が厚い CQRS 的な非対称**。図でも「読みは細い直通線、書きは Service 経由」と
分けて描く。理由は「読み取り系 Intent は `allowedExecutionTargets` を固定せず Extension プロセスで応答させたい
（アプリを起こす起動コストを避けたい）」ため（詳細: [insights/03-app-intents-core.md](insights/03-app-intents-core.md)）。
同心円 1 枚だとこの線が引けないのも、砂時計にする理由のひとつ。

---

## 参考リンク

### 主要リソース

- [App Intent Driven Development in Swift and SwiftUI - SwiftLee](https://www.avanderlee.com/swift/app-intent-driven-development/)
- [Action-Centered Design - Vidit Bhargava](https://blog.viditb.com/action-centered-design/)
- [Apple Intelligence: Action Centered Design Framework - Matthew Cassinelli](https://matthewcassinelli.com/apple-intelligence-action-centered-design-framework-feat-vidit-bhargava/)
- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - モデルベースUIデザインとの関係

### Apple公式ドキュメント

- [App Intents | Apple Developer Documentation](https://developer.apple.com/documentation/appintents)
- [Integrating actions with Siri and Apple Intelligence](https://developer.apple.com/documentation/appintents/integrating-actions-with-siri-and-apple-intelligence)
- [Making actions and content discoverable and widely available](https://developer.apple.com/documentation/appintents/making-actions-and-content-discoverable-and-widely-available)
- [Get to know App Intents - WWDC25](https://developer.apple.com/videos/play/wwdc2025/244/)
- [Bring your app's core features to users with App Intents - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10210/)

### 関連記事

- [How to Future-Proof Your iOS App With App Intents - Heady](https://www.heady.io/blog/app-intents-apple-intelligence)
- [MVI Architecture in SwiftUI - DEV Community](https://dev.to/swift_pal/mvi-architecture-in-swiftui-a-complete-guide-to-model-view-intent-pattern-2025-4c8)
- [MVI Architecture for SwiftUI - Better Programming](https://betterprogramming.pub/mvi-architecture-for-swiftui-apps-cff44428394)
