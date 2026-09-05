# Interactive snippets

A `SnippetIntent` returns SwiftUI; the host intent attaches it. This is how a Siri or Spotlight result becomes something the person can act on rather than just read.

```swift
public struct TodoSummarySnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Todo summary"
    public static let isDiscoverable = false     // presented via snippetIntent:, not Shortcuts

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        let summary = try TodoEntityStore.summary()      // re-read every time
        return .result(view: SummaryView(summary: summary))
    }
}

// host intent
return .result(value: count, dialog: dialog, snippetIntent: TodoSummarySnippetIntent())
```

`SnippetIntent` requires `perform()` to return a `ShowsSnippetView` result [Apple SDK: Xcode 27 beta 6]. A `var snippet: some View` alone does not satisfy it. Use intent-backed buttons in the returned view; a plain closure button from an overview example is not a substitute for system dispatch.

Rules that decide whether it works:

- **Buttons inside a snippet run intents with `Button(intent:)`**, exactly like a widget. All the `Button(intent:)` rules apply, including the interactive-intent trap.
- **Every button press re-runs the whole `SnippetIntent`**, so `perform()` must re-fetch current state rather than close over a stale snapshot. A snippet built from a value captured by the host intent shows the *pre-action* state forever.
- **Snippets render in Siri, Spotlight and Shortcuts — not in Control Center** ([feedback-channels](feedback-channels.md)).
- **Snippet bodies cannot use `@Dependency` on the entity side**; read the ambient store — and register that store in the widget extension too, or the snippet renders **empty** when resolved there [measured 2026-08-12]. That symptom (a working intent with a blank snippet) is the hardest one in this file to localise, and it is always a missing second registration (`app-intents-execution-and-processes`).

## When a snippet is the wrong answer

- The person only needs to *hear* it → dialog alone.
- The action needs a full screen → `.foreground(.immediate)` and navigate.
- The caller is a control → neither renders; redraw the control instead.
- The snippet would need to be scrollable or paginated → that is a screen.

## Design

Apple's snippet guidance [wwdc2025-281] amounts to: one clear piece of information, at most a couple of actions, and no state the person has to track across presses. Because each press re-runs the intent, a snippet is best thought of as a *view of current truth with buttons*, not a small stateful app.
