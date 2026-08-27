# 開発ログ: App Intents 中心設計 検証計画

`docs/APP_INTENTS_CENTRIC_PLAN.md` の状態が、どういう経緯で今の形になったかを記録する（SDK バージョン追従の顛末など）。

## 2026-06-10: reminders 本体スキーマ適合を保留 — マクロ生成 init が入れ子サブエンティティを要求

Phase 2 で App Schema (reminders) を検証中、`CategoryAppEntity` → `.reminders.list` / `TodoListType` →
`.reminders.listType` は適合できたが、コアの `TodoAppEntity` → `.reminders.reminder` は保留にした。
probe 検証の結果、reminder スキーマはマクロ生成 init が `EntityProperty<T>` 引数を取り、さらに
`section` / `locationTrigger` 等の入れ子サブエンティティを再帰的に要求することが判明。モデル（`TodoItem`）
から組み立てる自前 init と相性が悪く深掘りが必要と判断し、reminder 本体適合は独立タスクとして据え置いた。
list 階層での適合で App Schema の仕組み自体は検証済み。

## 2026-06-10: RelevantEntities は Todo ドメインに適合する AppEntityContext が無く不適合と結論

Phase 3 で `RelevantEntities.updateEntities(_:for:)` / `AppEntityContext` を検証したが、当時 API から
提供されている `AppEntityContext` は `.audio(...)` などドメイン固有の overlay context のみで、
todo/reminders 向けの context が存在しないと判明。「次の期限/緊急 Todo を文脈寄付する」という当初の
検証目標は達成不能と結論し 🚫 不適合として記録した。

## 2026-07-01: Xcode 27 beta 2 で watchOS の assistant schema が unavailable に → フォールバック追加

beta 2 で `reminders` / `system` ドメインの App Intents assistant schema が watchOS で unavailable に
なり、`TodoAppIntents`（watchOS でもコンパイルされる）のビルドが失敗するようになった。`CategoryAppEntity`
（`.reminders.list`）と `TodoListType`（`.reminders.listType`）はマクロ付き宣言を `#if` で分割できないため、
`#if os(watchOS)` で型を2系統に全書きして素の `AppEntity`/`AppEnum` にフォールバックし、
`ShowTodoSearchResultsIntent`（`.system.search`）は遷移先が watchOS に無いため `#if !os(watchOS)` で
丸ごと除外した（`9684418`）。watchOS は元々 Siri/Apple Intelligence のスキーマルーティングを使わないため
機能損失はない。

## 2026-07-02: Visual Intelligence が beta 2 で macOS に到達 — 「iOS 専用」の制約を解消

macOS/visionOS フルビルドで、Xcode 27 beta 2 から `VisualIntelligence` フレームワークが Mac にも
import 可能になったことが判明（`#if canImport(VisualIntelligence)` が Mac でも真になった）。Mac は
visual search の `IntentValueQuery` が返す entity 全てが openable（`OpenIntent` 保持）であることを
要求するため、`TodoOrCategory` union に含まれる `CategoryAppEntity` が not openable でビルド失敗して
いた（iOS シミュレータ/実機では発火せず Mac Catalyst 相当でのみ顕在化）。「iOS 専用」は当時 SDK に
フレームワークが存在しなかっただけの制約であり恒久的な不可能ではなかったため、Mac を除外せず
`OpenCategoryIntent`（`CategoryAppEntity` 用の `OpenIntent`、`perform()` は `navigateToRoot()` のみ）を
新設して union 全メンバを openable にし、iOS/macOS/visionOS の 3 destination フルビルドを green に
した（`8ddc76f`）。

このケースは「プラットフォーム限定は SDK 更新時に実ビルドで再検証すべき」という教訓として記録。

## 2026-07-08〜09: beta 3 で SSU training が PlaceDescriptor に壊れる — String へ暫定退避

beta 3 で `AppIntentsSSUTraining` が `GeoToolbox.PlaceDescriptorEntity` をドット付き変数名として
SSU 化しようとし、`^[a-zA-Z_][a-zA-Z_$0-9]*$` の正規表現チェックに落ちてビルドが赤くなった。暫定回避
として `PlaceDescriptor` を `@Parameter`/`@Property` から外し `String` に退避した（`35d772f`）。
同 beta で `AppShortcutsProvider` をアプリターゲットへ移動（`3280bed`）、および toolbar API 変更への
追従も行った。

## 2026-07-28: beta 4 でも SSU バグ未修正 — ワークアラウンド継続 + TransientAppEntity 実装

beta 4 で `PlaceDescriptor` の SSU training バグ（変数名正規表現エラー）が再現するか確認したところ、
DerivedData クリア後クリーンビルドでも未修正であることを確認し、`35d772f` のワークアラウンドを継続した。
並行して Phase 1 の残項目だった `TransientAppEntity` を実装（`TodoListSummaryEntity` +
`GetTodoSummaryIntent`、`df4a2aa`）し、Phase 1 を完了とした。

## 2026-08-11: beta 5 でも SSU バグ・watchOS unavailable の両方を再検証 — 変化なしを確認

beta 5 (27A5237l) で 2 つの既知 SDK 制約を実ビルドで再検証した。

- SSU バグ: `35d772f` を一旦 revert し、DerivedData クリア後クリーンビルドで
  `GeoToolbox.PlaceDescriptorEntity` の SSU 化エラーが再現することを確認 → 未修正と判断し revert を
  取り消してワークアラウンドを継続。
- watchOS assistant schema: `.reminders.list` / `.reminders.listType` / `.system.searchInApp` の
  ガードを外した watch 実ビルドで `'reminders' is unavailable in watchOS` 等のエラーを確認 → 依然
  unavailable と判断しフォールバックを継続。

このとき、SSU タスクは incremental ビルドだと直前の失敗結果（stale エラー）をログに再表示することを
実際に誤検知として観測したため、判定は必ず DerivedData クリア後のクリーンビルドで行う、という注意点も
記録した（`647acb6`）。

## 2026-08-11: 過去の記述を3点訂正 — resolvedEntities() は誤記ではない / RelevantEntities の実例引用ミス / reminder 本体適合への新しいリード

`docs/devlog/2026-08-11-constraint-recheck.md` による全項目再検証の一環で、本計画の記述を3点訂正した（`3140e5b`）。

1. `EntityCollection.resolvedEntities()`: wwdc2026-345 の書き起こしには文字列として登場しない
   （セッションの口頭説明は `.identifiers` のみ）ため誤記を疑ったが、Xcode 27 beta 5 の
   `AppIntents.swiftinterface` で `public func resolvedEntities() async throws -> [Entity]` の実在を
   確認し、SDK 由来の正当な API であると確定させた。
2. `RelevantEntities` 不適合の根拠として挙げていた実例が誤りだったと判明: wwdc2026-345 の実例は
   `.audio(.nowPlaying)` ではなく `.audio(.workout(activityType: .running))`。ただしどちらの例でも
   todo ドメインに適合しないという結論自体は変わらない。
3. reminder 本体スキーマ適合（保留中）について新しいリードを発見: wwdc2026-344 は同等にリッチな
   `calendar_event` スキーマ（`attendee` は `TransientAppEntity` の入れ子、`location` は union）に
   手書き init なしで適合させている。Xcode のスキーマ・コードスニペット機能で型の骨格を生成し、
   モデル→エンティティのマッピングは Query 側に持たせる流儀と見られる。本プロジェクトが試した
   「自前 `init(from: TodoItem)` で順次代入」というスタイルがマクロ生成 backing storage と衝突している
   可能性があり、#48 を再挑戦する際はこの CometCal パターン（スニペット生成 + Query 側 populate +
   入れ子は TransientAppEntity）を先に試すべき、という未実施の申し送りとして記録した。
