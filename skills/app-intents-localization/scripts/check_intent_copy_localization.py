#!/usr/bin/env python3
"""Check that every localizable string in the App Intents metadata has a catalog entry.

Why this needs a script: Intent copy that lives in a Swift package is **not extracted**
into any String Catalog. The AppIntents metadata records each `title` /
`IntentDescription` / `@Parameter(title:)` / `DisplayRepresentation` as a bare key, and
the system resolves that key against the *linking target's main bundle* — the compiler
even rejects a non-main bundle ("AppIntents requires 'LocalizedStringResource' to use the
main bundle"). So the keys have to be carried as **manual entries** in the app target's
`Localizable.xcstrings`, and nothing in the build tells you when they drift.

A missing key is invisible: the build is green and the app is fine in the source
language — only the translated build falls back to English.

Usage:
    python3 check_intent_copy_localization.py            # every target that links the package
    python3 check_intent_copy_localization.py --app path/to/MyApp.app \
        --catalog IntentTodo/Localizable.xcstrings

Not covered here: `IntentDialog` strings. They are built inside `perform()` and never
reach the metadata, so this script can't see them. To inventory those, temporarily give
the package a `defaultLocalization` plus a `Resources/Localizable.xcstrings`, build, and
read the keys Xcode extracts into it (then revert — a package catalog is never consulted
for intent copy).

Exit status: 0 when every metadata key is present in the catalog, 1 otherwise.

現在のルール: docs/insights/03-app-intents-core.md「Intent のコピーがどこから引かれるか」
経緯: docs/devlog/2026-08-28-intent-copy-localization.md
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys

DERIVED_DATA = os.path.expanduser("~/Library/Developer/Xcode/DerivedData")
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DEFAULT_CATALOG = os.path.join(REPO_ROOT, "IntentTodo", "Localizable.xcstrings")

# Every target that links TodoAppIntents needs the keys in *its own* main bundle.
# The Widget extension has no catalog of its own — it shares the watch app's via a
# membership exception (see docs/devlog/2026-08-28-ja-localization.md).
TARGETS = [
    ("", "IntentTodo/Localizable.xcstrings"),
    ("Watch/IntentTodoWatchApp.app", "IntentTodoWatchApp/Localizable.xcstrings"),
    ("PlugIns/IntentTodoLiveActivityExtension.appex", "IntentTodoLiveActivity/Localizable.xcstrings"),
    ("PlugIns/IntentTodoWidgetExtension.appex", "IntentTodoWatchApp/Localizable.xcstrings"),
]


def find_app(name: str) -> str | None:
    """Newest built .app for `name` in DerivedData, preferring a simulator build."""
    pattern = os.path.join(DERIVED_DATA, f"{name}-*", "Build", "Products", "*", f"{name}.app")
    candidates = [p for p in glob.glob(pattern) if os.path.isdir(p)]
    if not candidates:
        return None
    candidates.sort(key=lambda p: ("simulator" not in p, -os.path.getmtime(p)))
    return candidates[0]


def localizable_keys(actionsdata: dict) -> dict[str, set[str]]:
    """Every string the metadata expects to resolve, grouped by the slot it came from.

    Excludes `parameterSummary` format strings: those are emitted into the app target's
    catalog by the AppShortcuts extractor, so they are never missing.
    """
    groups: dict[str, set[str]] = {}

    def add(group: str, node) -> None:
        # Schema macros emit properties with an empty title (the system supplies the
        # display name from the schema), and an empty key can't be a catalog entry.
        if isinstance(node, dict) and node.get("key"):
            groups.setdefault(group, set()).add(node["key"])

    for action in actionsdata.get("actions", {}).values():
        add("intent title", action.get("title"))
        description = action.get("descriptionMetadata", {})
        add("intent description", description.get("descriptionText"))
        add("category name", description.get("categoryName", {}).get("title"))
        for keyword in description.get("searchKeywords", []):
            add("search keyword", keyword)
        for parameter in action.get("parameters", []):
            add("parameter title", parameter.get("title"))
            add("parameter description", parameter.get("parameterDescription"))

    def walk(node, group: str) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                if key in ("title", "subtitle", "name", "displayName"):
                    add(group, value)
                walk(value, group)
        elif isinstance(node, list):
            for value in node:
                walk(value, group)

    walk(actionsdata.get("entities", {}), "entity display")
    walk(actionsdata.get("enums", {}), "enum display")
    return groups


def check(bundle: str, catalog: str, locale: str) -> int:
    """Report and return the number of metadata keys the catalog doesn't carry."""
    data_path = os.path.join(bundle, "Metadata.appintents", "extract.actionsdata")
    label = f"{os.path.basename(bundle)} → {os.path.relpath(catalog, REPO_ROOT)}"
    if not os.path.exists(data_path):
        print(f"{label}\n  error: {data_path} not found", file=sys.stderr)
        return 1

    with open(data_path) as handle:
        groups = localizable_keys(json.load(handle))
    with open(catalog) as handle:
        strings = json.load(handle)["strings"]

    missing: list[tuple[str, str]] = []
    untranslated: list[tuple[str, str]] = []
    for group, keys in sorted(groups.items()):
        for key in sorted(keys):
            entry = strings.get(key)
            if entry is None:
                missing.append((group, key))
            elif entry.get("shouldTranslate") is not False:
                unit = entry.get("localizations", {}).get(locale, {}).get("stringUnit", {})
                if not unit.get("value"):
                    untranslated.append((group, key))

    total = sum(len(keys) for keys in groups.values())
    print(f"{label}")
    print(f"  {total} metadata keys / {len(missing)} missing / {len(untranslated)} untranslated in {locale}")
    for tag, rows in (("MISSING", missing), (f"UNTRANSLATED ({locale})", untranslated)):
        for group, key in rows:
            print(f"    {tag} [{group}] {key!r}")
    return len(missing)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--app", help="path to the built .app (default: newest IntentTodo build in DerivedData)")
    parser.add_argument("--name", default="IntentTodo", help="scheme/app name to look for in DerivedData")
    parser.add_argument("--catalog", help="check only this catalog against --app (default: every target)")
    parser.add_argument("--locale", default="ja", help="locale to report untranslated keys for")
    args = parser.parse_args(argv)

    app = args.app or find_app(args.name)
    if not app:
        print(f"error: no built {args.name}.app found under {DERIVED_DATA}. Build first.", file=sys.stderr)
        return 1

    if args.catalog:
        return 1 if check(app, args.catalog, args.locale) else 0

    missing = 0
    for relative_bundle, relative_catalog in TARGETS:
        missing += check(
            os.path.join(app, relative_bundle) if relative_bundle else app,
            os.path.join(REPO_ROOT, relative_catalog),
            args.locale,
        )
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
