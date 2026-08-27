#!/usr/bin/env python3
"""Static audit of an App Intents-centric Swift codebase.

Checks the mechanical rules of intent-centric architecture — the ones that are
cheap to get wrong, invisible at build time, and expensive to find at runtime.
Every rule maps to a section in the skill's references/.

Usage:
    python3 audit_intents.py [ROOT] [--json] [--only RULE,RULE] [--skip RULE,RULE]
                             [--fail-on {error,warn,never}]

Exit status: 0 clean, 1 findings at or above --fail-on (default: error).

This is a grep-level tool, not a compiler. It is tuned for few false positives;
when it cannot decide, it stays quiet. Never treat a clean run as proof that the
runtime behaviour is correct — see references/09-verification.md for the ladder
that actually proves things (AppIntentsTesting -> Shortcuts -> Spotlight -> Siri).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Iterable

SKIP_DIRS = {
    ".git", ".build", ".swiftpm", "build", "DerivedData", "Pods", "Carthage",
    "node_modules", ".venv", "vendor", ".index-build",
}

# ---------------------------------------------------------------------------
# model
# ---------------------------------------------------------------------------


@dataclass
class Finding:
    rule: str
    severity: str  # "error" | "warn"
    path: str
    line: int
    message: str
    hint: str = ""

    def as_dict(self) -> dict:
        return {
            "rule": self.rule,
            "severity": self.severity,
            "file": self.path,
            "line": self.line,
            "message": self.message,
            "hint": self.hint,
        }


@dataclass
class Decl:
    name: str
    kind: str  # struct | class | enum | actor | extension
    conformances: list[str]
    line: int


@dataclass
class SwiftFile:
    path: str          # repo-relative
    abspath: str
    text: str          # raw source, for reporting
    lines: list[str]   # raw lines, for reporting
    code: str          # comments + string contents blanked, for matching
    code_lines: list[str]
    target: str        # first path component (target / Packages)
    module: str | None  # module name when under Sources/<Module>/
    is_test: bool
    is_package: bool
    decls: list[Decl] = field(default_factory=list)

    # convenience -----------------------------------------------------------
    def find(self, pattern: str) -> list[tuple[int, str]]:
        """Return (1-indexed line number, raw line) for every code line matching pattern."""
        rx = re.compile(pattern)
        return [
            (i + 1, self.lines[i])
            for i, ln in enumerate(self.code_lines)
            if rx.search(ln)
        ]

    def has(self, pattern: str) -> bool:
        return re.search(pattern, self.code) is not None

    def code_find(self, pattern: str) -> list[tuple[int, str]]:
        """Same as find() but returns the blanked code line (safe to print)."""
        rx = re.compile(pattern)
        return [(i + 1, ln) for i, ln in enumerate(self.code_lines) if rx.search(ln)]

    def conformance_names(self) -> set[str]:
        out: set[str] = set()
        for d in self.decls:
            out.update(d.conformances)
        return out

    def declares_intent(self) -> bool:
        return any(c.endswith("Intent") for c in self.conformance_names())

    def declares_entity(self) -> bool:
        names = self.conformance_names()
        return bool(names & {"AppEntity", "TransientAppEntity"}) or self.has(
            r"@AppEntity\s*\("
        )

    def intent_type_names(self) -> set[str]:
        out = set()
        for d in self.decls:
            if d.kind == "extension":
                continue
            if any(c.endswith("Intent") for c in d.conformances):
                out.add(d.name)
        # schema-macro intents: @AppIntent(schema:) struct Foo { }
        for m in re.finditer(
            r"@AppIntent\s*\([^)]*\)\s*(?:public\s+)?struct\s+(\w+)", self.code
        ):
            out.add(m.group(1))
        return out


def blank_noncode(text: str) -> str:
    """Blank out comments and string-literal contents, preserving line structure.

    Rules that match on identifiers must not fire on prose in a doc comment or on
    a log message that happens to mention `perform()`.
    """
    out: list[str] = []
    i, n = 0, len(text)
    in_line_comment = False
    block_depth = 0
    in_string = False
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if ch == "\n":
            in_line_comment = False
            in_string = False
            out.append(ch)
            i += 1
            continue
        if in_line_comment:
            out.append(" ")
            i += 1
            continue
        if block_depth:
            if ch == "*" and nxt == "/":
                block_depth -= 1
                out.append("  ")
                i += 2
                continue
            if ch == "/" and nxt == "*":
                block_depth += 1
                out.append("  ")
                i += 2
                continue
            out.append(" ")
            i += 1
            continue
        if in_string:
            if ch == "\\" and nxt:
                out.append("  ")
                i += 2
                continue
            if ch == '"':
                in_string = False
                out.append('"')
                i += 1
                continue
            out.append(" ")
            i += 1
            continue
        if ch == "/" and nxt == "/":
            in_line_comment = True
            out.append("  ")
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_depth = 1
            out.append("  ")
            i += 2
            continue
        if ch == '"':
            in_string = True
            out.append('"')
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


DECL_RE = re.compile(
    r"^\s*(?:(?:public|package|internal|private|fileprivate|final|open|indirect|nonisolated)\s+)*"
    r"(struct|class|enum|actor|extension)\s+([A-Z]\w*)\s*(?::\s*([^{]+?))?\s*\{",
)


def parse_conformances(raw: str | None) -> list[str]:
    if not raw:
        return []
    raw = re.sub(r"where\b.*$", "", raw)
    parts = []
    depth = 0
    current = ""
    for ch in raw:
        if ch in "<([":
            depth += 1
        elif ch in ">)]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += ch
    parts.append(current)
    out = []
    for p in parts:
        p = p.strip()
        p = re.sub(r"^any\s+", "", p)
        p = re.sub(r"<.*>$", "", p).strip()
        if p:
            out.append(p)
    return out


def load_files(root: str) -> list[SwiftFile]:
    files: list[SwiftFile] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.endswith(".xcodeproj")]
        for fn in filenames:
            if not fn.endswith(".swift"):
                continue
            abspath = os.path.join(dirpath, fn)
            rel = os.path.relpath(abspath, root)
            try:
                text = open(abspath, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            parts = rel.split(os.sep)
            module = None
            if "Sources" in parts:
                i = parts.index("Sources")
                if i + 1 < len(parts) - 1:
                    module = parts[i + 1]
            is_test = (
                fn.endswith("Tests.swift")
                or fn.endswith("Test.swift")
                or any(p.endswith(("Tests", "Test", "UITest", "UITests")) for p in parts[:-1])
            )
            code = blank_noncode(text)
            sf = SwiftFile(
                path=rel,
                abspath=abspath,
                text=text,
                lines=text.splitlines(),
                code=code,
                code_lines=code.splitlines(),
                target=parts[0],
                module=module,
                is_test=is_test,
                is_package="Packages" in parts or "Sources" in parts,
            )
            for i, ln in enumerate(sf.code_lines):
                m = DECL_RE.match(ln)
                if m:
                    sf.decls.append(
                        Decl(
                            name=m.group(2),
                            kind=m.group(1),
                            conformances=parse_conformances(m.group(3)),
                            line=i + 1,
                        )
                    )
            files.append(sf)
    return files


# ---------------------------------------------------------------------------
# rules
# ---------------------------------------------------------------------------

RULES: dict[str, str] = {}
_RULE_FUNCS: list[tuple[str, object]] = []


def rule(name: str, doc: str):
    def deco(fn):
        RULES[name] = doc
        _RULE_FUNCS.append((name, fn))
        return fn

    return deco


REF = "references"


def body_lines(f: SwiftFile, header: re.Pattern[str]) -> Iterable[tuple[int, str]]:
    """Yield (0-based index, code line) for lines inside every body whose declaration
    line matches `header`. Brace-counted, so a nested closure on the closing line is
    still reported before the body is considered finished."""
    depth: int | None = None
    for i, ln in enumerate(f.code_lines):
        if depth is None:
            if header.search(ln):
                depth = ln.count("{") - ln.count("}")
                if depth <= 0:
                    depth = None if "}" in ln else 0
            continue
        yield i, ln
        depth += ln.count("{") - ln.count("}")
        if depth <= 0:
            depth = None


@rule("shortcuts-provider-placement", "AppShortcutsProvider must live in the app target, never in a package")
def r_shortcuts_placement(files: list[SwiftFile]) -> Iterable[Finding]:
    providers = [
        (f, d) for f in files for d in f.decls if "AppShortcutsProvider" in d.conformances
    ]
    for f, d in providers:
        if f.is_package:
            yield Finding(
                "shortcuts-provider-placement", "error", f.path, d.line,
                f"{d.name} conforms to AppShortcutsProvider inside a Swift package.",
                "autoShortcuts is NOT aggregated from packages into the app's unified "
                "Metadata.appintents — App Shortcuts silently never register. Move the "
                f"provider to the app target and `import` the intents. See {REF}/04-process-and-dependencies.md",
            )
    if len(providers) > 1:
        f, d = providers[1]
        yield Finding(
            "shortcuts-provider-placement", "error", f.path, d.line,
            f"{len(providers)} AppShortcutsProvider declarations found "
            f"({', '.join(p[1].name for p in providers)}).",
            "An app supports exactly one AppShortcutsProvider; more than one is a build error.",
        )
    for f, _ in providers:
        count = len(re.findall(r"\bAppShortcut\s*\(", f.code))
        if count > 10:
            yield Finding(
                "shortcuts-provider-placement", "error", f.path, 1,
                f"{count} AppShortcut entries declared (Apple's limit is 10).",
                "Collapse variants into one AppShortcut with an AppEnum/AppEntity parameter "
                f"and several phrases. See {REF}/02-multi-surface-mapping.md",
            )


@rule("app-intents-package-registration", "Every target that consumes a shared intents package needs its own AppIntentsPackage with includedPackages")
def r_package_registration(files: list[SwiftFile]) -> Iterable[Finding]:
    base_modules: set[str] = set()
    declaring_targets: set[str] = set()
    for f in files:
        for d in f.decls:
            if "AppIntentsPackage" not in d.conformances:
                continue
            declaring_targets.add(f.target)
            if f.module and "includedPackages" not in f.code:
                base_modules.add(f.module)
    if not base_modules:
        return
    entry_targets: dict[str, SwiftFile] = {}
    for f in files:
        if f.is_package or f.is_test:
            continue
        if re.search(r"^\s*@main\b", f.code, re.M):
            entry_targets.setdefault(f.target, f)
    for target, f in sorted(entry_targets.items()):
        imports_intents = any(
            g.target == target and any(g.has(rf"^\s*import\s+{m}\b") for m in base_modules)
            for g in files
        )
        if imports_intents and target not in declaring_targets:
            yield Finding(
                "app-intents-package-registration", "warn", f.path, 1,
                f"Target '{target}' links {'/'.join(sorted(base_modules))} but declares no AppIntentsPackage.",
                "Apple's documented step (wwdc2025-244 23:29): register EACH consuming target as an "
                "AppIntentsPackage with `includedPackages: [YourPackage.self]` so indexing and "
                f"validation cover it. See {REF}/04-process-and-dependencies.md",
            )


@rule("interactive-intent-from-button", "requestConfirmation / requestChoice intents must not be invoked from Button(intent:) or a control")
def r_interactive_from_button(files: list[SwiftFile]) -> Iterable[Finding]:
    interactive: dict[str, str] = {}
    for f in files:
        if not f.declares_intent():
            continue
        if f.has(r"\brequest(?:Confirmation|Choice)\s*\("):
            for name in f.intent_type_names():
                interactive[name] = f.path
    if not interactive:
        return
    call_sites = [
        (r"Button\s*\(\s*(?:role\s*:[^,]+,\s*)?intent\s*:\s*{name}\s*\(", "Button(intent:)"),
        (r"ControlWidgetButton\s*\(\s*action\s*:\s*{name}\s*\(", "ControlWidgetButton(action:)"),
        (r"action\s*:\s*{name}\s*\(", "a widget/control action:"),
    ]
    for f in files:
        if f.is_test:
            continue
        for name, decl_path in interactive.items():
            if name not in f.code:
                continue
            for tmpl, label in call_sites:
                rx = re.compile(tmpl.format(name=re.escape(name)))
                for i, ln in enumerate(f.lines):
                    if rx.search(ln):
                        yield Finding(
                            "interactive-intent-from-button", "error", f.path, i + 1,
                            f"{name} uses requestConfirmation/requestChoice ({decl_path}) "
                            f"but is invoked from {label}.",
                            "There is no surface to answer on: the run fails with "
                            "LNPerformActionErrorCodeUnsupportedValueType and NOTHING happens — no error UI. "
                            "Confirm in SwiftUI (.confirmationDialog) and call a non-interactive twin intent. "
                            f"See {REF}/05-ui-integration.md",
                        )
                        break


@rule("manual-perform", "Never call intent.perform() directly — @Dependency is only resolved on system dispatch")
def r_manual_perform(files: list[SwiftFile]) -> Iterable[Finding]:
    # `SomeIntent(...).perform()` or `someIntent.perform()` — an intent-shaped receiver.
    rx = re.compile(
        r"(?:\b\w*[Ii]ntent\w*\s*\([^()]*\)|\b\w*[Ii]ntent\w*)\s*\.perform\s*\(\s*\)"
    )
    for f in files:
        for i, ln in enumerate(f.code_lines):
            if "func perform(" in ln or "performBackgroundTask" in ln:
                continue
            m = rx.search(ln)
            if not m:
                continue
            yield Finding(
                "manual-perform", "error", f.path, i + 1,
                f"Direct `perform()` call: {m.group(0).strip()}",
                "@Dependency is injected by the system when it dispatches the intent; a manual call "
                "leaves it zero-initialised and traps at first use. Use Button(intent:) from UI, or "
                f"AppIntentsTesting's `run()` from tests. See {REF}/05-ui-integration.md",
            )


@rule("button-role-order", "Button(role:intent:) — role comes first")
def r_button_role_order(files: list[SwiftFile]) -> Iterable[Finding]:
    rx = re.compile(r"Button\s*\(\s*intent\s*:[^)]*\brole\s*:")
    for f in files:
        for i, ln in enumerate(f.lines):
            if rx.search(ln):
                yield Finding(
                    "button-role-order", "error", f.path, i + 1,
                    "Button(intent:…, role:…) resolves to a different init.",
                    "Write `Button(role: .destructive, intent: …)`; the reversed order fails with "
                    f"\"extraneous argument label 'intent:'\". See {REF}/05-ui-integration.md",
                )


@rule("widget-reload-coverage", "A data mutation must reload timelines AND controls")
def r_widget_reload(files: list[SwiftFile]) -> Iterable[Finding]:
    timeline_files = [f for f in files if f.has(r"reloadAllTimelines\s*\(")]
    for f in timeline_files:
        if f.has(r"reloadAllControls\s*\("):
            continue
        line = f.find(r"reloadAllTimelines\s*\(")[0][0]
        yield Finding(
            "widget-reload-coverage", "warn", f.path, line,
            "reloadAllTimelines() without ControlCenter.shared.reloadAllControls().",
            "Home widgets and Control Center are separate APIs. The system only auto-reloads the ONE "
            "control that ran the intent; every other control keeps showing stale values. "
            f"See {REF}/07-data-and-side-effects.md",
        )
    if len(timeline_files) > 1:
        for f in timeline_files[1:]:
            yield Finding(
                "widget-reload-coverage", "warn", f.path, f.find(r"reloadAllTimelines\s*\(")[0][0],
                f"reloadAllTimelines() is called from {len(timeline_files)} files.",
                "Funnel surface refresh through one helper called from the Service's `defer`, so no "
                "intent can forget it.",
            )


@rule("control-feedback", "Controls show neither dialog nor snippet — don't return them, notify only on failure")
def r_control_feedback(files: list[SwiftFile]) -> Iterable[Finding]:
    control_intents: set[str] = set()
    for f in files:
        for m in re.finditer(
            r"ControlWidget(?:Button|Toggle)\s*\((?:[^()]|\([^()]*\))*?action\s*:\s*(\w+)\s*[.(]",
            f.code,
            re.S,
        ):
            control_intents.add(m.group(1))
    if not control_intents:
        return
    for f in files:
        names = f.intent_type_names() & control_intents
        if not names:
            continue
        for pattern, what in (
            (r"\bdialog\s*:", "a dialog"),
            (r"\bsnippetIntent\s*:", "a snippet"),
        ):
            for line, _ in f.find(pattern):
                yield Finding(
                    "control-feedback", "warn", f.path, line,
                    f"{'/'.join(sorted(names))} is wired to a Control but returns {what}.",
                    "Verified on device (dialog 2026-04-14, snippet 2026-08-12): Control Center presents "
                    "neither. Feedback = the control's own redraw after perform() returns; add a local "
                    f"notification for FAILURES only. See {REF}/06-feedback-channels.md",
                )


@rule("deprecated-app-intents-api", "Deprecated or renamed App Intents API")
def r_deprecated(files: list[SwiftFile]) -> Iterable[Finding]:
    patterns = [
        (r"\bForegroundContinuableIntent\b",
         "ForegroundContinuableIntent is deprecated.",
         "Use `supportedModes: [.background, .foreground(.dynamic)]` and `continueInForeground()`."),
        (r"\bopenAppWhenRun\b",
         "openAppWhenRun is superseded by supportedModes.",
         "`.background` == false, `.foreground(.immediate)` == true."),
        (r"schema\s*:\s*\.system\.search\b(?!InApp)",
         ".system.search is deprecated.",
         "Use `.system.searchInApp` (wwdc2026-343 14:50)."),
        (r"CLKComplication",
         "ClockKit complications are legacy.",
         "watchOS complications are WidgetKit widgets; reload them with WidgetCenter."),
    ]
    for f in files:
        for pat, msg, hint in patterns:
            for line, _ in f.find(pat):
                yield Finding("deprecated-app-intents-api", "warn", f.path, line, msg, hint)


@rule("canimport-platform-gap", "#if canImport(X) alone does not prove the API is available on that platform")
def r_canimport(files: list[SwiftFile]) -> Iterable[Finding]:
    gapped = {
        "VisualIntelligence": ("!os(visionOS)", "framework imports on visionOS device SDK but the schema is unavailable — simulator builds pass, device builds fail"),
        "_AppIntents_UIKit": ("!os(watchOS)", "framework exists on watchOS but UISceneAppIntent / UIScene do not"),
        "_AppIntents_SwiftUI": ("os(iOS) || os(visionOS)", "framework exists on macOS but onAppIntentExecution is not declared there"),
    }
    for f in files:
        for i, ln in enumerate(f.lines):
            if not ln.lstrip().startswith("#if"):
                continue
            for fw, (fix, why) in gapped.items():
                if f"canImport({fw})" in ln and "os(" not in ln:
                    yield Finding(
                        "canimport-platform-gap", "warn", f.path, i + 1,
                        f"`canImport({fw})` guard has no os() clause.",
                        f"{why}. Add `&& {fix}`. See {REF}/08-platform-and-availability.md",
                    )


@rule("control-widget-visionos-guard", "ControlWidget types do not exist on visionOS")
def r_control_guard(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        # only the declaration / usage sites, not intents that merely mention a control
        declares = any("ControlWidget" in c for d in f.decls for c in d.conformances)
        uses = f.has(r"\bControlWidget(?:Button|Toggle)\s*\(|\bStaticControlConfiguration\s*\(")
        if not (declares or uses):
            continue
        if re.search(r"#if[^\n]*os\(", f.code):
            continue
        line = f.find(r"\bControlWidget|\bStaticControlConfiguration")[0][0]
        yield Finding(
            "control-widget-visionos-guard", "warn", f.path, line,
            "Control Center types used without a platform guard.",
            "Controls ship on iPhone/iPad/Watch/Mac but NOT visionOS. Wrap in `#if !os(visionOS)`; "
            f"`if #available` cannot stop type resolution. See {REF}/08-platform-and-availability.md",
        )


@rule("entity-dependency", "AppEntity cannot use @Dependency")
def r_entity_dependency(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        if not f.declares_entity() or f.declares_intent():
            continue
        # queries may use @Dependency; only flag when the entity type itself does
        for m in re.finditer(r"@AppEntity[^\n]*\n|struct\s+\w+\s*:[^\n]*AppEntity", f.text):
            break
        for line, _ in f.find(r"^\s*@Dependency\b"):
            if any(
                "Query" in d.name and d.line < line for d in f.decls
            ):
                continue
            yield Finding(
                "entity-dependency", "error", f.path, line,
                "@Dependency inside an AppEntity.",
                "Dependency injection is intent-only ('Unknown attribute Dependency' on entities). "
                "Register an ambient @MainActor store (e.g. `EntityStore.register(container:)`) in every "
                f"process and read it from the entity. See {REF}/10-advanced-entity-apis.md",
            )


@rule("swiftdata-in-intent", "Persistence belongs in a Service, not in perform()")
def r_swiftdata_in_intent(files: list[SwiftFile]) -> Iterable[Finding]:
    pats = [r"\bModelContext\s*\(", r"\.mainContext\b", r"\bFetchDescriptor<"]
    for f in files:
        if not f.declares_intent() or f.is_test:
            continue
        if "Query" in f.path:
            continue
        for pat in pats:
            hits = f.find(pat)
            if hits:
                yield Finding(
                    "swiftdata-in-intent", "warn", f.path, hits[0][0],
                    f"Intent file touches SwiftData directly ({hits[0][1].strip()[:60]}).",
                    "Intents own parameters + feedback; a @MainActor Service owns persistence, surface "
                    "reload and Spotlight indexing. (Exception: SnippetIntent bodies and AppEntity "
                    "properties cannot use @Dependency — there, read a registered ambient store, and keep "
                    f"the fetch itself in a store/service method.) See {REF}/07-data-and-side-effects.md",
                )
                break


@rule("transient-entity-misuse", "TransientAppEntity cannot be indexed or annotated")
def r_transient(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        for d in f.decls:
            if "TransientAppEntity" in d.conformances and "IndexedEntity" in d.conformances:
                yield Finding(
                    "transient-entity-misuse", "error", f.path, d.line,
                    f"{d.name} is both TransientAppEntity and IndexedEntity.",
                    "A transient entity has no query, so Spotlight cannot resolve it back. Persist it as "
                    f"an AppEntity or drop IndexedEntity. See {REF}/10-advanced-entity-apis.md",
                )


@rule("snippet-intent-discoverability", "SnippetIntent should not be discoverable")
def r_snippet(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        for d in f.decls:
            if "SnippetIntent" not in d.conformances:
                continue
            if re.search(r"isDiscoverable\s*(?::\s*Bool\s*)?=\s*false", f.code):
                continue
            yield Finding(
                "snippet-intent-discoverability", "warn", f.path, d.line,
                f"{d.name} is a SnippetIntent without `isDiscoverable = false`.",
                "Snippets are presented via `snippetIntent:`; exposing them in Shortcuts adds an action "
                f"nobody can use meaningfully. See {REF}/11-interaction-and-scale.md",
            )


@rule("app-enum-display", "Every AppEnum needs caseDisplayRepresentations")
def r_app_enum(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        for d in f.decls:
            if d.kind != "enum" or "AppEnum" not in d.conformances:
                continue
            if "caseDisplayRepresentations" in f.code or "@AppEnum" in f.code:
                continue
            yield Finding(
                "app-enum-display", "warn", f.path, d.line,
                f"{d.name}: AppEnum without caseDisplayRepresentations.",
                "A missing case is a runtime fatalError, not a compile error. Also: raw values are "
                f"persisted by string — never renumber or rename them. See {REF}/01-actions-and-entities.md",
            )


@rule("conditional-assert", "Tests must not hide failures behind `if …waitForExistence`")
def r_conditional_assert(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        if not f.is_test:
            continue
        for i, ln in enumerate(f.code_lines):
            s = ln.strip()
            m = re.match(r"(?:\}\s*else\s+)?if\b.*?\b(waitForExistence|exists)\b", s)
            if not m:
                continue
            window = "\n".join(f.code_lines[i : i + 8])
            if "XCTFail" in window:
                continue  # the else-branch fails explicitly: that is a real assertion
            # `if x.waitForExistence(...)` means you EXPECTED it — branching on it hides failure.
            waited = m.group(1) == "waitForExistence"
            yield Finding(
                "conditional-assert", "error" if waited else "warn", f.path, i + 1,
                f"Conditional assertion: {f.lines[i].strip()[:80]}",
                "If the element never appears the body never runs and the test goes green. This shape "
                "hid a completely broken delete path for months. Assert first "
                f"(`XCTAssertTrue(el.waitForExistence(timeout:))`), then act. See {REF}/09-verification.md",
            )


@rule("live-activity-intent-conformance", "Intents that touch Activity state should be LiveActivityIntent")
def r_live_activity(files: list[SwiftFile]) -> Iterable[Finding]:
    for f in files:
        if not f.declares_intent():
            continue
        if not f.has(r"\bactivity\.(?:end|update)\s*\(|Activity<[^>]+>\.(?:activities|request)"):
            continue
        if "LiveActivityIntent" in f.code:
            continue
        line = f.find(r"\bactivity\.(?:end|update)\s*\(|Activity<")[0][0]
        yield Finding(
            "live-activity-intent-conformance", "warn", f.path, line,
            "Intent mutates Live Activity state without LiveActivityIntent conformance.",
            "LiveActivityIntent is what Apple documents as running perform() in the app's process (and it "
            "is the only way to START an activity from the background). Conform under `#if os(iOS)`. "
            f"See {REF}/04-process-and-dependencies.md",
        )


@rule("entity-no-properties", "An AppEntity with no @Property members is invisible to Shortcuts, Siri and Spotlight")
def r_entity_no_properties(files: list[SwiftFile]) -> Iterable[Finding]:
    prop_rx = r"@(?:Property|ComputedProperty|DeferredProperty)\b"
    for f in files:
        if f.is_test:
            continue
        # Schema macros infer @Property for the members the schema defines.
        if f.has(r"@AppEntity\s*\("):
            continue
        if f.has(prop_rx):
            continue
        for d in f.decls:
            if d.kind == "extension":
                continue
            if not ({"AppEntity", "TransientAppEntity"} & set(d.conformances)):
                continue
            yield Finding(
                "entity-no-properties", "warn", f.path, d.line,
                f"{d.name} exposes no @Property members.",
                "Only @Property members reach the system: without them the entity cannot be "
                "filtered in Shortcuts, read by Siri or indexed in Spotlight — it is a display-only "
                "shell. Fine on purpose for a pure picker value; otherwise annotate the members the "
                f"system should see. See {REF}/01-actions-and-entities.md",
            )


@rule("query-no-suggestions", "An EntityQuery with no suggestedEntities() leaves parameter pickers empty")
def r_query_no_suggestions(files: list[SwiftFile]) -> Iterable[Finding]:
    # Enumerable / property queries derive suggestions from their own required members.
    exempt = {"EnumerableEntityQuery", "EntityPropertyQuery"}
    candidates: dict[str, tuple[SwiftFile, Decl]] = {}
    for f in files:
        if f.is_test:
            continue
        for d in f.decls:
            names = set(d.conformances)
            if not (names & {"EntityQuery", "EntityStringQuery", "IndexedEntityQuery"}):
                continue
            if names & exempt:
                continue
            if d.kind == "extension":
                continue
            candidates.setdefault(d.name, (f, d))
    for name, (f, d) in candidates.items():
        # A conformance or the implementation may live in another file: look project-wide.
        mentions = [g for g in files if name in g.code]
        if any(g.has(r"\b(?:suggestedEntities|allEntities)\s*\(") for g in mentions):
            continue
        if any(set(g.conformance_names()) & exempt for g in mentions if name in g.code):
            continue
        yield Finding(
            "query-no-suggestions", "warn", f.path, d.line,
            f"{name} implements no suggestedEntities().",
            "suggestedEntities() is what fills the parameter picker in Shortcuts and Siri. "
            "Returning the empty default means people see a blank list and assume the app is "
            f"broken. If it is cheap to compute, implement it. See {REF}/01-actions-and-entities.md",
        )


@rule("value-query-needs-open-intent", "Every entity a Visual Intelligence value query returns must be openable")
def r_value_query_open_intent(files: list[SwiftFile]) -> Iterable[Finding]:
    queries = [
        (f, d) for f in files if not f.is_test
        for d in f.decls if "IntentValueQuery" in d.conformances
    ]
    if not queries:
        return
    has_open = any("OpenIntent" in f.conformance_names() for f in files)
    if has_open:
        return
    f, d = queries[0]
    yield Finding(
        "value-query-needs-open-intent", "warn", f.path, d.line,
        f"{d.name} is an IntentValueQuery but the project declares no OpenIntent.",
        "Apple: \"This OpenIntent must exist, otherwise your app won't show up\" "
        "(wwdc2025-275 9:19). The requirement is enforced at compile time only on the macOS "
        f"destination, so an iOS-only build never tells you. See {REF}/11-interaction-and-scale.md",
    )


@rule("donate-inside-perform", "Donate from the app's UI, never from perform() — it cannot tell callers apart")
def r_donate_inside_perform(files: list[SwiftFile]) -> Iterable[Finding]:
    rx = re.compile(r"\bdonate\s*\(|IntentDonationManager\.shared\.donate\b")
    header = re.compile(r"\bfunc\s+perform\s*\(")
    for f in files:
        if f.is_test:
            continue
        for i, ln in body_lines(f, header):
            m = rx.search(ln)
            if m and "deleteDonations" not in ln:
                yield Finding(
                    "donate-inside-perform", "warn", f.path, i + 1,
                    f"Donation issued inside perform(): {m.group(0).strip()}",
                    'Apple: "Restrict your donations to direct interactions with your app\'s '
                    'interface, and not to interactions started by Siri or the Shortcuts app." '
                    "perform() cannot tell who called it (systemContext exposes only currentMode "
                    "and isVoiceOnly), so this also donates the Siri/Shortcuts runs. Donate at the "
                    f"UI site, or use callAsFunction(donate:). See {REF}/07-data-and-side-effects.md",
                )


@rule("localized-string-literal", "Runtime values go into LocalizedStringResource by interpolation, not stringLiteral:")
def r_localized_string_literal(files: list[SwiftFile]) -> Iterable[Finding]:
    # A literal argument is fine ("Done"); a variable/expression is the bug.
    rx = re.compile(r"LocalizedStringResource\s*\(\s*stringLiteral\s*:\s*([^)]+)\)")
    for f in files:
        for i, ln in enumerate(f.code_lines):
            m = rx.search(ln)
            if not m:
                continue
            arg = m.group(1).strip()
            if arg.startswith('"') and arg.endswith('"'):
                continue
            yield Finding(
                "localized-string-literal", "warn", f.path, i + 1,
                f"LocalizedStringResource(stringLiteral: {arg}) uses a runtime value as a "
                "localization key.",
                "Every render becomes a lookup for a key no catalogue contains, and the string is "
                f'never extracted for translation. Write `"\\({arg})"` instead. '
                f"See {REF}/01-actions-and-entities.md",
            )


@rule("spotlight-attribute-collision", "attributeSet must not write a CSSearchableItemAttributeSet key that @Property(indexingKey:) also maps")
def r_spotlight_attribute_collision(files: list[SwiftFile]) -> Iterable[Finding]:
    key_rx = re.compile(r"indexingKey\s*:\s*\\\.(\w+)")
    assign_rx = re.compile(r"\b\w+\s*\.\s*(\w+)\s*=")
    for f in files:
        if f.is_test:
            continue
        mapped = {m.group(1) for m in key_rx.finditer(f.code)}
        if not mapped:
            continue
        # Only look inside an attributeSet body.
        for i, ln in body_lines(f, re.compile(r"\bvar\s+attributeSet\b")):
            m = assign_rx.search(ln)
            if m and m.group(1) in mapped:
                key = m.group(1)
                yield Finding(
                    "spotlight-attribute-collision", "warn", f.path, i + 1,
                    f"attributeSet writes `.{key}`, which a @Property(indexingKey: \\.{key}) "
                    "already maps.",
                    "Which side wins on a shared key is undocumented, so the value you meant to "
                    "put into the semantic index can be silently replaced. Keep attributeSet to "
                    "keys no indexingKey claims (dueDate, keywords, displayName) and express "
                    f"status as keywords. See {REF}/10-advanced-entity-apis.md",
                )


@rule("locale-insensitive-entity-match", "entities(matching:) compares user input — use localizedStandardContains")
def r_locale_insensitive_entity_match(files: list[SwiftFile]) -> Iterable[Finding]:
    rx = re.compile(r"\.lowercased\s*\(\s*\)|\.uppercased\s*\(\s*\)")
    for f in files:
        if f.is_test:
            continue
        # `entities(matching string: String)` — the argument label is `matching`,
        # the parameter name is arbitrary, so stop at the label.
        header = re.compile(r"\bfunc\s+entities\s*\(\s*matching\b")
        for i, ln in body_lines(f, header):
            if rx.search(ln) and "contains" in ln.lower():
                yield Finding(
                    "locale-insensitive-entity-match", "warn", f.path, i + 1,
                    "entities(matching:) folds case by hand before comparing.",
                    "The input is what a person said or typed. lowercased().contains() is "
                    "locale-independent and treats kana/katakana, diacritics and Turkish dotless I "
                    "as different characters. Use localizedStandardContains(_:). "
                    f"See {REF}/01-actions-and-entities.md",
                )


# ---------------------------------------------------------------------------
# surface coverage
# ---------------------------------------------------------------------------

# (label, detection pattern, what adopting it would take, reference)
SURFACES: list[tuple[str, str, str, str]] = [
    ("Shortcuts actions", r":\s*(?:[\w\s,]*\b)?AppIntent\b|@AppIntent\s*\(",
     "any discoverable AppIntent is already a Shortcuts action", "00"),
    ("Siri phrases", r"\bAppShortcutsProvider\b",
     "AppShortcutsProvider in the APP target, <=10 entries", "04"),
    ("App UI via intents", r"Button\s*\(\s*(?:role\s*:[^,]+,\s*)?intent\s*:",
     "replace view-model calls with Button(intent:)", "05"),
    ("Widget", r"\bTimelineProvider\b|\bAppIntentTimelineProvider\b|:\s*Widget\b",
     "a widget extension + Button(intent:)/Link", "02"),
    ("Control Center / Action button", r"\bControlWidget\b",
     "ControlWidgetButton, or ControlWidgetToggle + SetValueIntent over a FIXED target", "02"),
    ("Live Activity", r"\bLiveActivityIntent\b|\bActivityConfiguration\b",
     "ActivityKit + LiveActivityIntent under #if os(iOS)", "02"),
    ("Spotlight index", r"\bIndexedEntity\b",
     "IndexedEntity + index incrementally on mutation", "10"),
    ("Semantic Spotlight", r"indexingKey\s*:",
     "@Property(title:indexingKey:) on iOS/macOS", "10"),
    ("Interactive snippets", r"\bSnippetIntent\b",
     "SnippetIntent returning SwiftUI, attached via snippetIntent:", "11"),
    ("Onscreen entities", r"\bappEntityIdentifier\b",
     "userActivity + appEntityIdentifier, or .appEntityIdentifier(forSelectionType:)", "11"),
    ("Visual Intelligence", r"\bIntentValueQuery\b",
     "one IntentValueQuery over SemanticContentDescriptor; entities must be openable", "11"),
    ("Schema domain", r"@App(?:Intent|Entity|Enum)\s*\(\s*schema\s*:",
     "adopt a domain that GENUINELY matches; check the tier first", "13"),
    ("Open semantics", r"\bOpenIntent\b",
     "OpenIntent on the main entity - prerequisite for Spotlight/VI results", "11"),
    ("Delete semantics", r"\bDeleteIntent\b",
     "DeleteIntent taking an ARRAY of entities", "11"),
    ("Absolute setter", r"\bSetValueIntent\b",
     "needed by ControlWidgetToggle; idempotent by construction", "07"),
    ("In-app search from Siri", r"\bShowInAppSearchResultsIntent\b|\.system\.searchInApp",
     "the cheapest schema for an app that fits no domain", "13"),
    ("Find X where", r"\bEntityPropertyQuery\b",
     "EntityPropertyQuery with properties/sortingOptions/comparators", "01"),
    ("Proactive prediction", r"\bPredictableIntent\b",
     "PredictableIntent + IntentPrediction descriptions", "12"),
    ("Undo", r"\bUndoableIntent\b",
     "UndoableIntent + register actions with the supplied undoManager", "11"),
    ("Focus filters", r"\bSetFocusFilterIntent\b",
     "SetFocusFilterIntent, if per-Focus behaviour is meaningful", "12"),
    ("Media / camera semantics", r"\bAudio(?:Playback|Recording|Starting)Intent\b|\bCameraCaptureIntent\b|\bPlayVideoIntent\b",
     "a conformance on an intent you already have", "12"),
    ("Bulk / long-running", r"\bEntityCollection<|\bLongRunningIntent\b",
     "EntityCollection + LongRunningIntent + CancellableIntent", "11"),
    ("Cross-device entities", r"\bSyncableEntity\b",
     "free if id is already stable across devices", "10"),
    ("Export to other apps", r"\btransferRepresentation\b",
     "Transferable + IntentValueRepresentation", "10"),
    ("Retirement path", r"\bDeprecatedAppIntent\b",
     "DeprecatedAppIntent + ReplacementIntent, before deleting an intent type", "12"),
    ("Intent tests", r"\bIntentDefinitions\s*\(", "AppIntentsTesting in a UI TEST bundle", "09"),
]

REF_FILES = {
    "00": "00-adoption-levels.md", "01": "01-actions-and-entities.md",
    "02": "02-multi-surface-mapping.md", "04": "04-process-and-dependencies.md",
    "05": "05-ui-integration.md", "07": "07-data-and-side-effects.md",
    "09": "09-verification.md", "10": "10-advanced-entity-apis.md",
    "11": "11-interaction-and-scale.md", "12": "12-surface-catalog.md",
    "13": "13-schema-domains.md",
}


def coverage(root: str) -> list[dict]:
    files = [f for f in load_files(root) if not f.is_test]
    tests = [f for f in load_files(root) if f.is_test]
    out = []
    for label, pattern, hint, ref in SURFACES:
        pool = files + tests if label == "Intent tests" else files
        rx = re.compile(pattern)
        hits = [f.path for f in pool if rx.search(f.code)]
        out.append({
            "surface": label,
            "present": bool(hits),
            "files": sorted(hits)[:3],
            "next_step": hint,
            "reference": f"{REF}/{REF_FILES[ref]}",
        })
    return out


def print_coverage(rows: list[dict]) -> None:
    present = [r for r in rows if r["present"]]
    missing = [r for r in rows if not r["present"]]
    print("Surfaces reached (a declaration exists — not proof it works; see "
          f"{REF}/09-verification.md):\n")
    for r in present:
        print(f"  reached  {r['surface']}")
    print("\nNot reached (adopt only what the app's actions actually justify — see "
          f"{REF}/12-surface-catalog.md):\n")
    for r in missing:
        print(f"  --       {r['surface']}\n             {r['next_step']}  [{r['reference']}]")
    print(f"\n{len(present)}/{len(rows)} surfaces. Coverage is not the goal: every surface can "
          "show stale data,\nand every exposed intent is one a person can build an automation on.")


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def run(root: str, only: set[str], skip: set[str]) -> list[Finding]:
    files = load_files(root)
    findings: list[Finding] = []
    for name, fn in _RULE_FUNCS:
        if only and name not in only:
            continue
        if name in skip:
            continue
        findings.extend(fn(files))
    findings.sort(key=lambda f: (0 if f.severity == "error" else 1, f.rule, f.path, f.line))
    return findings


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".", help="repository root (default: .)")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--only", default="", help="comma-separated rule names to run")
    ap.add_argument("--skip", default="", help="comma-separated rule names to skip")
    ap.add_argument("--list-rules", action="store_true", help="print the rule catalogue and exit")
    ap.add_argument("--coverage", action="store_true",
                    help="report which system surfaces the project reaches, and what the rest would take")
    ap.add_argument("--fail-on", choices=["error", "warn", "never"], default="error")
    args = ap.parse_args(argv)

    if args.list_rules:
        for name, doc in RULES.items():
            print(f"{name}\n    {doc}")
        return 0

    if args.coverage:
        rows = coverage(args.root)
        if args.json:
            print(json.dumps({"root": os.path.abspath(args.root), "surfaces": rows}, indent=2))
        else:
            print_coverage(rows)
        return 0

    only = {s for s in args.only.split(",") if s}
    skip = {s for s in args.skip.split(",") if s}
    findings = run(args.root, only, skip)

    if args.json:
        print(json.dumps({"root": os.path.abspath(args.root),
                          "findings": [f.as_dict() for f in findings]}, indent=2))
    else:
        if not findings:
            print("intent audit: no findings.")
        for f in findings:
            mark = "error" if f.severity == "error" else "warn "
            print(f"{mark} {f.path}:{f.line}  [{f.rule}]\n      {f.message}")
            if f.hint:
                print(f"      -> {f.hint}")
        errors = sum(1 for f in findings if f.severity == "error")
        warns = len(findings) - errors
        if findings:
            print(f"\n{errors} error(s), {warns} warning(s) across {len(RULES)} rules.")

    if args.fail_on == "never":
        return 0
    if args.fail_on == "warn" and findings:
        return 1
    if any(f.severity == "error" for f in findings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
