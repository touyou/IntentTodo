# 02 — Multi-surface mapping

Where each `AppIntent` and `AppEntity` should appear, and in what order to design them.

## Design from the smallest screen outward

The constraints of the smallest viable surface are the **clarifier**. They force you to identify the essential action.

Recommended design order:

1. **watchOS app + complication** — what is the single action a user wants from a glance?
2. **Home-screen widget** — what is the most-checked piece of information?
3. **Control Center / Action Button** — what action do users want to fire from anywhere?
4. **Live Activity** — what state genuinely needs continuous tracking?
5. **Shortcuts / Siri** — what verbs are valuable in automation chains?
6. **Spotlight** — what entities are worth being globally discoverable?
7. **visionOS** — what becomes spatial when you have unlimited canvas?
8. **Main app UI (iOS / iPadOS / macOS)** — finally, compose the now-stable Intent set into screens.

Skipping ahead to step 8 first is the most common failure mode — the resulting Intents will mirror your navigation tree instead of your actions.

## Mapping table

Use this matrix to decide where each Intent / Entity belongs.

| Action / data characteristic | Surface | Examples |
|---|---|---|
| Information glanced at every day | **Home widget** | Today's todos, unread count |
| Information that changes often, at-a-glance | **watchOS complication** | Next deadline, progress |
| Repeated user-initiated action | **Shortcuts / Siri** | "Add a todo", "Toggle done" |
| Continuously tracked state | **Live Activity** | Todo due in <1h |
| Quick fire-and-forget action | **Control Center** | Quick add, mark urgent done |
| Physically natural trigger | **Action Button** | Create new note |
| Globally searchable object | **Spotlight (`IndexedEntity`)** | Todo, category, project |
| Spatial / immersive experience | **visionOS** | Spatial UI, glass material |
| Composed multi-action workflow | **Main app UI** | Edit, organize, settings |

A single Intent can appear on multiple surfaces — that is the point. `AddTodoIntent` is exposed via Shortcuts, the Action Button, the iOS widget, and the watch complication, all from the same definition.

## Reuse rules

- **Same intent, different surfaces.** Reuse the existing Intent + Entity before inventing a new one. Different surface ≠ different Intent.
- **Same parameter shape across surfaces.** If the watch complication and the home widget both target a todo, both pass `TodoAppEntity` (Primary) or `String` id (FromExtension), not a new ad-hoc payload.
- **Surface-specific feedback only.** Different surfaces need different *output* (Dialog, notification, snippet, complication update) — but the *input* and *logic* should not fork. See `06-feedback-channels.md`.
- **One AppShortcutsProvider per app.** The provider lists the canonical phrasings; widget configurations and control widgets do not appear in it but consume the same Entity types.

## What to expose, what to skip

A useful first-pass coverage:

- 1 open-app intent (e.g. open editor for a fresh todo).
- 2–3 background action intents (add / toggle / delete).
- 1 favorite or pin-style intent (`ToggleFavoriteIntent`).
- 1–2 entity types (`TodoAppEntity`, optionally `CategoryAppEntity`).
- 1 widget configuration intent if the widget is configurable.
- 1 Live Activity intent if the app has long-running work.
- 1 control widget if the app has a single high-frequency action.

Skip on the first pass:

- Settings screens as intents — settings are configuration, not action.
- "Open tab N" intents unless tabs are themselves first-class actions.
- Bulk operations that require lots of UI — defer to the main app.
- Anything whose value is "the user can navigate here from Shortcuts". Navigation is not a feature.
