# Camera search and onscreen references

Two surfaces where the system asks *your app* a question, rather than running an action you defined.

## Visual Intelligence (camera and screenshots)

```swift
#if canImport(VisualIntelligence) && !os(visionOS)
import VisualIntelligence

public struct TodoVisualIntelligenceQuery: IntentValueQuery {
    @Dependency var todoService: TodoService        // value queries CAN use @Dependency

    public func values(for input: SemanticContentDescriptor) async throws -> [TodoOrCategory] {
        let labels = input.labels                   // generic English labels, en_US, no synonyms
        let todos = try await MainActor.run { try todoService.listTodos(filter: .all) }
        return todos.filter { t in labels.contains { t.title.localizedCaseInsensitiveContains($0) } }
                    .map(TodoOrCategory.todo)
    }
}
#endif
```

- `SemanticContentDescriptor` carries `labels: [String]` and `pixelBuffer: CVReadOnlyPixelBuffer?`. Labels are generic — no proper nouns, English only, no synonyms or translations. Do not build UX that depends on a specific label appearing.
- Returning a `@UnionValue` array is the value query's advantage over `EntityQuery`: results are not confined to one entity type.
- `values(for:)` is nonisolated — hop to `@MainActor` for the fetch, then filter off-actor on `Sendable` values.
- **One `SemanticContentDescriptor`-taking `IntentValueQuery` per app** [Apple: wwdc2026-297 11:39]. To span more types, widen the union — you cannot add a second query.
- No registration needed; the system discovers it. No App Shortcut needed.
- `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` handles "More results". It only requires a `semanticContent` parameter, so it avoids the entity-property pitfalls of the richer schema domains.
- Reuse rather than invent: tapping through a result uses your existing `OpenIntent`; multiple result types use your existing union.

### Every returned entity must be openable

"This `OpenIntent` must exist, otherwise your app won't show up" [Apple: wwdc2025-275 9:19]. The requirement is cross-platform, but it is **enforced at compile time only on the macOS destination**: `result type 'X' that is not openable … must be associated with an OpenIntent`. An iOS build never tells you.

If a union type returns two entity kinds, both need one — even if one of them has no dedicated screen and its `perform()` just opens the app.

### Availability is the tricky part

`canImport(VisualIntelligence)` is **not** an availability check:

- visionOS *simulator*: `canImport` false → code excluded → build succeeds.
- visionOS *device SDK*: `canImport` true → the `.visualIntelligence.*` schema compiles → `'visualIntelligence' is unavailable in visionOS`.
- Absent from the **iOS simulator** SDK, which is why `IntentValueQuery` cannot be exercised there at all (`app-intents-testing`).

So the guard is `#if canImport(VisualIntelligence) && !os(visionOS)`, and the only proof is a build per destination.

> Treat any "this framework is platform-limited" note as a statement about the SDK when it was written. Visual Intelligence on macOS turned out to be possible after one SDK bump and one deleted guard.

## Onscreen entities

Tell Siri what the person is looking at, so "that one" and "this song" resolve.

```swift
// single entity (detail screen)
.userActivity("com.example.MyApp.ViewingTodo") { activity in
    activity.title = String(localized: "Viewing \(todo.title)")
    activity.appEntityIdentifier = EntityIdentifier(for: entity)
}

// a collection (list) — ids are mapped lazily
List(todos, selection: $selected) { … }
    .appEntityIdentifier(forSelectionType: TodoAppEntity.self) {
        EntityIdentifier(for: TodoAppEntity.self, identifier: $0.id)
    }
```

- The activity type string must also be listed in `Info.plist` under `NSUserActivityTypes`, matching exactly.
- `appEntityIdentifier` / `EntityIdentifier` come from `AppIntents` — `import AppIntents` in the view file.
- The `forSelectionType:` form is what makes "the third one" work on long lists without mapping every id upfront.
- **`forSelectionType:` is honoured only on a `List`** [Apple: sample code], and specifically it keys off the `List`'s **selection value type**. A `List` with no selection — rows that are each a `Button(intent:)`, as on watchOS — does not qualify. On a `ScrollView { VStack { ForEach } }` it is a silent no-op. In both cases, annotate each row with the single-entity `.appEntityIdentifier(_:)` instead; same result, the collection form is only an optimisation.
- When the view **draws itself** (`Canvas`, a custom `Layout`), the hierarchy carries no bounds for the resolver to find. Return them explicitly:

  ```swift
  .appEntityUIElements { context in
      [AppEntityUIElement(identifier: EntityIdentifier(for: SongEntity.self, identifier: id),
                          bounds: context.bounds,
                          state: .init(isSelected: false))]
  }
  ```

- Notifications can carry the same association so Siri understands what an off-screen alert is about:

  ```swift
  content.appEntityIdentifiers = [EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)]
  ```

  [Apple: wwdc2026-343, iOS 27]. **Persistent `AppEntity` only** — `TransientAppEntity` is not allowed here [Apple: wwdc2026-343 21:38].

### This is the failure class that looks perfectly fine

Nothing renders differently when the annotation is missing, mistyped, or attached to a container that ignores it. Cover **every** annotated screen with `viewAnnotations()` in AppIntentsTesting, one test per surface — Apple's own samples do exactly that (detail sheet, each list segment, a `Canvas`, a card stack) because each uses a different annotation form and each fails independently (`app-intents-testing`).
