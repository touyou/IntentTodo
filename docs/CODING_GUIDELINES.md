# コーディング規約

Swift / SwiftUI の書き方について、このリポジトリで守っているルールと理由。
App Intents 固有のルールは [insights/](INSIGHTS.md) と [skills/](../skills/README.md) 側にある。

## 準拠する外部ガイドライン

- **SwiftLint 必須**。ルールはルートの `.swiftlint.yml`。CI / ビルド時に自動チェックする
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — 命名は
  明確さ優先、メソッド名は副作用に基づいて（mutating は動詞 / non-mutating は名詞）、パラメータ名は
  ドキュメントとして機能させる
- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/) — 標準コンポーネントを
  素直に使い、アクセシビリティとプラットフォーム慣習に沿う

## Swift / SwiftUI の必須ルール

- `@Observable` クラスには必ず `@MainActor` を付ける
- Strict Swift Concurrency を適用する
- `ObservableObject` は使わない → `@Observable`
- `NavigationView` は使わない → `NavigationStack`
- `foregroundColor()` は使わない → `foregroundStyle()`
- GCD は使わない → Swift Concurrency
- Combine は使わない → async / await 版の API を使う

## SwiftUI のベストプラクティス

- View にロジックを書かない。UI 状態は ViewModel、ビジネスロジックは `TodoService`（Intent 経由）
- コンポーネントはデータ単位で分割して、再レンダリング範囲をその View に閉じる
- **computed property で View を分割しない** → 新しい `View` struct を作る。
  computed property / `some View` を返す method は差分追跡の単位にならず、親の `body` 全体が再評価される
- `GeometryReader` より `containerRelativeFrame()` / `visualEffect()` を優先
- `AnyView` は必要最小限に

分割の実例（`TodoDetailView` を 7 つの private struct に割った形）と Formatter の共有方針:
[insights/04-ui-integration.md](insights/04-ui-integration.md#view-は-struct-抽出computed-property-view-は避ける)

## UI コピーは `LocalizedStringResource` で運ぶ

**文言を `String` 型のプロパティ / パラメータで運ばない。** `Text` / `Label` は `String` を渡すと
verbatim 初期化子を選ぶため、リテラルが String Catalog に**抽出されない**（`todo.title` のような
データの verbatim 表示は対象外）。

- UI コピーを持つパッケージ（`UI` / `WatchUI` / `WidgetUI` / `LiveActivity`）は自前の catalog を
  同梱しているので、**必ず各パッケージの `LocalizedStringResource.copy(_:)` を通す**
  （`Text(.copy("Cancel"))`）。SwiftUI の `Text("Cancel")` 形は実行時に `Bundle.main` を引くため、
  素のリテラルでは catalog に載っても実行時に引けない
- `\(date, style: .relative)` のような `LocalizedStringKey` 専用の補間だけは
  `Text("...", bundle: .module)` 形で書く。数値だけの表示は `Text(value, format: .number)`
- **`TodoAppIntents` は catalog を持たない**（持たせても引かれない）。Intent のコピーはリンク先
  ターゲットの main bundle から引かれるので `.copy(_:)` を使わない
- **文言を足したら 12 catalog 全部を埋める**（ソース言語 en / 訳 ja）。共有 Intent コピーは
  6 catalog に重複して現れるので、1 箇所だけ直すと呼出元によって言い回しが変わる形で壊れる
- `project.pbxproj` を直接編集しない。言語追加や catalog のターゲット追加は
  `xcode-integration:translation-coordinator` スキル経由の `LocalizationPlanner` にやらせる

抽出のされ方 / されなさ、Intent コピーの手動キー運用、検査スクリプト:
[insights/04-ui-integration.md](insights/04-ui-integration.md#spm-パッケージの-ui-コピーと-string-catalog) /
[insights/03-app-intents-core.md](insights/03-app-intents-core.md#intent-のコピーはどこから引かれるか) /
[skills/app-intents-localization](../skills/app-intents-localization/SKILL.md)

## SwiftData（CloudKit 使用時）

[Apple 公式: Define a CloudKit compatible schema](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices#Define-a-CloudKit-compatible-schema) より:

- `@Attribute(.unique)` は CloudKit では enforce されない（`#Unique<T>` マクロも同じメカニズム）
- リレーションシップはすべて optional。DeleteRule の `.deny` もサポート外
- プロパティはデフォルト値を持つか optional にする（同期時のコンフリクト対策）

**ビルドが通っても実行時に trap する 2 件**（`Calendar.RecurrenceRule` を属性にできない /
削除済みオブジェクトの配列属性は読めない）と `didSet` を使わない理由:
[insights/02-swiftdata-concurrency.md](insights/02-swiftdata-concurrency.md)

## コード内コメント（経緯は書かない）

ドキュメントと同じ切り分けをコードにも適用する（[ドキュメント運用](../AGENTS.md#ドキュメント運用)）。

- **書く**: なぜこの形なのかという**現在の理由**、非自明な制約、公式ドキュメント / WWDC セッションの
  引用（`wwdc2026-345 16:30` のように位置まで）
- **書かない**: 調査の経緯、失敗した仮説、「以前は〜していたが」「かつては〜」という履歴。
  これらは `docs/devlog/` に書く
- 経緯を追えるようにするため、代わりに**ポインタを 1 行**置く:
  `経緯: docs/devlog/03-app-intents-core.md（2026-08-21 の …）`
- 現在のルールの詳しい説明が insights にあるなら `詳細: docs/insights/03-app-intents-core.md` を置き、
  コード側は要約に留める（同じ説明を 2 箇所で腐らせない）

```swift
// ❌ 経緯がコードに漏れている
// 以前は CSSearchableIndex.default() を使っていたが、公式が prototyping 専用と
// 言っているのに気づいたので 2026-08-21 に名前付きへ移した。

// ✅ 現在の理由 + ポインタ
/// 名前付き index を使う。公式: "use a named `CSSearchableIndex` type and not the
/// default index. Use the default index only for prototyping and testing".
/// 経緯: docs/devlog/03-app-intents-core.md（2026-08-21 の default index からの移行）
```
