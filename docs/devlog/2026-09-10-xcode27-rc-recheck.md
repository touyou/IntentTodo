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
| **AppIntentsTesting のシミュレータ実行** | 全 23 件 passed | **全 23 件 passed** | なし（[誤診した](#4-appintentstesting-は壊れていないcode_signing_allowedno-が原因だった119)） |

**SDK は beta 6 から何も動いていない。** 一度「AppIntentsTesting が RC で壊れた」と書いたが、
**それはこちらが `CODE_SIGNING_ALLOWED=NO` を付けて `test` を走らせていたせい**だった（§4）。

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

## 4. AppIntentsTesting は壊れていない。**`CODE_SIGNING_ALLOWED=NO` が原因だった**（#119）

> **この節は 2 度書き直している。** 最初は「RC で AppIntentsTesting が退行した」と書いた。
> **それは誤りで、原因はこちらの測り方だった。** 誤診にたどり着いた経緯もそのまま残す。

### 結論

`IntentTodoUITest` の 3 スイート（`TodoEntityQueryTests` / `TodoIntentExecutionTests` /
`TodoSystemIntegrationTests`）は、RC でも **23 件すべて passed**（skip 0 / 失敗 0）。
beta 6 と同じ。

**`xcodebuild ... test` に `CODE_SIGNING_ALLOWED=NO` を付けると、AppIntentsTesting は動かない。**

```
Error Domain=AppIntentsServicesSecurityErrorDomain Code=803
"Unable to run internal tests on a Customer build"
```

### なぜそうなるか

`CODE_SIGNING_ALLOWED=NO` は **UI テストランナーの再署名ごと飛ばす**。すると
`XCTRunner.app` テンプレートの identity がそのまま残る:

| | 通常のビルド | `CODE_SIGNING_ALLOWED=NO` |
|---|---|---|
| runner の `Identifier` | `dev.touyou.IntentTodo.IntentTodoUITest.xctrunner` | **`com.apple.XCTRunner`** |
| runner の署名 | `flags=0x2(adhoc)` | **`flags=0x0(none)`**（未署名） |
| アプリ本体 | ad-hoc 署名 | `linker-signed` のみ |

AppIntentsTesting はテスト対象アプリの App Intents をアプリのプロセス経由で叩くので、
**「このランナーはそのアプリのテストランナーである」ことを署名で確かめている**。
ランナーが `com.apple.XCTRunner` のままだとその紐付けが成立せず、
`AppIntentsServicesSecurityErrorDomain` が拒否する。

### 因果の確定（同じデバイス・同じテスト・署名の有無だけを変えた）

| ビルド | 結果 |
|---|---|
| `CODE_SIGNING_ALLOWED=NO` なし | **passed**（8.5 秒） |
| `CODE_SIGNING_ALLOWED=NO` あり | **skipped**、803 |
| なし / 3 スイート全部 | **23 passed / 0 skipped / 0 failed / 803 は 0 件** |

### 誤診の経緯（同じ間違いを繰り返さないために）

1. SSU バグの確認（§1）で `CODE_SIGNING_ALLOWED=NO` を使った。**`build` には正しい**
   （署名なしでメタデータ抽出と SSU training は走る）
2. そのままコマンドラインを使い回して `test` を走らせた。**ここが間違い**
3. 803 が出た。文面が "Customer build" で、シミュレータランタイムが beta から
   Customer ビルド（24A434）へ変わった直後だったので、**SDK 側の退行だと読んだ**
4. 並列テスト / デバイス残留状態 / dyld cache を潰して「環境ノイズではない」と確認したが、
   **どの切り分けでも `CODE_SIGNING_ALLOWED=NO` は付けたまま**だった。
   変数を 1 つも動かしていないので、何回やっても同じ答えしか出ない
5. `intelligencetasksd` などのクラッシュ（後述）が同時に出ていたので、
   **無関係な現象を傍証として採用してしまった**
6. 本人が Xcode から手で実行し、そのログに **803 が 1 件も出ていなかった**ことで発覚した

**教訓**: 「SDK の退行だ」と結論する前に、**自分のコマンドラインと IDE の差分を 1 つずつ潰す**。
とくに「他のコマンドから流用したフラグ」は真っ先に疑う。
`--fail-on` 系の切り分け表を作ると「たくさん試した」感が出るが、
**同じ誤った定数を全行に置いたままなら切り分けになっていない**。

### `CODE_SIGNING_ALLOWED=NO` を使ってよい場所・だめな場所

| 用途 | 可否 |
|---|---|
| `build`（SSU / メタデータ抽出の確認） | ✅ 使ってよい。§1 の SSU 再現はこれで正しい |
| `build-for-testing` / `test` / `test-without-building` | 🚫 **AppIntentsTesting が 803 で全 skip する** |

### 併発していたクラッシュは 803 とは無関係だった

`XPCPeerRequirement.hasEntitlement(_:)` がシミュレータで未実装のまま trap する現象自体は実在する:

```
libswiftXPC.dylib   static XPCPeerRequirement.hasEntitlement(_:)
  → __XPC_API_MISUSE__
XPC-swiftoverlay/PeerRequirement.swift:13:
  Fatal error: API Misuse | XPC Peer Requirement isn't implemented on simulators yet
```

`intelligencetasksd` / `AppIntentsLiveEntityService` / `SettingsSearchReindexService` の
3 プロセスから同一シグネチャで出る。**ただしテストは 23 件すべて通るので、
AppIntentsTesting を妨げてはいない。** これを 803 の傍証に使ったのが誤りだった。

同様に、並列 clone のときだけ出ていた `IntentTodoWidgetExtension` の
`QuickAddTodoControl.body.getter` からの WidgetKit `assertionFailure` も、
署名ありの実行では出ない。

### 残る本物の論点: **skip は緑になる**

原因が自分側だったこととは別に、`waitUntilIntentsAreDiscoverable` が `XCTSkip` を投げるので

```
Executed 1 test, with 1 test skipped and 0 failures (0 unexpected)
Test Suite 'IntentTodoUITest.xctest' passed
```

と出る点は変わらない。**23 件が 1 件も実行されていないのに `TEST SUCCEEDED` になる。**
今回まさにこれで 1 日誤診した。skip の扱いは #119 で決める。

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
- **AppIntentsTesting の 3 スイート 23 件すべて passed**（署名ありのビルドで。§4）

## 6. ビルド警告（#120）

beta 6 のときの記録に警告の件数が無いので「RC で増えた」とは断定できない。

### 直したもの

| 警告 | 件数 | 対応 |
|---|---|---|
| `no calls to throwing functions occur within 'try' expression [#UnnecessaryEffectMarker]` | 10 | `TodoAppEntity+Shared.swift` の 3 箇所で `try await MainActor.run` → `await MainActor.run`。`MainActor.run` は `rethrows` で、クロージャが throw しないので `try` が不要だった。関数側の `async throws` は `@DeferredProperty` のローダー署名として維持 |
| 同上 | 1 | `IntentTodoUITest/AppIntents/TodoEntityQueryTests.swift:142`。クロージャが `try?` を使っているので外側の `try` が不要 |

### `typeDisplayRepresentation` の上書きも外した（本人判断で GO）

**`typeDisplayRepresentation` should not be overridden in an AppEntity that conforms to a schema**
（`TodoAppEntity+Shared.swift:24`、1 件）。

実測すると、**この上書きは出荷メタデータではすでに捨てられていた**。schema 適合の entity は
全部 `displayTypeName` が空になる:

| entity | schema | `displayTypeName.key` |
|---|---|---|
| `TodoAppEntity` | `reminders.ReminderEntity` | **`""`** |
| `CategoryAppEntity` | `reminders.ListEntity` | **`""`** |
| `TodoLocationTriggerAppEntity` | `reminders.LocationTriggerEntity` | **`""`** |
| `SubTaskAppEntity` / `TodoListSummaryEntity` | なし | `"Subtask"` / `"Todo List Summary"` |
| `WatchTodoAppEntity` / `WatchCategoryAppEntity` | なし | `"Todo"` / `"List"` |

`CategoryAppEntity` は上書きしていない（`CategoryAppEntity.swift:33` の宣言は `#if os(watchOS)` 側の
`WatchCategoryAppEntity`）し、`TodoLocationTriggerAppEntity` は宣言なしでビルドが通る
——**マクロが供給しているので、上書きしているのは `TodoAppEntity` だけ**。

watchOS では `TodoAppEntity` が `WatchTodoAppEntity`（schema なしの素の `AppEntity`）の typealias なので、
`#if os(watchOS)` で watch 側にだけ残す形にして測ったところ:

- **警告 0 件**、出荷メタデータは**全 entity で完全一致**（watch も `"Todo"` のまま）、`checks: all clear`
- ただし **Swift レベルの値が `"Todo"` → `""` になる**。マクロが生成するのは**空**の
  `TypeDisplayRepresentation` であって、reminders schema の名前が入るわけではなかった

**「Swift レベル」= プロセス内で Swift が `TodoAppEntity.typeDisplayRepresentation` を読んだ値**で、
システムが読む `Metadata.appintents` とは別。schema 適合 entity については後者がすでに空なので、
**システムから見た挙動は変わらない**。プロセス内で読んでいるのはテスト 1 本だけだった
（`grep` で全ターゲットを確認）。

`TodoAppEntityTests.swift`「TypeDisplayRepresentation names the type」は、実測した契約に書き直した:
watchOS では `"Todo"`、それ以外では**空**。Apple 側が schema 由来の名前を入れ始めたら落ちるので、
黙って食い違うのではなく気づける形になっている。

`DomainTests-product` / `RepositoryTests-product` の
`Metadata extraction skipped, no AppIntents.framework dependency found` は、AppIntents に依存しない
テストバンドルなので想定どおり。対応しない。

## 7. 「緑になる嘘テスト」を潰した（#113）

`audit_intents.py --fail-on error` が error にしていた 3 件と、コンパイラ警告から見つかった 2 件。
**`0 error(s)`** になった。

| 場所 | 何が起きていたか | 直し方 |
|---|---|---|
| `IntentTodoUITest.swift` `testFilterMenu` | フォールバックの連鎖の末尾が「ボタンが 2 個より多い」で、**アプリが起動していれば常に true**。メニューが開かなくても緑 | `TodoFilter` の全ケース + `Sort` の存在を無条件に assert |
| `IntentTodoWatchAppUITest.swift` `testEmptyStateMessage` | 本体まるごとが `if allDoneText.waitForExistence { … }` の中。**要素が出なければ何も検証せず緑** | 無条件 assert |
| `IntentTodoWatchAppUITest.swift` `testToggleTodoCompletion` | 残っていた状態で分岐。else 側は英語ラベル依存で、watch テストは言語を固定していなかった。**そもそも完了トグルを一度も叩いていなかった** | フィクスチャで todo を 1 件用意し、実際にトグルして行が消えることを assert |
| `IntentTodoWatchAppUITest.swift` `testListHasSections` | 「セクションがある **or** 空状態」で、空ストアなら必ず後者で通る。**セクションヘッダを検証していなかった** | フィクスチャ前提で `Upcoming` を無条件 assert |
| `IntentTodoUITest.swift` `addTodo(title:favorite:)` | `if favoriteToggle.exists { tap }`。**`testAddTodoWithFavorite` がお気に入りを一度も検証していなかった**（audit は warn 扱いだったが実害があった） | toggle の存在を assert してから tap |
| `RepositoryTests.swift` / `AppIntentsTests.swift` | `#expect(x != nil)` が非 Optional 相手で**常に true** | 「新品の mock は空」「package は他を巻き込まない」という落ちうる assert に置き換え |

watch 側は前提が揃っていなかったので、そこも埋めた:

- **watch アプリに DEBUG 限定の `-uitest-ephemeral-store` を追加**（iOS と同じ引数・同じ理由）。
  共有ストアはプロセスより長生きするので、前の実行の残りで分岐するしかなかった
- **watch テストの言語を `en` に固定**（iOS 側は既にやっていた）。
  `app.staticTexts["All Done!"]` はホストが ja のままだと永遠に解決しない
- **DEBUG 限定の `-uitest-seed-todo` を追加**。`typeText` が watchOS シミュレータで信用できないので、
  add sheet 経由では行を用意できない。フィクスチャが無いから完了テストは「リストが出た」しか
  見られず、それが「トグルを一度も叩かないまま緑」の正体だった

### watch で分かったこと 2 つ

- **行のタイトルは `staticText` ではなく `button`**（`NavigationLink` のラベルなので）。
  `app.staticTexts["Seeded Todo"]` は解決しない。`app.debugDescription` を吐かせて確定させた:

  ```
  Cell, label: 'Mark as complete, Seeded Todo'
    Button, identifier: 'circle', label: 'Mark as complete'
    Button, label: 'Seeded Todo'
  ```

- **完了させると行はリストから消える**。watch の `@Query` は `!isCompleted` で絞っているので、
  iOS のように `Mark as incomplete` へ変わるのを待っても永遠に来ない。
  最初その形で書いて落ちた（アプリの挙動が正しく、テストの期待が間違っていた）

### assert に歯があることを確認した

直したものが「たまたま緑」でないことを、**わざと壊して落ちることで**確かめた:

| 実験 | 結果 |
|---|---|
| `testFilterMenu` から `filterMenu.tap()` を外す | `XCTAssertTrue failed - Filter menu should offer 'All'` で失敗 |
| watch の期待文字列を存在しないものに差し替え | `XCTAssertTrue failed - Empty state should show 'All Done!' message` で失敗 |
| watch `testToggleTodoCompletion` から `checkbox.tap()` を外す | `XCTAssertTrue failed - Completed todo should leave the list` で失敗 |

いずれも元に戻して再実行し、緑を確認した。

### 残した warn

`audit_intents.py` の warn は 5 件残っている。うち conditional-assert は 2 件で、どちらも
**assert ではなく操作の分岐**なので嘘にならない:

- `IntentTodoUITest.swift:296` — `if list.exists { list.swipeDown() }`。直後の検索フィールドの
  assert は無条件なので、swipe が飛べばそこで落ちる
- `TodoSystemIntegrationTests.swift:133` — `returnToList()` の後片付け

## 8. 測らなかったもの

- **watchOS の `run()` が 4025 で落ちる件**（#30）。iOS 側が通ることが分かったので測り直せる状態
  になったが、今回は測っていない
- 実機の Siri / Visual Intelligence 経路（#30）
- macOS / visionOS ターゲットのビルド
