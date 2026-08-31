# 開発ログ: ドキュメントを 4 層に整理し、参照ドキュメントの古い記述を実装と突き合わせた（2026-08-31）

## きっかけ

ドキュメント全体（`docs/` 配下 + `AGENTS.md` + `README.md`、参照 WWDC 書き起こしを除いて約 8,000 行）を
通しで読み、振り分け・矛盾・古さを点検した。方針として次を確認した:

- **常に読み込まれるファイル**（`AGENTS.md` = `CLAUDE.md`）は**目次と非交渉ルールだけ**にする。
  865 行あり、コンテキストを毎回食う一方で、中身の 8 割は `docs/insights/` と `skills/` に同じ説明があった
- **参照ドキュメント**（`docs/*.md` / `docs/insights/`）は**最新の事実と why** だけを書く。
  経緯・「当時の判断」・不要なアンチパターンは置かない
- **実験の記録と経緯**はここ（devlog）に逃がす

`AGENTS.md` の「ドキュメント運用」節を 3 分割から 4 分割（地図 / 現在のルール / 経緯 / 残タスク）に
書き換えたのはこのため。

## やったこと

### 1. `AGENTS.md` を 865 行 → 約 150 行の目次に畳んだ

移送先:

| 元の節 | 移送先 |
|---|---|
| コーディング規約 / Swift・SwiftUI ガイドライン / UI コピー / SwiftData | **新規** `docs/CODING_GUIDELINES.md` |
| テスト方針 / 開発フロー（TDD） | **新規** `docs/TESTING.md` |
| App Intents 実装ガイド（22 節） | `docs/insights/03`〜`07` と `skills/`（大半は既にあった。無かった 3 件は下記） |
| Dialog vs 通知の使い分け表 | `docs/insights/06`（新設） |
| `TodoService.dataDidChange()` への集約 / `parameterSummary` は allowlist | `docs/insights/03`（新設） |
| 設計思想 / 核心原則 / 設計プロセス | `docs/AGENTS.md`（設計ガイド側に一元化） |
| マルチプラットフォーム展開指針 / 実装済み一覧 / 機能要件 / 拡張ロードマップ | `docs/PLAN.md` / `README.md` / `APP_INTENTS_CENTRIC_PLAN.md` に既にあったので削除 |

残したのは環境（OS / ターゲット構成）、**12 個の非交渉ルール**（知らずに触ると壊すが壊れたことに
気づけないもの）、ドキュメント運用、Git 運用、全ドキュメントの目次。

### 2. `docs/AGENTS.md`（755 行）を設計ガイドとして書き直した

最大の矛盾源だった。`skills/` 8 本が同じ内容を英語で、しかも現行仕様で持っているのに、
こちらは古い実装のコードサンプルを「推奨」として載せていた。見つかった食い違い:

- `@Dependency var modelContainer` を Intent 内で受け、`SwiftDataTodoRepository` を組む例
  → 現在は Intent は `TodoService` を受ける（実測: `todoService` 18 / `modelContainer` 4 で
  後者は Query と snippet Intent のみ）
- 「main target に `AppIntentsPackage` を宣言するとルーティングが壊れる」
  → **2026-08-12 に逆の結論へ切り替わっている**（利用側 4 ターゲットで `includedPackages` 付きで宣言する）
- `DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))`
  → ランタイム文字列をキーにする形。現在は `"\(title)"` 補間
- `entities(matching:)` で `localizedCaseInsensitiveContains`
  → 現在は `localizedStandardContains`
- watchOS 対策として `onTapGesture { Task { try? await intent.perform() } }`
  → 「直接 `perform()` を呼ばない」に真正面から反する（`role:` を外すだけでよい）
- `if #available(iOS 18.0, *)` / 「macOS 14 / iOS 17 以降」など 27 世代前提と合わない記述

コードサンプルは復元せず**削除**した（正しい版が `insights/` と `skills/` にある）。
残したのは思想・比較図・核心原則・**実装時に確認すること**（チェックリスト）。

### 3. `docs/insights/` の事実を実装と突き合わせた

コード側は正しく、ドキュメントだけが古かった（`grep` で確認）。

| 場所 | 直した内容 |
|---|---|
| 03 | 冒頭の「ビジネスロジックは Intent 内に」→ `TodoService` に。DI 例を `todoService` に。entity / query のサンプルを現行の書き方に |
| 03 | `CompleteTodoFromActivityIntent`（存在しない Intent）を統合可否の表から削除 |
| 03 | `#if canImport(VisualIntelligence)` → 実コードと同じ `&& !os(visionOS)`（07 の記述と矛盾していた） |
| 03 | 「reminder 本体スキーマ適合は引き続き保留」節（#56 で適合済みなのに残っていた）を削除 |
| 03 | Primary / FromExtension 分離の経緯・実測表・スタックトレースを devlog ポインタに畳んだ |
| 04 | 「推奨」例に `DeleteTodoIntent`（`requestConfirmation` 付き）を使っていた（同ファイル 40 行下で「UI から呼べない」と書いてある） |
| 04 | 「deployment target は 26.0 のまま」→ 全ターゲット 27.0。`#available(iOS 27, …)` が残っている理由を明記 |
| 04 | `onAppIntentExecution` 節（未採用 API に 100 行）を判断と `canImport` の罠に圧縮。存在しない Intent 名のサンプルを削除 |
| 04 | 汎用の「コード簡素化のパターン」（Dictionary 初期化など）を削除 |
| 05 | `WidgetReloader` を Intent に直書きするサンプル → `dataDidChange()` への集約 |
| 05 | 「Widget からのデータ操作は動作検証が必要」→ 決着済みの内容（`[.main]` 固定）に |
| 07 | `.watchOS(.v26)` → `.v27`（実際の `Package.swift` と不一致） |
| 07 | `attributeSet` のサンプルが `contentDescription` を埋めていた（03 が「二重書きは静かに壊れる」と言っている当の形。コードからは 2026-08-21 に撤去済み） |
| 07 | `IndexedEntity` のガードから visionOS が抜けていた（2026-08-28 に有効化済み） |
| 07 | `@available(iOS 16.1, *)` / 「iOS 17+ での直接 Intent 実行」/ 存在しない `OpenAddTodoIntent` |
| 02 | SwiftData の実行時 trap 2 件（`Calendar.RecurrenceRule` / 削除済みオブジェクトの配列属性）へのポインタを追加。03 にしか無く、SwiftData を触る人が辿れなかった |

### 4. その他

- `docs/PLAN.md` の「次に効きそうな方向」に **「多言語化（ja）。現状はアプリ全体が英語のみ」** が
  残っていた（#70 で 2026-08-28 に完了、12 catalog に ja が入っている）。「すでに入っているもの」へ移した
- `docs/APP_INTENTS_API_COVERAGE.md` 末尾の「このリストから外した」経緯 3 段落を devlog ポインタ 1 行に
- `docs/INSIGHTS.md` の「整理で削除した内容（CLAUDE.md 参照）」を、新しい置き場を指す
  「ここに書かないこと」に差し替え
- 見出し変更に伴うアンカー（`#ドキュメント運用現在のルール--経緯--残タスク-の三分割` → `#ドキュメント運用`）
  を 6 ファイルで更新
- `docs/presentation/99-script.notes.md` の E-2 表に、編集事故で**行が 6 行そのまま重複**していたのを削除

### 5. `APP_INTENTS_CENTRIC_PLAN.md` の実施記録を devlog へ移送（同日追加）

初回の整理では「参照元が多いので移送は保留し、冒頭に注意書きを置く」判断にしたが、
**注意書きで済ませるのは同じ問題の先送り**なので移送した。

- 計画側（309 → 187 行）に残したのは **到達状況の地図**だけ: セッション別の検証チェックリスト、
  フェーズ別の到達深度表（11 行）、決着済みの判断、既知の SDK 制約、availability 方針
- devlog（`app-intents-centric-plan.md`、92 → 203 行）へ移したのは **実施の記録**:
  Phase 0–11 の詳細リスト（コミットハッシュ + 当時の判断）、単発変更の適用表、
  Xcode 27 beta ごとの追従表
- 移送時に、フェーズ表からは「当時は統合不可と結論 → のちに撤去」のような**現在の状態でない記述**を
  落とした（`ExecutionTargets` の行など）。読み手が必要なのは「今どうなっているか」
- 一度 `<details>` で畳んで両方に残す形を書いたが、**畳んでも二重管理は二重管理**なので削除した

## 判断として残すこと

- **スクリプト（`99-script.md` / `*.script.md`）は直接編集しない**。本人が書く原稿なので、
  指摘は `99-script.notes.md` 側に書く。今回もそうした
- **参照ドキュメントに残す「why」と、devlog に逃がす「経緯」の線引き**は「その説明が無いと**今**の
  判断ができないか」で引く。`Control では dialog も snippet も出ない` の**根拠**（呼出元だけ変えた比較）は
  残す価値がある（同じ推論ミスを繰り返させないため）が、「2 回逆の結論を出した」は devlog 側
- `docs/AGENTS.md` というファイル名は AGENTS.md 規約（ディレクトリごとのエージェント指示）と
  紛らわしいが、リンク元が多いので**リネームしない**。中身が設計ガイドであることは冒頭で明示した
