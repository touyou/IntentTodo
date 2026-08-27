# Swift Package 設計

## 依存関係設計

現行 7 パッケージ構成:

```
Packages/
├── Domain/          # 最基底 (依存なし)。SwiftData モデル / DueDateStatus / ActivityAttributes
├── Repository/      # Domain に依存。データアクセス層 (Protocol + SwiftData impl)
├── TodoAppIntents/  # Repository に依存。Intent 定義 + ビジネスロジック + Shortcuts (コア)
├── UI/              # TodoAppIntents + Domain (+ LiveActivity) に依存。メインアプリ SwiftUI
├── LiveActivity/    # Domain + TodoAppIntents に依存。iOS 限定、ActivityKit 管理 + Lock Screen View
├── WidgetUI/        # Domain + TodoAppIntents に依存。ホーム Widget の View 層
└── WatchUI/         # Domain + TodoAppIntents に依存。watchOS 限定、View + Components + Complication
```

`LiveActivity` / `WidgetUI` / `WatchUI` の 3 パッケージは UI パッケージと並列の「表示側の葉ノード」で、互いには依存しない。各 Extension ターゲット (`IntentTodoWidgetExtension` / `IntentTodoLiveActivityExtension` / `IntentTodoWatchApp`) はそれぞれ対応するパッケージを import し、ターゲット内には `@main` / `WidgetBundle` / `ActivityConfiguration` / Widget 宣言などのシステム結線スキャフォルドだけを置く。

### 依存関係の原則

1. **単方向依存**: 下位層は上位層を知らない
2. **Domain は独立**: 他のモジュールに依存しない
3. **TodoAppIntents がコア**: ビジネスロジックの唯一の場所
4. **UI 系は薄く**: Intent 実行トリガーと結果表示のみ
5. **Extension ターゲットは scaffold のみ**: View 層・Activity 管理・Complication 定義は全て SPM 側に配置して、プレビュー高速化とテスト可能化を得る
6. **`WatchUI` は `.watchOS(.v27)` のみ宣言**: iOS / macOS 側ターゲットから誤って import した際にコンパイル時に弾ける

### `@_exported import` は現在使っていない

```swift
// 例: Repository.swift で書けば、Repository を import しただけで Domain の型も使える
@_exported import Domain
```

依存の隠蔽になり、どのモジュールの型を使っているかが読めなくなるため、**現在は各ファイルで
必要なモジュールを明示的に import している**（`Domain` と `TodoAppIntents` を並べて書く）。

---

## DevDock式パッケージ構成

各パッケージが独立した `Package.swift` を持ち、相対パスで依存関係を参照する構成。

```
ProjectRoot/
├── ProjectName/              # アプリソース
├── ProjectName.xcodeproj     # Xcodeプロジェクト
└── Packages/                 # 独立したパッケージ群
    ├── Domain/
    │   ├── Package.swift     # 独立したマニフェスト
    │   ├── Sources/Domain/
    │   └── Tests/DomainTests/
    ├── Repository/
    │   ├── Package.swift     # path: "../Domain" で依存
    │   └── ...
    └── UI/
        ├── Package.swift     # path: "../Repository" で依存
        └── ...
```

### 相対パス依存の記述

```swift
// Packages/Repository/Package.swift
let package = Package(
    name: "Repository",
    dependencies: [
        .package(path: "../Domain"),  // 相対パスで参照
    ],
    targets: [
        .target(
            name: "Repository",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
            ]
        ),
    ]
)
```

### メリット

1. **xcworkspace不要**: xcodeprojにPackagesフォルダをドラッグするだけ
2. **各パッケージが独立**: 個別にビルド・テスト可能
3. **明確な依存関係**: 各Package.swiftで依存が明示される
4. **Xcodeとの親和性**: パッケージ内のソースが直接編集可能

### ルート Package.swift 方式との比較

| 観点 | DevDock式（独立Package.swift） | ルートPackage.swift方式 |
|-----|-------------------------------|----------------------|
| Xcodeでの編集 | 直接編集可能 | 設定次第 |
| 個別ビルド | 各パッケージで可能 | 全体のみ |
| 依存の明確さ | 各ファイルで明示 | 1ファイルに集約 |
| xcworkspace | 不要 | 必要な場合あり |
