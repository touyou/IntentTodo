# 開発ログ: Control Widget と iOS 26

`docs/insights/06-control-widget-ios26.md` の現在のルールが、どういう経緯で今の形になったかを記録する。

## 2026-04-14: Control Widget から呼んだ Intent は `.result(dialog:)` が表示されないことを実機で確認

Control Center 経由で呼ぶ Intent（`ToggleUrgentTodoIntent`, `ShowTodoCountIntent`）で `.result(dialog:)` を
試したが、Control Widget では Dialog が画面に表示されないことを実機で確認した。UI/Widget の
`Button(intent:)` 経由でも表示されないのは把握済みだったが、Control Widget 固有の挙動として記録。
以降 Control Center 起点の Intent はローカル通知でフィードバックする運用にした
（`ControlNotificationHelper` 経由、`ToggleUrgentTodoIntent` / `ShowTodoCountIntent` 参照）。

なお Control Widget はグラス風ミニマム UI が UX 設計語彙で、dialog 表示はそもそも設計の一部として
想定されていない可能性が高い（Apple 公式には明文記述なし）。本プロジェクトでは by-design 相当として扱い、
Apple Feedback の提出は行わないことにした。

## 2026-04-15: Controls の visionOS 非対応を公式ドキュメントで確認

Apple 公式 [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy#Review-system-experiences-for-each-platform)
の "Review system experiences for each platform" セクションにある対応表を確認したところ、Controls は
**iPhone / iPad / Apple Watch / Mac で Yes、Apple Vision Pro のみ No** と明記されていた。
`if #available(iOS 18.0, *)` は実行時版チェックであり、コンパイル時に visionOS SDK が `ControlWidget` /
`ControlWidgetButton` / `StaticControlConfiguration` 型を提供しない問題を回避できないため、
`#if !os(visionOS)` で型参照自体を切る方針にした。

## 2026-08-11: `ControlValueProvider` の役割分担の理由付けを訂正

以前は「body 過剰評価を避けるため」と説明していたが、Apple の説明（wwdc2024-10157 9:51 / 11:22）を
確認し直すと、非同期でのデータ取得は `ControlValueProvider` の役割として明確に分担されており、
reload 時にシステムが `ControlValueProvider` → `body` の順で実行する、という設計そのものが理由だった。
body 内で直接 SwiftData fetch すると、この非同期取得と描画の分担モデルに沿わず（body は同期的に
値を描くだけであるべき）、意図しない挙動やタイミング不整合につながる、というのが正確な理由。
ルール自体（body で直接 fetch しない）は変更なし、理由の説明だけを訂正した。

## 2026-08-11: `ControlConfigurationIntent` と `SetValueIntent` の「同時準拠できない」という表現を訂正

「同時準拠できない」という制約表現は誤解を招くと気づいた。wwdc2024-10157 のモデルでは
configuration intent（設定パラメータ用）と action intent（`SetValueIntent` 等）はそもそも
**別々の Intent** として設計されており、1 つの Intent に両方の役割を持たせようとした結果
「同時に準拠できない」という制約に見えていただけだった。

本プロジェクトの Control 群（`ToggleUrgentTodoControl` / `QuickAddTodoControl` / `TodoCountControl`）を
確認したところ、実際にはカスタム `ControlConfigurationIntent` を持たず `StaticControlConfiguration` のみを
使い、トグル操作は `ControlWidgetButton(action:)` に渡す独立した `AppIntent`（`SetValueIntent` 準拠ではない）
で実装しており、役割分離は既に達成できていた。コード変更は不要と判断し、表現のみ訂正した。

## 2026-08-11: `ControlConfigurationIntent` が別モジュールから参照できない原因を「Name Mangling」から訂正

Widget Extension 内で定義した `ControlConfigurationIntent` がアプリ本体から参照できない件について、
以前は「Name Mangling」が原因と説明していたが、これは誤りだった。真因は単純な**ターゲット/モジュール境界**
（Extension ターゲットの型は別モジュールなのでアプリ側から import できない、Swift の通常のアクセス制御と
同じ話）。共有したい場合は SPM パッケージへ型を移すのが公式サポートされた方法（wwdc2025-244 22:34）。

本プロジェクトは `StaticControlConfiguration` を使い ConfigurationIntent 自体を必要としない設計にしている
ため、この問題は実質発生しない。ルール自体に影響はないが、原因説明を訂正した。

## 2026-08-11: `ToggleUrgentTodoControl` に `.controlWidgetStatus(_:)` を実装

`ToggleUrgentTodoControl` のラベルに `.controlWidgetStatus(_:)`（wwdc2024-10157）を追加し、
`snapshot.isCompleted` に応じて "Completed" / "Due soon" を Control 自体に一時表示するようにした
（iOS シミュレータ向けビルドで型・コンパイルを確認済み）。ローカル通知はシステムの通知センターに
残り続ける副作用があるため、この一時的な状態表示は通知の完全な代替ではなく併用
（Control 内の即時フィードバック + 通知による永続的な記録）という位置づけにした。

`TodoCountControl` は `ControlWidgetButton` がボタン（状態を持たない fire-and-forget）でタップ後も
表示値（未完了数）自体は変化しないため、`.controlWidgetStatus` の適用は見送った
（実機での見え方の比較は今後の課題）。

## 2026-08-12: Control を Toggle 化し、成功通知を廃止（`.controlWidgetStatus` も撤去）

「WWDC の内容に照らすと Control は Toggle と Snippet を使うべきで、通知は分かっていなかった頃の名残では」
という問題提起から、Control 3 種の設計を再検証した。

**調べた結果 3 点**:

1. **Toggle には「固定された対象」が要る。** `ControlWidgetToggle` の action は
   `SetValueIntent where ValueType == Bool` で、`isOn` は provider が読み戻せる永続的な bool
   でなければならない（Apple: "Toggles are controls that have two states" / "Buttons don't have
   state; use them for fire-and-forget actions"）。旧 `ToggleUrgentTodoControl` の「最も緊急な Todo」は
   完了させると provider が**別の（未完了の）Todo** を返すため on 状態が永続せず、Toggle の意味論を
   満たさない。Apple のサンプル（TimerToggle / GarageDoorOpener）はいずれも「設定で選ばれた特定 entity」
   に対する操作になっている。
2. **旧実装には表示バグがあった。** provider の predicate が `!isCompleted` で絞っていたため
   `snapshot.isCompleted` は常に false で、直前のコミットで足した `.controlWidgetStatus("Completed")`
   分岐は到達不能だった。Toggle 化により状態そのものがコントロール面に出るので、
   `.controlWidgetStatus` は「コントロールが既に伝えている情報には使うな」という公式ガイダンス
   （"Use status text sparingly and only in situations where important information isn't conveyed by
   the control"）に沿って撤去した。
3. **Snippet は Control では表示されない。** AppIntents「Visual presentation」は
   "**Siri, Spotlight, and the Shortcuts app** display snippets"、wwdc2025-281 0:29 も
   "This includes Spotlight, Siri, and the Shortcuts app" と列挙しており、Control / Control Center は
   含まれない。dialog と同じカテゴリの制約なので「通知を Snippet に置き換える」は不可。
   → **この 3 点目は誤り**。肯定リストからの推論にすぎず、wwdc2025-275 が反証している。
   同日の後続エントリ「『Control では snippet が出ない』は誤り」を参照。

**それでも通知を減らす判断は正しかった**、というのが結論。Apple のモデルでは Control のフィードバックは
`perform()` 完了時の自動リロードによるコントロール自身の再描画であり、成功通知はそれと二重になるうえ
通知センターに残り続ける。特に `TodoCountControl` は未完了数が既にコントロール面に出ているのに、
タップでその数を通知するという完全な二重表示だった。

**変更内容**:

| 対象 | Before | After |
|------|--------|-------|
| 緊急 Todo コントロール | `ToggleUrgentTodoControl`（Static + Button + 成功通知） | `ToggleTodoControl`（`AppIntentControlConfiguration` + `ControlWidgetToggle` + `SetTodoCompletionIntent`）。対象 Todo は `SelectTodoConfigurationIntent` で選ぶ |
| `TodoCountControl` | タップ → `ShowTodoCountIntent` → 件数を通知 | タップ → `LaunchAppIntent.incompleteTodos()` で一覧を開く |
| `ShowTodoCountIntent` / `GetTodoSummaryIntent` | 通知 / dialog のみ | dialog + `snippetIntent: TodoSummarySnippetIntent()`（Snippet が実際に描画される Siri / Spotlight / Shortcuts 側に寄せた） |
| `ToggleUrgentTodoIntent` | Control 用 + 成功通知 | Siri / Shortcuts 専用に整理、dialog + サマリ Snippet |
| `ControlNotificationHelper` | 成功 2 種 + エラー | **エラーのみ**。失敗した Control タップだけは他に伝える手段が無い（dialog も snippet も出ず、コントロールは前の状態のまま再描画されるので「何も起きなかった」と読める）ため残した。`appEntityIdentifiers`（WWDC 2026 #343）はエラー通知側に引き継ぎ |

`kind` は `ToggleUrgentTodoControl` → `ToggleTodoControl` で変わるため、既存の配置は一度消える
（設定して使うコントロールに変わったので、どのみち再設定が必要）。`.promptsForUserConfiguration()` で
追加時に対象 Todo の選択を促す。

`SelectTodoConfigurationIntent` は Widget Extension 内に置いた。アプリ本体から参照する必要が無く、
SPM に置くと watchOS / visionOS も含む全ターゲットでコンパイルされるため。Extension 内定義で問題に
なるのは「アプリ側から参照したい場合」だけ（上記 2026-08-11 の項参照）。

`SetTodoCompletionIntent` は `todoId: String` を取る（`TodoAppEntity` パラメータではない）。
FromExtension 系と同じ理由で、Extension プロセスでの事前 entity 解決フェーズを踏ませないため。
値は絶対値で受ける（`toggleCompletion` ではなく `TodoService.setCompletion(todoId:isCompleted:)`）—
Toggle はシステムが要求した状態に収束しなければならず、flip では冪等にならない。

検証: iOS / visionOS / macOS / watchOS の 4 プラットフォームでビルド成功、SPM テスト 70 件パス
（`setCompletion` の絶対値/冪等性、`summarize` の集計を追加）。実機 Control Center での見え方は未検証。

## 2026-08-12: 「Control では snippet が出ない」は誤り — 推論を実測と偽って書いていた

同日の上記エントリで「Snippet は Control では表示されない」と断定したが、**これは誤り**だった。

根拠として挙げていたのは AppIntents「Visual presentation」の "Siri, Spotlight, and the Shortcuts app
display snippets" と wwdc2025-281 0:29 の "This includes Spotlight, Siri, and the Shortcuts app" だが、
どちらも**肯定リスト**であって Control を明示的に除外してはいない。「列挙に無い＝出ない」は推論であり、
それを dialog の実測結果（2026-04-14）と並べて書いたことで、実測されたルールのように見えてしまった。

決定的な反証は **wwdc2025-275 1:40–1:59**:

> I'll tap on **the control** that runs an App Intent to find the closest landmark. After locating it,
> **the intent will show a snippet** displaying the landmark with a heart button next to the title.
> […] I'll tap the heart button to add it to my favorites. **The snippet will immediately update**
> to show its new status.

コントロールのタップ → Intent 実行 → snippet 表示 → snippet 内ボタンで即更新、をそのまま実演している
（ただしセッションにコントロール側のコードは無く、transcript だけでは Control Center のコントロールか
までは確定できない）。

**この誤りが設計に与えた影響**: 「Control では snippet が出ない」を前提に、snippet を返す Intent
(`ShowTodoCountIntent` / `GetTodoSummaryIntent` / `ToggleUrgentTodoIntent`) をすべて Control から外して
Siri 側に寄せ、Control 側の Intent は `.result()` だけを返す形にした。結果、**Control 経由で snippet を
返す経路が 1 つも無い**状態になり、「Control Center で snippet が一切出ない」のは当然という、検証すら
できない構成になっていた。誤った前提が、それを反証する実験の可能性ごと潰していた形。

**対応（実機検証の仕込み）**:

1. `SetTodoCompletionIntent` の戻り値を `some IntentResult & ShowsSnippetIntent` にし、
   `.result(snippetIntent: TodoSnippetIntent(todoId: todoId))` を返すようにした。
   Control のトグル後に snippet（完了/お気に入りボタン付き）が出るかを見る。
2. `IntentTodoWidgetBundle.init()` で `TodoEntityStore.register(container:)` を追加した。
   `TodoSnippetIntent` は `@Dependency` ではなく `TodoEntityStore.container` からデータを読むため、
   Extension プロセスで解決されると中身が空になり「Todo not found」が描かれる。これを踏むと
   「snippet は出たがデータが空」を「snippet が出ない」と誤認しかねないので、実験前に潰した。
   `AppDependencyManager` への登録と `TodoEntityStore` への登録は別物、という教訓。

**出なかった場合に次に試すこと（変数は 1 つずつ動かす）**:

1. `allowedExecutionTargets = [.main]` を `SetTodoCompletionIntent` に指定する。現在は未指定で
   ヒューリスティクス任せのため Widget Extension プロセスで実行されている可能性がある。
   snippet の提示経路がアプリプロセス限定なら、これで出るようになるはず。
2. ボタン形状で試す。デモの「control」はボタンに見え、こちらは `ControlWidgetToggle` +
   `SetValueIntent` なので、トグルだけ提示されない可能性が残る。
3. それでも出なければ、ドキュメントの列挙どおり Control は非対応と結論し、
   デモの「control」がアプリ内 UI のコントロールを指していたと解釈する。

**教訓**: 肯定リスト（"A, B, C が対応"）から否定（"D は非対応"）を導かない。導いたなら
「推論である」と明示する。今回はそれを怠り、実測（dialog）と推論（snippet）を同じ表に並べたことで、
自分の後続の設計判断まで誤らせた。

## 2026-08-12: snippet の実機検証は Count コントロールを主役にする

前項では `SetTodoCompletionIntent`（Toggle）に snippet を仕込んだが、**役割的に Count のほうが適切**という
指摘を受けて主役を入れ替えた。Toggle は完了状態がコントロール面にそのまま出ているので snippet から
得るものが少ないのに対し、Count は「情報を見せる」のが仕事なので、内訳（期限切れ / 完了 / 総数）を
snippet で見せられるなら体験がまるごと変わる。前の議論で挙がっていた「Count → その場で件数を見せる」案
そのものでもある。

**現在の仕込み（2 形態を同時に検証）**:

| コントロール | 形 | 実行される Intent | 返す snippet |
|---|---|---|---|
| `TodoCountControl`（主）| Button + `.background` | `ShowTodoCountIntent` | `TodoSummarySnippetIntent`（件数の内訳）|
| `ToggleTodoControl` | Toggle + `SetValueIntent` | `SetTodoCompletionIntent` | `TodoSnippetIntent(todoId:)` |

2 形態を残しているのは、**「Control では一切出ない」のか「ボタン形状でしか出ない」のかを 1 回の実機確認で
切り分ける**ため（wwdc2025-275 のデモの "control" はボタンに見える）。エスカレーション手順の 2 番目を
前倒しで同時に回している形。

**トレードオフ**: Count コントロールのタップは `LaunchAppIntent.incompleteTodos()`（未完了一覧を開く）から
`ShowTodoCountIntent`（`.background`）に戻したので、**snippet が出なければタップしても何も起きない
コントロールになる**。その場合は `LaunchAppIntent.incompleteTodos()` に戻す（一覧を開く挙動自体は
`NavigationModel.pendingFilter` の修正で「ただアプリを開くだけ」ではなくなっている）。
なお snippet 内には `LaunchAppIntent.incompleteTodos()` のボタンを置いてあるので、snippet が出る場合でも
一覧へ抜ける経路は残る。

## 2026-08-12: 実機で決着 — Control は snippet を提示しない（呼出元だけを変えて比較）

前 2 項の「出ないと断定 → 誤りと訂正 → 検証を仕込む」の結末。**呼出元だけを変えて同じ Intent・
同じ snippet を走らせる**比較で確定した。

| # | 条件 | 結果 |
|---|------|------|
| 1 | Spotlight → `AddTodoIntent` → `TodoSnippetIntent` | **出る** ✅ |
| 2 | Spotlight → `ShowTodoCountIntent` → `TodoSummarySnippetIntent`（パラメータ無し）| **出る** ✅ |
| 3 | Control(Button) → `ShowTodoCountIntent` → 同上 | **出ない** ❌ |
| 4 | 3 + `allowedExecutionTargets = [.main]` | **出ない** ❌ |
| 5 | Control(Toggle / `SetValueIntent`) → `TodoSnippetIntent` | **出ない** ❌ |

2 と 3 は **Intent も snippet も同一**で、違うのは呼出元だけ。これで以下がすべて否定された:

- snippet 実装の不備（1・2 で成立）
- `TodoSummarySnippetIntent` が `@Parameter` を持たないこと（2 で成立。セッションのサンプルは
  パラメータ有りだが、無くても Spotlight では動く）
- 実行プロセス（4 でアプリプロセスに固定しても変化なし）
- `isDiscoverable = false`（2 と 3 で同一設定。2 は出ている）
- コントロールの形状（3 の Button と 5 の Toggle の両方で出ない）
- 宣言・メタデータの不備（ビルド成果物の `Metadata.appintents` を実際に読み、
  `ShowTodoCountIntent` に `outputFlags 36`(= `ShowsSnippetIntent` + value)、
  `TodoSummarySnippetIntent` に `systemProtocols: ["com.apple.link.systemProtocol.Snippet"]` が
  出ていること、アプリ / Widget Extension 双方に登録されていることを確認済み。
  `supportedModes` も、未宣言のサンプルと同じ `1`(background) で一致）

**結論**: Control は snippet の提示先ではない（iOS 27 / Xcode 27 beta 5 実測）。dialog と同じ扱い。
wwdc2025-275 1:40–1:59 の "control" は Control Center のコントロールではなく、アプリ内 UI の
ボタンを指していたと解釈するのが妥当（直前に "The TravelTracking app contains lots of landmarks"
とアプリ画面の話をしている流れ）。

**後片付け（実験用コードの撤去）**:

- `TodoCountControl` のアクションを `ShowTodoCountIntent` → `LaunchAppIntent.incompleteTodos()` に戻した。
  snippet が出ない以上、タップしても無反応のコントロールになるため。
- `SetTodoCompletionIntent` の戻り値を `.result()` に戻した（`ShowsSnippetIntent` を撤去）。
- `ShowTodoCountIntent` の `allowedExecutionTargets = [.main]` を撤去（切り分け用だった。
  Control から呼ばれなくなったので不要）。
- `IntentTodoWidgetBundle.init()` の `TodoEntityStore.register(container:)` は**残す**。
  これは実験の副産物ではなく本来必要な登録（Extension プロセスで snippet / deferred property が
  解決されると空になる問題への対処）。

**教訓**: 「どの面が何を提示するか」は、呼出元だけを変えて同じ Intent を走らせる比較が最短で確定させる。
今回も、最初に Spotlight で試していれば「snippet 実装の問題か / 面の問題か」が一発で分かれ、
プロセス・形状・パラメータの仮説を立てる必要すらなかった。**まず既知の良い面で動かし、
次に疑わしい面に持っていく**。逆順にやると変数が絡んで確定しない。

## 2026-08-12: 裏付け確認 — セッション群は「Control で snippet が出る」前提では語っていない

上記の実測結果が WWDC セッションと矛盾しないか、ローカル控え（`docs/references/wwdc/`）全 40 本を
横断して確認した。結果、**矛盾しない**どころか、専門セッション 2 本が相互に沈黙していることが分かった。

| セッション | Control への言及 | snippet / dialog の扱い |
|---|---|---|
| **wwdc2024-10157**「Extend your app's controls across the system」(Controls 専門) | 57 箇所 | **snippet も dialog も一度も出てこない**。唯一の `.result(` は `SetValueIntent` サンプルの空の `.result()`。挙げられるフィードバック手段は「`perform()` 完了時の自動リロード」「`controlWidgetStatus`」「`controlWidgetActionHint`」の 3 つだけ |
| **wwdc2025-281**「Design interactive snippets」(Snippets 専門) | **言及ゼロ**（control / Control Center / ControlWidget すべて 0 件）| 表示先は "Spotlight, Siri, and the Shortcuts app" のみ |
| wwdc2024-10210 | コントロール実装を一通り実演 | アクションは `OpenTrail`（アプリを開く）。"Or add actions and **status** to Control Center" と status 止まり。結果 UI の話は無い |
| wwdc2025-244 / 260 / 2026-310 / 2024-10134 / 10176 / 2022-10121 | 「App Intents は Control Center でも使える」という一般的な列挙のみ | 言及無し |

つまり **Controls 専門セッションは snippet に触れず、Snippets 専門セッションは Control に触れない**。
「できる」とも「できない」とも書かれていないが、少なくとも**できる前提で語られてはいない**。

### 唯一の反例 wwdc2025-275 の再評価

「コントロールのタップから snippet が出る」と読める唯一の箇所（1:40–1:59）について、同セッション内の
"control" の全用例を洗ったところ:

- "Supported Modes gives intents greater **control** over foregrounding"（一般語）
- "with the new view **control** APIs"（SwiftUI 側の話 = `onAppIntentExecution`）
- "you might want to **control** which one runs a particular intent"（一般語）
- "I'll tap on **the control** that runs an App Intent"（問題の箇所）

**このセッションは "Control Center" / "controls" / "ControlWidget" という語を一度も使っていない**。
一方 wwdc2024-10210 は同じことを説明するのに "A Control Center control" / "ControlWidget" /
"ControlWidgetButton" / "This is the new configuration mode for Control Center" と必ず明示している。
Apple のセッションは WidgetKit の Control を指すときは用語を明示する傾向があり、275 にそれが無いことから、
**あの "the control" はアプリ内 UI のコントロール（ボタン）を指していた**と読むのが自然。

これで実測（Control では出ない / Spotlight では出る）と一次資料の整合が取れた。以後、この件は
「実測 + セッション横断で裏付け済み」として扱う。

## 2026-08-12: Control Center の見え方を実測 → 隣のコントロールが更新されないバグを発見

制約再検証 C-8 の残タスク「実機 Control Center での見え方の確認」を、iOS 27 シミュレータの Control Center で実施した。

**確認できたこと（意図どおり）**: `ControlWidgetToggle` の状態がコントロール面にちゃんと出る。アクセシビリティ階層で `ToggleTodoControl` の `value` が `To Do` ↔ `Completed, Selected` と切り替わり、タップに追随した。Toggle 化した狙い（フィードバックをコントロール自身の再描画に寄せる）は成立している。

**見つかったバグ**: トグルで todo を完了にしても、隣の `TodoCountControl`（未完了数）が `2` のまま止まっていた。3 秒待っても、アプリを再インストールするまで直らない。

原因は `WidgetReloader.reloadAllWidgets()` が `WidgetCenter.shared.reloadAllTimelines()` しか呼んでいなかったこと。**ホームウィジェットとコントロールは別 API** で、`WidgetCenter` はコントロールを更新しない。システムが自動でリロードするのは「その Intent を実行したコントロール自身」だけなので、他のコントロールは明示的に `ControlCenter.shared.reloadAllControls()` を呼ぶ必要がある（`ControlCenter` は iOS 18+ / macOS 26+ / watchOS 26+、visionOS では unavailable なので `#if !os(visionOS)` で保護）。

修正後に再確認: トグル（Completed → To Do）と同時に `TodoCountControl` が `1` → `2` へ更新された。

この不具合は「トグルは正しく動いているのに、隣の数字だけ嘘をつく」という形なので、アプリ本体の UI やテストでは一切引っかからない。アプリ本体 / Siri からデータを変えたときも同様にコントロールだけ取り残されるため、影響範囲はトグル経由に限らない。

**残タスク**: `.promptsForUserConfiguration()`（対象 todo 未設定のときの設定フロー）と失敗時のエラー通知は、今回のシミュレータではコントロールが設定済みだったため通っていない。

> 前者は次項（2026-08-12）で確認済み。**後者（失敗時のエラー通知が実際に出るか）は未確認のまま → #30 の H 節で追跡**。

スクリーンショット: `.verification/2026-08-12-control-center/`（gitignore 対象）

## 2026-08-12: C-8 の残り 2 項目を実測 → 削除ボタンが全く動いていないのを発見

C-8 の残り（`.promptsForUserConfiguration()` の設定フロー / 失敗時のエラー通知）を iOS 27 シミュレータで確認しに行って、途中で**別の重大なバグ**を踏んだ。

**`.promptsForUserConfiguration()`: 意図どおり動く**。Control Center の「コントロールを追加」ギャラリーから "Complete Todo" をタップすると、その場で設定シートが出る（タイトル "Complete Todo / Intento"、説明文、`Todo` パラメータの行）。対象 todo が決まっていないコントロールをそのまま置かせない、という狙いは達成できている。シート内のピッカーを開く操作はシミュレータの remote-process シートで階層が取れず、選択までは追えなかった（実機で確認するのが早い）。

**エラー通知の確認中に発見: 詳細画面の「Delete Todo」が何も起きない**。設定済みコントロールが指す todo を消してエラー経路を作ろうとして、詳細画面の Delete Todo を押しても todo が消えなかった。コンソールに:

```
DeleteTodoIntent failed to execute with error: LNPerformActionErrorCodeUnsupportedValueType
```

原因は `DeleteTodoIntent.perform()` の `requestConfirmation(dialog:)`。**アプリ内の `Button(intent:)` には確認を提示する面が無いため、確認を要求した時点で失敗して削除まで到達しない**。Control で dialog / snippet が出ないのと同じ「呼出元に提示面が無い」系の問題で、こちらは失敗が無言なぶんタチが悪い。

影響範囲は UI の削除経路すべて: `DeleteButton`（一覧のスワイプ）/ `TodoDetailView` / `VisionOSTodoView` / `WatchTodoDetailView` の 4 箇所。**Siri / Shortcuts / AppIntentsTesting 経由では成功する**（確認に応じる相手が居るため）ので、AppIntentsTesting のクリーンアップは今まで正常に動いていた。

**なぜ気付かなかったか**: 既存の UI テスト `testDeleteTodo` が
```swift
if deleteButton.waitForExistence(timeout: 3) { ... XCTAssertFalse(todoCell.exists) }
```
と `if` で包まれていて、しかも探していたラベルが `"Delete"`（実際は `DeleteButton` の `.accessibilityLabel("Delete todo")`）だったため、**ボタンが見つからない → 中身が一度も実行されない → 緑**、という状態が続いていた。条件付き assert は「壊れていることを隠す」形で効く。

**対応**:
- 確認なしの `DeleteTodoImmediatelyIntent`（`isDiscoverable = false`）を追加。分ける理由は entity 解決の回避ではなく**対話の有無**で、`SnoozeTodoIntent` / `QuickSnoozeTodoIntent` と同じ構図
- スワイプの `DeleteButton` は「スワイプして Delete を押す」自体が確認なので確認なし版を直接実行
- 詳細画面（iOS / visionOS / watchOS）は SwiftUI の `.confirmationDialog` で確認してから確認なし版を実行。確認 UI がアプリ側に来たぶん、体験はむしろ標準的になった
- `DeleteTodoIntent`（確認付き）は Siri / Shortcuts 用としてそのまま残す
- テストを修正: `testDeleteTodo` の `if` を外して正しいラベルで assert、詳細画面用に `testDeleteTodoFromDetailView` を追加（確認ダイアログ → 削除まで）

**教訓**: `requestConfirmation` / `requestChoice` を含む Intent は、**アプリ内 `Button(intent:)` から呼ぶと失敗する**。対話を伴う Intent は Siri / Shortcuts 専用と考え、UI からは確認なし版を用意して、確認は SwiftUI 側で取る。そして**条件付き assert（`if ... { XCTAssert }`）はテストを書いていないのと同じ**。

## 2026-08-27: 通知が拒否されていると Control の失敗が完全に無音になる（#59）

`ControlNotificationHelper` は「Control の失敗を伝える唯一の経路」として置いてあるが、
**通知が拒否されている端末ではその経路自体が無言で死ぬ**ことに手当てが無かった（#32 → #59 の
残課題 2）。`UNUserNotificationCenter.add` の completion は許可が無くても error を返さない
（システムが黙って捨てる）ため、既存のログでは検出できていなかった。

送信前に `notificationSettings().authorizationStatus` を見る形に変え、出せないと分かったら
App Group の `UserDefaults` に記録を残すようにした（`MissedFeedback`）。書き手が Control /
Widget の Extension プロセスになり得るため、プロセスをまたげる置き場が必要だった。

**「設定が無効なら常に出す」ではなく「実際に取りこぼしたときだけ出す」にした**理由: ユーザーが
意図的に切っている設定を毎回蒸し返すのは、silent failure を直すためにうるさい失敗を作る形になる。
記録は経路が復活した時点（`requestAuthorization` が `true` を返した起動）でも消すようにして、
古い記録でバナーが残らないようにした。

同じ器をライブアクティビティ無効時（残課題 3）にも使った。`areActivitiesEnabled == false` の
無言 return は、ユーザー設定に沿った正常系なので `error` ログにはせず `warning` + 記録に留めている。

副産物: `UNMutableNotificationContent` / `UNNotificationRequest` は `Sendable` ではないので、
許可確認のために `Task` を挟むと「外で組んで渡す」形が sending 違反になる。content の組み立てごと
Task の中に移した。
