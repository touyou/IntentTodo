# 8 skill を Claude Code 以外のエージェントへ配れる形にした経緯

2026-08-31。`skills/` の 8 本は Claude Code 前提で書き始めたが、`SKILL.md` の形式は
[Agent Skills](https://agentskills.io/specification) としてほぼそのまま他エージェントでも通る。
「Codex のマーケットプレイスへ載せたい」から始めて、どこまでを 1 つのパッケージで賄えるかを調べた。

## 分かったこと: 増やすのは配布用マニフェストだけで、skill 本体は 1 セットで足りる

- **skill 本体はコピー不要**。Codex / Gemini CLI / GitHub Copilot / Cursor はいずれも
  `SKILL.md` + `scripts/` + `references/` の同じ仕様を読む。エージェント別に差があるのは
  **置き場所と配布経路だけ**だった
- `gh skill publish --dry-run` で 8 本すべてが仕様検証を通った。唯一の指摘は
  `license` フィールド（推奨）の欠落だったので、8 本の frontmatter に `license: MIT` を追加した
- **Agent Plugins**（2026-08-06 公開、Vercel / AWS / Cursor / Microsoft / OpenAI / Google）が
  「リポジトリ直下 `plugin.json` + `skills/`」を共通のパッケージ形式として定義していて、
  このリポジトリの構成が既にそれと一致していた。`plugin.json` 1 枚で
  Codex / Cursor / Copilot / VS Code / Kiro に届く

追加したファイル:

| ファイル | 読む側 |
|---|---|
| `plugin.json` | Codex / Cursor / Copilot / VS Code / Kiro（Agent Plugins） |
| `.agents/plugins/marketplace.json` | Codex（リポジトリマーケットプレイス） |
| `.claude-plugin/marketplace.json` | Claude Code |
| `skills/*/agents/openai.yaml` | Codex / ChatGPT アプリ（表示名・既定プロンプト） |

## `$schema` は 1.1.0 ではなく 1.0.0 で止めた

Agent Plugins の仕様リポジトリには `schemas/1.0.0/` と `schemas/1.1.0/` の両方があり、
新しい方を書きたくなる。が、Codex が受け付ける URI は
`SUPPORTED_AGENT_PLUGIN_SCHEMA_URIS = [".../1.0.0/plugin.schema.json"]` の 1 つだけで、
`agent-plugins.org/schemas/` 始まりで未知のバージョンは `Unsupported` としてプラグインごと
拒否される（`codex-rs/utils/plugins/src/plugin_namespace.rs`）。**仕様が先に進んでいても、
クライアント側が対応するまで上げない**。

同じ調べ方で確定したこと（すべて openai/codex のソース）:

- マーケットプレイスは `.agents/plugins/marketplace.json` →
  `.agents/plugins/api_marketplace.json` → `.claude-plugin/marketplace.json` →
  `.cursor-plugin/marketplace.json` の順に探して、**最初に見つかった 1 つだけ**を使う。
  Claude 用と Codex 用を同じリポジトリに置いても二重に並ばない
- root `plugin.json` があると `skills/` と `mcp.json` は**固定位置**として拾われ、
  マニフェストからの上書きはできない
- 表示メタデータは `extensions["com.openai"].interface` に置ける（無ければ
  `.codex-plugin/plugin.json` がオーバーレイとして読まれる）。`defaultPrompt` は 3 件・各 128 文字まで
- marketplace の `policy` は省略可で、既定は `AVAILABLE` / `ON_INSTALL`

## `/plugin install touyou/IntentTodo` は元から成立していなかった

`skills/README.md` にそう書いてあったが、Claude Code は
**`.claude-plugin/plugin.json` だけのリポジトリをマーケットプレイスとして追加できない**。
`marketplace.json` を置いて `/plugin marketplace add` → `/plugin install <name>@<marketplace>` の
2 段が正しい。今回 `marketplace.json` を追加したので、この記述ごと直った。

ローカルで通しで確認した（`claude plugin marketplace add ./` → `install` → キャッシュに
`skills/` 8 本を確認 → uninstall / marketplace remove）。

## `source: "./"` はワーキングツリーを丸ごとコピーする

上の確認で **4.0 GB** コピーされた。プラグインルート = リポジトリルートなので、
`.gitignore` 済みの `.build/` まで含めて持っていかれる（git 追跡分は 3 MB）。
GitHub 経由のインストールは追跡されているファイルだけなので実害はないが、
ローカルパスで試すときは素のクローンを指す。この注意は `skills/INSTALL.md` に書いた。

なお「skills を小さなサブディレクトリに移してプラグインルートを分ける」案は採らなかった。
`skills/` へのリンクがドキュメント側に多数あるうえ、`plugins/<name>/skills` から
`../../skills` への symlink は Agent Plugins 仕様がプラグインルート外への解決を禁じているため
（クライアントは拒否する）成立しない。

## 未実行のまま残したこと

手元に `codex` / `gemini` CLI が無く、**Codex と Gemini CLI では実行できていない**。
`gh skill publish --dry-run` と Claude Code のインストールは実行済み。
OpenAI 公式のプラグインディレクトリは 2026-08 時点で第三者登録が開いていないため、
公開手段はリポジトリマーケットプレイス（`codex plugin marketplace add touyou/IntentTodo`）と
`gh skill publish`（GitHub のリリース + `agent-skills` トピック）の 2 つ。
