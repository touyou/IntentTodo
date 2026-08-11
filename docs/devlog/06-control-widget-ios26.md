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
