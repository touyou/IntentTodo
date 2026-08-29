# `TodoAppEntity` を `.reminders.reminder` に適合させた件（#56）

[コスト測り直し](2026-08-29-reminder-schema-cost-remeasure.md)を受けて、モデルまで揃える形
（選択肢 B）で適合させた。**測定では見えていなかった制約が 1 つ出てきた**ので、そこを含めて残す。

現在のルールは [AGENTS.md](../../AGENTS.md) と
[docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md) にある。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f）/ iOS 27.0 Simulator |
| 実測日 | 2026-08-29 |

## 1. 追加したモデルフィールド（CloudKit 互換）

`TodoItem` に 5 つ。既定値ありか optional なので軽量マイグレーションで済む。

| フィールド | 型 | 備考 |
|---|---|---|
| `completionDate` | `Date?` | 完了経路（トグル / 絶対値セット / 最急トグル）で `TodoService.syncCompletionDate` が更新 |
| `tags` | `[String] = []` | スキーマは `Set<String>` 要求。entity 境界で変換 |
| `urls` | `[URL] = []` | `[URL]` は SwiftData 属性として通る |
| `recurrenceFrequency` / `recurrenceInterval` | `String?` / `Int = 1` | `Calendar.RecurrenceRule` は**属性にできない**（下記 §3）。primitive で持ち `TodoRecurrence` で組み直す |
| `locationTriggerEvent` | `String?` | arrive / depart の raw value。enum で持たないのは CloudKit 互換のため |

`TodoItemSnapshot` にも同じフィールドを足して undo の往復を保った（`makeTodoItem` で復元）。

### `Calendar.RecurrenceRule` は SwiftData 属性にできない

最初は `recurrenceRule: Calendar.RecurrenceRule?` を `@Model` プロパティに置いた。**コンパイルは
通る**が、アプリ起動時に落ちる:

```
EXC_BREAKPOINT (SIGTRAP) / libswiftCore _assertionFailure
  SwiftData ... x10
  IntentTodo one-time initialization function for schema
```

`ModelContainer` 生成前、schema の一度きり初期化で trap するので、UI テストは全ケースが
「起動直後にクラッシュ」で落ちる（原因が分かりにくい形）。フィールドを外して単一の
`testAppLaunches` を通すことで切り分けた。

→ 場所（`TodoPlace`）や担当者と同じく **CloudKit 互換 primitive + entity 境界で組み立て** に
寄せた（`TodoRecurrence`）。表現できるのは `daily` / `weekly` / `monthly` / `yearly` × interval。

## 2. スキーマ名エイリアスは `@ComputedProperty` で足りる

`note` / `creationDate` / `isFlagged` / `list` はスキーマが要求する**綴り**で、アプリ側の既存名
（`todoDescription` / `createdAt` / `isFavorite` / `category`）とは違う。`@ComputedProperty` で
別名を足すだけで満たせるので**リネームしていない**。

`list` はスキーマが**非 optional**を要求するので、未分類 todo には合成の
`CategoryAppEntity.uncategorized`（固定 id `"uncategorized"`）を見せる。実体のカテゴリを作ると
カテゴリ一覧に現れて編集対象になってしまうため、合成にした。

`dueDate` だけは名前が衝突する（スキーマは `DateComponents?`、アプリは `Date?`）ので、
stored を `dueDateValue: Date?` に改名し、`dueDate` を `@ComputedProperty` にした。
**測定どおり機械的置換 12 箇所**で済んだ（`TodoAppEntity` 6 / `TodoFocusFilter` 1 /
`TodoListViewModel` 2 / `TodoWidgetRow` 1 / `TodoRowView` 2）。

## 3. 測定で見えていなかった制約: スキーマは**サブエンティティ側にも適合を要求する**

ここが今回の本題。`TodoAppEntity` を適合させると watchOS ビルドがこう落ちた。

```
error: Property 'list' type does not match required AppSchemaEntity property type 'ListEntity'
error: Property 'locationTrigger' type does not match required AppSchemaEntity property type 'LocationTriggerEntity'
```

watchOS では `.reminders` スキーマが unavailable なので `CategoryAppEntity` は
`WatchCategoryAppEntity`（スキーマ無しのフォールバック）になっている。**親のスキーマ適合は
子のスキーマ適合を要求する**ため、フォールバックのままでは親も適合できない。

つまり「reminder スキーマに適合する」は `list` / `listType` / `locationTrigger` /
`locationTriggerEvent` を含む**サブグラフ全体**を適合させることを意味する。単体 probe では
サブエンティティも全部スキーマ付きで書いていたので気づけなかった。

### 解いた方法: 適合を手書きする

マクロ `@AppEntity(schema:)` / `@AppEnum(schema:)` が生やすものは 2 つだけ:

1. `AssistantSchemaEntity` / `AssistantSchemaEnum` 適合 + `__appSchemaEntity` / `__appSchemaEnum`
2. メンバへの `@Property` 付与（`@attached(memberAttribute)`）

**`AssistantSchemaEntity` / `AssistantSchemaEnum` プロトコル自体は watchOS でも available**で、
unavailable なのは `.reminders.reminder` のような**スキーマ名前空間シンボル**だけ。スキーマ識別子は
文字列なので、① を手書きすればマクロを使わずに watchOS でも適合できる。

```swift
extension WatchCategoryAppEntity: AssistantSchemaEntity {
    public static let __appSchemaEntity = "reminders.list"
}
```

これを 4 つの watchOS フォールバック（`WatchCategoryAppEntity` / `WatchTodoListType` /
`WatchTodoLocationTriggerAppEntity` / `WatchTodoLocationTriggerEvent`）に足した。
**副産物として watchOS 側もスキーマ付きになった**（これまで watch の出荷メタデータは
`assistant schemas: none` だった）。

`TodoAppEntity` 自身も同じ手書き形で適合させている。マクロを使うと `#if` で外せず、
`CategoryAppEntity` と同じ「型を 2 系統で全書き」になるが、`TodoAppEntity` は
`IndexedEntity` / `Transferable` / `URLRepresentableEntity` を抱えた大きな型で二重管理は事故る。

## 4. `#if` で適合を切ると衝突する（`#49` の再現を実測）

最初は `#if !os(watchOS)` で適合を切った。ビルドは緑で、`assistantDefinedSchemas` にも
`reminders.ReminderEntity` が**入っていた**。それでも `inspect_appintents_metadata.py` は
スキーマ無しと報告した。生データを見ると、同じ mangled name `14TodoAppIntents0aB6EntityV` の
エントリが 3 つあり、うち 1 つ（埋め込まれた watchOS アプリ由来）が空だった。

```
schema: [{"domain": "reminders", "name": "ReminderEntity"}]  mangled: 14TodoAppIntents0aB6EntityV
schema: [{"domain": "reminders", "name": "ReminderEntity"}]  mangled: 14TodoAppIntents0aB6EntityV
schema: []                                                   mangled: 14TodoAppIntents0aB6EntityV
```

これが #49 が記録している衝突そのもの。**`#if` で適合を切るのは（型名を分けない限り）ダメ**で、
全プラットフォームで同じ適合を宣言するのが正解だった。適合を手書きにしたことで、watchOS でも
同じ宣言ができるようになり衝突が消えた。

適合後は全型が単一のスキーマ集合を持つ:

```
TodoAppEntity: ['reminders.ReminderEntity']
CategoryAppEntity / WatchCategoryAppEntity: ['reminders.ListEntity']
TodoLocationTriggerAppEntity / WatchTodoLocationTriggerAppEntity: ['reminders.LocationTriggerEntity']
```

> **測り方の教訓**: `grep 'reminders.ReminderEntity'` では見つからない。メタデータは
> `{"domain": "reminders", "name": "ReminderEntity"}` の形で持つ。文字列 grep で「無い」と
> 判断しかけた。判定は `inspect_appintents_metadata.py` に任せる。

## 5. 削除済みオブジェクトの配列属性は読めない（`tags` / `urls` を deferred にした）

`tags` / `urls` を `@Property` として `init(from:)` で読む形にしたら、UI テストの
`testDeleteTodoFromDetailView` だけがクラッシュした。

```
libswiftCore _assertionFailure
  SwiftData x3
  TodoItem.tags.getter
  TodoAppEntity.init(from:)
  TodoDetailContent.entity.getter
```

**SwiftData は削除済みオブジェクトの配列属性を読むと trap する**（scalar は最後の値を返すので
耐える）。詳細画面は削除直後にもう 1 度 body を評価し、`@Query` の結果にはまだ削除済みの
オブジェクトが入っているため、そこで配列を読んで落ちる。

- `!todoItem.isDeleted` のガードは**効かなかった**（同じ trace で再発）。この時点で `isDeleted`
  は false のまま
- 効いたのは **`@DeferredProperty` に変えて id から引き直す**形。既存の `subtaskProgress` と
  同じパターンで、消えた todo は「見つからない」に落ちるだけになる
- **スキーマ要求は `@DeferredProperty` でも満たせる**（`tags` / `urls` を deferred にしても
  `reminders.ReminderEntity` は登録されたままで `checks: all clear`）

配列/関係を値スナップショットに載せないというのは元々の契約（`subtaskProgress` のコメント）で、
そこに揃えた形になる。

## 6. 追加した Intent コピー

スキーマ適合で 14 キー増えたので 3 catalog（`IntentTodo` / `IntentTodoWatchApp` /
`IntentTodoLiveActivity`）に手動キーとして入れた。

`Note` / `Creation Date` / `Completion Date` / `Is Flagged` / `List` / `Tags` / `URLs` /
`Recurrence` / `Location Trigger` / `Location Trigger Event` / `Place` / `Event` /
`Arriving` / `Leaving` / `Uncategorized`

- **`StringCatalogEdit` は既存キーの訳を入れるツールで、キーを新規作成できない**
  （`String key 'Arriving' not found`）。手動キーの作成はスクリプトで行い、書式は
  `json.dumps(..., indent=2, separators=(",", " : "))` が Xcode の出力とバイト一致することを
  往復で確認してから書いた（素の `indent=2` だと全ファイルが差分になる）
- `check_intent_copy_localization.py` が拾うのは enum の display 等で、entity の
  `@Property(title:)` は拾わない。既存の property title は catalog に入っているので、
  **チェッカーが黙っていても慣習に合わせて入れる**

## 7. 確認

- クリーンビルド（iOS 27.0 Simulator）green、SSU エラー 0 件
- 全テスト green（`** TEST SUCCEEDED **`、失敗 0。UI テスト + AppIntentsTesting 3 スイート）
- `inspect_appintents_metadata.py`: `checks: all clear`。`TodoAppEntity` は 20 props +
  `reminders.ReminderEntity`
- `check_intent_copy_localization.py`: 4 ターゲットすべて `0 missing / 0 untranslated in ja`

## 8. 残ったこと

- `tags` / `urls` / `recurrenceFrequency` / `locationTriggerEvent` は**書き込む経路が無い**
  （モデルとスキーマ露出だけ）。Intent / UI からの編集は別タスク
- `CategoryAppEntity` / `TodoListType` の 2 系統宣言は、適合を手書きにできると分かった今
  **1 系統に畳める可能性がある**（スキーマ差分が消えたので mangled name を分ける理由が薄い）。
  ただし `@Property(indexingKey:)` の availability 差など別の理由が残るので未着手
