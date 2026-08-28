# intent-centric-architecture

Apple プラットフォーム向けの **App Intent 中心設計** を、別プロジェクトでも再現できる形にまとめた Claude Code skill。

このリポジトリ ([IntentTodo](https://github.com/touyou/IntentTodo)) はサンプル実装であり、skill 自体は他のプロジェクトでも独立して使える。

## 何をしてくれるか

iOS / iPadOS / macOS / visionOS / watchOS の App Intent 設計について、Claude Code が以下の判断を支援する:

- **どのレベルから始めるか**（11 の原則のうち 3 つはプロセスが 2 つ以上ある場合だけ。ターゲット 1 つのアプリが守るのは残り 8 つ。拡張やプラットフォームが増えた時点で何が増えるか）
- 既存アプリへの後付け（ViewModel / URL ハンドラ / メニューコマンドに散った「アクション」の棚卸しから）
- 何を `AppIntent` にし、何を `AppEntity` にするか（verb-noun ルール、1 アクション 1 Intent、分けてよい 3 条件）
- どのプラットフォーム / システムサーフェスに展開するか（Action-Centered Design マトリクス、サーフェスごとの正しい API、サーフェス一覧カタログ）
- どの `AppSchema` ドメインが自分のアプリに当てはまるか（Siri 対応ドメイン / Shortcuts 限定ドメイン / 全部入り必須ドメインの区別）
- `supportedModes`（フォアグラウンド遷移）と `allowedExecutionTargets`（実行プロセス）の使い分け
- `@Dependency` + `AppDependencyManager` をどのプロセスに登録するか
- `AppIntentsPackage` / `includedPackages` / `AppShortcutsProvider` の置き場所
- 呼出元ごとのフィードバック経路（dialog / snippet / 通知 / コントロール自身の再描画）
- Entity の拡張 API（プロパティマクロ、Spotlight index、`TransientAppEntity`、`@UnionValue`、assistant schema）
- 検証の進め方（AppIntentsTesting → Shortcuts → Spotlight → Siri）

検証ベースは iOS 27 / Xcode 27 beta 5（2026-08 時点）。記述には根拠ラベル（`[Apple]` / `[measured]` / `[inferred]`）を付けてあるので、SDK が上がったら `[measured]` を優先的に再確認すればよい。

beta 6（27A5252f）では SDK 制約の棚卸しだけを行い、**記述を変える差分は無かった**（SSU training の `PlaceDescriptor` バグ / watchOS の assistant schema unavailable / `AppEntityContext` が audio のみ、のいずれも継続）。測り方と結果は [docs/devlog/2026-08-28-xcode27-beta6-recheck.md](../../docs/devlog/2026-08-28-xcode27-beta6-recheck.md)。

## 構成

```
.claude/skills/intent-centric-architecture/
├── SKILL.md                  # ルーター: 適用レベル・原則・判断表・既知のダメな回避策・参照先
├── scripts/
│   ├── audit_intents.py                 # 24 ルールの静的監査 + サーフェス到達状況レポート
│   └── inspect_appintents_metadata.py   # ビルド成果物のメタデータ検査
└── references/               # 必要になったときだけ読む詳細
    ├── 00-adoption-levels.md
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
    ├── 12-surface-catalog.md
    ├── 13-schema-domains.md
    └── code-templates.md
```

## スクリプト

skill を入れていなくても単体で使える。どちらも標準ライブラリのみ・引数なしで `--help`。

```bash
# 静的監査（ビルド不要）
python3 scripts/audit_intents.py . --fail-on error
python3 scripts/audit_intents.py . --list-rules
python3 scripts/audit_intents.py . --json

# いま到達しているシステムサーフェスと、未到達のものに何が必要か（ビルド不要）
python3 scripts/audit_intents.py . --coverage

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

## 経緯はここには書かない

skill 本体（`SKILL.md` / `references/`）は**現在のルールとその根拠だけ**を載せる。
「以前はこう書いていた」「どの仮説が外れた」「どのバグに何ヶ月気づかなかった」といった経緯は、
他プロジェクトにコピーされた先では解決しないパスになるので、ファイル内にポインタも置かない。

追いたい場合の入口は 2 つ:

- **根拠ラベル**（`[measured 2026-08-12, iOS 27 / Xcode 27 beta 5]`）— SDK が上がったとき何を再確認すべきかは、これだけで足りる
- 上流リポジトリ [touyou/IntentTodo](https://github.com/touyou/IntentTodo) の `docs/devlog/`（トピック別・時系列の調査ログ）と `docs/insights/`（各知見の詳細）

## 関連ドキュメント

- [Liquid Glass と App Intents 中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) — 設計思想の背景記事
- [Apple Developer: App Intents](https://developer.apple.com/documentation/appintents)

## ライセンス

MIT License — 親リポジトリの [LICENSE](../../LICENSE) を継承。
