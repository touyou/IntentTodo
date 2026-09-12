# 添付を足して `createReminder` / `updateReminder` に適合した件（#138）

[同日の Intent スキーマ適合](2026-09-12-intent-schema-adoption.md)で残した 2 本。要求差分のうち
`section` は[セクション実装](2026-09-12-sections.md)で、`images` は添付をモデルに足すことで埋めた。

現在のルールは
[docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md#intent-スキーマ適合appintentschema)、
状態は [docs/APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md)。

## 環境

| | |
|---|---|
| Xcode | 27.0 RC（27A266a） |
| destination | iOS 27.0 Simulator（iPhone 17 Pro Max） |
| 実測日 | 2026-09-12 |

## 1. 添付（`images`）

`.reminders.createReminder` は `images: [IntentFile]` を**非 optional**で要求する。受け取って
捨てる形は避け、`TodoAttachment`（`@Attribute(.externalStorage)`）を足して保存した。

- **`IntentFile` は識別子を持たない**。フォームは保存のたびに添付集合を丸ごと送るので、
  素朴に「集合を作り直す」と毎回同じ bytes を削除 → 再挿入することになり、CloudKit に
  同じ画像を上げ直す。`TodoService.applyAttachments` は **filename + byte 数**で既存行と
  突き合わせ、一致したものはそのまま残す
- cascade は **todo を削除したときにしか発火しない**。集合から外れた添付は
  `repository.deleteAttachments` で明示的に消さないと、どこからも参照されない行が残る

## 2. 適合で出た 4 つの要求（ビルドでしか出ない）

`@AppIntent(schema: .reminders.createReminder)` を足してから緑になるまでに出た診断:

| 診断 | 対応 |
|---|---|
| `Missing required parameter 'note' / 'isFlagged' / …` | リネーム（`todoDescription` → `note` ほか） |
| `Parameter 'dueDate' does not match required AppSchemaIntent type 'DateComponents'` | `TodoDueDate` で `Date` と往復 |
| `The 'supportedTypeIdentifiers' argument of parameter 'images' must specify at least one UTType subtype of the following supertypes: 'public.image'` | `public.png` / `public.jpeg` / `public.heic` / `public.tiff` を列挙（`public.image` 自体は supertype なので不可） |
| `requires 'TodoLocationTriggerAppEntity' to conform to 'IndexedEntity', 'UniqueAppEntity', 'TransientAppEntity', provide a default 'EntityStringQuery', or provide an 'IntentValueQuery'` | 場所名で引ける `EntityStringQuery` を追加（素の `EntityQuery` は id でしか答えられない） |

## 3. ビルドが緑になっても動かなかった: 非 optional コレクション

ビルドは通り、出荷メタデータにも `reminders.CreateReminderIntent` が入った。しかし
`AppIntentsTesting` を回すと **14 / 15 が落ちた**:

```
Unsupported operation: The App Intent requested value for parameter 'tags',
which is not supported by AutoConfirmingPerformDelegate
```

スキーマが要求する `tags: Set<String>` / `urls: [URL]` / `images: [IntentFile]` は
**非 optional**なので、値を渡さない呼出元（`makeIntent(title:)`、watch の追加画面、
「やることを追加」だけの Siri）に対してシステムが値を聞き返す。`default: []` を付けて解決。

**「スキーマに適合した」と「呼べる」は別**という例がもう 1 つ増えた。

## 4. 1 時間使った偽の失敗: シミュレータ側の登録が古いまま残る

`todo` → `target` のリネーム後、テストが

```
The App Intent requested value for parameter 'todo'
```

で落ち続けた。`todo` というパラメータはもうどこにも無い。切り分け:

| 試したこと | 結果 |
|---|---|
| インクリメンタルビルドのメタデータを確認 | **旧パラメータ 16 個 / schema 空**。357 ファイル再コンパイルされても `*.appintents` は再生成されない（AGENTS.md ルール 12 の実例） |
| DerivedData を消してクリーンビルド | メタデータは正しく `target` / schema 付き。**それでもテストは同じエラー** |
| `simctl uninstall` して再テスト | 変化なし |
| `simctl erase` して再テスト | エラーの内容が変わり（`tags` を要求）、**旧パラメータの参照は消えた** |

つまりアプリを入れ替えても **App Intents のシステム側登録は古いまま**で、アンインストールでも
戻らない。パラメータをリネームしたら `simctl erase` が要る。

> 教訓の形: 「メタデータで確認する」の対象は**出荷メタデータとシステムの登録の 2 つ**。
> 前者が正しくても後者が古いと、実装のせいに見える失敗が出る。

## 5. FB24548956 は踏まなかった

`locationTrigger: TodoLocationTriggerAppEntity?` は **App Shortcut に登録済みの
`AddTodoIntent` の `@Parameter`** で、その entity は `place: PlaceDescriptor` を持つ。
system value 型を `@Parameter` に置くと SSU が無音で落ちるバグ（FB24548956）の射程かを
測った:

- `must match regular expression` / `Could not archive SSU` / `emitted errors` は **0 件**
- `en.lproj/nlu.appintents` / `ja.lproj/nlu.appintents` 生成あり

**発火するのはパラメータの型が system value 型そのものの場合**で、system value 型を
プロパティに持つ自前 entity では踏まない（entity の `@Property` で踏まないことの
[2026-08-29 の実測](2026-08-29-entity-placedescriptor-restore.md)と同じ線）。

## 6. 仕様として残した形

- **スキーマ外のアプリ固有パラメータは optional なら残せる**ので、`estimatedDuration` /
  `assignee` / `location` / `locationTriggerEvent` / `section` / `images`(update 側) は維持
- `location`（場所名だけ）と `locationTrigger`（場所 + arrive/depart）は**両方持つ**。
  スキーマの entity は両方揃わないと作れないが、アプリは「場所だけ」も
  「イベントを先に決める」も許す。両方来たら `locationTrigger` が勝つ
- `isCompleted` が update スキーマに含まれるので、完了の書き込み経路は
  `SetTodoCompletionIntent` と 2 本になった。どちらも `TodoService` を通り、
  `completionDate` の同期は 1 か所

## 7. 結果

出荷メタデータ（クリーンビルド `/tmp/ITFinalDD`）:

```
AddTodoIntent               reminders.CreateReminderIntent
UpdateTodoIntent            reminders.UpdateReminderIntent
DeleteTodosIntent           reminders.DeleteRemindersIntent
CreateSectionIntent         reminders.CreateSectionIntent
OpenTodoIntent              system.OpenIntent
OpenCategoryIntent          system.OpenIntent
ShowTodoSearchResultsIntent system.SystemSearchInAppIntent
TodoAppEntity               reminders.ReminderEntity
CategoryAppEntity           reminders.ListEntity
TodoSectionAppEntity        reminders.SectionEntity
TodoLocationTriggerAppEntity reminders.LocationTriggerEntity
```

`autoShortcuts: 8` / SSU エラー 0 件 / Intent コピーの ja 欠落 0 件。
テストは TodoAppIntents 157 / Repository 30 / Domain 19 / `IntentTodoUITest` の
AppIntents 3 スイート 23、すべて green。

`reminders` ドメインで残っているのは `createList` と `reminders.group`（#139）。
