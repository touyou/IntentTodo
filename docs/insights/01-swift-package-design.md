# Swift Package 設計

## 依存関係設計

```
Packages/
├── Domain/       # 最も基底（依存なし）
├── Repository/   # Domain に依存
├── AppIntents/   # Repository に依存（コア）
└── UI/           # AppIntents に依存
```

### 依存関係の原則

1. **単方向依存**: 下位層は上位層を知らない
2. **Domain は独立**: 他のモジュールに依存しない
3. **AppIntents がコア**: ビジネスロジックの唯一の場所
4. **UI は薄く**: Intent実行トリガーと結果表示のみ

### @_exported import の活用

```swift
// Repository.swift
@_exported import Domain
```

これにより、Repositoryをimportするだけで自動的にDomainの型も使用可能になる。

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
