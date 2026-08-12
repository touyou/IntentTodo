#!/usr/bin/env python3
"""Inspect the App Intents metadata that the system actually reads.

App Intents are not "the Swift types you wrote" — they are the `Metadata.appintents`
bundle produced at build time. A whole class of failures (App Shortcuts never
appearing in Siri, a schema conformance that silently didn't register, an entity
with no visible properties) is invisible in the compiler, in
`XcodeRefreshCodeIssuesInFile`, and in a green build, but plainly visible here.

Usage:
    # after a build, point at DerivedData products (or any bundle / .appintents dir)
    python3 inspect_appintents_metadata.py ~/Library/Developer/Xcode/DerivedData/MyApp-*/Build/Products
    python3 inspect_appintents_metadata.py MyApp.app --json
    python3 inspect_appintents_metadata.py --find MyApp     # search DerivedData by name

What the checks mean is documented in references/09-verification.md and
references/04-process-and-dependencies.md.

Exit status: 0 clean, 1 if an error-level check failed (see --fail-on).
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from dataclasses import dataclass, field

DATA_NAME = "extract.actionsdata"
DERIVED_DATA = os.path.expanduser("~/Library/Developer/Xcode/DerivedData")
APPLE_SHORTCUT_LIMIT = 10       # AppShortcutsProvider entries per app
APPLE_PHRASE_LIMIT = 1000       # phrase templates per app


@dataclass
class Bundle:
    path: str
    label: str
    data: dict

    # kind ------------------------------------------------------------------
    @property
    def is_app(self) -> bool:
        return self.label.endswith(".app")

    @property
    def is_appex(self) -> bool:
        return self.label.endswith(".appex")

    @property
    def is_package(self) -> bool:
        return self.label.endswith(".appintents")

    @property
    def is_nested(self) -> bool:
        return "/PlugIns/" in self.path or "/Watch/" in self.path or ".xctest/" in self.path

    # content ---------------------------------------------------------------
    def actions(self) -> dict:
        return self.data.get("actions") or {}

    def entities(self) -> dict:
        return self.data.get("entities") or {}

    def queries(self) -> dict:
        return self.data.get("queries") or {}

    def enums(self) -> list:
        return self.data.get("enums") or []

    def auto_shortcuts(self) -> list:
        return self.data.get("autoShortcuts") or []

    def modules(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for a in self.actions().values():
            mod = (a.get("fullyQualifiedTypeName") or "?").split(".")[0]
            out[mod] = out.get(mod, 0) + 1
        return out

    def phrase_count(self) -> int:
        return sum(len(s.get("phraseTemplates") or []) for s in self.auto_shortcuts())

    def schemas(self) -> list[tuple[str, str, str]]:
        """(kind, type name, schema) for every schema-conforming action/entity."""
        out = []
        for kind, table in (("action", self.actions()), ("entity", self.entities())):
            for name, obj in table.items():
                for s in obj.get("assistantDefinedSchemas") or []:
                    out.append((kind, name, f"{s.get('domain')}.{s.get('name')}"))
        return out

    def not_discoverable(self) -> list[str]:
        out = []
        for name, a in self.actions().items():
            if a.get("isDiscoverable") is False:
                out.append(name)
            vis = a.get("visibilityMetadata") or {}
            if vis.get("isDiscoverable") is False and name not in out:
                out.append(name)
        return sorted(out)

    def entity_rows(self) -> list[dict]:
        rows = []
        for name, e in sorted(self.entities().items()):
            protos = [
                p for p in (e.get("systemProtocolMetadata") or []) if isinstance(p, str)
            ]
            rows.append({
                "name": name,
                "properties": len(e.get("properties") or []),
                "property_names": [p.get("identifier") for p in (e.get("properties") or [])],
                "transient": bool(e.get("transient")),
                "query": e.get("defaultQueryIdentifier"),
                "system_protocols": protos,
                "schemas": [
                    f"{s.get('domain')}.{s.get('name')}"
                    for s in (e.get("assistantDefinedSchemas") or [])
                ],
            })
        return rows


@dataclass
class Check:
    severity: str  # error | warn | info
    bundle: str
    message: str
    hint: str = ""


# ---------------------------------------------------------------------------
# discovery
# ---------------------------------------------------------------------------


def find_metadata(paths: list[str]) -> list[str]:
    found: list[str] = []
    for p in paths:
        p = os.path.expanduser(p)
        if os.path.isfile(p) and p.endswith(DATA_NAME):
            found.append(p)
            continue
        if not os.path.isdir(p):
            continue
        if os.path.basename(p) == "Metadata.appintents":
            cand = os.path.join(p, DATA_NAME)
            if os.path.isfile(cand):
                found.append(cand)
                continue
        for dirpath, dirnames, filenames in os.walk(p):
            dirnames[:] = [d for d in dirnames if d not in {"Intermediates.noindex", "EagerLinkingTBDs"}]
            if DATA_NAME in filenames and os.path.basename(dirpath) == "Metadata.appintents":
                found.append(os.path.join(dirpath, DATA_NAME))
    return sorted(set(found))


def find_in_derived_data(name: str) -> list[str]:
    pattern = os.path.join(DERIVED_DATA, f"{name}-*", "Build", "Products")
    return sorted(glob.glob(pattern))


def label_for(path: str) -> str:
    """Human label: the bundle that owns this Metadata.appintents."""
    owner = os.path.dirname(os.path.dirname(path))
    return os.path.basename(owner)


def config_for(path: str) -> str:
    """The Build/Products subdirectory, e.g. Debug-iphonesimulator."""
    parts = path.split(os.sep)
    if "Products" in parts:
        i = parts.index("Products")
        if i + 1 < len(parts):
            return parts[i + 1]
    return ""


def load(paths: list[str]) -> list[Bundle]:
    out = []
    for p in paths:
        try:
            data = json.load(open(p, encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"warn  cannot read {p}: {exc}", file=sys.stderr)
            continue
        out.append(Bundle(path=p, label=label_for(p), data=data))
    # Embedded copies (App.app/PlugIns/X.appex, App.app/Watch/Y.app) duplicate the
    # standalone product. Keep one per (bundle, build configuration), preferring the
    # standalone path so paths stay short and checks don't double-report.
    best: dict[tuple[str, str], Bundle] = {}
    for b in out:
        key = (b.label, config_for(b.path))
        prev = best.get(key)
        if prev is None or (prev.is_nested and not b.is_nested):
            best[key] = b
    return list(best.values())


# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------


def run_checks(bundles: list[Bundle]) -> list[Check]:
    checks: list[Check] = []
    top_apps = [b for b in bundles if b.is_app]
    pkg_shortcuts = [b for b in bundles if b.is_package and b.auto_shortcuts()]
    any_shortcuts = any(b.auto_shortcuts() for b in bundles)

    if not any_shortcuts and top_apps:
        checks.append(Check(
            "warn", top_apps[0].label,
            "no App Shortcuts anywhere in this build (autoShortcuts: 0 in every bundle).",
            "Fine if the app intentionally has none. If you did write an AppShortcutsProvider, it is not "
            "reaching the app's unified metadata — see the note below about package placement.",
        ))

    for b in top_apps:
        n = len(b.auto_shortcuts())
        if n == 0 and pkg_shortcuts:
            checks.append(Check(
                "error", b.label,
                f"autoShortcuts: 0 here, but {pkg_shortcuts[0].label} has "
                f"{len(pkg_shortcuts[0].auto_shortcuts())}.",
                "`autoShortcuts` is the one key that is NOT aggregated from packages into the app bundle "
                "(actions/entities/queries are). An AppShortcutsProvider inside a package registers "
                "nothing: no Siri phrase, no Shortcuts gallery entry, no Spotlight action — with a green "
                "build. Move the provider into the app target and `import` the intents.",
            ))
        elif n > APPLE_SHORTCUT_LIMIT:
            checks.append(Check(
                "error", b.label,
                f"autoShortcuts: {n} exceeds Apple's limit of {APPLE_SHORTCUT_LIMIT}.",
                "Collapse variants into one AppShortcut with an AppEnum/AppEntity parameter plus several "
                "phrases.",
            ))
        if b.phrase_count() > APPLE_PHRASE_LIMIT:
            checks.append(Check(
                "warn", b.label,
                f"{b.phrase_count()} phrase templates (limit {APPLE_PHRASE_LIMIT}).",
            ))

    for b in bundles:
        known = set(b.actions())
        for s in b.auto_shortcuts():
            ident = s.get("actionIdentifier")
            if ident and ident not in known:
                checks.append(Check(
                    "error", b.label,
                    f"App Shortcut references unknown action '{ident}'.",
                    "The intent did not make it into this bundle's metadata — check target membership "
                    "and the AppIntentsPackage / includedPackages registration.",
                ))
        if not (b.is_app or b.is_appex):
            continue
        for row in b.entity_rows():
            if row["properties"] == 0:
                checks.append(Check(
                    "warn", b.label,
                    f"entity {row['name']} exposes 0 properties.",
                    "Only @Property members are visible to Shortcuts, Siri and Spotlight. A 0-property "
                    "entity can be passed around but nothing can be read from or filtered on it. If the "
                    "type uses @AppEntity(schema:), verify the macro really registered "
                    "(schemas column below should be non-empty too).",
                ))
            if row["transient"] and row["query"]:
                checks.append(Check(
                    "warn", b.label,
                    f"entity {row['name']} is transient but declares a default query.",
                ))

    # aggregation: within one build configuration, the app should be a superset of the
    # packages it links. Compare per config so an iOS package is never held against a
    # watchOS bundle.
    for app in [b for b in bundles if b.is_app or b.is_appex]:
        cfg = config_for(app.path)
        pkg_actions: set[str] = set()
        for pkg in bundles:
            if pkg.is_package and config_for(pkg.path) == cfg:
                pkg_actions |= set(pkg.actions())
        missing = sorted(pkg_actions - set(app.actions()))
        if missing and len(missing) != len(pkg_actions):
            checks.append(Check(
                "warn", f"{app.label} ({cfg})",
                f"{len(missing)} action(s) present in linked packages but missing here: "
                f"{', '.join(missing[:6])}{'…' if len(missing) > 6 else ''}",
                "Expected when a platform #if excludes them (e.g. a watchOS-unavailable schema); "
                "otherwise the target is not picking up the package's metadata — check target membership "
                "and the AppIntentsPackage / includedPackages declaration for that target.",
            ))

    # The same finding usually repeats across build configurations; report it once.
    seen: dict[tuple[str, str], Check] = {}
    extra: dict[tuple[str, str], int] = {}
    for c in checks:
        key = (c.severity, c.message)
        if key in seen:
            extra[key] = extra.get(key, 0) + 1
        else:
            seen[key] = c
    out = []
    for key, c in seen.items():
        n = extra.get(key, 0)
        if n:
            c.bundle = f"{c.bundle} +{n} more"
        out.append(c)
    return out


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------


def print_report(bundles: list[Bundle], checks: list[Check], verbose: bool) -> None:
    rows = sorted(bundles, key=lambda x: (config_for(x.path), not x.is_app, x.label))
    width = max((len(b.label) for b in bundles), default=10)
    cwidth = max((len(config_for(b.path)) for b in bundles), default=6)
    print(
        f"{'bundle'.ljust(width)}  {'config'.ljust(cwidth)}  "
        f"actions  entities  queries  enums  shortcuts  phrases"
    )
    print("-" * (width + cwidth + 52))
    for b in rows:
        print(
            f"{b.label.ljust(width)}  {config_for(b.path).ljust(cwidth)}  "
            f"{len(b.actions()):>7}  {len(b.entities()):>8}  {len(b.queries()):>7}  "
            f"{len(b.enums()):>5}  {len(b.auto_shortcuts()):>9}  {b.phrase_count():>7}"
        )

    for b in rows:
        if not (verbose or b.is_app):
            continue
        print(f"\n== {b.label}\n   {b.path}")
        mods = b.modules()
        if mods:
            print("   modules: " + ", ".join(f"{k} ({v})" for k, v in sorted(mods.items())))
        nd = b.not_discoverable()
        if nd:
            print(f"   isDiscoverable=false ({len(nd)}): " + ", ".join(nd))
        schemas = b.schemas()
        if schemas:
            print("   assistant schemas:")
            for kind, name, schema in schemas:
                print(f"     {kind:<6} {name} -> {schema}")
        else:
            print("   assistant schemas: none")
        print("   entities:")
        for row in b.entity_rows():
            flags = []
            if row["transient"]:
                flags.append("transient")
            flags += row["system_protocols"]
            flags += row["schemas"]
            suffix = f"  [{', '.join(flags)}]" if flags else ""
            names = ", ".join(row["property_names"][:6])
            more = "…" if len(row["property_names"]) > 6 else ""
            print(f"     {row['name']}: {row['properties']} props ({names}{more}){suffix}")
        if b.auto_shortcuts():
            print("   app shortcuts:")
            for s in b.auto_shortcuts():
                phrases = len(s.get("phraseTemplates") or [])
                print(f"     {s.get('actionIdentifier')} — {phrases} phrase(s)")

    if checks:
        print("\nchecks:")
        for c in sorted(checks, key=lambda x: {"error": 0, "warn": 1, "info": 2}[x.severity]):
            print(f"  {c.severity:<5} [{c.bundle}] {c.message}")
            if c.hint:
                print(f"        -> {c.hint}")
    else:
        print("\nchecks: all clear.")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("paths", nargs="*", help="bundles, .appintents dirs, or a Build/Products tree")
    ap.add_argument("--find", metavar="PROJECT", help="search DerivedData for PROJECT-*/Build/Products")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true", help="detail every bundle, not just apps")
    ap.add_argument("--fail-on", choices=["error", "warn", "never"], default="error")
    args = ap.parse_args(argv)

    paths = list(args.paths)
    if args.find:
        hits = find_in_derived_data(args.find)
        if not hits:
            print(f"no DerivedData products found for '{args.find}' under {DERIVED_DATA}", file=sys.stderr)
            return 2
        paths += hits

    if not paths:
        ap.print_usage()
        print("\nGive a path, or use --find <ProjectName>. Build first: metadata only exists after a build.")
        return 2

    metadata_files = find_metadata(paths)
    if not metadata_files:
        print("no Metadata.appintents/extract.actionsdata found under the given paths.", file=sys.stderr)
        print("Did the build run? Package-only builds emit <Module>.appintents instead.", file=sys.stderr)
        return 2

    bundles = load(metadata_files)
    checks = run_checks(bundles)

    if args.json:
        print(json.dumps({
            "bundles": [
                {
                    "label": b.label,
                    "path": b.path,
                    "actions": sorted(b.actions()),
                    "entities": b.entity_rows(),
                    "queries": sorted(b.queries()),
                    "enums": len(b.enums()),
                    "auto_shortcuts": [
                        {
                            "action": s.get("actionIdentifier"),
                            "phrases": len(s.get("phraseTemplates") or []),
                        }
                        for s in b.auto_shortcuts()
                    ],
                    "schemas": [
                        {"kind": k, "type": n, "schema": s} for k, n, s in b.schemas()
                    ],
                    "not_discoverable": b.not_discoverable(),
                    "modules": b.modules(),
                }
                for b in bundles
            ],
            "checks": [c.__dict__ for c in checks],
        }, indent=2))
    else:
        print_report(bundles, checks, args.verbose)

    if args.fail_on == "never":
        return 0
    if args.fail_on == "warn" and checks:
        return 1
    return 1 if any(c.severity == "error" for c in checks) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
