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
    ap.add_argument("--fail-on", choices=["error", "warn", "never"], default="error")
    args = ap.parse_args(argv)

    if args.list_rules:
        for name, doc in RULES.items():
            print(f"{name}\n    {doc}")
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
