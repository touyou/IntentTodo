# App Schema と watch ターゲットが両立しない件（#56 / #86）

[reminder スキーマ適合](2026-08-29-reminder-schema-conformance.md)（#83）で入れた
**`__appSchemaEntity` の手書き適合 5 箇所を撤去**し、`TodoAppEntity` を 2 系統に分けた。

きっかけは「手書きはちょっと非推奨な気がする。コンパイルエラーが出るならそれはスキーマに
非推奨なことをしているということでは」という指摘。**そのとおりだった**ので、なぜそうなのかを
SDK とビルドログまで降りて確かめた記録。

現在のルールは [AGENTS.md](../../AGENTS.md) と
[docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md) にある。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f） |
| 実測日 | 2026-08-29 |

## 1. 「reminders が watchOS で使えない」は言い方が狭すぎた

`#83` 以降ずっと「`reminders` ドメインの assistant schema は watchOS で unavailable」と書いてきた。
これは嘘ではないが、読んだ人が「では別ドメインなら？」と考えてしまう書き方だった。

SDK の swiftinterface を全数走査した結果、**23 ドメインすべて**が非対応:

| ドメイン | watchOS | tvOS |
|---|---|---|
| `audio` `books` `browser` `calendar` `camera` `clock` `files` `journal` `mail` `maps` `messages` `notes` `phone` `photos` `presentation` `reader` `reminders` `spreadsheet` `system` `whiteboard` `wordProcessor` | ❌ | ❌ |
| `assistant` | ❌ | ❌（macOS / visionOS も ❌） |
| `visualIntelligence` | ❌ | ❌（visionOS も ❌） |

**例外ゼロ。** ドメインを変えても、自前スキーマにしても回避できない。

理由も裏が取れた。WWDC 2026 Apple Intelligence Group Lab (`35:34`):

> The new Siri AI is available on iPhone, iPad, Mac, and visionOS. It is not available on HomePod.

App Schema は「その Siri に語彙を渡す」仕組みなので、提供範囲がそのまま availability になっている
（`assistant` が iOS 限定、`visualIntelligence` が visionOS 除外、という細かい差まで一致する）。
取りこぼしではなく**意図的で一貫した線引き**。

> 一方 `@AppEntity(schema:)` **マクロ自体**は watchOS SDK でも
> `@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)` で available。
> 渡せるドメインが 1 つも無いので、この availability は実質空振り。

## 2. 手書き `__appSchemaEntity` がなぜダメか

`#83` は「`AssistantSchemaEntity` プロトコル自体は watchOS でも available だから、識別子を
文字列で手書きすれば適合できる」と書いた。動くのは事実だが、採ってはいけない形だった。

**プロトコル要求ですらない。** SDK を見ると `AssistantEntity` / `AssistantSchemaEntity` は
実質空のプロトコルで、`__appSchemaEntity` はどこにも要求されていない。

```swift
public protocol AssistantEntity : AppEntity {}
public protocol AssistantSchemaEntity : AssistantEntity {
  static var isAssistantOnly: Bool { get }   // default 実装あり
}
```

つまりこの名前は**マクロが生やし、メタデータ抽出器が読むだけの非公開の申し合わせ**。
`@attached(extension, ..., names: named(__appSchemaEntity))` が示すとおりマクロの生成物であって、
API ではない。Apple の App Intents ガイダンスも "Never recommend or emit non-public or
underscore-prefixed symbols" と明言している。名前が変われば**ビルド緑のままスキーマだけ静かに
消える**——このリポジトリが一番恐れている壊れ方そのもの。

**公開 API での抜け道も無い。** ドメイン名前空間を経由せず `AppSchema.Entity("ListEntity")` を
自分で組めれば済むが、`init(_:)` は `@usableFromInline internal`。

**内容としても誤り。** スキーマという機能が存在しないプラットフォーム向けのメタデータに
「この型は `reminders.ReminderEntity` です」と書いていることになる。

そして踏んでいたコンパイルエラー（`Property 'list' type does not match required
AppSchemaEntity property type 'ListEntity'`）は「スキーマに反することをしている」ではなく、
**watchOS で宣言すべきでない適合を宣言したから検証が走った**だけだった。正しい直し方は
「検証を黙らせる」ではなく「watchOS では宣言しない」。

## 3. では素直に `#if` で切れないのはなぜか — ビルドログで確定

`#if !os(watchOS)` で適合を切ると、iOS の出荷メタデータから `reminders.ReminderEntity` が消える
（`#83` の観測。今回も再現した）。この原因を推測で済ませず、ビルドログまで追った。

iOS アプリターゲットの `appintentsmetadataprocessor` に渡る `--metadata-file-list` /
`--static-metadata-file-list` の中身:

```text
…/Debug-iphonesimulator/TodoAppIntents.appintents/Metadata.appintents/extract.actionsdata
…/Debug-iphonesimulator/UI.appintents/Metadata.appintents/extract.actionsdata
…
…/Debug-watchsimulator/IntentTodoWatchApp.app/Metadata.appintents/extract.actionsdata   ← watchOS
…/Debug-watchsimulator/TodoAppIntents.appintents/Metadata.appintents/extract.actionsdata ← watchOS
…/Debug-watchsimulator/WatchUI.appintents/Metadata.appintents/extract.actionsdata        ← watchOS
```

**iOS アプリのメタデータに watchOS スライスが入力として渡っている。** このファイルリストは
`WriteAuxiliaryFile ... IntentTodo.DependencyMetadataFileList` で **Xcode が自動生成**していて、
こちらが書いたものではない。watch アプリを埋め込む構成なら自動的にこうなる。

マージ結果は型名キーの辞書 1 エントリで、同じ mangled name にスキーマ有り / 無しが並ぶと
**スキーマ無し側が残る**（iOS 側の入力は全部スキーマを持っているのに、出力は `[]`）。

→ **この制約は我々のプロジェクト構成ではなく Apple のビルドシステム側**。裏付けとして:

- Apple 公式の Apple Intelligence サンプル 4 本（Calendar / Messaging / Music / Photo）は
  **どれも watch ターゲットを持たない**（`SUPPORTED_PLATFORMS` は iphoneos / macosx / xros のみ）。
  この組み合わせは公式サンプルで一度も踏まれていない
- ドキュメントにも App Schema のプラットフォーム制限や、複数ターゲット / watch との
  メタデータマージについての記述は無い

## 4. 採った形

**`TodoAppEntity` にも watch 用の別型名を与える。** 既存 4 型と同じパターンに揃えた。

| 型 | 非 watchOS | watchOS |
|---|---|---|
| `TodoAppEntity` | `@AppEntity(schema: .reminders.reminder)` | `WatchTodoAppEntity`（スキーマ無し・スキーマ要求プロパティ無し） |
| `CategoryAppEntity` | `@AppEntity(schema: .reminders.list)` | `WatchCategoryAppEntity` |
| `TodoListType` | `@AppEnum(schema: .reminders.listType)` | `WatchTodoListType` |
| `TodoLocationTriggerEvent` | `@AppEnum(schema: .reminders.locationTriggerEvent)` | `WatchTodoLocationTriggerEvent` |
| `TodoLocationTriggerAppEntity` | `@AppEntity(schema: .reminders.locationTrigger)` | **型ごと無し**（`#if !os(watchOS)`） |

得られたもの:

- **手書き `__appSchemaEntity` が 5 → 0**
- **iOS の出荷メタデータで、各スキーマを主張する型が 1 つずつになった。** `#83` の形では
  `CategoryAppEntity` と `WatchCategoryAppEntity` が**両方** `reminders.ListEntity` を主張していて、
  1 アプリに同じスキーマの型が 2 つある状態だった（`inspect_appintents_metadata.py` は
  `all clear` を返すので気づけない）
- **`typeDisplayRepresentation` の override 警告が 5 → 1**（残る 1 件は `TodoAppEntity` の意図的な
  override。`numericFormat` を持たせるため）
- watch のメタデータは `assistant schemas: none` に戻った = Apple の意図どおり
- SwiftLint 違反も 3 → 1（ファイル分割の副産物）

重複のコストは**プロパティ宣言と init のみ**。表示・クエリ・等価性・deferred ローダーは
`TodoAppEntity+Shared.swift` に 1 つだけ置き、`typealias` 経由で両系統に効かせている。
watch 側はスキーマ要求の 9 プロパティを持たないので、実際の重複は 410 行中 200 行弱。

### 実測でわかった落とし穴: const 抽出は `typealias` を通らない

`Transferable` / `URLRepresentableEntity` を共有 extension（`extension TodoAppEntity: Transferable`）に
置いたら、**watchOS スライスだけ**でメタデータ抽出が落ちた。

```text
TodoAppEntity.swift:454: error: The property 'transferRepresentation' must be static,
have a compile-time constant value, and cannot be computed or dynamic
```

これらの宣言は const 抽出（swiftconstvalues）で読まれるため、`typealias` 越しでは具象型に
結び付かない。**具象型名で書く**（watch 側は `extension WatchTodoAppEntity: Transferable`）。
最初「同じファイルに置けば通る」と読み違えて 1 往復したが、`--platform-family watchOS` の行を
見て typealias が原因だと分かった。

> 教訓: このエラーは「iOS では通って watchOS だけ落ちる」形で出る。`#if` でプラットフォームを
> 分けた直後は、**エラー行だけでなくどのスライスで出たか**を読む。

## 5. 残したこと

- **Feedback を起票する**（追跡: **#86**）。「App Schema が watchOS に無い」ことと「埋め込んだ watch アプリの
  メタデータが iOS アプリにマージされる」ことが組み合わさると、**共有 entity を持つアプリは型を
  二重定義しない限りどのスキーマにも適合できない**。しかも無言で壊れる
- watch の Shortcuts からは、スキーマ要求プロパティ（`tags` / `urls` / `recurrence` /
  `locationTrigger` / `completionDate` など）が見えなくなった。watch にフォームは無く
  読み取り経路も無かったので実害はないが、必要になったら watch 側の型に足す
