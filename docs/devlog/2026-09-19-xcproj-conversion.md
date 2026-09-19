# プロジェクトファイルを Xcode 27.2 の `project.xcproj` 形式へ変換した

Xcode 27.2 beta（27B5019j）の `xcodebuild -convert-project` に新形式 `Xcode Project` が入ったので、
`IntentTodo.xcodeproj/project.pbxproj`（53 KB）を `project.xcproj`（20 KB）へ変換した。

```
DEVELOPER_DIR=/Applications/Xcode-27.2.0-beta.app/Contents/Developer \
  xcodebuild -project IntentTodo.xcodeproj -convert-project "Xcode Project"
```

`-convert-project -help` は形式名として解釈されてエラーになるが、そのエラーメッセージに
指定できる形式（`Xcode 2.4` … `Xcode 27.0`, `Xcode Project`）が並ぶ。

## 何が変わったか

- `project.pbxproj` が消え、`project.xcproj` が置かれる。`xcshareddata/`（スキーム）と
  `project.xcworkspace/` はそのまま。`.xcodeproj` のディレクトリ名は変わらないので
  `-project IntentTodo.xcodeproj` を渡すスクリプトはそのまま動く
- 中身は JSON 風のテキスト。オブジェクト ID の参照グラフではなく、同期フォルダごとの
  `target-membership` / `membership-exceptions`、ターゲットごとのビルド設定という形で書かれる
- macOS から Watch アプリと Live Activity を外していた `platformFilter = ios;` は、
  埋め込み product の `target-membership` に `"platforms": [ "ios" ]` として移った

## 等価性をどう確かめたか

ルール 12（ビルドの成否ではなくメタデータで見る）に従い、リポジトリのコピー上で変換してから
以下を比べた。

| 確認 | 結果 |
|---|---|
| `-showBuildSettings -alltargets`（6 ターゲット × Debug / Release、パス系を除く） | 変換前と行単位で一致 |
| 27.2 でのビルド（iOS Sim / macOS / visionOS Sim / watchOS Sim、`CODE_SIGNING_ALLOWED=NO`） | 4 つとも成功 |
| 変換前後それぞれクリーンビルドした `Metadata.appintents/extract.actionsdata`（10 バンドル） | バイト比較では全部差分が出たが、絶対パスを置換しキーと配列を正規化すると全部一致 |
| Xcode 27.0（27A266a）/ 27.1 beta での `xcodebuild -list` | どちらも新形式を読めた |

バイト差分は変換先と変換元を別ディレクトリでビルドしたことによる絶対パスと並び順だけだった。

## 未確認

- TestFlight / App Store 配布ビルドでの読み込み（ルール 14）。面に関わる変更ではないが、
  次のリリースで配布ビルドの App Intents が読まれることを確認する（#30）
