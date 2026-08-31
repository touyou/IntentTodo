# 2026-08-31 — 追加画面と編集画面のフィールドを一致させた経緯

追加画面（`AddTodoView`）と詳細の編集シート（当時 `TodoAttributesEditView`）で
いじれるフィールドが噛み合っていない、という指摘から始めた。

## 測った非対称

| フィールド | 追加 | 詳細表示 | 編集シート | `UpdateTodoIntent` | `TodoService.update` |
|---|---|---|---|---|---|
| title / description / dueDate / isFavorite / estimatedDuration / assignee | ✅ | ✅ | ❌ | ✅ | ✅ |
| location | ✅ | ✅ | ❌ | ❌ | ❌ |
| tags / urls / recurrence / locationTriggerEvent | ✅ | ✅ | ✅ | ✅ | ✅ |

- 編集シートが持っていたのは 11 フィールドのうち 4 つだけだった。これは
  [2026-08-29-attribute-write-paths.md](2026-08-29-attribute-write-paths.md) で
  reminders 属性の書き込み経路を通したときに、**その 4 属性のためのシートとして**作ったため。
  他のフィールドは「Shortcuts からは書けるがアプリからは書けない」状態で残っていた。
- **`location` はどこからも編集できなかった**。`AddTodoIntent` は受け取るのに
  `UpdateTodoIntent` にパラメータが無く、`TodoService.update` にも列が無い。
  作成時に付けた場所を後から直す手段が無く、`locationTriggerEvent`（場所が要る）も
  実質作成時にしか意味を持てなかった。
- 詳細**表示**側は既に全フィールドを出していた（`TodoDetailMetadataSection` が値のあるものだけ出す）。
  つまり「見えるのに直せない」形だった。

## 直し方

- フォームの中身を `TodoFormSections` + `TodoFormDraft`（`Packages/UI/Sources/UI/Components/`）に
  1 本化し、追加・編集の両画面がそれを描くだけにした。両画面の差は
  **確認ボタンがどの Intent を走らせるか**だけになる。
- `UpdateTodoIntent` に `locationName` を追加（`AddTodoIntent.location` と同じ理由で
  `String`。system value 型は FB24548956 を踏む）。`parameterSummary` にも載せたので
  Shortcuts 編集画面からも設定できる。
- `UpdateTodoIntent` の便宜 init は**全フィールド必須**にした。デフォルト値を与えると、
  Intent にフィールドが増えたときフォームが黙って古いままになる。
- フォームは全フィールドを `.set` で送るので、編集シートは部分パッチではなく
  **todo 全体の last-write-wins**。現在値から始めるので触らなかった欄は同じ値が書き戻る。

## 決めたこと（コードのコメントに残していない判断）

- **場所名を変えたら座標は落とす。** モデルは場所を name + 座標に分解して持っており
  （CloudKit 制約）、座標は解決元の名前に属する。名前だけ差し替えると
  `TodoPlace` が前の場所の `PlaceDescriptor` を組み直してしまう。
  名前が同じなら座標は保つ（フォームが毎回全フィールドを送るので、これが無いと
  無関係な保存で座標が消える）。3 ケースともテストにした
  （`TodoAttributeWritePathTests` の update: location 節）。
- **`estimatedDuration` の Picker に todo 自身の値を混ぜる。** 選択肢は 15〜240 分の固定リストだが、
  Siri / Shortcuts はリスト外の値を書ける。混ぜないと Picker が空欄で描かれ、
  保存でリスト内の値に丸められる。
- **Empty state は増やさない。** 詳細表示は「値があるものだけ」を出す方針を維持
  （未設定フィールドを空行で並べない）。編集側で全フィールドが常に見えるので、
  表示側に空行を足す必要は無い。
- 「詳細を編集」→「編集」に改名した。4 属性のシートではなくなったので
  `Edit Details` は stale になり、`Edit` / `Edit Todo` を新設した。
  アクセシビリティ識別子（`editDetailsButton` / `saveAttributesButton`）は
  UI テストが引いているのでそのまま。

## 編集途中に閉じそうになったときの確認

同日に「編集途中で閉じそうになったら確認を出したい」という追加要望があり、そこで
**`dismissalConfirmationDialog(_:shouldPresent:actions:message:)` が iOS では空振りする**と分かった。

- ドキュメント（SwiftUI Extended API / 各オーバーロードの Discussion）には
  「On iOS, the dialog appears when someone swipes down on the sheet or taps outside it」と
  書かれている。iOS 27 SDK でビルドは通る（`@available` で弾かれない）。
- シミュレータ（iPhone 17 Pro Max / iOS 27.0）で測った結果、**一度も発火しなかった**:
  - フォーム内側（`Form` + toolbar）に付けた場合 → スワイプ下げでそのまま閉じる
  - シート content の根（`NavigationStack` の外、`presentationDetents` と同じ位置）に
    `shouldPresent: true` を**固定**で付けた場合 → それでもスワイプ下げでそのまま閉じる
  - 同じ固定条件で「キャンセル」の `dismiss()` を踏んだ場合 → 確認なしで閉じる
  → 「置き場所が悪い」「dirty 判定が false」の両方を潰した上で発火しないので、
  少なくとも iOS のシートでは実装が来ていないと判断した。macOS のウィンドウでは動く可能性が残るが、
  このアプリの追加・編集はどのプラットフォームでもシートなので使い道がない。
- 代わりに 2 段構えにした（`View.confirmDiscardingForm(hasChanges:isConfirming:onDiscard:)`）:
  - `interactiveDismissDisabled(hasChanges)` で、変更があるときだけスワイプ下げ / 外側タップを塞ぐ
    （detent 間のリサイズは残るので、シートが壊れて見えることはない）
  - 「キャンセル」は dirty なら `confirmationDialog` を出し、clean ならそのまま閉じる
  - SwiftUI には「dismiss しようとした」を観測する公開 API が無いため、
    スワイプ下げ自体に確認を出すことはできない。塞ぐところまでが限界
- **保存経路は塞がらない**ことが重要。`AddTodoIntent` / `UpdateTodoIntent` は
  `NavigationModel` のフラグを倒して閉じており、これは presenter 側の状態なので
  `interactiveDismissDisabled` の対象外。実機で「保存 → 閉じる」まで確認した。

## 確認

- iOS / macOS / visionOS の 3 destination でビルド（visionOS の詳細画面は
  `#if os(visionOS)` の中にあり、iOS ビルドでは型名の変更が検証されない）
- `TodoAttributeWritePathTests` の update 系 6 本（新規 3 本を含む）が緑
- シミュレータで 4 経路を実際に触って確認:
  1. 未編集でスワイプ下げ → そのまま閉じる
  2. 入力後にスワイプ下げ → 閉じない（塞がれる）
  3. 入力後にキャンセル → 「変更を破棄しますか?」→ 破棄で閉じ、todo は作られない
  4. 入力後に追加 / 保存 → 確認は出ず、そのまま保存されて閉じる（編集側は `modifiedAt` も進む）
