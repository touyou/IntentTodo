# Intent 側の App Schema 適合を測り、3 本を適合させた件（#138 / #139）

Entity / Enum は `.reminders.*` に適合済みだったが、**Intent 側の適合が
`.system.searchInApp` と `.visualIntelligence.*` の 2 本しか無い**ことに気づいて測り直した。
`.system.open` を「素の `OpenIntent` で成立している」として据え置いていた判断も、
出荷メタデータで見ると**同値ではなかった**。

現在の状態は [docs/APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md)、
ルールは [docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md#intent-スキーマ適合appintentschema)。

## 環境

| | |
|---|---|
| Xcode | 27.0 RC（27A266a） |
| destination | iOS 27.0 Simulator（iPhone 17 Pro Max）/ My Mac |
| 実測日 | 2026-09-12 |
| DerivedData | `/tmp/ITSchemaProbeDD`（共有 DerivedData を汚さない） |

## 1. 据え置き理由が実測と合っていなかった

`.system.open` は「⏸ 素の `OpenIntent` で成立している」としていた。SDK を見ると確かに
`.system.open` は `AppSchema.Intent("OpenIntent")` に解決される（プロトコルと同名）。
だが**出荷メタデータは別物を記録していた**:

| Intent | `systemProtocols` | `assistantDefinedSchemas` |
|---|---|---|
| `OpenTodoIntent`（プロトコルのみ） | `OpenEntity`, `URLRepresentable` | `[]` |
| `ShowTodoSearchResultsIntent`（マクロ） | `ShowInAppStringSearchResults`, **`AssistantIntent`** | `{system, SystemSearchInAppIntent}` |

wwdc2026-240 `9:41`–`15:10` が言っているのはこの差で、素の App Intent は
Shortcuts / Spotlight / ウィジェットには出るが **Siri の自然言語実行には載らない**
（"actions use schemas to become executable by Siri"）。「開く」の意味解釈（`OpenEntity`）と
「Siri が実行できる宣言」（`AssistantIntent` + schema）は別に立つ。

## 2. 要求はビルドでしか出ない

要求の洗い出しに使えないと分かった経路を先に書く。

| 経路 | 結果 |
|---|---|
| `XcodeRefreshCodeIssuesInFile` | **形を検証しない**。存在しないスキーマ名（`.system.openNonexistentProbe`）は即エラーになるのに、`AddTodoIntent` に `.reminders.createList` を付けても診断 0 件 |
| ホストの `swift build`（SPM 単体） | 同じく通る（`Build complete!`）。この経路は `ExtractAppIntentsMetadata` を走らせない |
| Xcode ビルド | `Missing required parameter 'x' from AppSchemaIntent '...'` などで全部出る |

`.reminders.createList` を `AddTodoIntent` に付けた**明らかに誤った適合が 2 経路で緑**になったので、
「ライブ診断が緑」は Intent スキーマ適合の根拠にならない。

出しているのは `appintentsmetadataprocessor`（`ExtractAppIntentsMetadata` フェーズ）で、
**halting error 扱い**なのでスキーマ 1 本の形が合わないとそのターゲットの
メタデータが丸ごと出力されない:

```
error: At least one halting error was produced during export, so no AppIntents metadata
have been exported and this target is not usable with AppIntents until errors are resolved
```

適合の追加は「効くか効かないか」ではなく「そのターゲットの App Intents 全部が止まるか」なので、
1 本ずつ足してビルドを緑に戻しながら進める。

## 3. watchOS の扱いは entity と違った

まず 4 本に付けて My Mac ビルド（scheme は watch アプリも含む）:

```
'reminders' is unavailable in watchOS
'deleteReminders' is unavailable in watchOS
'system' is unavailable in watchOS
'open' is unavailable in watchOS
```

entity では同じ壁を**型名の分離**（`WatchTodoAppEntity`）で越えていた。iOS の統合メタデータへの
merge で同名エントリの後の入力（= watch スライス）が前を丸ごと置き換えるため（FB24570185）。

Intent では `#if !os(watchOS)` を**マクロ行だけ**に掛け、`struct` 宣言は 1 本のままにできた:

```swift
#if !os(watchOS)
@AppIntent(schema: .system.open)
#endif
public struct OpenTodoIntent: OpenIntent, URLRepresentableIntent {
```

iOS Simulator のクリーンビルドで、**watch スライスは確かに merge されているのに**
（統合メタデータに `WatchTodoAppEntity` / `WatchCategoryAppEntity` が居る）
`OpenTodoIntent` の schema は残った。**Intent は型名を分けなくてよい**。

## 4. 適合できた 3 本（マクロ 1 行）

```
DeleteTodosIntent   [{'domain': 'reminders', 'name': 'DeleteRemindersIntent', 'version': '1.0.0'}]
OpenCategoryIntent  [{'domain': 'system',    'name': 'OpenIntent',            'version': '1.0.0'}]
OpenTodoIntent      [{'domain': 'system',    'name': 'OpenIntent',            'version': '1.0.0'}]
```

- SSU: `en.lproj/nlu.appintents` / `ja.lproj/nlu.appintents` 生成あり、
  `must match regular expression` / `Could not archive SSU` / `emitted errors` は 0 件
- `swift test`（TodoAppIntents パッケージ）140 tests passed
- `.system.open` の要求は `target: any AppEntity` の 1 つだけなので、`OpenIntent` 適合済みの
  2 本はそのまま通った。`.reminders.deleteReminders` も `entities: [ReminderEntity]` 要求 =
  `DeleteIntent` の形そのもの

## 5. 残した 2 本の要求差分（#138）

`AddTodoIntent` → `.reminders.createReminder`:

```
Missing required parameter 'note' / 'isFlagged' / 'images' / 'list' / 'recurrence' /
                           'locationTrigger' / 'section'
Required AppSchemaIntent parameter 'urls' must not be optional
Required AppSchemaIntent parameter 'tags' must not be optional
Parameter 'tags' does not match required AppSchemaIntent parameter of 'Set<String>'
Parameter 'dueDate' does not match required AppSchemaIntent type 'DateComponents'
Intent parameters must be optional when not defined by the AppSchemaIntent   ← isFavorite
```

`UpdateTodoIntent` → `.reminders.updateReminder`:

```
Missing required parameter 'note' / 'isFlagged' / 'isCompleted' / 'list' /
                           'recurrence' / 'locationTrigger' / 'target'
Parameter 'dueDate' does not match required AppSchemaIntent type 'DateComponents'
Parameter 'tags' does not match required AppSchemaIntent parameter of 'Set<String>'
Intent parameters must be optional when not defined by the AppSchemaIntent   ← todo
```

ここから分かった規則 2 つ:

- **スキーマ外のパラメータは持てるが optional 必須**。アプリ固有の `estimatedDuration` /
  `assignee` は残せる。非 optional の `isFavorite` / `todo` が弾かれた
- **entity 側で使った `@ComputedProperty` の別名は使えない**。パラメータは storage なので、
  `note` / `isFlagged` / `target` はリネームで満たすしかない（`dueDate` の型衝突を
  `dueDateValue` + computed で逃げた entity 側の手が効かない）

差分の大きさが UI 呼出元（追加フォーム / 属性エディタ）に波及するので、
**既存 Intent を寄せるか Siri 向けに別 Intent を足すか**の判断を #138 に残した。

## 6. ドキュメントに穴があった

`createReminder` / `updateReminder` / `createList` / `createSection` / `reminders.group` /
`reminders.section` は **`docs/` に 1 度も登場していなかった**（grep 0 件）。#56 は
「entity の適合コスト」を測って決着させた話で、Intent 側は検討記録すら無い状態だった。
状態の地図（APP_INTENTS_API_COVERAGE.md）に 6 行足し、残りは #138 / #139 に起票した。
