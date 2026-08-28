# `TodoAppEntity.location` を `PlaceDescriptor` に戻した件（FB24548956 / #57）

[2026-08-28 の切り分け](2026-08-28-ssu-system-value-type-bug.md)で「SSU バグが発火するのは
**App Shortcut に登録した Intent の `@Parameter`** だけで、entity の `@Property` は SSU の
variable にならない」と分かったので、`35d772f` の退避のうち **entity 側だけ**を戻して実測した。

現在のルールは [AGENTS.md](../../AGENTS.md)「App Shortcut に登録する Intent の `@Parameter` に
system value 型を使わない」にある。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f） |
| destination | iOS 27.0 Simulator（iPhone 17 Pro Max） |
| 実測日 | 2026-08-29 |
| Feedback | FB24548956 |

## 変更したもの

`TodoAppEntity` の中だけで閉じた。UI は model の `locationName` を直接読んでいる
（`TodoDetailView` / `VisionOSTodoDetailView`）ので影響しない。

| 箇所 | 変更 |
|---|---|
| `@Property(title: "Location") var location` | `String?` → `PlaceDescriptor?` |
| `init(todoItem:)` | `TodoPlace.descriptor(name:latitude:longitude:)` で組み立て |
| `init(id:…)` | `location: PlaceDescriptor? = nil` |
| `ValueRepresentation(exporting:)` | `todo.location` をそのまま返す（`TodoPlace` 経由の復元をやめた） |

**副産物**: `ValueRepresentation` はこれまで `latitude: nil, longitude: nil` を渡していたので
**座標が落ちていた**（住所表現だけ export していた）。entity が `PlaceDescriptor` を持つように
なったことで、モデルに緯度経度があれば `.coordinate` 表現がそのまま Maps へ流れる。

`AddTodoIntent.location` は `TodoAppShortcuts` に登録済みの Intent の `@Parameter` なので
**`String` のまま**。`TodoPlace.decompose` は引き続き呼び出し元なし。

## 実測

クリーンビルド（共有 DerivedData を汚さない別ディレクトリ）:

```
xcodebuild -project IntentTodo.xcodeproj -scheme IntentTodo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' \
  -derivedDataPath /tmp/ITCleanDD CODE_SIGNING_ALLOWED=NO build
```

- `** BUILD SUCCEEDED **`、`must match regular expression` / `Could not archive SSU` /
  `emitted errors` は **0 件**
- SSU タスクのログのタイムスタンプが当日のもの（stale ログではない）
- SSU アセットが生成されている: `IntentTodo.app/en.lproj/nlu.appintents/` と
  `ja.lproj/nlu.appintents/`（各 8KB）

> **置き場の注意**: 最小再現プロジェクト（単一 locale）では `Metadata.appintents/nlu/` に出るが、
> **ローカライズ済みの本アプリでは `<locale>.lproj/nlu.appintents/`** に出る。
> `Metadata.appintents` の中だけ見て「nlu が無い」と誤読しかけた。成功判定はログの
> `Archiving all locales` → `archived N locales` と `<locale>.lproj/nlu.appintents` で行う。

出荷メタデータ（`inspect_appintents_metadata.py`）:

- `checks: all clear`、`TodoAppEntity` は 11 props のまま
- `location` の `valueType` が system entity になった:

```json
{"identifier": "location", "isOptional": true, "title": {"key": "Location"},
 "valueType": {"entity": {"wrapper": {"system": {
   "bundleIdentifier": "com.apple.-GeoToolbox-AppIntents",
   "contentTypeIdentifier": "com.apple.GeoToolbox.PlaceDescriptor"},
   "typeName": "GeoToolbox.PlaceDescriptorEntity"}}}}
```

**`GeoToolbox.PlaceDescriptorEntity` という同じ型名がメタデータには入っているのに SSU は落ちない**
——これが「SSU の variable になるのは `@Parameter` だけ」の裏取りになっている。

AppIntentsTesting:

- `TodoEntityQueryTests` / `TodoIntentExecutionTests` / `TodoSystemIntegrationTests` の 3 スイート
  すべて passed、`** TEST SUCCEEDED **`、失敗 0 件

## 残ったこと

- `AddTodoIntent.location` の `String` 退避は FB24548956 が直るまで維持。追跡は #57
- `TodoPlace.decompose` は `@Parameter` を戻せたときに出番が来る
