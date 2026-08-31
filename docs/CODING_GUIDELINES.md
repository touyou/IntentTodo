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

## コード内コメント

**コメントは英語で書く**（App Intents 中心設計の参考実装として公開しているため。ドキュメントは日本語）。
**実装中・コードリーディング中に本当に必要な情報だけ**を残し、それ以外はドキュメント側に置く。

**書く**

- **なぜこの形なのか**という現在の理由。とくに「自明な書き方をすると壊れる」もの
- 非自明な制約と、公式の一次情報。引用は位置まで添える: `[Apple: wwdc2026-345 16:30]`
- 公開 API の `///`（型・メソッドの契約）と `// MARK:`（構造のナビゲーション）

**書かない**

- **ドキュメントへのリンク**（`詳細: docs/insights/...` / `経緯: docs/devlog/...`）。
  ドキュメントはドキュメントとして読む。コードから docs へ誘導すると、リンク先が動いたときに
  黙って腐るうえ、コメントを読む文脈（実装中）では開かない
- **履歴**（「以前は〜」「旧実装は〜」「2026-08-12 に切り替えた」）。今の形の理由だけを書く。
  経緯は `docs/devlog/`
- **将来の計画**（「必要になったら〜を足す」）。決めたなら issue、決めていないなら書かない
- **コードの言い換え**。`// 追加ボタン` のような行、引数名を繰り返すだけの `///`
- 調査の分量に見合わせた長い説明。3 行で足りるものを 20 行書かない

```swift
// ❌ 履歴 + ドキュメントへの誘導 + 分量
// 以前は CSSearchableIndex.default() を使っていたが、公式が prototyping 専用と
// 言っているのに気づいたので 2026-08-21 に名前付きへ移した。移行時は旧 index に
// 残ったアイテムが二重に出るので初回起動で 1 度だけ掃除している。
// 詳細: docs/insights/03-app-intents-core.md

// ✅ 現在の理由だけ、英語で
/// Named, not the default index. Apple: "use a named `CSSearchableIndex` type and not the
/// default index. Use the default index only for prototyping and testing".
```
