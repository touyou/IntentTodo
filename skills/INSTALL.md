# インストールと配布

9 skill は [Agent Skills 仕様](https://agentskills.io/specification)（`SKILL.md` + `scripts/` +
`references/`）そのままなので、**この仕様に対応したエージェントならどれでも同じファイルが動く**。
違うのは「どこに置くか」と「どう配布するか」だけ。skill の中身・発火条件は
[README.md](README.md) を参照。

このリポジトリが持っているパッケージ用ファイル:

| ファイル | 読む側 | 役割 |
|---|---|---|
| [`plugin.json`](../plugin.json)（リポジトリ直下） | Codex / Cursor / GitHub Copilot / VS Code / Kiro | [Agent Plugins 1.0](https://agent-plugins.org) のポータブルマニフェスト。`skills/` を固定位置として拾わせる |
| [`.agents/plugins/marketplace.json`](../.agents/plugins/marketplace.json) | Codex | リポジトリ内マーケットプレイス（`codex plugin marketplace add` の対象） |
| [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) | Claude Code | 同じものの Claude Code 版 |
| [`.claude-plugin/plugin.json`](../.claude-plugin/plugin.json) | Claude Code | Claude Code のプラグイン定義 |
| `skills/*/agents/openai.yaml` | Codex / ChatGPT アプリ | skill ごとの表示名・短い説明・既定プロンプト |

`plugin.json` の `$schema` は **1.0.0 に固定**している。Codex が受け付けるのは
`https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` だけで、1.1.0 を書くと
`Unsupported` 扱いでプラグインごと落ちる（`codex-rs/utils/plugins/src/plugin_namespace.rs` の
`SUPPORTED_AGENT_PLUGIN_SCHEMA_URIS`）。仕様側が 1.1.0 を出しても、Codex が対応するまで上げない。

## Codex

### プラグインとして入れる（推奨）

```bash
codex plugin marketplace add touyou/IntentTodo
```

`.agents/plugins/marketplace.json` が読まれ、`app-intents-centric-design` が 1 プラグインとして
出てくる（9 skill 入り）。あとは Codex の plugin 一覧からインストールする。

Codex がマーケットプレイスとして見るのは以下の 4 パスで、**先に見つかった 1 つだけ**を使う:
`.agents/plugins/marketplace.json` → `.agents/plugins/api_marketplace.json` →
`.claude-plugin/marketplace.json` → `.cursor-plugin/marketplace.json`。
このリポジトリは 1 番目と 3 番目を持っているので、Codex は 1 番目、Claude Code は 3 番目を読む。

ローカルのチェックアウトから試すなら:

```bash
codex plugin marketplace add ./IntentTodo
```

`source: local` はワーキングツリーをそのままコピーするので、**`.build/` や DerivedData が
残っているツリーを指すと数 GB コピーされる**。素のクローンか GitHub 経由を使う。

### skill を直接置く

```bash
# プロジェクト単位
mkdir -p .agents/skills && cp -R path/to/IntentTodo/skills/app-intents-* .agents/skills/
# ユーザー単位
cp -R path/to/IntentTodo/skills/app-intents-* ~/.agents/skills/
```

`~/.codex/config.toml` の `[[skills.config]]` で個別に無効化できる。

### OpenAI の公式ディレクトリへ載せる

ChatGPT / Codex 共通の公開ディレクトリは、2026-08 時点で**サードパーティからの登録が開いていない**
（submission / self-serve publishing とも "coming soon"）。開いたら
[Build plugins](https://developers.openai.com/codex/build-plugins) の手順に従う。それまでの公開手段は
上の `codex plugin marketplace add touyou/IntentTodo`（リポジトリマーケットプレイス）。

## Claude Code

```
/plugin marketplace add touyou/IntentTodo
/plugin install app-intents-centric-design@intenttodo
```

skill ファイルを直接置く場合は、8 つのディレクトリを対象プロジェクトの `.claude/skills/` か
ユーザーグローバルの `~/.claude/skills/` にコピーする。

## Gemini CLI

`.agents/skills/`（`~/.agents/skills/`）を `.gemini/skills/` の別名として読むので、Codex と同じ
配置がそのまま効く。ワークスペース側の skill は `/trust` 済みでないと読まれない。

```bash
gemini skills install touyou/IntentTodo            # ユーザー単位
gemini skills install touyou/IntentTodo --scope workspace
/skills list                                        # セッション内で確認
```

## GitHub Copilot / Cursor / その他

`gh skill` が各エージェントの想定ディレクトリへ振り分けてくれるので、**エージェントごとの置き場を
覚える必要はない**:

```bash
gh skill install touyou/IntentTodo --all --agent github-copilot
gh skill install touyou/IntentTodo --all --agent cursor --scope user
gh skill install touyou/IntentTodo app-intents-testing --agent codex
gh skill list
```

`--agent` は github-copilot / claude-code / cursor / codex / gemini-cli / antigravity / amp /
opencode など 40 種類以上。`gh skill install --help` に一覧がある。

Copilot 単体で完結させたいなら、リポジトリの `.github/skills/` に置いてコミットする形でもよい。

## 公開側の作業

### skill を GitHub の検索対象に載せる

```bash
gh skill publish --dry-run   # Agent Skills 仕様に対する検証だけ
gh skill publish --tag v0.5.0
```

`publish` は 9 skill を仕様に照らして検証したうえで、リポジトリに `agent-skills` トピックを付け、
リリースを作る。これで `gh skill search app-intents` から見つかる。
検証は `skills/*/SKILL.md` を見て、命名規則・ディレクトリ名との一致・`name` / `description` の有無・
`allowed-tools` の型・インストール時メタデータの残骸を確認する。**リリース前に必ず `--dry-run` を
通す**（`license` のような推奨フィールドの欠落も出る）。

### バージョンを上げるとき

版番号は 3 か所にある。**同時に上げる**:

- `plugin.json`（Agent Plugins）
- `.claude-plugin/plugin.json`（Claude Code）
- `.claude-plugin/marketplace.json` の plugins[].version

## 対応状況の根拠

| 事実 | 根拠 |
|---|---|
| 9 skill が Agent Skills 仕様に適合 | `gh skill publish --dry-run` が警告なしで通る（2026-08-31 実行） |
| `.claude-plugin/marketplace.json` + `source: "./"` で 9 skill 入りプラグインとして入る | `claude plugin marketplace add ./` → `install` → キャッシュ内に `skills/` 9 本を確認（2026-08-31 実行） |
| Codex のマーケットプレイス探索パスと順序 | [openai/codex `core-plugins/src/marketplace.rs`](https://github.com/openai/codex/blob/main/codex-rs/core-plugins/src/marketplace.rs) の `MARKETPLACE_MANIFEST_RELATIVE_PATHS` |
| Codex は root `plugin.json` を Agent Plugins として読み、`skills/` を固定位置で拾う | [`core-plugins/src/agent_plugin_manifest.rs`](https://github.com/openai/codex/blob/main/codex-rs/core-plugins/src/agent_plugin_manifest.rs) |
| Codex が受け付ける `$schema` は 1.0.0 のみ | [`utils/plugins/src/plugin_namespace.rs`](https://github.com/openai/codex/blob/main/codex-rs/utils/plugins/src/plugin_namespace.rs) |
| `extensions["com.openai"].interface` が Codex の表示メタデータになる | 同上 `agent_plugin_manifest.rs`（無い場合は `.codex-plugin/plugin.json` をオーバーレイ） |
| `agents/openai.yaml` の `interface` フィールド | [Build skills](https://developers.openai.com/codex/skills) |
| 公式ディレクトリが第三者に開いていない | [Build plugins](https://developers.openai.com/codex/build-plugins)（2026-08 時点） |

Codex / Gemini CLI は**手元に CLI が無いため未実行**（`gh skill` と Claude Code は実行済み）。
ドキュメントとソースからの確定にとどまる。
