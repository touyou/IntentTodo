# SSU training バグの発火条件を切り分けて Apple に報告した件

`35d772f` 以来「`PlaceDescriptor` を `@Parameter` / `@Property` にすると SSU training が落ちる」と
記録してきたが、**`@Property` 側は裏が取れていなかった**。Feedback Assistant に出すために根拠を
洗い直したところ、発火条件はもっと狭く、代わりに**対象の型はもっと広い**ことが分かった。

現在の結論は [AGENTS.md](../../AGENTS.md) と [docs/APP_INTENTS_API_COVERAGE.md](../APP_INTENTS_API_COVERAGE.md)
にある。ここには**何をどう測ったか**を残す。

## 環境

| | |
|---|---|
| Xcode | 27.0 beta 6（27A5252f）/ 26.6（17F113） |
| 実測日 | 2026-08-28 |
| 再現プロジェクト | `~/Desktop/AppIntentsSSUFeedback/SSUPlaceRepro.zip`（App 1 / Intent 1 / ShortcutsProvider 1） |

## 1. 発火条件は「App Shortcut に登録した Intent の `@Parameter`」だけ

`xcodegen` で作った最小プロジェクト（App + Intent + `AppShortcutsProvider` のみ）で 1 条件ずつ測った。

| 形 | 結果 |
|---|---|
| `@Parameter var place: PlaceDescriptor?` + `AppShortcutsProvider` に登録 | **エラー** |
| 同じ Intent を `AppShortcutsProvider` から外す | 緑 |
| `@AppEntity(schema: .reminders.locationTrigger)` の `place: PlaceDescriptor`（`@Parameter` は `String?`） | **緑**。`nlu/` も生成される |
| `@AppIntent(schema: .messages.sendMessage)` の `locations: [PlaceDescriptor]` を登録（UnicornChat） | 緑 |
| `@Parameter var place: String?` に変えただけの対照 | 緑 |

SSU の `variables` は「App Shortcut が参照する Intent のパラメータ**型名**」から作られる。
スキーマ由来のものは `__DISPLAY_REPRESENTATION_DEFINED_BY_ASSISTANT_DEFINED_SCHEMA__` になるか
そもそも variable にならないので踏まない。**entity の `@Property` は variable にならない。**

> つまり「`@Property` でも発生する」という 2026-08-12 の記録（[03-app-intents-core.md](03-app-intents-core.md)）は
> 単体では再現しない。当時の probe 2 は probe 1（`AddTodoIntent` の `PlaceDescriptor` `@Parameter`）と
> 同居していた可能性が高い。

## 2. `PlaceDescriptor` 固有ではない

SDK の swiftinterface を全部なめると、cross-module で `AppIntents._SystemIntentValue` に適合する型は 5 つ。
うち 4 つを実ビルドで確認し、全部同じ形で落ちた。

| パラメータ型 | 生成された variable 名 |
|---|---|
| `GeoToolbox.PlaceDescriptor` | `GeoToolbox.PlaceDescriptorEntity` |
| `LinkPresentation.LinkMetadata` | `LinkPresentation.LinkMetadataEntity` |
| `MediaIntents.AudioSearch` | `MediaIntents.AudioSearchEntity` |
| `Photos.PHAsset` | `_Photos_AppIntents.PHAssetEntity` |
| `VisualIntelligence.SemanticContentDescriptor` | 未測定（当該構成で module 解決できず） |

いずれも公式の「Adding parameters to an app intent → Define parameters using only the supported types」が
**Other system types** としてサポートを明記している型。`PHAsset` はアンダースコア付きの overlay module 名が
そのまま漏れている。

## 3. 実害は「ターゲット全体の SSU アセットが落ちる」

エラー時、`Metadata.appintents/` に **`nlu/` が生成されない**（`extract.actionsdata` / `root.ssu.yaml` /
`version.json` だけ）。`String?` の対照ビルドでは `nlu/nlu.lzfse` + `.version` が出る。

つまり該当 Intent だけでなく、**そのターゲットの全 App Shortcut** が音声理解の学習アセットを失う。
しかもツールは exit 0 で返すのでローカルは `** BUILD SUCCEEDED **`。

生成物（`root.ssu.yaml`）はこうなっている:

```yaml
variables:
- name: GeoToolbox.PlaceDescriptorEntity
  type: ssu/parameter
  definitions:
  - locale: en
    synomyms: []
```

検証器側の正規表現 `^[a-zA-Z_][a-zA-Z_$0-9]*$` は
`Xcode.app/Contents/Frameworks/SiriSSUKitModel.framework` に文字列として入っている。
**生成器と検証器が食い違っている**ので、アプリ側でできることは「その型を使わない」しかない。

## 4. リリース版 Xcode 26.6 でも再現する（beta 限定ではない）

| Xcode | destination | 結果 |
|---|---|---|
| 26.6（17F113） | iOS 26.5 Simulator | 再現 |
| 27.0 beta 6（27A5252f） | iOS 27.0 Simulator | 再現 |

`PlaceDescriptor` の `_SystemIntentValue` 適合は iOS 26.0 から。beta 3〜6 で追ってきた話は
**26 世代から出荷されているバグ**だった。

## 5. Apple 公式サンプルでも再現する

`~/Developer/Private/wwdc26-app-intents-samples/IntegratingYourMessagingAppWithAppleIntelligence`
（UnicornChat）は素のままならクリーンビルド緑。`MessageIntents.swift` に `PlaceDescriptor` を
`@Parameter` に持つ Intent を 13 行足し、`AppShortcuts.swift` に `AppShortcut` を 1 つ足すだけで
同じエラーが出る。`IntegratingYourPhotoAppWithAppleIntelligence`（PhotosDomainExample）は
`AssetEntity.location: PlaceDescriptor?` を持つが、App Shortcut の Intent パラメータではないため緑。

## 6. 測り方の注意（beta 5 / beta 6 の記録どおり）

判定は**必ずクリーンビルド**。`Metadata.appintents` が変わっていないと `AppIntentsSSUTraining` は
再実行されず、インクリメンタルのログには前回の出力がそのまま並ぶ。

## 7. 残ったこと

- Feedback Assistant に提出済み（文面と再現プロジェクト: `~/Desktop/AppIntentsSSUFeedback/`）。
  追跡は **#57**
- **#56（`.reminders.reminder` 本体適合）の据え置き理由を測り直す**。「SSU バグでブロック」は
  §1 で否定された。マクロ生成 init 側の障害が本当に残っているかは別途クリーンビルドで確認する
