# 2026-09-11: App Intents のビルド時メタデータ（静的 / 動的リンクと永続 ID）を実測で突き合わせ

外部の発表で聞いた 3 点を、公式ドキュメント（wwdc2025-244 / wwdc2023-10103 / AppIntents リファレンス）と
本リポジトリのビルド生成物に突き合わせた記録。

聞いた話:

1. 静的リンクならメタデータは自動でマージされる
2. 動的リンク先を参照できるようにするために `AppIntentsPackage` がある
3. `AppIntentsPackage` を使うと参照先を示すメタデータファイルが別にでき、それを基に参照される
4. パッケージ名が変わると名前が変わりうるので `persistentIdentifier` が使えるのではないか

## 実測に使ったもの

`~/Library/Developer/Xcode/DerivedData/IntentTodo-*/Build/Products/Debug-iphonesimulator`（tools `27A266a`）の
各 `*.appintents/Metadata.appintents/` と `IntentTodo.app/Metadata.appintents/`。

```bash
cat .../Metadata.appintents/extract.packagedata
xcrun swift-demangle '$s14TodoAppIntents0aC7PackageV'   # -> TodoAppIntents.TodoIntentsPackage
python3 -c "import json;j=json.load(open('.../extract.actionsdata'));print(sorted(j['actions']))"
```

## 1〜3: 合っていた。ただし本プロジェクトでは宣言は効いていない

| バンドル | `AppIntentsPackage` 宣言 | `extract.packagedata` | `actions` / `entities` / `queries` |
|---|---|---|---|
| `TodoAppIntents.appintents` | あり（`includedPackages` 無し） | `{"includes":[]}` | 24 / 5 / 4 |
| `UI.appintents` | 無い | ファイルごと無い | 24 / 5 / 4 |
| `WidgetUI.appintents` | 無い | 無い | 24 / 5 / 4 |
| `LiveActivity.appintents` | 無い | 無い | 24 / 5 / 4 |
| `IntentTodo.app/Metadata.appintents` | あり（`includedPackages: [TodoIntentsPackage.self]`） | `{"includes":["14TodoAppIntents0aC7PackageV"]}` | 24 / 7 / 4 |

- 「参照先を示す別のメタデータファイル」は `extract.packagedata` で、中身は `includedPackages` に並べた型の
  **マングル名**だった（3 は裏取りできた）
- `UI` / `WidgetUI` / `LiveActivity` は `AppIntentsPackage` を 1 つも宣言していないのに
  `TodoAppIntents` の 24 actions がそのまま載っている。Xcode の SPM は既定で静的リンクで、
  `IntentTodo.app` に `Frameworks/` も無い（7 パッケージ全部が静的）。よって 1 も裏取りできた
- 公式の言い方も条件付きだった:
  > "You should use App Intents Package when referencing code not compiled into a static library."
  > （wwdc2025-244 `24:00`）

### 2026-08-12 の判断の解釈を訂正

当時「宣言の有無で `Metadata.appintents` の件数が完全一致 → 重複は起きていない」を採用根拠の 1 つに
していた。件数が一致した理由は「重複が起きなかった」ではなく**静的リンクの時点でマージが済んでいて、
宣言は `extract.actionsdata` に触っていなかった**ため。採用の結論自体は変えない（Apple のデモどおりで
害が無く、パッケージを動的プロダクトに変えた瞬間に効き始める）が、「メタデータに型が出てこない」問題を
`includedPackages` の足し引きで直そうとしない、という運用に書き換えた。

`docs/presentation/02-constraints-and-craft.md` の T11 は根拠 1 の言い方が上記と食い違うが、
登壇でどう話すかの判断なので手を入れていない。

## 4: 趣旨は「構成を変えると保存済みショートカットが迷子になるのをどうするか」だった

最初「パッケージ名が変わると名前が変わりうる」と受け取って前提の誤りとして書いたが、聞きたかったのは
**Shortcuts アプリが参照していた App Intents がパッケージ構成の変更で迷子になる問題に
`persistentIdentifier` が使えるのでは**、という話だった。測った結果でそのまま答えられる。

| 変えるもの | 保存済みショートカット |
|---|---|
| 型をアプリターゲットからパッケージへ移す | 無事（`identifier` は型名のまま） |
| パッケージ名 / モジュール名を変える | 無事（`identifier` にモジュール名は入らない） |
| **型名を変える** | 迷子。旧 `identifier` はメタデータから消える |

直感は当たっていて、**トリガが「パッケージ名」ではなく「型名」**だった、というのが結論。
パッケージへ切り出すついでに名前を整えると踏むので、体感としては「構成変更で壊れた」になる。

## 前提の測り直し: 効くのは「型名を変えたとき」

`identifier`（Shortcuts / donation が保存している側）の既定値はモジュール名を含まない素の型名だった。

```
AddTodoIntent:   AddTodoIntent
TodoAppEntity:   TodoAppEntity
TodoEntityQuery: TodoEntityQuery
TodoFilterType:  TodoFilterType
```

（`RunCodeSnippet` で `persistentIdentifier` を直接印字）

モジュール名が入るのは `fullyQualifiedTypeName` / `mangledTypeName` / `defaultQueryIdentifier` で、
いずれも同一ビルド内で解決される。よって**パッケージ名やモジュール名の変更では永続 ID は動かない**。
`PersistentlyIdentifiable` のリファレンスも用途を "maintaining the identity of a type, even when its
**type name** is changed" と書いており、`AttributedTypeIdentifier.persistentIdentifier` の説明も
"typically corresponds to the struct name of the original entity declaration"。

### 静的抽出が上書きを読むかを確認

`ShowTodoCountIntent` に `public static let persistentIdentifier = "com.example.probe.ShowTodoCount"` を
一時的に足してビルドし、メタデータを見てから戻した。

- `TodoAppIntents.appintents` の `actions` から `ShowTodoCountIntent` が消え、
  `com.example.probe.ShowTodoCount` がキーになり、`identifier` も同じ値になった
- 静的リンクしている `IntentTodoLiveActivityExtension.appex` のマージ後メタデータにも
  その値で載った（上書きは集約先まで伝播する）
- `mangledTypeName` は変わらない（型の実体の参照は別経路）

ビルド時抽出なので `title` と同じく定数でなければならない。

### App Shortcut がぶら下がったまま孤立しないかを確認（途中で誤診した）

`ShowTodoCountIntent` は `AppShortcutsProvider` に登録してあるので、`autoShortcuts` 側の
`actionIdentifier` が上書きに追従しないと **App Shortcut が無音で消える**。そこを見にいったら、
最初はまさにその形に見えた:

- アプリの統合メタデータの `actions` に `ShowTodoCountIntent` と `com.example.probe.ShowTodoCount` の
  **両方**が居た（24 → 26 件）
- `autoShortcuts[].actionIdentifier` は旧名の `ShowTodoCountIntent` のまま

原因はインクリメンタルビルドだった。`UI.appintents` / `WidgetUI.appintents` などパッケージ側の
抽出結果が**依存先を変えても再生成されず**、古い identifier を持ったまま統合メタデータへ merge されていた。
出力ディレクトリを手で削ってビルドし直しても、ビルドシステムは up-to-date と判断して作り直さない。

別の `-derivedDataPath` でクリーンビルドしたら結果が反転した:

```
LiveActivity.appintents      total  25  ['com.example.probe.ShowTodoCount']
TodoAppIntents.appintents    total  25  ['com.example.probe.ShowTodoCount']
UI.appintents                total  25  ['com.example.probe.ShowTodoCount']
WidgetUI.appintents          total  25  ['com.example.probe.ShowTodoCount']
IntentTodo.app               total  25  ['com.example.probe.ShowTodoCount']
   autoShortcuts actionIdentifiers: [..., 'com.example.probe.ShowTodoCount']
```

どのバンドルも新 identifier 1 つだけで、`autoShortcuts` も追従していた。**上書きは一貫している**。

教訓として、`AGENTS.md` の「確認はビルドの成否ではなくメタデータで行う」には
**そのメタデータがインクリメンタルビルドで古いままのことがある**という但し書きが必要だった。
2026-08-28 に SSU ログで同じ読み違えをしかけている（`2026-08-28-xcode27-beta6-recheck.md`）。

### entity にはもう 1 層ある

`AppEntity` を指すショートカットが保存しているのは（型の `persistentIdentifier`,
インスタンスの `AppEntity.ID`）の組。型名を固定しても ID の作り方を変えたら同じように迷子になる。
こちらは今回測っていない。

現在のルール: [docs/insights/03-app-intents-core.md](../insights/03-app-intents-core.md)
「メタデータが集約される条件は『リンクの形』」「型の永続 ID は素の型名」
