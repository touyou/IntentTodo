# Siri tools and app skills (27.3+)

Measured with Xcode 27.3 beta (27C5020n) on a to-do app with 34 intents. Apple's own guidance for this is the `siri-app-integration` skill that Xcode 27.3 exports (`xcrun agent skills export <dir>`); this file records what held up when applied to a real app, and the decisions it forced.

## Which intents become tools

Start from every discoverable intent and remove, in this order:

| Remove | Why |
|---|---|
| Intents that adopt a **primary-domain schema** (`reminders`, `messages`, `notes`, `system`, `calendar`, `mail`, `photos`, …) | Siri already handles them. `ToolIntent` on one is a build error, and the error stops metadata export for the whole target. Only Shortcuts-only domains (`books`, `browser`, `journal`, `presentation`, `reader`, `spreadsheet`, `whiteboard`, `wordProcessor`) combine with `.tool` |
| **Search / find intents** | Siri finds entities itself through Spotlight and `EnumerableEntityQuery`, then passes them to a tool |
| **Duplicates** of a schema intent or of another tool | A single-item delete next to a schema bulk delete, a count next to a richer summary. The analyzer does not flag overlap between your own tools; judge it yourself |
| Open / launch, snippet, Focus filter, widget-configuration intents, and `isDiscoverable = false` UI variants | parts of a screen or a system surface, not something a person asks Siri to do on its own |
| Anything that only works on one screen or while the app is open | tools are callable whenever Siri can reach the app, including while a Live Activity is running |

What is left is usually the app's verbs (complete, snooze, favourite, merge, rename, delete) plus a few read-only intents that answer questions ("what's left today?"). Keep destructive ones: they are what people ask Siri for. Keep their `requestConfirmation`.

Record the excluded intents and the reason next to the conformances, so the next person does not re-litigate them.

## Adopting

```swift
// ToolIntentConformances.swift — one file for all of them
#if !os(watchOS) && !os(tvOS)
@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SnoozeTodoIntent: ToolIntent {}
#endif
```

- Gated extensions, not `@available` on the type: the intents keep working in Shortcuts and Spotlight on earlier releases.
- The built metadata changes in exactly one place per tool: `com.apple.link.systemProtocol.ToolIntent` is added to `systemProtocols`. Identity, parameters and saved shortcuts are untouched.
- **Toolchain:** the type does not exist in the 27.2 SDK, so this file does not build on Xcode 27.2. `#if compiler(>=…)` cannot separate the two (both Swift 6.4.2); `#if canImport(AppIntents, _version: 301.2)` can. Prefer waiting for the release toolchain over shipping an underscored guard.

## Metadata Siri reads

Fix these before trusting any Siri behaviour, then run the analyzer (`app-intents-testing`, rung 0.5):

- Every tool parameter has a description that says what the value means. An `AppEnum` mode parameter lists its cases in the description.
- `IntentDescription(_:categoryName:searchKeywords:)` with words people say that the title does not contain. This API exists since iOS 16, so it needs no gate.
- Entity property descriptions need `@Property(description:)`, which is **27.3-only on an entity that also ships earlier**. With a 27.0 deployment target they cannot be added yet; expect `SMA203` suggestions until then.

## App skills (`Skills.skillsbundle`)

A skill gives Siri's model task-level context and the order to use tools in. It is read on the person's device at runtime; it is not a coding-assistant skill.

```
<AppTarget>/Skills.skillsbundle/
└── Skills/
    └── tidy-lists-and-tags/
        └── SKILL.md      # frontmatter: name, description only
```

- **If the app target is a synchronized folder, putting the bundle inside it is enough.** It lands in Copy Bundle Resources without touching the project file, and the build writes `Metadata.appintents/Skills.skillsc` into the app [measured]. If the target is not synchronized, add the bundle through Xcode (File ▸ New ▸ File from Template ▸ Skills Bundle) — a bundle outside every build phase ships nothing and says nothing.
- **A malformed skill fails the build** [measured]: `SKILL.md:2: error: 'tidy-lists-and-tags': Invalid identifier format 'Tidy_Lists'` and `The 'name' field must match the parent directory name`, exit 65. Apple's guidance adds that while any error remains, *no* skill ships.
- `name` is lowercase kebab-case and equals the directory name. `description` (≤ 1,024 characters) is the only thing read when choosing a skill: name the requests in the user's words, and say what the skill is *not* for. Quote it if it contains `: `.
- The body names tools by their **title in natural language** ("the Merge Lists tool"), never by Swift type name. Say the order, when to ask, and what not to do. Do not restate titles and descriptions.
- Write a skill only for a task that needs context or several tools in order. Every tool must still make sense without it.
- Only `SKILL.md` ships. `references/` next to it is ignored.

## Checking

1. Clean build, then `xcrun sirimetadataanalyzer <App>.app --format json` (and `--language` per shipping language). The JSON's `toolbox.skills` shows the compiled skill text.
2. On a device with 27.3 and Apple Intelligence: SiriEvaluations scenarios with `Calls` for each tool, `Calls(.disallowed)` for destructive tools the request should not reach, and `Loads(.required)` for each skill.
