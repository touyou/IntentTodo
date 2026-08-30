#!/usr/bin/env python3
"""シミュレータの Biome ストリームから intent の donation / 実行記録を読む。

donation には列挙用の公開 API が無い（`deleteDonations(matching:)` はあるが read が無い）ため、
「donate が効いているか」をコードから観測できない。代わりにシミュレータのデータコンテナに
ある Biome ストリームを直接読む。

    <device>/data/Library/Biome/streams/restricted/
        IntelligenceEngine.Interaction.Donation   # donation の記録
        App.Intents.Transcript                    # intent 実行の記録（呼出元 bundle id 付き）

どちらも append-only の mmap セグメントで、オフセット順に時刻が単調増加する。protobuf 風の
バイナリだがスキーマは非公開なので、ここでは「型名 / bundle id の文字列」と「CFAbsoluteTime
として読める double」を拾って対応付けるだけに留める。

**検証専用**。出荷コードからこのパスに依存してはいけない（非公開・OS 更新で消えうる）。

使い方:

    # 現状のダンプ
    inspect_donation_stream.py --device booted

    # 呼出元だけ変えて比較する（差分実験）
    inspect_donation_stream.py --device booted --snapshot /tmp/before
    # ... ここでアプリを操作する（UI の Button(intent:) を 1 回だけ叩く等）...
    inspect_donation_stream.py --device booted --diff /tmp/before

判定の注意:

- **`IntelligenceEngine.Interaction.Donation` は遅れて書かれる。** 派生ストリーム
  （`Library/Biome/compute/sessions/*/subscriptions/` に購読がある）なので、操作直後の `--diff` は
  必ず +0 になる。実測では **4 分後は未反映、80 分後は反映済み**。**+0 を見たら待つ**。
  `App.Intents.Transcript` の方は即時（数秒）なので、intent が走ったかどうかの確認はこちらで行う。
- **positive control を必ず置く**。Spotlight の App Shortcut など、システムが走らせる経路
  （公式に自動 donate されると書かれている）で出ることを確認してからでないと、「出なかった」が
  チャネルの盲目・書き込み遅延・アプリ側の不発のどれなのか分からない。
- **`--bundle` の既定フィルタで絞りすぎない。** 記録の近傍に bundle id が入らないものがあり、
  絞ると取りこぼす。判定は `--bundle ""` で行う。
- ファイルの mtime は当てにならない（mmap 書き込みで更新されない）。中身の時刻を見る。
  中身の時刻は **UTC**。
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

STREAMS = ("IntelligenceEngine.Interaction.Donation", "App.Intents.Transcript")
CF_EPOCH = datetime.datetime(2001, 1, 1)
# CFAbsoluteTime として妥当な範囲（2025-01-01 .. 2030-01-01 相当）に絞る
TS_MIN, TS_MAX = 7.57e8, 9.15e8
TYPE_RE = re.compile(rb"[A-Z][A-Za-z0-9]{2,}(?:Intent|Entity|Enum)\b")
BUNDLE_RE = re.compile(rb"[a-z][a-zA-Z0-9]+(?:\.[a-zA-Z0-9\-]+){2,}")


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
            sys.exit("起動中のシミュレータが無い（--device に UDID か名前を渡す）")
        if len(booted) > 1:
            names = ", ".join(f"{d['name']} ({d['udid']})" for d in booted)
            sys.exit(f"起動中が複数あるので明示して: {names}")
        return booted[0]["udid"]
    for d in flat:
        if device in (d["udid"], d["name"]):
            return d["udid"]
    sys.exit(f"デバイスが見つからない: {device}")


def stream_dir(udid: str) -> Path:
    return (
        Path.home() / "Library/Developer/CoreSimulator/Devices" / udid
        / "data/Library/Biome/streams/restricted"
    )


def segments(udid: str, stream: str) -> list[Path]:
    d = stream_dir(udid) / stream / "local"
    if not d.is_dir():
        return []
    return sorted(p for p in d.iterdir() if p.is_file())


def timestamps(data: bytes) -> list[tuple[int, datetime.datetime]]:
    """CFAbsoluteTime として読める double をオフセット付きで拾う。"""
    found = []
    for i in range(len(data) - 8):
        (value,) = struct.unpack_from("<d", data, i)
        if TS_MIN < value < TS_MAX:
            found.append((i, CF_EPOCH + datetime.timedelta(seconds=value)))
    return found


def records(data: bytes, bundle_filter: str | None) -> list[dict]:
    """型名の出現ごとに、近傍の bundle id と時刻を添えて返す。"""
    stamps = timestamps(data)
    out = []
    for match in TYPE_RE.finditer(data):
        lo, hi = max(0, match.start() - 160), min(len(data), match.end() + 200)
        window = data[lo:hi]
        bundles = sorted({b.decode() for b in BUNDLE_RE.findall(window)})
        if bundle_filter:
            bundles = [b for b in bundles if bundle_filter in b]
            if not bundles:
                continue
        near = sorted({t for off, t in stamps if abs(off - match.start()) < 400})
        out.append({
            "offset": match.start(),
            "type": match.group().decode(),
            "bundles": bundles,
            "time": near[-1].isoformat(sep=" ", timespec="seconds") if near else None,
        })
    return out


def load(udid: str, bundle_filter: str | None) -> dict[str, list[dict]]:
    result = {}
    for stream in STREAMS:
        rows = []
        for seg in segments(udid, stream):
            rows += records(seg.read_bytes(), bundle_filter)
        result[stream] = rows
    return result


def snapshot(udid: str, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for stream in STREAMS:
        for seg in segments(udid, stream):
            target = dest / stream / seg.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(seg, target)
    print(f"snapshot -> {dest}")


def snapshot_records(src: Path, bundle_filter: str | None) -> dict[str, list[dict]]:
    result = {}
    for stream in STREAMS:
        rows = []
        d = src / stream
        if d.is_dir():
            for seg in sorted(p for p in d.iterdir() if p.is_file()):
                rows += records(seg.read_bytes(), bundle_filter)
        result[stream] = rows
    return result


def key(row: dict) -> tuple:
    return (row["offset"], row["type"], tuple(row["bundles"]))


def report(rows: list[dict], limit: int) -> None:
    if not rows:
        print("    (なし)")
        return
    for row in rows[-limit:]:
        bundles = ", ".join(row["bundles"]) or "-"
        print(f"    {row['time'] or '?':19s}  {row['type']:34s}  {bundles}")
    if len(rows) > limit:
        print(f"    ... 全 {len(rows)} 件（末尾 {limit} 件を表示）")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--device", default="booted", help="UDID / デバイス名 / booted")
    parser.add_argument("--bundle", default="dev.touyou.IntentTodo",
                        help="この文字列を含む bundle id の記録だけを見る（空文字で無効化）")
    parser.add_argument("--snapshot", type=Path, help="現在のセグメントをここへ複製する")
    parser.add_argument("--diff", type=Path, help="このスナップショットからの増分だけを出す")
    parser.add_argument("--limit", type=int, default=30, help="表示件数")
    args = parser.parse_args()

    udid = resolve_device(args.device)
    bundle_filter = args.bundle or None

    if args.snapshot:
        snapshot(udid, args.snapshot)
        return

    current = load(udid, bundle_filter)

    if args.diff:
        before = snapshot_records(args.diff, bundle_filter)
        print(f"# 増分（{args.diff} からの差分） device={udid}")
        for stream in STREAMS:
            seen = {key(r) for r in before.get(stream, [])}
            added = [r for r in current[stream] if key(r) not in seen]
            print(f"\n## {stream}  (+{len(added)})")
            report(added, args.limit)
        return

    print(f"# 現在の記録 device={udid} filter={bundle_filter or '(なし)'}")
    for stream in STREAMS:
        print(f"\n## {stream}  ({len(current[stream])} 件)")
        report(current[stream], args.limit)


if __name__ == "__main__":
    main()
