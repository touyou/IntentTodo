# reminders 属性の書き込み経路を通した件（#56）

[スキーマ適合](2026-08-29-reminder-schema-conformance.md)（#83）で `tags` / `urls` /
`recurrenceFrequency` / `locationTriggerEvent` をモデルと entity に足したが、**値を変える経路が
1 つも無かった**。Shortcuts では「取得はできるが設定できない」形で、アプリ UI には入力欄が無い
状態だった。ここを Intent と UI の両方から埋めた。

作業中に **#83 が置いていった破損 3 件**が出てきたので、それも含めて残す。

現在のルールは [AGENTS.md](../../AGENTS.md) と
[docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md) にある。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f）/ iOS 27.0 Simulator |
| 実測日 | 2026-08-29 |

## 1. 一番効いた発見: `parameterSummary` は**編集画面の allowlist**だった

`AddTodoIntent` に `@Parameter` を足す前に、既存のパラメータが Shortcuts でどう見えるかを確認した。
Apple の App Intents ガイダンス（`app-intents-specialist` スキルの `parameters.md`）が明言している。

> `ParameterSummary` is not cosmetic — it is the allowlist for which parameters the Shortcuts
> editor surfaces. […] every other `@Parameter` is **silently omitted** from the editor UI,
> even though it still exists and still resolves.

`AddTodoIntent` の summary は `Summary("Add todo titled \(\.$title)")` だけだったので、
**`dueDate` / `isFavorite` / `estimatedDuration` / `assignee` / `location` は Shortcuts の編集画面に
そもそも出ていなかった**。`UpdateTodoIntent` も `Summary("Update \(\.$todo)")` だけで、
「部分更新の三状態」を作り込んだ 6 パラメータが全部隠れていた。

つまり新しい属性を `@Parameter` として足すだけでは「書き込む経路がある」にならない。両方の
Intent に trailing `@ParameterKeyPathsBuilder` ブロックを足して全パラメータを列挙した。

検証は生成物側で行う。`Metadata.appintents` の `actionConfiguration.actionSummary.wrapper` に
`otherParameterIdentifiers` が並ぶ。

```
"otherParameterIdentifiers": [
  "todoDescription", "dueDate", "isFavorite", "estimatedDuration", "assignee",
  "location", "tags", "urls", "recurrenceFrequency", "recurrenceInterval",
  "locationTriggerEvent"
]
```

> 見落としていたのは**ビルドが緑で、Siri から名指しすれば動く**からだった。Shortcuts アプリを
> 実際に開かないと気づけない類なので、判定は上記のメタデータで機械的に見るのが良い。

## 2. `[URL]` の `@Parameter` は SSU バグを踏まなかった

`AddTodoIntent` は `TodoAppShortcuts` に登録済みなので、
[SSU training バグ（FB24548956）](2026-08-28-ssu-system-value-type-bug.md)の発火条件
（App Shortcut 登録済み Intent の `@Parameter` に system value 型）に該当する場所。`[URL]` と
`[String]` を足すことになるため、クリーンビルドで確認した。

- `BUILD SUCCEEDED`、`GeoToolbox.PlaceDescriptorEntity must match regular expression …` は 0 件
- SSU アセットも生成される（`en.lproj/nlu.appintents/nlu.lzfse` / `ja.lproj/nlu.appintents/nlu.lzfse`）

`URL` はメタデータ上 primitive として扱われ、`GeoToolbox.PlaceDescriptorEntity` のような
ドット入りの型名にならない。バグの条件は「配列かどうか」ではなく「型名がドットを含む system
value 型かどうか」だと確認できた。

## 3. `Calendar.RecurrenceRule` は `@Parameter` にできないので `AppEnum` を作った

entity 側（`TodoAppEntity.recurrence`）はスキーマ要求どおり `Calendar.RecurrenceRule?` だが、
これは Siri / Shortcuts が渡せる型ではない（SwiftData 属性にもできない。#83 §3）。書き込み側は
`TodoRecurrenceFrequency`（`AppEnum`）+ interval の 2 パラメータで表現し、読み取り側の
`TodoRecurrence.rule(frequency:interval:)` が rule に組み直す形にした。

`#83` で作った `TodoRecurrence.Frequency`（internal）を public な `AppEnum` に昇格させた。
raw value は **`TodoItem` の保存値**と**保存済みショートカットが replay する値**の二重の契約に
なるので、追加はできるが改名・並べ替えはできない旨をコメントに残した。

### `AppEnum` の表示名は UI からも読める（文言を 1 セットに保てる）

ピッカーのラベルに使う文言を UI パッケージの catalog にもう 1 組持つ必要はなかった。SDK の
`CaseDisplayRepresentable`（`AppEnum` の祖先）が `localizedStringResource` を default 実装で
生やしている。

```swift
public protocol CaseDisplayRepresentable : CustomLocalizedStringResourceConvertible, CaseIterable, Hashable {
  static var caseDisplayRepresentations: [Self : DisplayRepresentation] { get }
}
extension CaseDisplayRepresentable {
  public var localizedStringResource: LocalizedStringResource { get }
}
```

`Text(option.localizedStringResource)` で `caseDisplayRepresentations` の文言がそのまま出る。
`TodoAppIntents` は catalog を持たないので解決先はアプリターゲットの main bundle、つまり
**Intent コピーとして既に手動キーで入れているもの**が使われる。Siri とアプリ UI で同じ文言が出る。

同じ理由で `CaseIterable` の明示適合も不要だった（`AppEnum` が transitively 要求している）。
最初は両方書いていて、`ForEach(TodoLocationTriggerEvent.allCases)` を通すために `CaseIterable` を
足す変更まで入れていたが、不要だったので戻した。

## 4. 詳細画面で `todo.tags` を読んで #83 と同じ trap を踏んだ

`TodoDetailContent.body` の中で `if !todo.tags.isEmpty` と書いたら、
`testDeleteTodoFromDetailView` がアプリのクラッシュで落ちた。

```
libswiftCore _assertionFailure
  SwiftData x3
  TodoItem.tags.getter
  closure #1 in TodoDetailContent.body.getter
  SwiftUI List<>.init(content:)
```

**#83 §5 と完全に同じ罠**（SwiftData は削除済みオブジェクトの配列属性を読むと trap する。scalar は
最後の値を返すので耐える）。#83 では `TodoAppEntity.init(from:)` の中で踏み、`@DeferredProperty`
（id から引き直す）に変えて解いた。今回は View 側に同じ読みを新しく持ち込んだ形。

解き方も同じ方向に揃えた。`tags` / `urls` は `body` から読まず、`@State` のスナップショットを
`.task(id: todo.modifiedAt)` で **entity の `@DeferredProperty` 経由**（= id から引き直し）で更新する。

- 契機に `modifiedAt` を使えるのは scalar だから（削除済みでも読める）。`UpdateTodoIntent` が
  保存すると進むので、保存後の表示更新も同じ仕組みで足りる
- 編集シートにも配列は渡す形にした（`TodoAttributesEditView(todo:tags:urls:)`）。シートの content
  クロージャは提示中に再評価されうるので、そこでモデルの配列を読むと同じ trap の口が残る
- `@DeferredProperty` は `Set<String>` を返すので表示順は自前で決める。`localizedStandardCompare`
  で並べて決定的にした（編集して保存すると保存順もこれに揃う）

> **教訓**: この trap は「entity 側で 1 回直した」では終わらない。`TodoItem` の配列属性を新しく
> 読む場所を作るたびに再発する。**`@Model` の配列属性は `body` から読まない**をルールにした。

## 5. #83 が置いていった破損 3 件

`dueDate: Date? → DateComponents?` の変更（#83 §2）の追従漏れ。**どれもビルドが緑のまま
（もしくは走らせていない経路で）残っていた**。

| 場所 | 症状 | 気づけなかった理由 |
|---|---|---|
| `TodoAppIntentsTests`（3 ファイル 4 箇所） | **コンパイルエラー**（`DateComponents?` と `Date` の `==`） | `IntentTodo.xcscheme` の `Testables` に **`IntentTodoUITest` だけ**が入っており、SPM パッケージのユニットテストは `xcodebuild test` で走らない |
| `VisionOSTodoView.swift` | **コンパイルエラー**（`DateComponents` を `Date` に渡している） | visionOS ビルドを回していなかった |
| `TodoIntentExecutionTests.testQuickSnooze…` | 実行時 `castingFailed(elementType: "DateComponents", targetType: "Date")` | `AnyAppEntity` の dynamic member lookup なので**コンパイルは通る** |

3 件目の直し方だけ注意が要る。`dueDateValue`（stored な `Date?`）は `@Property` ではないので
`AnyAppEntity` からは読めない。entity が露出するのは分までに射影された `DateComponents?` なので、
期待値も同じ粒度に落として比べる形にした。

```swift
let snoozedComponents: DateComponents = try snoozed.value.dueDate
let expectedComponents = Calendar.current.dateComponents(
    [.year, .month, .day, .hour, .minute],
    from: dueDate.addingTimeInterval(30 * 60)
)
XCTAssertEqual(snoozedComponents, expectedComponents)
```

> **`TodoAppIntentsTests` がスキームから外れている**のは今回の作業では直していない（スキーム設定の
> 変更は影響範囲が別）。137 テストが CI からも `xcodebuild test` からも走らない状態なので、
> **#84** に切り出した。

## 6. String Catalog のキー順は `localizedStandardCompare`

新しいキーを足すときに、Python の `sorted()` で並べ替えると**ファイル全体が差分になる**。
Xcode が書く順序は codepoint 順ではない。

```
Xcode:  ["Delete", "Delete “%@”?", "Delete ${entities}", ...]
sorted: ["Delete", "Delete ${entities}", "Delete “%@”?", ...]   # $ (0x24) < “ (0x201C)
```

`Add to favorites` / `Add todo` / `Add Todo` の並びも codepoint 順では再現できない（Xcode は
大文字小文字を無視し、同一視されたら小文字を先に置く）。

`String.localizedStandardCompare(_:)` で並べると **UI パッケージの catalog（107 キー）の既存順序と
完全一致**した。Python からは ICU 照合を再現できないので、キー列だけを Swift のワンライナーに
渡して並べ替えるのが手っ取り早い。

一方 **アプリターゲットの 3 catalog は codepoint 順**で書かれていた（`'1 day'` が
`'^[%lld pending todo]…'` より前）。#83 が Python スクリプトで手動キーを入れたときの順序が
そのまま残っているためで、こちらは `sorted()` で追記すると差分が純増分になる。

→ **catalog ごとに既存の並びに合わせる**。判定は「diff に削除行が出ないこと」で行う
（`git diff --numstat` の 2 列目が 0）。

## 7. 決めたこと

- **`tags` / `urls` は差分ではなく置き換え**。「1 つ足す」は呼出側が現在値に足した配列を渡す形で
  表現する。Shortcuts の編集画面が配列を丸ごと編集する形なので、Intent の意味と UI の意味がずれない
- **タグの重複判定は大文字小文字 / ダイアクリティカルマークを無視する**（`compare(_:options:range:locale:)`）。
  検索の `localizedStandardContains` が区別しないものを 2 件持たない、という一貫性
  - `localizedStandardCompare` を使いかけたが、これは Finder の**並び順**で、
    `"Work".localizedStandardCompare("WORK")` は `.orderedAscending`（同値ではない）。テストが落ちて気づいた
- **編集シートを閉じるのは `UpdateTodoIntent.perform()`**（`navigationModel.dismissAttributeEditor()`）。
  `AddTodoIntent` が追加シートに対してやっているのと同じ「Intent 完了 = シート閉じる」の 1 対 1 対応。
  ボタン側で併せて `dismiss()` すると、Intent が失敗しても閉じて「保存された」ように見える
- **`locationTriggerEvent` は場所が無くても保存する**。場所を後から足せるので、弾くより
  「有効にするには場所を設定してください」とフッターで伝える方が素直
- **visionOS の詳細画面にも同じ編集導線を足した**。追加画面（`AddTodoView`）は共有なので、
  入れないと「作るときは設定できるのに後から直せない」プラットフォームができる

## 8. 確認

- クリーンビルド green（iOS / macOS / visionOS / watchOS）、SSU エラー 0 件、`nlu/` 生成あり
- `xcodebuild test`（iOS）: 40 テスト green（新規 UI テスト `testAddTagFromDetailView` を含む）
- `swift test`（`TodoAppIntents` パッケージ）: **137 テスト green**（#83 以降コンパイルできて
  いなかったものを直して +12）
- `inspect_appintents_metadata.py`: `checks: all clear`
- `check_intent_copy_localization.py`: 4 ターゲットすべて `0 missing / 0 untranslated in ja`
- `swiftlint`: main と同じ 3 件（いずれも既存）
