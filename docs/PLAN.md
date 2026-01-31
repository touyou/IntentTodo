# App Intents中心設計に基づいたマルチプラットフォームTodoアプリ

## 設計思想

本プロジェクトは**App Intents中心設計**を採用しています。これは以下の概念を統合したアプローチです：

- **App Intent Driven Development**: アクションをデフォルトでApp Intentとして定義
- **Action-Centered Design**: アクションと情報を設計の原子単位とする
- **モデルベースUIデザイン**: ユースケース中心設計（誰が何を行動できる）との自然な写像

### 核心原則

> アプリは「アクションのクラスター」である。UIやプラットフォームは二次的であり、**アクション（Intent）と情報（Entity）が本質**。

これにより：
- デザイン（ユースケース）と実装（Intent）の間に自然な対応関係が生まれる
- 一度定義したアクションが複数のプラットフォームで再利用可能になる
- Apple Intelligenceとの統合が自然に実現される

## Todoアプリ自体の要件

- ベースは単純なToDo
- 完了、削除、お気に入り、検索、期限、ソート、カテゴリ分類、詳細、サブタスクなどがある
- 基本のUIは標準UIで作る（Liquid Glass時代ではUIクロームより**コンテンツとアクションが本質**）

## 設計要件

- 全てのアクションはApp Intentとして定義されること
- xcodeprojにしか存在できない中核となるファイル以外はSwift Package Managerで管理されること
- パッケージはレイヤーごと: Domain, Repository, AppIntents, UI（UseCase層は廃止→AppIntentsが担う）
- SwiftUIのView自体にはなるべくロジックを書かず、ViewModelに記述する（ただしViewModelはUI状態管理のみ）
- コンポーネントはデータ単位で分けて、何か更新があった際に再レンダリングの範囲がそのViewに絞られるような形にできると良さそう
- App Intentsで定義したアクションはButton(intent:)でなるべく直接実行できるように。その他にもApp Intentsを呼び出すようにしてなるべく二重でロジックを書かないようにする

## マルチプラットフォーム展開計画

Action-Centered Designの指針に従い、アクション/情報の特性に応じて展開先を決定：

### 展開マトリクス

| 機能/情報 | iOS App | ウィジェット | watchOS | visionOS | ライブアクティビティ | コントロールセンター | Shortcuts/Siri |
|----------|---------|-------------|---------|----------|------------------|-------------------|----------------|
| Todo一覧表示 | ✅ メイン | ✅ 今日分 | ✅ 簡易版 | ✅ 空間UI | - | - | ✅ |
| Todo詳細表示 | ✅ | - | ✅ | ✅ 空間UI | - | - | - |
| Todo追加 | ✅ | ✅ Large | ✅ | ✅ | - | ✅ | ✅ |
| 完了切り替え | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| お気に入り切り替え | ✅ | - | ✅ | ✅ | - | - | ✅ |
| 削除 | ✅ | - | ✅ | ✅ | - | - | ✅ |
| 未完了数 | ✅ | ✅ | ✅ コンプ | ✅ | - | ✅ | - |
| 期限1時間以内 | ✅ | ✅ | ✅ | ✅ | ✅ 自動表示 | - | - |
| スヌーズ | - | - | - | - | ✅ 30分延長 | - | - |
| 検索 | ✅ | - | - | ✅ | - | - | ✅ Spotlight |

### プラットフォーム別詳細

#### iOS/iPadOS メインアプリ
- NavigationStackによるリスト→詳細遷移
- フィルター・ソート・検索機能
- 期限の日時設定対応

#### ホーム画面ウィジェット (Small/Medium/Large)
- **Small**: 未完了数 + Todo一覧（3件）
- **Medium**: Todo一覧（4件）+ 残り件数表示
- **Large**: Todo一覧（5件）+ クイック追加ボタン

#### watchOS
- **アプリ**: 期限間近・未完了一覧、簡易追加
- **コンプリケーション**:
  - Circular: 未完了数
  - Corner: 進捗ゲージ
  - Rectangular: 次の期限Todoプレビュー
  - Inline: 未完了数と次の期限

#### visionOS
- **空間UI**: ガラス素材、Ornament、ホバーエフェクト
- **NavigationSplitView**: サイドバー+詳細のデュアルペイン
- **インタラクション**: 視線追跡・ハンドジェスチャー対応

#### ライブアクティビティ (Dynamic Island / Lock Screen)
- **トリガー**: 期限1時間以内のTodo（自動開始）
- **表示**: タイトル、残り時間カウントダウン
- **アクション**: 完了マーク、30分スヌーズ
- **終了**: 完了時または期限15分経過後

#### コントロールセンター (iOS 18+)
- **クイック追加**: アプリを開いて追加画面へ
- **Todo数表示**: 未完了数をタップでアプリ起動
- **緊急Todo切り替え**: 最も期限が近いTodoの完了切り替え

#### Action Button対応
- 物理ボタンでクイックTodo追加

### 設計フロー

1. **最小スクリーンから設計**: Apple Watchで本質的なアクションを特定
2. **Intent化**: 特定したアクションをApp Intentとして定義
3. **プラットフォーム展開**: 上記マトリクスに従って各プラットフォームに実装
4. **メインアプリUI**: アクションをクラスター化してスクリーン設計

## 拡張可能性（Future Enhancements）

App Intents中心設計をさらに深化させる次のフェーズ：

### Apple Intelligence統合（FoundationModels）

| Intent | 説明 | 実装方針 |
|--------|------|----------|
| GenerateTodosIntent | 「買い物リストを作って」でTodo自動生成 | LanguageModelSession + @Generable |
| SummarizeTodosIntent | 今日のTodoをサマリー表示 | Guided Generation |
| SmartCategorizeIntent | AI によるカテゴリ自動分類 | Tool Calling連携 |

```swift
// Tool Calling例: LLMからTodoIntentを呼び出し
struct TodoSearchTool: Tool {
    func call(arguments: Arguments) async throws -> ToolOutput {
        let todos = try await repository.search(term: arguments.query)
        return .string(todos.map { $0.title }.joined(separator: "\n"))
    }
}
```

### Visual Intelligence

- **IntentValueQuery**: カメラで撮影したメモや付箋からTodo項目を認識
- **Onscreen Entities**: 表示中のTodoについてSiri/ChatGPTに質問可能

```swift
// 画面上のTodoをSiriに認識させる
.userActivity("ViewingTodo") { activity in
    activity.appEntityIdentifier = EntityIdentifier(for: todoEntity)
}
```

### Intent Modes強化

現状の`openAppWhenRun`から、より細かい制御へ：

```swift
struct SmartAddTodoIntent: AppIntent {
    // バックグラウンドで実行、必要時のみフォアグラウンド
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    func perform() async throws -> some IntentResult {
        if needsUserInput {
            try await continueInForeground()
        }
        // ...
    }
}
```

### Interactive Snippets

Siri応答にインタラクティブなボタンを追加：

```swift
struct TodoSnippetIntent: SnippetIntent {
    var snippet: some View {
        VStack {
            Text(todo.title)
            HStack {
                Button("完了にする") { /* ToggleTodoCompletionIntent */ }
                Button("30分延長") { /* SnoozeTodoIntent */ }
            }
        }
    }
}
```

### Entity強化

```swift
struct TodoAppEntity: IndexedEntity {
    // 動的プロパティ（キャッシュなし、常に最新）
    @ComputedProperty
    var isFavorite: Bool {
        UserDefaults.standard.favorites.contains(id)
    }

    // 遅延ロード（明示的に要求されたときのみ取得）
    @DeferredProperty
    var subtaskCount: Int {
        get async throws {
            try await repository.fetchSubtasks(for: id).count
        }
    }

    // Spotlight詳細検索
    var searchableAttributes: CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet()
        attrs.keywords = [category?.name, "todo", title].compactMap { $0 }
        attrs.dueDate = dueDate
        return attrs
    }
}
```

### Liquid Glass対応強化

```swift
// Widget: アクセントモード対応
struct TodoWidgetView: View {
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        VStack {
            Text(todo.title)
                .widgetAccentable()  // アクセントグループ
            // ...
        }
    }
}

// App: ガラスボタンスタイル
Button("Add Todo") { }
    .buttonStyle(.glass)
```

### visionOS Widget強化

```swift
struct TodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(...) { entry in
            TodoWidgetView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .supportedMountingStyles([.elevated, .recessed])
        .widgetTexture(.glass)
    }
}

struct TodoWidgetView: View {
    @Environment(\.levelOfDetail) var levelOfDetail  // 近接認識

    var body: some View {
        if levelOfDetail == .simplified {
            // 遠距離: 大きいフォント、シンプル表示
        } else {
            // 近距離: 詳細表示
        }
    }
}
```

## SwiftUI, Swiftなどについて

- docs/referencesに最新の知識を置いておくので、そちらをまず見ること
- その上でわからないことはWeb検索し、なるべく最新のベストプラクティスに従うこと

## 参考資料

- [Liquid GlassとApp Intents中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) - 設計思想の背景
- [Action-Centered Design](https://blog.viditb.com/action-centered-design/) - Vidit Bhargavaによるフレームワーク
- [App Intent Driven Development](https://www.avanderlee.com/swift/app-intent-driven-development/) - SwiftLeeによる実装ガイド
