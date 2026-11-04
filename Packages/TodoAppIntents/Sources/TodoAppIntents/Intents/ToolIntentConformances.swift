//
//  ToolIntentConformances.swift
//  TodoAppIntents
//

import AppIntents

// Intents Siri's model may call as tools (Siri AI, 27.3). These intents keep shipping
// unchanged on earlier releases, so each conformance lives in a gated extension rather
// than `@AppIntent(.tool)` on the type. `ToolIntent` is unavailable on watchOS and tvOS,
// which `@available(..., *)` alone does not cover.
//
// Not tools:
// - Intents adopting a primary-domain schema (`.reminders.*`, `.system.*`): Siri already
//   handles them, and adding `ToolIntent` is a build error that stops metadata export.
// - Search intents (`SearchEverythingIntent`, `TodoSemanticContentSearchIntent`): Siri
//   finds entities itself through Spotlight and the entity queries.
// - `DeleteTodoIntent`: overlaps the `.reminders.deleteReminders` intent Siri already uses.
// - `ShowTodoCountIntent`: Get Todo Summary answers the same question with more detail.
// - Open / launch, snippet, Focus filter and non-discoverable UI variants.
#if !os(watchOS) && !os(tvOS)

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension ToggleTodoCompletionIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension CompleteTodosIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension ToggleUrgentTodoIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension SnoozeTodoIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension ToggleFavoriteIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension ShowTodosIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension GetTodoSummaryIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension UpdateListIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension MergeListsIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension DeleteListIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension RenameTagIntent: ToolIntent {}

@available(iOS 27.3, macOS 27.3, visionOS 27.3, *)
extension DeleteTagIntent: ToolIntent {}

#endif
