# intent-centric-architecture

Apple プラットフォーム向けの **App Intent 中心設計** を、別プロジェクトでも再現できる形にまとめた Claude Code skill。

このリポジトリ ([IntentTodo](https://github.com/touyou/IntentTodo)) はサンプル実装であり、skill 自体は他のプロジェクトでも独立して使える。

## 何をしてくれるか

iOS / iPadOS / macOS / watchOS / visionOS の App Intent 設計について、Claude Code が以下の判断を支援する:

- 何を `AppIntent` にし、何を `AppEntity` にするか（verb-noun ルール）
- どのプラットフォーム / システムサーフェスに展開するか（Action-Centered Design マトリクス）
- `supportedModes` の選び方（`.background` / `.foreground(.immediate/.dynamic/.deferred)`）
- `@Dependency` + `AppDependencyManager` の登録パターン（メインアプリ / Widget Extension / Live Activity プロセス）
- Live Activity / Widget からの実行で起きる `AppEntity` 解決のプロセス問題と Primary + FromExtension 分離パターン
- `onAppIntentExecution` / `AppIntentSceneDelegate` / cold-start fallback による Intent → UI 連携
- Dialog vs ローカル通知の使い分け（Control Widget で Dialog が表示されない問題を含む）

検証ベースは iOS 26 系（2026 春時点）。

## インストール

### Claude Code plugin としてインストール

```
/plugin install touyou/IntentTodo
```

(Claude Code の plugin marketplace に追加された後)

### skill ファイルを直接コピー

このディレクトリ (`skills/intent-centric-architecture/`) を、対象プロジェクトの `.claude/skills/` 以下、またはユーザーグローバルの `~/.claude/skills/` 以下にコピーするだけで動作する。

```
.claude/skills/intent-centric-architecture/
├── SKILL.md
└── references/
    ├── 01-actions-and-entities.md
    ├── 02-multi-surface-mapping.md
    ├── 03-supported-modes.md
    ├── 04-process-and-dependencies.md
    ├── 05-ui-integration.md
    ├── 06-feedback-channels.md
    ├── 07-data-and-side-effects.md
    └── code-templates.md
```

## 発火タイミング

Claude Code は SKILL.md の `description` を見て自動発火する。明示的に呼びたい場合は会話で `/intent-centric-architecture` と入力するか、「App Intent 中心で設計したい」「`supportedModes` どれにすべき？」のように具体的なトピックを話題にすればよい。

## 関連ドキュメント

- [Liquid Glass と App Intents 中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) — 設計思想の背景記事
- [Apple Developer: App Intents](https://developer.apple.com/documentation/appintents)

## ライセンス

MIT License — 親リポジトリの [LICENSE](../../LICENSE) を継承。
