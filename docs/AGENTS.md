# App Intents 中心設計ガイド

このプロジェクトが採用している設計の**考え方**と、実装時に毎回確認する条件。
API ごとの書き方は [insights/](INSIGHTS.md)（このリポジトリ固有の知見）と
[skills/](../skills/README.md)（他プロジェクトでも使える形にまとめた 8 本）にある。

## 設計思想の背景

| 概念 | 出典 | 本設計での活用 |
|------|------|--------------|
| **App Intent Driven Development** | SwiftLee | コード再利用とシステム統合の基盤 |
| **Action-Centered Design** | Vidit Bhargava | マルチプラットフォーム展開指針 |
| **モデルベース UI デザイン** | 書籍 / 社内研修由来 | ユースケースと Intent の写像 |

### アプリ = アクションのクラスター

> アプリはプラットフォームに縛られない「アクションと情報の集合体」である。

- **Intent（動詞）** = ユースケースの「行動できる」
- **Entity（名詞）** = ユースケースの「誰が」「何を」

Apple 自身が同じ言い方をしている（"They're the commands, or verbs, in your app." /
"Entities are objects … They're the nouns." — wwdc2024-10210 `7:23`）。
デザイン（ユースケース定義）と実装（Intent 定義）の間に**自然な写像**が生まれるのがこの設計の要点で、
「誰が何を行動できる」で棚卸ししたものが、そのまま Entity + Intent になる。

### Liquid Glass 時代の設計観

UI クローム（装飾）が透明化し背景に溶け込む時代には、**コンテンツとアクションが本質**になる。
標準 UI で足りるぶん、カスタムスタイリングへの投資を Intent 定義に振り替えると、
Apple Intelligence との統合が副産物として付いてくる。

## 従来設計との比較

```
【従来の MVVM】
View → ViewModel → UseCase → Repository → Domain
                    ↑
              ビジネスロジック

【App Intents 中心】
View  ─┐
Siri  ─┼→ Intent → Service → Repository → Domain
Widget─┤    ↑         ↑
Control┘   宣言    ビジネスロジック
       (呼出面は対等。UI はその一つに過ぎない)
```

**UseCase 層は「廃止」ではなく分裂している。** ユースケースの**宣言**（名前・引数・戻り値）を
`AppIntent` が、**実装**（手続き・不変条件・副作用）を `TodoService` が受け持つ。
Layered / Clean Architecture との対応表・砂時計図・置き場の判定ルールは
[APP_INTENT_DRIVEN_DESIGN.md](APP_INTENT_DRIVEN_DESIGN.md#layered--clean-architecture-との対比)。

### 核心原則

1. **すべてのアクションを Intent として定義する**
2. **Intent がユースケースの公開契約の Single Source of Truth**（実装の置き場は `TodoService`）
3. **UI は Intent 実行のトリガーと結果表示のみ**（`Button(intent:)` が唯一の実行経路）
4. **ロジックの二重実装を排除する**
5. **アクションと情報が設計の原子単位**。UI やプラットフォームは二次的

### 設計プロセス

1. **最小のスクリーンから設計を始める**（Apple Watch など、最も制約の厳しい面で本質的なアクションを特定）
2. **アクションを Intent 化する**
3. **プラットフォーム固有の実装へ拡張する**（展開マトリクスは [PLAN.md](PLAN.md#展開マトリクス)）
4. **メインアプリの UI は最後**（複数のアクションをクラスター化して画面を設計）

> これは**設計の順序で、実装の順序ではない**。届ける順序は「Shortcuts から呼べる Intent 1 本 →
> そのアクションに見合う面を 1 つ」から始める。

## 実装時に確認すること

> タスク管理ではなく**実装時に毎回目を通す条件**。未完了タスクは issue 側に置く。

**Intent**

- `@MainActor` を `perform()` に付与（`TodoService` が `@MainActor`）
- ビジネスロジックは `TodoService` に置き、Intent は接続点に薄く保つ
- 適切な `IntentResult` 型を返却。エラーは `IntentError`（`CustomAppIntentErrorConvertible`）
- **SwiftData を書き換えるなら `allowedExecutionTargets = [.main]`**（`IntentExecutionTargetsTests` が検出）
- **Intent が変えられるパラメータは全部 `parameterSummary` に載せる**（載せないと Shortcuts から設定できない）
- 破壊的 / 不可逆なら `UndoableIntent` + `TodoUndoRegistrar`
- 内部用なら `isDiscoverable = false`。`requestConfirmation` / `requestChoice` を含むなら UI から呼ばない
- **1 アクション 1 Intent**。分けてよいのは振る舞いが違うときだけ（呼出元の都合では分けない）

**AppEntity**

- `id` は**起動・デバイスをまたいで安定**していること
- `typeDisplayRepresentation` / `displayRepresentation` / `defaultQuery` を実装
- 実行時の値は `"\(value)"` の補間形式で渡す（`LocalizedStringResource(stringLiteral:)` は使わない）
- システムに見せる属性は `@Property`（素の `var` はどこからも見えない）
- Spotlight 対応なら `IndexedEntity` + `@Property(indexingKey:)`。`attributeSet` との**二重書きを避ける**
- 人が読む文字列の突き合わせは `localizedStandardContains(_:)`

**App Shortcuts**

- **`AppShortcutsProvider` はアプリターゲット直下**（パッケージに置くと `autoShortcuts: 0` で無言に壊れる）
- String 型パラメータはフレーズに埋め込まない（`AppEntity` / `AppEnum` のみ）
- `shortTitle` と `systemImageName` を設定。パラメータ無しのフレーズも 1 つ残す
- `AppShortcutsProvider` は 1 つだけ。パラメータ入りフレーズには `updateAppShortcutParameters()` の配線が必要
- 登録済み Intent の `@Parameter` に system value 型（`PlaceDescriptor` 等）を置かない（SDK バグ / FB24548956）

**確認の手段**

- ビルドの成否は根拠にならない。`inspect_appintents_metadata.py` でシステムが読むメタデータを直接見る
- 「どの面が何を提示するか」は**呼出元だけ変えて同じ Intent を走らせて**確定させる（推論しない）
- 手で確かめる前に、[TESTING.md](TESTING.md) の 3 層のどこに載るかを検討する

## 詳しくはどこを見るか

| 知りたいこと | 見る場所 |
|---|---|
| このリポジトリでの実装形と落とし穴 | [insights/](INSIGHTS.md)（7 トピック） |
| 他プロジェクトでも通じる書き方・症状からの逆引き | [skills/](../skills/README.md)（8 本） |
| API ごとの採用 / 不採用の状態 | [APP_INTENTS_API_COVERAGE.md](APP_INTENTS_API_COVERAGE.md) |
| なぜ今の形になったか（調査・失敗の記録） | [devlog/](devlog/README.md) |

## 参考資料

- [Apple: App Intents](https://developer.apple.com/documentation/appintents)
- [Apple: Making your app's functionality available to Siri](https://developer.apple.com/documentation/appintents/making-your-app-s-functionality-available-to-siri)
- セッション別の API 一覧と非推奨タイムライン: [WWDC_APP_INTENTS_SESSIONS.md](WWDC_APP_INTENTS_SESSIONS.md)
- [Action-Centered Design - Vidit Bhargava](https://blog.viditb.com/action-centered-design/)
- [App Intent Driven Development - SwiftLee](https://www.avanderlee.com/swift/app-intent-driven-development/)
- [Liquid Glass と App Intents 中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents)
