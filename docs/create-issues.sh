#!/bin/bash
# GitHub Issues 一括起票スクリプト
# 使い方: bash docs/create-issues.sh
# 前提: gh CLI がインストール済み & 認証済み (gh auth login)
#
# ラベルを事前に作成する場合:
#   gh label create verification --color 0E8A16 --description "実機検証が必要"
#   gh label create enhancement --color A2EEEF --description "機能改善"
#   gh label create bug --color D73A4A --description "バグ"

set -e

REPO="touyou/IntentTodo"

echo "Creating labels..."
gh label create verification --repo "$REPO" --color 0E8A16 --description "実機検証が必要" 2>/dev/null || true
gh label create enhancement --repo "$REPO" --color A2EEEF --description "機能改善" 2>/dev/null || true
gh label create bug --repo "$REPO" --color D73A4A --description "バグ" 2>/dev/null || true
gh label create new-api --repo "$REPO" --color 5319E7 --description "新API活用" 2>/dev/null || true
gh label create app-intents --repo "$REPO" --color FBCA04 --description "App Intents関連" 2>/dev/null || true

echo ""
echo "=== カテゴリ A: プラットフォーム別検証 ==="

gh issue create --repo "$REPO" \
  --title "verify: macOS での Button(intent:) 全アクション動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
macOS Catalyst 環境での App Intents 中心設計の検証。

## 検証項目
- [ ] `Button(intent:)` による全アクション実行（追加・完了切替・削除・お気に入り）
- [ ] SwiftData + CloudKit 同期の macOS 上での動作
- [ ] Spotlight 検索（`IndexedEntity`）での Todo 表示
- [ ] `NavigationStack` ベースのナビゲーション
- [ ] Siri / Shortcuts アプリからの Intent 実行

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Entities/TodoAppEntity.swift`
- `Packages/UI/Sources/UI/Views/TodoList/TodoListView.swift`

検証完了後、README.md のプラットフォーム別表で macOS の検証状況を ✅ に更新すること。
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: watchOS アプリ + コンプリケーション動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
watchOS アプリおよびコンプリケーションの実機検証。

## 検証項目
- [ ] `WatchTodoListView` での Todo 一覧表示
- [ ] `WatchAddTodoView` での Todo 追加
- [ ] `WatchTodoDetailView` での詳細表示
- [ ] `Button(intent:)` の watchOS 動作（Task パターン — insights/07 参照）
- [ ] コンプリケーション表示（Circular / Corner / Rectangular / Inline）
- [ ] SwiftData の watchOS 上での動作

## watchOS 固有の注意点
watchOS では `Button(intent:role:)` シグネチャが使えないため async パターンで代替。`docs/insights/07-platform-specific.md` 参照。

## 関連ファイル
- `IntentTodoWatchApp/Views/`
- `IntentTodoWatchApp/Complication/`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: visionOS 空間 UI + Ornament 動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
visionOS の空間 UI 対応の実機（またはシミュレータ）検証。

## 検証項目
- [ ] `NavigationSplitView` によるサイドバー + 詳細ペイン
- [ ] `glassBackgroundEffect()` のレンダリング
- [ ] `.hoverEffect(.lift)` の視線追跡対応
- [ ] Ornament 内のフィルター・ソート・追加ボタン
- [ ] `Button(intent:)` による全アクション実行
- [ ] Spatial UI でのアクセシビリティ

## 関連ファイル
- `Packages/UI/Sources/UI/Views/VisionOS/VisionOSTodoView.swift`
EOF
)"

echo ""
echo "=== カテゴリ B: Extension 別検証 ==="

gh issue create --repo "$REPO" \
  --title "verify: Control Center QuickAdd（通知パターン）の動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
Control Center の QuickAdd ボタンが `.background` + 通知パターンで正しく動作するか検証。

## 検証項目
- [ ] `QuickAddTodoNotifyIntent` の `perform()` がバックグラウンドで呼ばれる
- [ ] ローカル通知が正しく送信される
- [ ] 通知タップでアプリが開き Todo 追加画面に遷移する
- [ ] 通知権限が未許可の場合のフォールバック動作

## 関連ファイル
- `IntentTodoWidget/Controls/QuickAddTodoControl.swift`
- `IntentTodoWidget/Intents/ControlIntents.swift`
- `IntentTodoWidget/Helpers/ControlNotificationHelper.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: Control Center TodoCount（通知パターン）の動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
Control Center の TodoCount ボタンが未完了数をローカル通知で表示できるか検証。

## 検証項目
- [ ] `ShowTodoCountIntent` の `perform()` がバックグラウンドで呼ばれる
- [ ] 未完了 Todo 数が正しくカウントされる
- [ ] ローカル通知に正しい数値が表示される
- [ ] Todo 数が 0 の場合の表示

## 関連ファイル
- `IntentTodoWidget/Controls/TodoCountControl.swift`
- `IntentTodoWidget/Intents/ControlIntents.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: Live Activity（Dynamic Island + ロック画面）の動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
期限 1 時間以内の Todo に対する Live Activity の自動表示・操作の検証。

## 検証項目
- [ ] 期限 1 時間以内の Todo で Live Activity が自動開始される
- [ ] Dynamic Island にタイトル・残り時間が表示される
- [ ] ロック画面にカウントダウンが表示される
- [ ] `CompleteTodoFromActivityIntent`（LiveActivityIntent）で完了操作ができる
- [ ] `SnoozeTodoIntent` で 30 分延長ができる
- [ ] 完了時または期限 15 分経過後に自動終了する
- [ ] `LiveActivityIntent` によるバックグラウンド Activity 開始

## 公式Doc裏付け
> "you can only start a Live Activity while the app is in the foreground, unless you adopt App Intents and start the Live Activity using a LiveActivityIntent"

## 関連ファイル
- `IntentTodoLiveActivity/`
- `docs/insights/07-platform-specific.md`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: Siri フレーズと Shortcuts アプリからの Intent 実行検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
4 つの App Shortcuts が Siri と Shortcuts アプリから正しく動作するか検証。

## 検証項目
- [ ] "Add a todo in IntentTodo" → Todo 追加フロー
- [ ] "Show my todos in IntentTodo" → Todo 一覧表示
- [ ] "Show incomplete todos in IntentTodo" → 未完了 Todo 表示
- [ ] "Show favorite todos in IntentTodo" → お気に入り Todo 表示
- [ ] Shortcuts アプリで各 Intent がパラメータ付きで利用可能
- [ ] Siri がフレーズを正しく認識する
- [ ] `supportedModes` に基づく foreground/background 動作

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Shortcuts/TodoAppShortcuts.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: Spotlight 検索での Todo 表示検証（IndexedEntity）" \
  --label "verification" \
  --body "$(cat <<'EOF'
IndexedEntity を通じた Spotlight 検索連携の検証。

## 検証項目
- [ ] iOS の Spotlight で Todo アイテムが検索可能
- [ ] macOS の Spotlight で Todo アイテムが検索可能
- [ ] `DisplayRepresentation` の title / subtitle / image が正しく表示される
- [ ] 検索結果タップでアプリの該当 Todo に遷移する
- [ ] Todo の追加/削除が Spotlight インデックスに反映される

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Entities/TodoAppEntity.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: Home Widget 全サイズ（Small/Medium/Large）の動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
ホーム画面ウィジェットの各サイズでの表示・操作の検証。

## 検証項目
- [ ] Small ウィジェット: 未完了数 + Todo 一覧（3 件）表示
- [ ] Medium ウィジェット: Todo 一覧（4 件）+ 残り件数表示
- [ ] Large ウィジェット: Todo 一覧（5 件）+ クイック追加ボタン
- [ ] `Link(destination:)` によるアプリ起動（公式推奨パターン）
- [ ] フィルター設定（All / Incomplete / Favorites / DueToday）が反映される
- [ ] Todo の追加/完了でウィジェットが更新される（`WidgetReloader`）

## 公式Doc根拠
> "If you want to offer an interaction that opens the app, use Link"
(Apple: "Adding interactivity to widgets and Live Activities")

## 関連ファイル
- `IntentTodoWidget/IntentTodoWidget.swift`
- `IntentTodoWidget/Views/WidgetViews.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "verify: watchOS コンプリケーション全ファミリーの動作検証" \
  --label "verification" \
  --body "$(cat <<'EOF'
watchOS コンプリケーションの各ファミリーでの表示検証。

## 検証項目
- [ ] Circular: 未完了数の表示
- [ ] Corner: 進捗ゲージの表示
- [ ] Rectangular: 次の期限 Todo プレビュー
- [ ] Inline: 未完了数と次の期限表示
- [ ] タイムライン更新（Todo の追加/完了で更新される）

## 関連ファイル
- `IntentTodoWatchApp/Complication/`
EOF
)"

echo ""
echo "=== カテゴリ C: 新 API 活用・コード改善 ==="

gh issue create --repo "$REPO" \
  --title "enhance: onAppIntentExecution で IntentAppState を補完/置換" \
  --label "enhancement,new-api,app-intents" \
  --body "$(cat <<'EOF'
iOS 26 で追加された `onAppIntentExecution(_:perform:)` View modifier を活用し、現在の `IntentAppState` による Intent → UI 連携パターンを改善する。

## 背景
現在、Intent からアプリ UI を更新する場合、`IntentAppState`（App Group UserDefaults + Notification）を経由している。`onAppIntentExecution` を使えば、View modifier で宣言的にハンドリングでき、コードがシンプルになる。

## 実装方針
1. `LaunchAppIntent` / `OpenAddTodoIntent` に `TargetContentProvidingIntent` を追加
2. `IntentTodoApp.swift` のルートビューに `.onAppIntentExecution()` を設定
3. `IntentAppState` は Extension 間通信に限定し、アプリ内は `onAppIntentExecution` へ移行

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/AppState/IntentAppState.swift`
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Intents/LaunchAppIntent.swift`
- `IntentTodo/IntentTodoApp.swift`

## 参照
- CLAUDE.md「onAppIntentExecution」セクション
- docs/insights/04-ui-integration.md
EOF
)"

gh issue create --repo "$REPO" \
  --title "enhance: AppIntentSceneDelegate でシーン固有の Intent ハンドリング" \
  --label "enhancement,new-api,app-intents" \
  --body "$(cat <<'EOF'
iOS 26 の `AppIntentSceneDelegate` を活用し、シーンレベルで Intent をハンドリングする仕組みを追加する。

## 背景
macOS / visionOS / iPad マルチウィンドウでの適切なシーンでの Intent 処理を実現。

## 実装方針
1. `AppIntentSceneDelegate` を実装
2. `UISceneAppIntent` 準拠の Intent を定義
3. macOS / visionOS でのマルチウィンドウ対応
EOF
)"

gh issue create --repo "$REPO" \
  --title "bug: ControlWidgetButton の OpenIntent initializer が iOS 26 で動作しない" \
  --label "bug" \
  --body "$(cat <<'EOF'
Apple 公式ドキュメントに `ControlWidgetButton` の `OpenIntent` 専用 initializer（"Creates a button template for a control that launches an app"）が存在するが、iOS 26 正式版で動作しない。

## 現状
- 10 種類のアプローチを試行済み（詳細: `docs/insights/06-control-widget-ios26.md`）
- `.background` Intent + ローカル通知パターンで代替中

## TODO
- [ ] Apple Developer Forums で同様の報告を検索
- [ ] Feedback Assistant でバグレポートを提出
- [ ] 最小再現プロジェクトを作成
- [ ] 次期 Xcode / iOS ベータで動作確認
- [ ] 修正された場合、Control Widget を OpenIntent パターンに戻す
EOF
)"

gh issue create --repo "$REPO" \
  --title "enhance: TodoAppEntity の Spotlight 検索属性を強化" \
  --label "enhancement" \
  --body "$(cat <<'EOF'
現在の `IndexedEntity` 実装はデフォルトの `DisplayRepresentation` ベースのみ。`CSSearchableItemAttributeSet` で検索属性を強化する。

## 改善案
\`\`\`swift
extension TodoAppEntity: IndexedEntity {
    var searchableAttributes: CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet()
        attrs.keywords = ["todo", title].compactMap { \$0 }
        attrs.dueDate = dueDate
        return attrs
    }
}
\`\`\`

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Entities/TodoAppEntity.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "enhance: AddTodoIntent に .foreground(.deferred) モードを追加" \
  --label "enhancement,new-api,app-intents" \
  --body "$(cat <<'EOF'
Siri / Shortcuts から実行する際、タイトルのみなら `.background` で処理し、詳細設定が必要な場合のみ `continueInForeground()` でアプリを開くパターンを実装。

## 注意事項
- `continueInForeground()` は Control Widget コンテキストでは動作しない（insights/06 参照）
- Shortcuts / Siri 経由での使用を想定

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Intents/AddTodoIntent.swift`
EOF
)"

gh issue create --repo "$REPO" \
  --title "enhance: NavigationIntents に TargetContentProvidingIntent を追加" \
  --label "enhancement,new-api,app-intents" \
  --body "$(cat <<'EOF'
`OpenAddTodoIntent` / `OpenTodoListIntent` に `TargetContentProvidingIntent` を追加し、`onAppIntentExecution` パターンとの連携を可能にする。

## 現状
\`\`\`swift
public struct OpenAddTodoIntent: AppIntent {
    public static var supportedModes: IntentModes { .foreground }
}
\`\`\`

## 改善案
\`\`\`swift
public struct OpenAddTodoIntent: AppIntent, TargetContentProvidingIntent {
    public static var supportedModes: IntentModes { .foreground }
}
\`\`\`

## 関連ファイル
- `Packages/TodoAppIntents/Sources/TodoAppIntents/Intents/NavigationIntents.swift`
EOF
)"

echo ""
echo "✅ 全 16 件の issue を起票しました"
