# 開発ログ: Extension とデータ共有

`docs/insights/05-extensions-and-data-sharing.md` の現在のルールが、どういう経緯で今の形になったかを記録する。

## 2026-08-11: WWDC 2026 session 8017 のマイグレーション指針、一次資料未確認と判明

「マイグレーションは 1 プロセス（アプリ本体）だけが担当する」という指針は WWDC 2026 "SwiftData Group Lab"
(session 8017) で明言されたものとして記録していたが、`docs/references/wwdc/` のローカルアーカイブを確認したところ
session 8017 の書き起こしは存在しなかった（存在するのは `wwdc2026-8011-apple-intelligence-group-lab.md` のみで、
これは別テーマの Group Lab）。Group Lab はライブ Q&A で公式の書き起こしが提供されないことも多く、この指針は
一次資料で確認できていない伝聞ベースの知見として扱うことにした。

指針の内容自体（マイグレーション担当プロセスを 1 つに固定し、アプリ更新直後にアプリ本体より先に
Widget/Extension が起動し得ることを踏まえて Extension 側にはマイグレーションプランを含めない）は、
SwiftData のプロセス間共有における一般原則として妥当性が高いため、ルール自体は維持した。出典の再確認・
補強は今後の課題として残した。

## 2026-08-11: WidgetReloader 手動呼び出しが必要な理由をニュアンス訂正

wwdc2023-10028 (13:47 "As soon as your perform returns, the system will immediately initiate a reload of your
widget timeline" / 10:02 "reloads initiated from an interaction are always guaranteed") を確認した結果、
Widget 内の `Button(intent:)` から呼ばれた Intent はシステムが完了時に自動でタイムラインをリロードすることが
保証されていると判明した。手動リロードが本当に必要なのは、アプリ本体 / Siri / Shortcuts 経由など
**Widget 起点でない経路**でデータが変わったケースだけだった。

全 Intent で無条件に `WidgetReloader.reloadAllWidgets()` を呼ぶ現在のルール自体は安全側の運用のため
変更不要と判断し（呼び出し重複のコストは無視できる）、理由付けだけを「Widget 起点は自動、それ以外の経路の
ために必要」と正確化した。

## 2026-08-11: 「Extension 内では WidgetReloader を import できない場合がある」という記述を訂正

過去の記述に「Extension 内では `WidgetReloader` を import できない場合がある」という注意書きがあったが、
実態を確認したところ当てはまらないことが判明した。`WidgetReloader` は `TodoAppIntents` パッケージ内にあり、
`IntentTodoLiveActivity` / `IntentTodoWidget` の両 Extension ターゲットは（Intent 型を使うために）実際には
既に `import TodoAppIntents` していた。

これはプラットフォーム制約ではなく、Extension ターゲットの SPM 依存グラフに `WidgetReloader` の所在パッケージが
含まれているかどうかだけの問題で、本プロジェクトでは既に含まれている。実際、全 `WidgetReloader.reloadAllWidgets()`
呼び出しは `TodoService`（`TodoAppIntents` パッケージ内）に集約されており、Extension ターゲットのコードから
直接 `WidgetCenter.shared.reloadAllTimelines()` を呼んでいる箇所は無いことも確認した。誤った注意書きは削除し、
「依存が無いケースに遭遇したら所在パッケージを Extension ターゲットの依存に追加すればよい」という一般化した
形に直した。
