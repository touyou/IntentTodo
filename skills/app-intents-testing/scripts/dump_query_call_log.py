#!/usr/bin/env python3
"""アプリが記録した「システムが query を呼んだ記録」を外から読む。

entity の解決はシステムが選んだプロセスで走るので、**呼ばれなかった query と 0 件返した
query は外から見分けが付かない**（どちらも「面が空」になる）。`os_log` はライブでしか見られず、
donation ストリームに載るのは intent の *実行* だけ。そこでアプリ側（DEBUG のみ）で

    App Group の UserDefaults ← [{id, date, query, caller, requested, returned, process}, ...]

を追記しておき、このスクリプトで読む。**`requested > 0` なのに `returned == 0`** の行が
「システムは聞いたのにアプリが何も返していない」の形で、これが見たいものである。

アプリ側の実装は `references/query-call-log.md`。

使い方:

    # いま記録されているものを読む（起動中のシミュレータ）
    dump_query_call_log.py --group group.com.example.App

    # 差分実験: 印を付けて → 1 操作だけして → 増えた分だけ見る
    dump_query_call_log.py --group group.com.example.App --snapshot /tmp/qcl
    # ... Siri / Spotlight / Shortcuts から 1 回だけ呼ぶ ...
    dump_query_call_log.py --group group.com.example.App --diff /tmp/qcl

    # Mac ネイティブアプリ
    dump_query_call_log.py --group group.com.example.App --mac

    # 0 件しか返せていない呼び出しだけ
    dump_query_call_log.py --group group.com.example.App --empty-only

読み方は `defaults export`（シミュレータは `simctl spawn` 経由）に任せている。コンテナの
plist を直接読むのに比べて、**書き込み直後でも読める**（UserDefaults の書き込みは cfprefsd が
遅延フラッシュするので、ファイルを直接読むと取りこぼす）し、Mac では
`~/Library/Group Containers` が TCC で保護されていてフルディスクアクセス無しには開けない。
ファイルしか手元に無い場合だけ `--plist PATH` を使う。

注意:

- **出た行は「呼ばれた」ことの証拠だが、出ない行は証拠にならない。** DEBUG ビルドでしか
  記録されず、App Group を持たないプロセスからの呼び出しは載らない。
- **`process` 列を見る。** 呼び出しに答えたのがアプリ本体か extension かで、`@Dependency` の
  登録場所も `allowedExecutionTargets` の妥当性も変わる。
- 追記は read-modify-write なので、**複数プロセスが同時に答えた分は取りこぼす**。
  件数の厳密さではなく「呼ばれたか」を見る道具である。
- 上限（既定 200 件）を超えた分は**古い方から消える**。長く放置した後の「無い」は当てにならない。
"""

from __future__ import annotations

import argparse
import json
import plistlib
import subprocess
import sys
from pathlib import Path

DEFAULT_KEY = "queryCallLog"


def resolve_device(device: str) -> str:
    """`booted` / 名前 / UDID を UDID に解決する。"""
    out = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        capture_output=True, text=True, check=True,
    ).stdout
    devices = json.loads(out)["devices"]
    flat = [d for group in devices.values() for d in group]
    if device == "booted":
        booted = [d for d in flat if d["state"] == "Booted"]
        if not booted:
            sys.exit("起動中のシミュレータが無い（--device に UDID か名前を渡す、Mac なら --mac）")
        if len(booted) > 1:
            names = ", ".join(f"{d['name']} ({d['udid']})" for d in booted)
            sys.exit(f"起動中が複数あるので明示して: {names}")
        return booted[0]["udid"]
    for d in flat:
        if device in (d["udid"], d["name"]):
            return d["udid"]
    sys.exit(f"デバイスが見つからない: {device}")


def export_domain(group: str, *, mac: bool, device: str) -> dict:
    """`defaults export` でドメイン全体を取り、dict にして返す。"""
    command = ["defaults", "export", group, "-"]
    if not mac:
        command = ["xcrun", "simctl", "spawn", resolve_device(device), *command]
    result = subprocess.run(command, capture_output=True)
    if result.returncode != 0:
        sys.exit(f"defaults export が失敗した: {result.stderr.decode().strip()}")
    try:
        return plistlib.loads(result.stdout)
    except Exception as error:  # plistlib は入力次第で色々投げる
        sys.exit(f"defaults export の出力を plist として読めない: {error}")


def read_plist_file(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            return plistlib.load(handle)
    except FileNotFoundError:
        sys.exit(f"plist が無い: {path}")
    except PermissionError:
        sys.exit(
            f"plist を開けない（TCC）: {path}\n"
            "`~/Library/Group Containers` は保護されている。--plist をやめて --mac を使うか、"
            "ターミナルにフルディスクアクセスを与える"
        )


def entries_from(domain: dict, key: str) -> list[dict]:
    raw = domain.get(key)
    if raw is None:
        keys = ", ".join(sorted(domain)) or "(空)"
        sys.exit(
            f"キー {key!r} が無い。このドメインにあるのは: {keys}\n"
            "DEBUG ビルドで、かつ query が 1 度でも呼ばれていないと作られない"
        )
    if isinstance(raw, str):
        raw = raw.encode()
    try:
        return json.loads(raw)
    except (TypeError, ValueError) as error:
        sys.exit(f"{key!r} を JSON として読めない: {error}")


def format_table(entries: list[dict]) -> str:
    if not entries:
        return "(記録なし)"
    rows = []
    for entry in entries:
        requested = entry.get("requested")
        returned = entry.get("returned")
        counts = f"{requested} → {returned}" if requested is not None else str(returned)
        rows.append((
            str(entry.get("date", ""))[:19].replace("T", " "),
            str(entry.get("process", "")),
            str(entry.get("query", "")),
            str(entry.get("caller", "")),
            counts,
            "EMPTY" if (requested or 0) > 0 and returned == 0 else "",
        ))
    headers = ("date", "process", "query", "caller", "count", "")
    widths = [max(len(row[i]) for row in (*rows, headers)) for i in range(len(headers))]
    lines = ["  ".join(h.ljust(widths[i]) for i, h in enumerate(headers)).rstrip()]
    lines.append("  ".join("-" * widths[i] for i in range(len(headers))).rstrip())
    for row in rows:
        lines.append("  ".join(row[i].ljust(widths[i]) for i in range(len(headers))).rstrip())
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--group", required=True, help="App Group identifier (group.…)")
    parser.add_argument("--device", default="booted", help="booted / 名前 / UDID（既定: booted）")
    parser.add_argument("--mac", action="store_true", help="Mac ネイティブアプリのドメインを読む")
    parser.add_argument("--plist", metavar="PATH", help="ドメインではなく plist ファイルを直接読む")
    parser.add_argument("--key", default=DEFAULT_KEY, help=f"defaults のキー（既定: {DEFAULT_KEY}）")
    parser.add_argument("--last", type=int, metavar="N", help="末尾 N 件だけ")
    parser.add_argument("--empty-only", action="store_true", help="requested > 0 かつ returned == 0 の行だけ")
    parser.add_argument("--json", action="store_true", dest="as_json", help="JSON で出す")
    parser.add_argument("--snapshot", metavar="PATH", help="今ある記録に印を付ける（差分実験の前）")
    parser.add_argument("--diff", metavar="PATH", help="--snapshot 以降に増えた分だけ出す")
    args = parser.parse_args()

    if args.plist:
        source = args.plist
        domain = read_plist_file(Path(args.plist))
    else:
        source = f"{args.group} ({'mac' if args.mac else args.device})"
        domain = export_domain(args.group, mac=args.mac, device=args.device)

    entries = entries_from(domain, args.key)

    if args.snapshot:
        ids = [entry.get("id") for entry in entries]
        Path(args.snapshot).write_text(json.dumps(ids))
        print(f"{len(ids)} 件に印を付けた → {args.snapshot}")
        return

    if args.diff:
        seen = set(json.loads(Path(args.diff).read_text()))
        entries = [entry for entry in entries if entry.get("id") not in seen]

    if args.empty_only:
        entries = [
            entry for entry in entries
            if (entry.get("requested") or 0) > 0 and entry.get("returned") == 0
        ]

    if args.last:
        entries = entries[-args.last:]

    if args.as_json:
        print(json.dumps(entries, ensure_ascii=False, indent=2))
    else:
        print(format_table(entries))
        print(f"\n{len(entries)} 件  ({source})")


if __name__ == "__main__":
    main()
