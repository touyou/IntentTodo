# App Intents 中心設計 skills

Apple プラットフォーム向けの **App Intent 中心設計** を、別プロジェクトでも再現できる形にまとめた
Agent Skills 群。**場面ごとに 9 本**に分かれていて、やりたいことに応じて自動発火する。
Claude Code / Codex / Gemini CLI / GitHub Copilot / Cursor で同じファイルが使える（[INSTALL.md](INSTALL.md)）。

このリポジトリ ([IntentTodo](https://github.com/touyou/IntentTodo)) はサンプル実装であり、skill 自体は
他のプロジェクトでも独立して使える。

## 9 本の分担

`app-intents-centric-design` が入口で、残り 8 本が場面ごとの詳細。**どれを呼ぶか分からないときは
入口に投げれば振り分けられる**（症状 → skill の対応表を持っている）。

| skill | 発火する「やりたいこと / 症状」 |
|---|---|
| **app-intents-centric-design** | アプリの機能を Siri / ショートカットから使えるようにしたい。既存アプリに後付けしたい。何を Intent にすべきか。設計をレビューしてほしい |
| **app-intents-design-session** | 何を Intent にすべきか一緒に考えてほしい / 既存の App Intents を棚卸ししたい / 画面ベースの機能一覧をアクションに落としたい / どのアクションにウィジェットやコントロールを与えるか / 名前と Siri の言い回しを決めたい |
| **app-intents-system-surfaces** | ウィジェットにボタンを付けたい / コントロールセンターに出したい / Dynamic Island / Apple Watch / Action ボタン / カメラで検索 / 集中モード。「どこに出すべき？」 |
| **app-intents-execution-and-processes** | ウィジェットのボタンが動かない / `Failed to retrieve dependency` / アプリが勝手に開く・開かない / パッケージに置いたら Shortcuts に出ない / 複数プラットフォーム対応 |
| **app-intents-ui-and-feedback** | アプリ内ボタンから実行したい / 押しても何も起きない / 確認ダイアログが出ない / 実行後に画面遷移したい / Siri に喋らせたい / 通知が来ない |
| **app-intents-parameters-and-prompts** | パラメータを追加したい / Shortcuts の編集画面にパラメータが出ない / ユーザーに選ばせたい・確認を取りたい / 値を空にできない / 場所や写真をパラメータにしたい |
| **app-intents-entities-and-search** | データを Entity にしたい / Shortcuts が値を読めない・絞り込めない / Spotlight に出したい / Siri の読み上げが変 / 大量データ / App Schema（reminders 等）に適合したい |
| **app-intents-testing** | ちゃんと動いているか確かめたい / ビルドは緑なのに機能が存在しない / テストを書きたい / テストは緑なのに壊れている |
| **app-intents-localization** | 多言語対応したい / Intent の文言だけ英語のまま / String Catalog に出てこない / Siri のフレーズを訳したい / 訳文に英語が混じる |

横断ルール（11 の非交渉ルール・既知のダメな回避策・根拠ラベル運用）は**複製せず入口だけに置いて
ある**。同じ情報を 2 箇所に書かない、という [docs/devlog/README.md](../docs/devlog/README.md) の
方針をそのまま適用している。

検証ベースは **iOS 27 / Xcode 27 beta 6（2026-08 時点）**。記述には根拠ラベル
（`[Apple]` / `[measured]` / `[inferred]`）が付いているので、SDK が上がったら `[measured]` を
優先的に再確認すればよい。

## 構成

```
skills/
├── app-intents-centric-design/          # 入口: 11 ルール・レベル判定・症状の振り分け
│   ├── SKILL.md
│   ├── scripts/audit_intents.py         # 24 ルールの静的監査 + サーフェス到達状況
│   └── references/{adoption-levels, actions-and-intents,
│                   service-and-side-effects, templates}.md
├── app-intents-design-session/             # 対話でユースケース → Intent 集合を導く進行役
│   └── references/{interview, gap-analysis, artifacts}.md
├── app-intents-system-surfaces/
│   └── references/{surface-catalog, controls,
│                   visual-intelligence-and-onscreen}.md
├── app-intents-execution-and-processes/
│   └── references/{execution-modes, dependencies-and-registration,
│                   packaging, platform-availability, templates}.md
├── app-intents-ui-and-feedback/
│   └── references/{ui-integration, feedback-channels, snippets, templates}.md
├── app-intents-parameters-and-prompts/
│   └── references/{parameter-summaries, asking-and-updating}.md
├── app-intents-entities-and-search/
│   └── references/{entity-surface, property-macros, spotlight,
│                   schema-domains, entity-shapes-and-scale, templates}.md
├── app-intents-testing/
│   ├── scripts/inspect_appintents_metadata.py   # ビルド成果物のメタデータ検査
│   ├── scripts/inspect_donation_stream.py       # donation 観測（検証専用・非公開パス）
│   └── references/{metadata, appintents-testing, tests-that-lie, templates}.md
└── app-intents-localization/
    ├── scripts/check_intent_copy_localization.py  # Intent コピーの訳漏れ検出
    └── references/{intent-copy, package-ui-copy, siri-phrases, verifying}.md
```

各 skill には `SKILL.md` のほかに `agents/openai.yaml`（Codex / ChatGPT アプリ向けの表示名・
短い説明・既定プロンプト）が入っている。他のエージェントはこのファイルを無視する。

## スクリプト

skill を入れていなくても単体で使える。すべて標準ライブラリのみ・`--help` あり。

```bash
# 静的監査（ビルド不要）— 24 ルール
python3 app-intents-centric-design/scripts/audit_intents.py . --fail-on error
python3 app-intents-centric-design/scripts/audit_intents.py . --list-rules
python3 app-intents-centric-design/scripts/audit_intents.py . --json

# いま到達しているシステムサーフェスと、未到達のものに何が必要か（ビルド不要）
python3 app-intents-centric-design/scripts/audit_intents.py . --coverage

# 実装済みの Intent / Entity / App Shortcut 枠と、どの Intent も届いていないアクション（ビルド不要）
python3 app-intents-centric-design/scripts/audit_intents.py . --gap

# ビルド成果物の Metadata.appintents を読む（ビルド後）
python3 app-intents-testing/scripts/inspect_appintents_metadata.py --find MyProject
python3 app-intents-testing/scripts/inspect_appintents_metadata.py path/to/MyApp.app -v

# Intent コピーが catalog から漏れていないか（ビルド後）
python3 app-intents-localization/scripts/check_intent_copy_localization.py

# donation の観測（シミュレータ限定・検証専用。出荷コードで依存しない）
python3 app-intents-testing/scripts/inspect_donation_stream.py --snapshot
python3 app-intents-testing/scripts/inspect_donation_stream.py --diff --bundle ""
```

`inspect_appintents_metadata.py` は「ビルドは緑なのに機能が存在しない」タイプの失敗を唯一可視化できる:
`autoShortcuts: 0`（`AppShortcutsProvider` がパッケージにある）、プロパティ 0 件の entity、
Shortcuts 編集画面に出ていないパラメータ、登録されなかった schema 適合、**同じ schema を主張する型が 2 つ**。

## インストール

[Agent Skills 仕様](https://agentskills.io/specification)に沿っているので、**Claude Code だけでなく
Codex / Gemini CLI / GitHub Copilot / Cursor でも同じファイルが動く**。エージェント別の手順・
パッケージ用ファイルの役割・公開手順は [INSTALL.md](INSTALL.md)。

```
# Claude Code
/plugin marketplace add touyou/IntentTodo
/plugin install app-intents-centric-design@intenttodo

# Codex
codex plugin marketplace add touyou/IntentTodo

# Copilot / Cursor / Gemini CLI / その他（置き場は gh が振り分ける）
gh skill install touyou/IntentTodo --all --agent github-copilot
```

skill 同士は名前で相互参照している（「詳細は `app-intents-testing` を見よ」など）うえ、
スクリプトを相対パスで参照している箇所もあるので、**9 本まとめて入れるのが想定構成**。
入口 1 本だけを入れると参照先が無い状態になる。

## 発火タイミング

各 `SKILL.md` の `description` を見て自動発火する。**用語を知らなくても発火する**ように、
「やりたいこと」と「症状」で書いてある（「押しても何も起きない」「ウィジェットにボタンを付けたい」
「訳が反映されない」など）。明示的に呼ぶなら `/app-intents-<name>`。

## 経緯はここには書かない

skill 本体（`SKILL.md` / `references/`）は**現在のルールとその根拠だけ**を載せる。
「以前はこう書いていた」「どの仮説が外れた」「どのバグに何ヶ月気づかなかった」といった経緯は、
他プロジェクトにコピーされた先では解決しないパスになるので、ファイル内にポインタも置かない。

追いたい場合の入口は 2 つ:

- **根拠ラベル**（`[measured 2026-08-29, iOS 27 / Xcode 27 beta 6]`）— SDK が上がったとき何を
  再確認すべきかは、これだけで足りる
- 上流リポジトリ [touyou/IntentTodo](https://github.com/touyou/IntentTodo) の `docs/devlog/`
  （トピック別・時系列の調査ログ）と `docs/insights/`（各知見の詳細）

## 関連ドキュメント

- [Liquid Glass と App Intents 中心設計](https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents) — 設計思想の背景記事
- [Apple Developer: App Intents](https://developer.apple.com/documentation/appintents)

## ライセンス

MIT License — 親リポジトリの [LICENSE](../LICENSE) を継承。
