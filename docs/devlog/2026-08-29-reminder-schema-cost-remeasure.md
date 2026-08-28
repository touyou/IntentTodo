# `.reminders.reminder` 適合コストを測り直した件（#56）

[2026-08-28 の切り分け](2026-08-28-ssu-system-value-type-bug.md)で「SSU バグでブロック」が否定されたので、
#56 の据え置き理由をゼロから測り直した。結論は **SDK はブロックしていない / 残るのは設計判断だけ**。

現在の状況は [docs/APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md) にある。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f）/ iOS 27.0 Simulator |
| 実測日 | 2026-08-29 |
| probe | `/tmp/SSUSchemaRepro`（最小プロジェクト。反復が速いので要求仕様の洗い出しはこちらで） |

## 1. 完全適合は成立する（SSU も通る）

probe で `.reminders.reminder` + 入れ子の `.reminders.locationTrigger` /
`.reminders.locationTriggerEvent` + `.reminders.list` / `.reminders.listType` を全部適合させた。

- `** BUILD SUCCEEDED **`
- 出荷メタデータに `reminders.ReminderEntity` / `reminders.LocationTriggerEntity` /
  `reminders.ListEntity` が登録、`checks: all clear`
- **`nlu/` が生成される**。`locationTrigger.place: PlaceDescriptor` を持っていても SSU は落ちない
  （かつてブロッカーとして記録していた形が、実際には踏まないことの直接確認）

途中で出た診断 2 件（仕様として記録）:

- `'ProbeListType' conforming to 'reminders.listType' requires enum case 'standard'`
- `Required AppSchemaEntity property 'type' must not be optional`（`.reminders.list` の `type`）

## 2. 要求プロパティは 12（beta 6 で変化なし）

空の適合体をビルドすると全部列挙される。2026-08-12 の記録と一致。

```
Missing required property 'title' / 'note' / 'dueDate' / 'isCompleted' / 'completionDate' /
'creationDate' / 'isFlagged' / 'tags' / 'list' / 'recurrence' / 'locationTrigger' / 'urls'
```

## 3. `@ComputedProperty` でスキーマ要求を満たせる（= 既存名を変えなくてよい）

probe で `note` を `@ComputedProperty var note: String? { todoDescription }` にしても
`ProbeReminder: 12 props` / `reminders.ReminderEntity` 登録が成立した。

| スキーマ要求名 | 本アプリの既存名 | 対応 |
|---|---|---|
| `note` | `todoDescription` | computed alias |
| `creationDate` | `createdAt` | computed alias（`Date?` へ緩める） |
| `isFlagged` | `isFavorite` | computed alias（`Bool?` へ緩める） |

**リネームは不要**。据え置き理由に「破壊的リネームが要る」と書いていたら、それは誤りになる。

## 4. 強制的な変更は `dueDate` の型衝突だけ（実測 5 ファイル 12 箇所）

スキーマは `dueDate: DateComponents?` を要求する。本アプリの `TodoAppEntity.dueDate` は `Date?` で
**名前が衝突する**ため、ここだけは computed alias で逃げられない。

`dueDateValue: Date?`（stored）+ `dueDate: DateComponents?`（`@ComputedProperty`）に置き換えて
実際にビルドを回し、壊れる箇所を全部潰して緑にした。

| ファイル | 箇所 |
|---|---|
| `TodoAppEntity.swift` | 6（宣言 / `isOverdue` / snapshot / init ×2 / `attributeSet`） |
| `TodoFocusFilter.swift` | 1（`isUrgent`） |
| `TodoListViewModel.swift` | 2（`dueDateAscending` / `Descending` の比較） |
| `TodoWidgetRow.swift` | 1 |
| `TodoRowView.swift` | 2 |

**全部 `dueDate` → `dueDateValue` の機械的置換**で、ロジック変更は無い。watchOS の詳細画面
（`WatchTodoDetailView` / `WatchTodoRow`）は `TodoItem` ベースなので影響しない。

> 測り方の注意: パッケージ内でコンパイルが止まると下流の consumer が見えない。「エラーが
> TodoAppEntity.swift だけ」の時点で「他に consumer は無い」と読みかけたが、自ファイルを
> 直したら UI / WidgetUI 側が出てきた。**緑になるまで潰し切ってから件数を数える。**

この scratch 変更は測定後に revert 済み（`git checkout -- Packages/`）。

## 5. 残っているのは設計判断

| 要求 | 現状 | 判断が必要なこと |
|---|---|---|
| `list`（非 optional） | `category: CategoryAppEntity?`（CloudKit 要件で optional） | 未分類 todo に見せる既定 Category を用意するか |
| `completionDate` | 無し | モデル追加 or computed で nil |
| `tags`（`Set<String>`） | 無し | モデル追加 or computed で空 |
| `recurrence` | 無し | モデル追加 or computed で nil |
| `urls`（`[URL]`） | 無し | モデル追加 or computed で空 |
| `locationTrigger` | 場所名 + 緯度経度はある。arrive/depart のイベントが無い | 新 entity を足して nil を返すか、イベントをモデルに持つか |

「モデル追加」側は CloudKit 互換の primitive に落とせるが SwiftData スキーマ変更を伴う。
「computed スタブ」側はデータモデルを触らずに `reminders.ReminderEntity` 登録だけ得られる。

## 6. 結論

**#56 は SDK 待ちではない。** 着手の可否は上記 §5 のどこまでを埋めるかという product 判断で決まる。
`@ComputedProperty` が使えることと `dueDate` が機械的置換 12 箇所で済むことが分かったので、
かつて見積もっていたより実装コストは小さい。
