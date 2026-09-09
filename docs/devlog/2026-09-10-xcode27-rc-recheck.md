# Xcode 27 RC で SDK 制約を棚卸しした件（#57）

現在の結論は [AGENTS.md](../../AGENTS.md) と [docs/APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md)
にある。ここには **RC（27A266a）で何をどう測って、[beta 6 の記録](2026-08-28-xcode27-beta6-recheck.md)の
どれが変わり、どれが変わらなかったか**を残す。

## 環境

| | |
|---|---|
| Xcode | 27.0 RC（27A266a）/ `/Applications/Xcode-27.0.0-release.candidate.app` |
| SDK | iOS / macOS / watchOS / tvOS / visionOS すべて 27.0 |
| iOS Simulator runtime | 27.0（**24A434**）。beta 6 のときは beta ランタイムだった |
| host macOS | 26A5425a |
| 実測日 | 2026-09-10 |

> `/Applications/Xcode.app` は 26.6（17F113）のまま。RC の `Contents/Developer/usr/bin` が PATH の先に
> 入っている（`xcode-select -p` は 26.6 を指したまま）。Xcode.app として起動しているのは RC。

## 結論の要約

| 項目 | beta 6 | RC | 変化 |
|---|---|---|---|
| `PlaceDescriptor` の SSU training バグ（FB24548956） | 未解消 | **未解消** | なし |
| watchOS の assistant schema | unavailable | **unavailable** | なし |
| `AudioContext` | `.nowPlaying` のみ | **`.nowPlaying` のみ** | なし |
| `indexingKey:` / `IndexedEntityQuery` の面 | watchOS / tvOS のみ不可 | **同じ** | なし |
| `TargetContentProvidingIntent` / `onAppIntentExecution` | macOS / watchOS unavailable | **同じ** | なし |
| 27.0 で新規に生えた公開 API | 4 件（記録済み） | **追加なし** | なし |
| **AppIntentsTesting のシミュレータ実行** | 全緑 | **全件 skip（803）** | **RC で退行** |

**SDK の API 面は beta 6 から動いていない。代わりに、シミュレータで AppIntentsTesting が
まったく走らなくなった。**

## 1. `PlaceDescriptor` の SSU training バグ: **未解消**（回避策は存置）

`AddTodoIntent.location` を `String?` → `PlaceDescriptor?` に戻し、`AddTodoView` から
`PlaceDescriptor` を渡す形にして、**共有 DerivedData を汚さない別ディレクトリでクリーンビルド**した。

```
xcodebuild -project IntentTodo.xcodeproj -scheme IntentTodo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' \
  -derivedDataPath /tmp/ITRCProbeDD CODE_SIGNING_ALLOWED=NO build
```

結果は beta 3〜6 と同一:

```
error: GeoToolbox.PlaceDescriptorEntity must match regular expression ^[a-zA-Z_][a-zA-Z_$0-9]*$ # variables.2.name
2026-09-10 08:04:52.350 appintentsnltrainingprocessor[88520:9403429] error: Could not archive SSU artifacts. Check build log.
Command AppIntentsSSUTraining emitted errors but did not return a nonzero exit code to indicate failure
```

- ログ中の時刻が当日（stale ログではない。beta 5 / 6 で踏んだ読み違えを毎回この形で潰す）
- `** BUILD SUCCEEDED **` のまま、`nlu.appintents` の生成数は **0**

→ probe は revert し、`String` 退避を維持した。

比較として、退避したままの現行ツリーでは同じクリーンビルドで
`Archiving all locales` → `archived 2 locales` が出て、`en.lproj/nlu.appintents` と
`ja.lproj/nlu.appintents` が生成される。

`variables.2.name`（beta 6 は `variables.1.name`）とインデックスが 1 つずれているのは、
その後 `@Parameter` が増えたため。バグの内容は同じ。

## 2. watchOS の assistant schema: **未解消**（フォールバックは存置）

RC の watchOS 27 SDK の swiftinterface で、`.reminders`（Intent / Entity / Enum の 3 系統とも）に
`@available(watchOS, unavailable)` が付いたままであることを確認した。`.system` も同じ。

```
@available(anyAppleOS 27.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension AppSchemaEntity where Self == AppSchema.Entity {
  public static var reminders: some AppSchema.RemindersEntity
```

→ `WatchCategoryAppEntity` / `WatchTodoListType` の 2 系統宣言と
`ShowTodoSearchResultsIntent` の `#if !os(watchOS)` はそのまま。

出荷メタデータ側の副作用が無いことも確認した（`inspect_appintents_metadata.py`、後述）。

## 3. API 差分: **公開 API の追加は無い**

RC の iOS `AppIntents.swiftinterface` から公開型（protocol / struct / class / enum / actor / macro）
353 件を抽出し、リポジトリ（コード + docs + skills）に一度も名前が出ないものを availability で
仕分けた。**27.0 available かつ未記録の公開型は 0 件**（唯一引っかかった
`_ModelDelegationIntentEnabledStatus.UnavailableReason` は `@_documentation(visibility: internal)`）。

メンバ（`func` / `var`）側の同じ仕分けでも、27.0 で新規かつ未記録のものは 0 件。
`.audio.playAudiobook` が `@available(anyAppleOS, deprecated: 27.0, message: "Use .audio.playAudio instead")`
になっているのを見つけたが、本アプリが触らない audio schema の話。

beta 6 で記録した 4 件（`LongRunningTaskOptions` / `RunSystemShortcutIntent` /
`IntentResponseStream` / `AppUnionValueCasesProviding`）の判断も RC で変わらない:

- `SystemShortcut` は RC でも `public static func ==` しか公開されておらず、**公開イニシャライザが無い**
- `IntentSystemContext` は `preciseTimestamp` / `isVoiceOnly` / `locale` の 3 つ（呼出元の識別には使えない）
- `AudioContext` は `.nowPlaying` のみ、`AppEntityContext` のファクトリは `.audio(_:)` のみ
  → `RelevantEntities` が todo ドメインに適合不能という結論は RC でも同じ

`indexingKey:` / `IndexedEntity` / `IndexedEntityQuery` の面も beta 6 と同じ
（iOS / macOS / visionOS available、watchOS / tvOS unavailable。watchOS SDK には
`indexingKey:` オーバーロード自体が存在しない）。
`TargetContentProvidingIntent` / `onAppIntentExecution` も `@available(macOS, unavailable)` /
`@available(watchOS, unavailable)` のまま（native macOS SDK には iOSSupport 側の
`_AppIntents_SwiftUI` しか無い）。

## 4. **AppIntentsTesting がシミュレータで走らなくなった**（RC の退行 / #119）

`IntentTodoUITest` の 3 スイート（`TodoEntityQueryTests` / `TodoIntentExecutionTests` /
`TodoSystemIntegrationTests`）が、beta 6 では全 23 件 passed だったのに、RC では
**1 件も実行されない**。

`AppIntentsTestCase.setUp()` が `suggestedEntities()` を 30 秒ポーリングし、毎回これで落ちる:

```
Error Domain=AppIntentsServicesSecurityErrorDomain Code=803
"Unable to run internal tests on a Customer build"
```

同時に、シミュレータの `intelligencetasksd` が**クラッシュループしている**（当日 26 本の crash report）:

```
libswiftXPC.dylib  static XPCPeerRequirement.hasEntitlement(_:)
  → __XPC_API_MISUSE__
XPC-swiftoverlay/PeerRequirement.swift:13:
  Fatal error: API Misuse | XPC Peer Requirement isn't implemented on simulators yet
```

呼び出し元は `IntelligenceTasksEngine`。**エンタイトルメント確認の XPC がシミュレータで
未実装のまま trap する**という形で、803 の security error と話が繋がる位置にいる
（因果は Apple 側にしか確定できないので、ここでは「同時刻に起きている」までに留める）。

### 切り分けたこと

| 疑い | 実測 |
|---|---|
| 並列テスト（clone）のせい | `-parallel-testing-enabled NO` でも 803 |
| DerivedData / デバイスの残留状態 | `simctl create` した**新品のデバイス**でも 803 |
| dyld shared cache が beta のまま | `simctl runtime dyld_shared_cache update --all` 済み。`usable` 応答、変化なし |
| リポジトリ側の設定 | 変更していない。同じツリーが beta 6 では全緑だった |

### いちばん危ないところ: **skip なので緑になる**

`waitUntilIntentsAreDiscoverable` は `XCTSkip` を投げる。したがって単体で走らせると

```
Executed 1 test, with 1 test skipped and 0 failures (0 unexpected)
Test Suite 'IntentTodoUITest.xctest' passed
```

と出る。**AppIntents の検証が 1 行も実行されていないのに TEST SUCCEEDED になる。**
[docs/TESTING.md](../TESTING.md) の「緑になる嘘テスト」がそのまま起きている。
skip の扱いは #119 で決める。

### 副次: Control Widget が trap する

同じテスト実行で `IntentTodoWidgetExtension` も落ちている（当日 6 本）:

```
libswiftCore.dylib  _assertionFailure(_:_:file:line:flags:)
WidgetKit           (?)
IntentTodoWidgetExtension.debug.dylib  closure #1 in QuickAddTodoControl.body.getter
```

`QuickAddTodoControl` は `ControlWidgetButton(action: LaunchAppIntent.addTodo())` だけの
コントロール。RC の `WidgetKit/ControlAction.swift` には
`Unable to create an LNAction from` / `Unable to obtain LNActionMetadata from` /
`Can't create CHSIntentReference from` という assertion 候補があり、いずれも
**App Intents メタデータの解決失敗**を指す。803 と同根の疑いが濃いが、
WidgetKit 側のシンボルを解決できていないので断定はしない（#119）。

アプリを普通に起動した限りではこの crash は出ない（テスト実行時のみ観測）。

## 5. 回帰確認（RC / 変更なしのツリー）

- iOS シミュレータ（iPhone 17 Pro Max / iOS 27.0）でクリーンビルド **`** BUILD SUCCEEDED **`、error 0**
- SSU: `archived 2 locales`、`en.lproj/nlu.appintents` と `ja.lproj/nlu.appintents` を生成
- パッケージのユニットテスト（`DomainTests` / `RepositoryTests` / `TodoAppIntentsTests` / `UITests`）
  **244 件 passed / 失敗 0**
- `inspect_appintents_metadata.py`: 11 バンドル、**`checks: all clear`**
  - `TodoAppEntity` 20 props、`[Indexed, AssistantEntity, Syncable, URLRepresentable, reminders.ReminderEntity]`
  - assistant schema 6 件（`reminders.ListEntity` / `ReminderEntity` / `LocationTriggerEntity` /
    `ListType` / `LocationTriggerEvent` / `system.SystemSearchInAppIntent`）が iOS 側に残り、
    watchOS 側は `assistant schemas: none`（意図どおり）
  - App Shortcut 8 件、phrase の欠落なし
- **AppIntentsTesting の 3 スイートは実行できていない**（§4）

## 6. ビルド警告 2 種（RC で観測 / 出所は未確定）

beta 6 のときの記録に警告が無いので「RC で増えた」とは断定できない（当時 0 件だったとは書かれていない）。
どちらも実体のある指摘なので #120 に切り出した。

| 警告 | 件数 | 中身 |
|---|---|---|
| `no calls to throwing functions occur within 'try' expression [#UnnecessaryEffectMarker]` | 10 | `TodoAppEntity+Shared.swift` の `try await MainActor.run { … }`。クロージャが throw しない |
| `The property 'typeDisplayRepresentation' should not be overridden in an AppEntity that conforms to a schema` | 1 | `TodoAppEntity+Shared.swift:24`。`reminders.ReminderEntity` に適合しているので schema 側が持つ |

2 つ目は**消すと UI コピーが変わる**（"Todo" / "N todos" が schema 由来の表示に置き換わる）ので、
機械的に直さず #120 で判断する。

## 7. 測らなかったもの

- **watchOS の `run()` が 4025 で落ちる件**（#30）。iOS 側で AppIntentsTesting 自体が
  走らない状態なので、watchOS を測っても切り分けにならない
- 実機の Siri / Visual Intelligence 経路（#30）。§4 が実機でも起きるかはここでは判定できない
- macOS / visionOS ターゲットのビルド。iOS で退行が出た時点で、まずそちらを確定させた
