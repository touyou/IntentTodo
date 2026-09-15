# 配布ビルドだけ App Intents が丸ごと読み込まれない件を `AppIntentsPackage` まで絞った

1.1.0 をリリースしたら、ショートカット / Spotlight にアプリのアクションが 1 つも出なくなった。
入れ直すと**アプリ名すら一覧に出ない** — App Shortcut が出ないのではなく、**バンドル単位で
App Intents の取り込みを拒否されている**形。

結論（ビルド二分で確定した範囲）と、その過程で潰した仮説を残す。

## 1. 成果物は健全だった

最初に疑うべき「ビルド時抽出の無音失敗」は全部シロだった。出荷済みの Mac App Store 版
`IntentTodo.app/Contents/Resources/Metadata.appintents` を直接読んだ結果:

| | |
|---|---|
| `actions` / `entities` / `queries` / `enums` | 26 / 9 / 6 / 8 |
| `autoShortcuts` | 8 |
| `autoShortcutProviderMangledName` | `10IntentTodo0B12AppShortcutsV`（アプリターゲットの `TodoAppShortcuts`） |
| `AddTodoIntent` | `isDiscoverable: true` / `assistantOnly: false` / `requiredCapabilities: []` |
| メタデータ形式 | `version 3.0` / tools `27A266a`（他の App Store アプリ・システムアプリと同じ） |

さらに **macOS の Release ローカルビルドと App Store 版はバンドル構成が `_MASReceipt` 以外完全一致**。
配布パイプラインは何も落としていない。

## 2. 変数はインストール経路だけだった

| | 構成 | インストール経路 | 結果 |
|---|---|---|---|
| Xcode Run | Debug | Xcode | **出る** |
| Xcode Run | Release | Xcode | **出る** |
| TestFlight / App Store | Release | App Store | 出ない |

同じソース・同じ構成でも、配布経路を通ると読まれない。他の App Store アプリ（Graphica /
Graphica Playground）は正常なので、システム側は健全。

## 3. 潰した仮説

| 仮説 | 潰し方 |
|---|---|
| `updateAppShortcutParameters()` を `App.init()` で呼んでいて失敗する | ログに `Failed to refresh AppShortcut parameters` は実在したが、**Debug ビルドでも同じように出る**ので差にならない（呼び出し位置は正しい形へ直した） |
| Release 構成が壊れている | iOS Release ローカルビルドで `Metadata.appintents` も `ja/en.lproj/nlu.appintents` も正常生成 |
| SSU バグ FB24548956 の発火 | `appintentsnltrainingprocessor` が 8 件のフレーズを ja / en 両方 training してアセットを出している |
| schema 由来の `title: null` が壊している | Apple 純正が普通にやっている（Preview 9 件 / Mail 5 件 / Freeform 5 件） |
| `CFBundleName` の不一致 | 表示名の問題で、索引には効かない（別途修正した） |
| ja フレーズの `${applicationName}` 欠落 | 26 件すべてに入っている |
| LaunchServices の登録汚染 | この Mac に 39 件あったので 2 件まで掃除したが、症状は変わらず |
| `PlaceDescriptor` の復帰（`4c2985d`） | ビルド 28 が NG なので窓の外 |

## 4. TestFlight のビルド二分

`asc builds list` の `uploadedDate` を UTC に直して commit と突き合わせた。

| build | UTC | 結果 |
|---|---|---|
| 8 | 2026-07-09 10:29 | **OK** |
| 13 | 2026-08-11 15:22 | **OK** |
| 14 | 2026-08-12 12:28 | （未測定） |
| 28 | 2026-08-27 01:56 | NG |
| 29 | 2026-09-09 22:29 | NG |

ビルド 13 → 14 の間に入ったのは 5 commit で、そのうち App Intents の構造に触るのは 1 つだけ:

**`c4f20ef` feat: includedPackages 付き `AppIntentsPackage` を各ターゲットで宣言（A-1 決着）**

## 5. なぜこれが本命か

`AppIntentsPackage` 宣言が出荷バンドルに足すものは `extract.packagedata` ただ 1 つ:

```json
{"includes":["14TodoAppIntents0aC7PackageV"],"version":1}
```

中身は `includedPackages` に並べた型の**マングル名**。つまり **App Intents のメタデータの中で、
型を実行時にマングル名で引く唯一の経路**であり、解決に失敗したときの巻き添え範囲がバンドル全体。
「アプリ名すら出ない」という症状の形と一致する。開発インストールで通って配布で落ちる点も、
`STRIP_INSTALLED_PRODUCT` / `STRIP_SWIFT_SYMBOLS` が効くのが配布側だけであることと整合する。

## 6. 2026-08-12 の「害が無い」判断が持っていた穴

当時「静的リンクなのでメタデータのマージは宣言なしでも起きる。宣言は `extract.actionsdata` に
触っていないので**害が無い**」と結論づけて採用した。この「害が無い」は**ビルド生成物の件数を
数えて出した判断**で、**配布して端末が取り込むところは一度も測っていない**。

同じ穴は `PlaceDescriptor` の `@Property` 復帰（`docs/devlog/2026-08-29-entity-placedescriptor-restore.md`）
でも開いていた。あちらもローカルビルドで `nlu/` が出ることを根拠にしている。

> **ローカルビルドの生成物が正しいことは、配布したものが読まれることを意味しない。**
> App Intents の「確認はメタデータで行う」は、**配布経路を通した実機**まで含めて初めて成立する。

## 7. やったこと

`AppIntentsPackage` の宣言を全廃した（パッケージ側 1 つ + 利用側 4 ターゲット）。
iOS Release ビルドで差分を確認:

- `extract.packagedata` がどのバンドルからも消えた
- `actions` 26 / `entities` 9 / `queries` 6 / `enums` 8 / `autoShortcuts` 8 は**据え置き**
- `ja/en.lproj/nlu.appintents` も据え置き

失うものは無い。

## 8. 確定した

宣言を外した build 37 を TestFlight で確認して、**ショートカット / Spotlight / Siri がすべて復帰した**。
`c4f20ef`（`includedPackages` 付き `AppIntentsPackage` の宣言）が原因で確定。ビルド 14〜28 に
入った残り 4 commit（`e1cf256` / `38e3338` / `04e85e5` / `d37efe2`）は無関係だった。

1.1.1 / build 37 として 3 プラットフォームとも審査に提出した。

現在のルール: [AGENTS.md](../../AGENTS.md) 13 / 14、
[docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md)「パッケージ内での定義」
