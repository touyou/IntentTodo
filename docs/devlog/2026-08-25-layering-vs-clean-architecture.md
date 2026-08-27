# 開発ログ: 「UseCase 層は廃止」という説明をやめた経緯（2026-08-25）

`docs/APP_INTENT_DRIVEN_DESIGN.md` の
[Layered / Clean Architecture との対比](../APP_INTENT_DRIVEN_DESIGN.md#layered--clean-architecture-との対比)
と、骨子② の T07b / `99-script.notes.md` の C-3x が今の形になった経緯。

## きっかけ

登壇資料でこの設計を Layered / Clean Architecture と対比して説明しようとしたときに、
**「UseCase と Repository の使い分けが、図にすると綺麗に退避できないのでは」** という引っかかりが出た。
実際に図が描けない。

## 何が原因だったか

図が破綻していたのではなく、**説明の言葉が実態と食い違っていた**。

それまでのドキュメント（`AGENTS.md` / `docs/AGENTS.md` / `docs/PLAN.md` / `README.md` /
`APP_INTENT_DRIVEN_DESIGN.md` / 骨子② T02 / `99-script.md` L74）はどれも
**「UseCase 層を廃止 → AppIntents がロジックを担う」**と書いていた。

しかし 2026-04-15 以降のコードはそうなっていない。ロジックは `TodoService`（494 行）にあり、
Intent は接続点として薄い。つまり実態は廃止ではなく **宣言（Intent）と実装（Service）への分裂**。

- `99-script.notes.md` の C-3 には既に「**『UseCase を廃止した』＝『ロジックの置き場をなくした』ではない**」
  という注意書きが入っていた（2026-08-22 時点）。ただし**その先の「じゃあ層としてはどう対応するのか」を
  書いていなかった**ため、図に落とす段で詰まった
- `README.md` は「**App Intent がビジネスロジックの唯一の場所**」と書いたままで、`TodoService` 導入後の
  実態から取り残されていた（今回訂正）

## 追加で言えるようになったこと

言い直しの過程で、対比として使える点が 3 つ出た。いずれも既存の実測から導けるもので、新たな検証はしていない。

1. **同心円が破綻する構造的な理由**: Clean / Layered は 1 軸（依存方向）で切るが、App Intents 中心設計は
   **呼出面**という別の軸を持ち込む。だから `AppIntent` の置き場所が一意に決まらない
   （Controller + Presenter + UseCase 入力ポートの 3 役を兼ねている）。図は同心円ではなく**砂時計**にする
2. **凍る方向の反転**: Intent 型名 / parameter 名 / `AppEnum` の raw value はユーザーのショートカットに
   永続化されるため、**外周が最もリファクタできない**。Clean の「外側 = 揺れる詳細」の前提と逆
3. **依存逆転の目的の違い**: `TodoRepositoryProtocol` が効いているのは「DB を差し替えられる」ではなく
   **プロセス境界**（`allowedExecutionTargets` / Widget Extension とメインアプリ）

## 明文化した非対称

図を描く過程で、書いていなかった実態が 1 つ表に出た。
**`EntityQuery` 系の読み取りは `TodoService` も Repository も飛ばして `@Dependency var modelContainer` から
ストアに直通している**（書き込みは必ず `TodoService` 経由）。

実態は「書き込み側だけ層が厚い CQRS 的な形」。理由は既存のルール（読み取り系 Intent は
`allowedExecutionTargets` を固定せず Extension プロセスで応答させる = アプリ起動コストを避ける）から
説明できるので、意図せぬ漏れではなく**意図的な非対称として明記する**ことにした。

## 直したファイル

| ファイル | 変更 |
|---|---|
| `docs/APP_INTENT_DRIVEN_DESIGN.md` | 「Layered / Clean Architecture との対比」節を新設（対応表 / 砂時計図 / 置き場の判定 3 ルール / 反転 2 点 / 非対称）。「廃止」表現を全て言い直し。パッケージ構成の記述が 4 パッケージのまま古かったのも修正 |
| `AGENTS.md`（`CLAUDE.md` の実体） | 「UseCase 層は廃止」→「宣言と実装に分裂」+ 対比節へのポインタ |
| `docs/AGENTS.md` | MVVM 比較図に `Service` と複数呼出面を反映 |
| `docs/PLAN.md` | 同じ言い直し |
| `README.md` | 「App Intent がビジネスロジックの唯一の場所」を訂正し、役割分担表に `TodoService` / Repository を追加 |
| `docs/presentation/02-constraints-and-craft.md` | **T07b** を新設（T07 の直後）。T02 / 構成の全体像 / 発表前チェックリストを追随 |
| `docs/presentation/99-script.notes.md` | C-3 に **C-3x**（7 枚分の材料）を追加。想定 Q&A に 2 問追加。発表前チェックに L74 の言い直しを追加 |

`docs/presentation/99-script.md`（本人執筆の本番スクリプト）は**書き換えていない**。
L74 の言い直しは `99-script.notes.md` の発表前チェックリストに項目として置いてある。
