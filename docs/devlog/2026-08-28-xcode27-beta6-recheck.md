# Xcode 27 beta 6 で SDK 制約を棚卸しした件（#57）

現在の結論は [AGENTS.md](../../AGENTS.md) と [docs/APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md)
にある。ここには **beta 6（27A5252f）で何をどう測って、beta 5 の記録のどれが変わり、どれが変わらなかったか**
を残す。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f）/ `/Applications/Xcode-27.0.0-beta.6.app` |
| SDK | iPhoneOS27.0 / WatchOS27.0 |
| 実測日 | 2026-08-28 |

> `/Applications/Xcode.app` は 26.6（iOS 26.5 SDK）で iOS 27 SDK を持たない。CLI から測るときは
> beta 6 の `Contents/Developer/usr/bin` を PATH の先に置く（`xcode-select -p` は 26.6 を指したまま）。

## 1. `PlaceDescriptor` の SSU training バグ: **未解消**（回避策は存置）

`35d772f` の String 退避を一度戻して（`AddTodoIntent.location` / `TodoAppEntity.location` を
`PlaceDescriptor?` へ、`AddTodoView` を `locationDescriptor` へ）、**共有 DerivedData を汚さない
別ディレクトリでクリーンビルド**した。

```
xcodebuild -project IntentTodo.xcodeproj -scheme IntentTodo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' \
  -derivedDataPath /tmp/IntentTodoCleanDD CODE_SIGNING_ALLOWED=NO build
```

結果は beta 3〜5 と同一のまま:

```
error: GeoToolbox.PlaceDescriptorEntity must match regular expression ^[a-zA-Z_][a-zA-Z_$0-9]*$ # variables.1.name
error: Could not archive SSU artifacts. Check build log.
Command AppIntentsSSUTraining emitted errors but did not return a nonzero exit code to indicate failure
```

→ revert は取り消し、`String` 退避を維持した。

**測り方の注意（beta 5 のときの記録どおり）**: この判定は**必ずクリーンビルドで**行う。
`Metadata.appintents` が変わっていないと `AppIntentsSSUTraining` はそもそも再実行されず、
インクリメンタルのログには**前回の実行時刻の出力がそのまま並ぶ**。今回も編集直後の
インクリメンタルビルドは緑で、SSU セクションのタイムスタンプが編集前のものだった
（「直った」と読み違えられる形）。ログの中の時刻を見る。

## 2. watchOS の assistant schema: **未解消**（フォールバックは存置）

beta 6 の watchOS SDK の swiftinterface で、`.reminders` / `.system` の両ドメインとも
`@available(watchOS, unavailable)` が付いたままであることを確認した。

```
$ grep -B3 'AppSchema.Entity("reminders")' .../WatchSimulator.sdk/.../AppIntents.swiftinterface
@available(anyAppleOS 27.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
```

実ビルドでも同じ（`.reminders.reminder` を使う使い捨てファイルを置いたときの watchOS 側の診断）:

```
error: 'reminders' is unavailable in watchOS
error: 'reminder' is unavailable in watchOS
```

→ `WatchCategoryAppEntity` / `WatchTodoListType` の 2 系統宣言と
`ShowTodoSearchResultsIntent` の `#if !os(watchOS)` はそのまま。

畳めていないこと自体の副作用が出ていないことも確認した（`inspect_appintents_metadata.py`）:
出荷メタデータに `reminders.ListEntity` / `reminders.ListType` / `system.SystemSearchInAppIntent`
が残っており、`checks: all clear`。

## 3. `.reminders.reminder` 本体の適合（#56）は **SSU バグと同じ根に当たる**

据え置きの理由を「マクロ生成 init + 入れ子サブエンティティの再設計コスト」と書いていたが、
それ以前に **reminder スキーマは `locationTrigger`（`LocationTriggerEntity`）を持つ** ため、
適合すると `PlaceDescriptor` が再び `@Property` の系譜に入る。§1 が未解消のまま適合しても
SSU のエラーに戻るだけなので、**#56 は #57 §1 が解決するまで動かせない**（依存関係を #56 に追記した）。

なお `@AppEntity(schema: .reminders.reminder)` のマクロ生成物そのものは beta 6 でも
`extension X: AssistantSchemaEntity { static let __appSchemaEntity = "reminders.reminder" }` のみで、
beta 5 から変わっていない（要求プロパティの検証は後段のメタデータ抽出で走る）。

## 4. beta 6 で見つけた API 差分

`AppIntents` の公開シンボルを swiftinterface から全部並べ、リポジトリのどこにも名前が出てこない
ものを availability で仕分けた。**27.0 で入っていてまだ記録が無かったのは 4 つだけ**で、
いずれも本アプリで採用する筋がない。

| API | 何か | 判断 |
|---|---|---|
| `LongRunningTaskOptions` / `performBackgroundTask(options:)` | `.requiresGPU` を宣言できる option set | GPU を使う処理が無い |
| `RunSystemShortcutIntent` / `SystemShortcut`（iOS 限定） | システム側のショートカットを実行する system intent | `SystemShortcut` に公開イニシャライザが無く、アプリからは値を作れない |
| `IntentResponseStream` | `_ModelDelegationIntent` の応答をストリームで返す入れ物 | 下線付き（`@_documentation(visibility: internal)`）。公開 API として使えない |
| `AppUnionValueCasesProviding` | `@UnionValue` マクロが生成する裏側のプロトコル | 既に `TodoOrCategory` で採用済みの機能の内部型 |

**変わったもの**: `AudioContext` は beta 6 でも `.nowPlaying` だけで、`.workout(activityType:)` は
依然として存在しない。`AppEntityContext` のファクトリも `.audio(_:)` のみ。
→ `RelevantEntities` が todo ドメインに適合不能という結論は beta 6 でも同じ。

`TargetContentProvidingIntent` / `onAppIntentExecution` の `@available(macOS, unavailable)` /
`@available(watchOS, unavailable)` も beta 6 のまま（`_AppIntents_SwiftUI` の swiftinterface で確認）。

## 5. visionOS では Spotlight index が使える（唯一のコード変更）

制約を 1 つずつ SDK で確かめる過程で、`@Property(indexingKey:)` を
`#if os(iOS) || os(macOS)` で囲っている前提が beta 6 の SDK と合っていないことに気づいた。

| シンボル | availability |
|---|---|
| `EntityProperty.init(title:indexingKey:)` | `macOS 15.4, iOS 18.4, watchOS 11.4, tvOS 18.4, visionOS 2.4` + `@available(watchOS, unavailable)` `@available(tvOS, unavailable)` |
| `IndexedEntity` | `macOS 15.0, iOS 18.0, visionOS 2.0` |
| `CSSearchableIndex.indexAppEntities(_:priority:)` | 同上（visionOS SDK の swiftinterface にも居る） |
| `IndexedEntityQuery` | `macOS 27.0, iOS 27.0, visionOS 27.0` |

つまり beta 6 で **unavailable なのは watchOS / tvOS だけ**。`CoreSpotlight.framework` も
visionOS SDK にある。

これまでの記録は「`indexingKey:` オーバーロードは iOS / macOS でしか vend されない。visionOS / watchOS では
`Extra argument 'indexingKey'` + `Cannot infer key path type` でビルド失敗する」（`docs/insights/03-app-intents-core.md`）
だった。**どの beta で測ったかを書いていなかった**ため、

- Apple が途中の beta で visionOS を available にした
- 当時の切り分けが誤っていた（watchOS で落ちたのを visionOS にも広げて書いた）

のどちらなのかは今から判別できない。**今後 availability を記録するときは、落ちた面・試した面・
測った SDK を書き分ける**（この教訓は AGENTS.md 側ではなくここに残す）。

`#if os(iOS) || os(macOS)` を `|| os(visionOS)` へ広げた（4 ファイル + テスト 1 ファイル）:

- `TodoAppEntity`（`indexingKey` の分岐 / `IndexedEntity` 準拠）
- `TodoSpotlightIndex` / `TodoService+Spotlight` / `TodoEntityQuery`（`IndexedEntityQuery`）

確認:

- visionOS シミュレータ（Apple Vision Pro / visionOS 27.0）で `** BUILD SUCCEEDED **`
- visionOS の出荷メタデータで `TodoAppEntity` に **`com.apple.appintents.entity.Indexed`** が付き、
  `contentDescription`（`indexingKey` のマップ先）も入っている（`inspect_appintents_metadata.py`）
- iOS / macOS もビルド green（watchOS は分岐が変わらないまま iOS ビルドに同梱されて緑）


## 6. 回帰確認

- iOS シミュレータ（iPhone 17 Pro Max / iOS 27.0）でクリーンビルド green
- `AppIntentsTesting` の 23 テスト（`TodoEntityQueryTests` / `TodoIntentExecutionTests` /
  `TodoSystemIntegrationTests`）全緑
- `inspect_appintents_metadata.py`: 11 バンドル、`checks: all clear`

## 7. 測らなかったもの

- **watchOS の `run()` が 4025 で落ちる件**は再検証していない。使い捨ての watch テストを書いて
  watchOS シミュレータを起こす必要があり、そのシミュレータ自体が
  `FBSOpenApplicationServiceErrorDomain Code=1` で不安定という記録がある（[07-platform-specific.md](07-platform-specific.md)）。
  #30 の手動確認に残したまま。
- 実機の Siri / Visual Intelligence 経路（#30）。beta 6 でも自動化できる領域ではない。
