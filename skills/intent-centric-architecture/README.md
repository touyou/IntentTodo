# intent-centric-architecture

Apple プラットフォーム向けの **App Intent 中心設計** を、別プロジェクトでも再現できる形にまとめた Claude Code skill。

このリポジトリ ([IntentTodo](https://github.com/touyou/IntentTodo)) はサンプル実装であり、skill 自体は他のプロジェクトでも独立して使える。

## 何をしてくれるか

iOS / iPadOS / macOS / watchOS / visionOS の App Intent 設計について、Claude Code が以下の判断を支援する:

- 何を `AppIntent` にし、何を `AppEntity` にするか（verb-noun ルール、1 アクション 1 Intent、分けてよい 3 条件）
- どのプラットフォーム / システムサーフェスに展開するか（Action-Centered Design マトリクス、サーフェスごとの正しい API）
- `supportedModes`（フォアグラウンド遷移）と `allowedExecutionTargets`（実行プロセス）の使い分け
- `@Dependency` + `AppDependencyManager` をどのプロセスに登録するか
- `AppIntentsPackage` / `includedPackages` / `AppShortcutsProvider` の置き場所
- 呼出元ごとのフィードバック経路（dialog / snippet / 通知 / コントロール自身の再描画）
- Entity の拡張 API（プロパティマクロ、Spotlight index、`TransientAppEntity`、`@UnionValue`、assistant schema）
- 検証の進め方（AppIntentsTesting → Shortcuts → Spotlight → Siri）

検証ベースは iOS 27 / Xcode 27 beta 5（2026-08 時点）。記述には根拠ラベル（`[Apple]` / `[measured]` / `[inferred]`）を付けてあるので、SDK が上がったら `[measured]` を優先的に再確認すればよい。

## 構成

```
.claude/skills/intent-centric-architecture/
├── SKILL.md                  # ルーター: 原則・判断表・参照先
├── scripts/
│   ├── audit_intents.py                 # 17 ルールの静的監査
│   └── inspect_appintents_metadata.py   # ビルド成果物のメタデータ検査
└── references/               # 必要になったときだけ読む詳細
    ├── 01-actions-and-entities.md
    ├── 02-multi-surface-mapping.md
    ├── 03-execution-modes.md
    ├── 04-process-and-dependencies.md
    ├── 05-ui-integration.md
    ├── 06-feedback-channels.md
    ├── 07-data-and-side-effects.md
    ├── 08-platform-and-availability.md
    ├── 09-verification.md
    ├── 10-advanced-entity-apis.md
    ├── 11-interaction-and-scale.md
    └── code-templates.md
```

## スクリプト

skill を入れていなくても単体で使える。どちらも標準ライブラリのみ・引数なしで `--help`。

```bash
# 静的監査（ビルド不要）
python3 scripts/audit_intents.py . --fail-on error
python3 scripts/audit_intents.py . --list-rules
python3 scripts/audit_intents.py . --json

# ビルド成果物の Metadata.appintents を読む（ビルド後）
python3 scripts/inspect_appintents_metadata.py --find MyProject
python3 scripts/inspect_appintents_metadata.py path/to/MyApp.app -v
```

`inspect_appintents_metadata.py` は「ビルドは緑なのに機能が存在しない」タイプの失敗を唯一可視化できる:
`autoShortcuts: 0`（AppShortcutsProvider がパッケージにあって登録されていない）、プロパティ 0 件の entity、
登録されなかった schema 適合、ターゲットに届いていない intent など。

## インストール

### Claude Code plugin として

```
/plugin install touyou/IntentTodo
```

### skill ファイルを直接コピー

このディレクトリ (`skills/intent-centric-architecture/`) を、対象プロジェクトの `.claude/skills/` 以下、
またはユーザーグローバルの `~/.claude/skills/` 以下にコピーするだけで動作する。

## 発火タイミング

`SKILL.md` の `description` を見て自動発火する。明示的に呼ぶなら `/intent-centric-architecture`、
あるいは「App Intent 中心で設計したい」「`supportedModes` どれにすべき？」「コントロールから dialog が出ない」
のように具体的なトピックを話題にすればよい。

## 関連ドキュメント

- [Liquid Glass と App Intents 中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) — 設計思想の背景記事
- [Apple Developer: App Intents](https://developer.apple.com/documentation/appintents)
- 本リポジトリの `docs/insights/` — 各知見の詳細、`docs/devlog/` — そのルールに至った調査・失敗・再検証の記録

## ライセンス

MIT License — 親リポジトリの [LICENSE](../../LICENSE) を継承。
