# 1.0 提出前の下ごしらえをした件（#127）

Xcode 27 が RC まで来たので、[RC の SDK 棚卸し](2026-09-10-xcode27-rc-recheck.md)の続きとして
**App Store に出すために足りていなかったもの**を埋め、Xcode Cloud を叩く `production` ブランチを切った。

ここには**何を足したか・何を測ったか・スクショの自動撮影で何に詰まったか**を残す。
現在のルールは [AGENTS.md](../../AGENTS.md) と [README.md](../../README.md) 側にある。

## 環境

RC 棚卸しと同じ。Xcode 27.0 RC（27A266a）/ 各 SDK 27.0 / iOS Simulator runtime 27.0（24A434）/ 実測日 2026-09-10。

> `xcode-select -p` は 26.6 を指したままで、PATH の先に RC の `usr/bin` が入っている。
> **`xcodebuild` は RC を掴むが `xcrun swift` は 26.6 を掴む**ので、パッケージの `swift test` は
> `DEVELOPER_DIR=/Applications/Xcode-27.0.0-release.candidate.app/Contents/Developer` を付ける。
> 付けないと `package 'domain' is using Swift tools version 6.4.0 but the installed version is 6.3.3` で落ちる。

## 1. 提出でしか効かない設定が 2 つ抜けていた

RC 棚卸しは SDK の制約を見る作業だったので、**提出物としての穴**は見ていなかった。

### `PrivacyInfo.xcprivacy` が無かった

`MissedFeedback` / `TodoFocusFilter` / `TodoSpotlightIndex` が `UserDefaults` を使っている。
required reason API なので、申告が無いとアップロード後に ITMS-91053 の警告メールが来る。

理由コードは 2 つ要る。実装が両方の形を使っているため:

| コード | 意味 | 該当 |
|---|---|---|
| `CA92.1` | アプリ自身からしか見えない情報の読み書き | `TodoSpotlightIndex`（`UserDefaults.standard`） |
| `1C8F.1` | 同じ App Group のアプリ / Extension からしか見えない情報の読み書き | `MissedFeedback` / `TodoFocusFilter`（`suiteName:`） |

置き場は **4 バンドル分**。Apple のドキュメントが
「required reason API を使う executable / dynamic library ごとに、それを含むバンドルが manifest を持つ」
と書いているので、アプリ本体だけでは足りない:

```
IntentTodo.app/PrivacyInfo.xcprivacy
IntentTodo.app/PlugIns/IntentTodoWidgetExtension.appex/PrivacyInfo.xcprivacy
IntentTodo.app/PlugIns/IntentTodoLiveActivityExtension.appex/PrivacyInfo.xcprivacy
IntentTodo.app/Watch/IntentTodoWatchApp.app/PrivacyInfo.xcprivacy
```

**`project.pbxproj` の変更は 0 行だった。** 4 ターゲットのフォルダはすべて
file-system-synchronized group なので、ファイルを置くだけでリソースとして焼かれる。
最初 `IntentTodo/PrivacyInfo.xcprivacy`（= リポジトリ直下）に書いてしまい、
そちらは同期グループの外なので `PBXFileReference` だけが増えてターゲットに入らなかった。
**pbxproj に差分が出たら置き場所を間違えている**、という判定に使える。

### `ITSAppUsesNonExemptEncryption` が空だった

空のままだとビルドを上げるたびに App Store Connect で輸出コンプライアンスを手入力させられる。
`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` を `IntentTodo` と `IntentTodoWatchApp` に入れた
（`UpdateTargetBuildSetting` 経由。Debug / Release 両方に入る）。

## 2. 全プラットフォームの Release ビルドと archive を通した

RC 棚卸しの §8 で「macOS / visionOS のビルドは測っていない」と残していた分。

| 対象 | 結果 |
|---|---|
| `generic/platform=iOS` / Release | `BUILD SUCCEEDED`、warning **0** |
| `platform=macOS,arch=arm64` / Release | `BUILD SUCCEEDED`、warning **0** |
| `generic/platform=visionOS` / Release | `BUILD SUCCEEDED`、warning **0** |
| `generic/platform=watchOS` / Release（`IntentTodoWatchApp Watch App`） | `BUILD SUCCEEDED`、warning **0** |
| `xcodebuild archive`（実署名 / `-allowProvisioningUpdates`） | 成功 |

archive の中身も確認した。**ここまで見て初めて「Xcode Cloud が通る状態」と言える**:

- `PrivacyInfo.xcprivacy` が 4 バンドルすべてに入っている
- `CFBundleShortVersionString 1.0.0` / `CFBundleVersion 1` / `ITSAppUsesNonExemptEncryption false`
- Widget / Live Activity / Watch app が埋め込まれ、`TeamIdentifier=B4S4333JDW` で署名済み
- **SSU の音声理解アセットが `en.lproj/nlu.appintents` と `ja.lproj/nlu.appintents` に出ている**
  （`PlaceDescriptor` 退避を維持しているので FB24548956 を踏んでいない）

回帰も再確認した: パッケージ 244 件 passed / AppIntentsTesting 23 件 passed（803 は 0 件）/
`audit_intents.py` **0 error** / `inspect_appintents_metadata.py` **checks: all clear**。

## 3. 提出用スクショの自動撮影（`scripts/capture_screenshots.sh`）

XCUITest で撮って `.xcresult` の attachment を取り出す形にした。1 コマンドで撮り直せる。

出力は `Screenshots/<platform>/<locale>/NN-name.png`（gitignore）。

### フィクスチャは `Domain` に DEBUG 限定で置いた

`ScreenshotFixture`。ja / en それぞれの todo 6 件 + カテゴリ 3 件。
**タイトルは string catalog に入れていない**——フィクスチャのデータであって UI コピーではないし、
入れると 12 言語すべてに翻訳義務が生まれる。それでも言語別に持っているのは、
日本語のストアに英語の todo が並んだスクショを出すと未翻訳のアプリに見えるため。

### 詰まったところ 5 つ

**(a) `App.init()` で seed するとアプリが落ちる。**
`ModelContainer.init` はストアのロード完了前に返る。インストール直後の初回起動——
つまり UI テストの毎回の起動——で `mainContext` を触ると
`NSInternalInconsistencyException: No eligible connection available` で SIGABRT する。
UI テストからは「アプリがクラッシュしました」としか見えず、原因が全く分からない。
**シーンの `.task` に移して解決**。手で `simctl launch` すると（インストール済みなので）再現しないのが厄介だった。

**(b) `delete(model:)` も落ちる。**
バッチ削除は `NSBatchDeleteRequest` を通り、同じく Objective-C 例外で abort する。
`fetch` して 1 件ずつ `delete` する形に変えた。

**(c) `-AppleLanguages` を launch argument で渡しても ja にならなかった。**
最初 `TEST_RUNNER_SCREENSHOT_LOCALE` でロケールをテストへ渡し、テストが
`-AppleLanguages "(ja)"` を組み立てる形にしていた。環境変数が届かず、既定の `en` に落ちて
**ja のスクショが全部英語で撮れていた**（本人の指摘で気づいた。緑になったので機械的には検出できない）。
`xcodebuild -testLanguage ja -testRegion JP` に置き換えた。
これはアプリ側の `Locale.current` も動かすので、フィクスチャの言語選択もこれ 1 つで揃う。

**(d) visionOS は XCUITest では撮れない。`simctl` に切り替えた。**
`XCUIScreen.main.screenshot()` は 1x1 の画像を返す（掴むべき単一のフレームバッファが無い）。
`app.screenshot()` に替えると画像自体は出るが、**1280x720 に切り取られた平たい矩形**で、
ウィンドウの下と右が欠け、visionOS の見え方でもなければ ASC の寸法（3840x2160）でもなかった。

`xcrun simctl io <device> screenshot` は**部屋ごと 3840x2160 で描画してくれる**。ASC の要件と一致し、
実際のストアの visionOS スクショと同じ見え方になる。ただし simctl はタップできないので、
画面遷移の手段を別に用意する必要があった:

- **ディープリンクは使えない。** `simctl openurl` は外部からの遷移として扱われ、
  「"Intento" で開きますか?」の確認がキャプチャの上に載る
- **起動引数で開く画面を指定する形にした**（`-uitest-screenshot-screen detail`）。
  画面ごとに起動し直して 1 枚ずつ撮る
- **通知許可のダイアログもキャプチャに載る。** iOS のシミュレータはたまたま自動で許可していた
  だけだった。フィクスチャ実行時は許可要求ごと飛ばすようにした
- **撮る前にデバイスを erase する。** 前の実行が空間に残したウィンドウやアラートが
  そのまま写り込む。部屋ごと撮るということはそういうこと

**(e) watchOS で行をタップすると完了トグルを押していた。**
1 行の中でボタンは「ナビゲーションリンク」「完了チェックボックス」の順。
インデックスで 1 番目を取ると**チェックボックス**を押してしまい、todo が完了してリストから消え、
遷移しないまま失敗する。identifier が SF Symbol 名（`circle`）なので、それ以外を選ぶ形にした。

### 撮れたもの

| プラットフォーム | 枚数 / ロケール | 画素数 | ASC 要件 |
|---|---|---|---|
| iPhone 17 Pro Max | 4 | 1320x2868 | ✅ 6.9" と一致 |
| iPad Pro 13-inch (M5) | 4 | 2064x2752 | ✅ 13" と一致 |
| Apple Watch Ultra 4 (49mm) | 2 | 422x514 | 要確認（#127） |
| Apple Vision Pro | 3 | 3840x2160 | ✅ 一致 |
| macOS | — | — | 撮れていない（#127） |

撮り方が 2 系統に分かれた。**iPhone / iPad / Watch は XCUITest**（`XCUIScreen.main.screenshot()` が
デバイスのフレームバッファをそのまま返し、ASC の要求ピクセル数と一致する）、
**visionOS は `simctl io screenshot`**（上記 (d)）。

visionOS と macOS に設定画面が無いのは仕様。`SettingsView` は `ShortcutsLink` を中心に組んであり、
`ShortcutsLink` が macOS に無いので `TodoListToolbar` が `#if os(iOS)` でボタンごと落としている。
テスト側も同じ `#if` で揃えた。

### macOS は落とした（#127）

3 つ重なっていて、この回では終わらなかった:

1. **ウィンドウが復元されず、アクセシビリティツリーがメニューバーだけになる。**
   前回セッションの状態を macOS が復元し、ウィンドウ 0 枚で起動していた。
   `-ApplePersistenceIgnoreState YES` を launch argument に足して解消（これは直った）
2. **サイドバーの行から詳細へ遷移できない。** macOS では 1 行が
   `checkbox_<uuid>-favorite_<uuid>` という 1 個の Button に畳まれていて、`NavigationLink` が
   別要素として出てこない。`Cell` を tap しても選択されない
3. **`-uitest-ephemeral-store` が効いていない疑い。** UI テスト中のリストに
   フィクスチャと手元の実データが同時に並んでいた。`ProcessInfo.arguments` には
   引数が届いている（`ps` で確認）のに共有ストアが開かれている。**原因未解明**

3 を踏まえて `ScreenshotFixture.seedIfRequested` に
**「in-memory コンテナでなければ seed しない」ガード**を入れた。
フィクスチャは書く前にストアを空にするので、これが無いと実データを消しうる。

`scripts/capture_screenshots.sh` の既定のプラットフォーム一覧から macOS を外し、
`./scripts/capture_screenshots.sh mac` と明示したときだけ走るようにした。

## 4. production ブランチ

Xcode Cloud は `production` ブランチで発火し、Xcode 27 でビルドする設定になっている。
上の確認（4 プラットフォームの Release ビルド + 実署名 archive + テスト全部）が緑になった状態で
`main` から切って push した。
