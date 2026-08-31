//
//  IntentTodoWidgetBundle.swift
//  IntentTodoWidget
//

import AppIntents
import SwiftUI
import TodoAppIntents
import WidgetKit

@main
struct IntentTodoWidgetBundle: WidgetBundle {
    init() {
        // `AppDependencyManager` is per-process, so registrations made by the app do not
        // carry over here.
        //
        // Only read-only intents, entity resolution and snippet rendering can run in this
        // process: every writing intent is pinned to the app with
        // `allowedExecutionTargets = [.main]`.
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)

        // `WidgetBundle.init` is evaluated on the main actor, hence `assumeIsolated`.
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: sharedWidgetModelContainer)
            AppDependencyManager.shared.add(dependency: todoService)

            // Snippet intents and the entity's deferred properties cannot use
            // `@Dependency`; they read `TodoEntityStore`, which needs its own registration
            // or they resolve to empty in this process.
            TodoEntityStore.register(container: sharedWidgetModelContainer)
        }
    }

    var body: some Widget {
        // Home screen widgets
        IntentTodoWidget()

        // Control Center widgets. Controls are unavailable on visionOS.
        #if !os(visionOS)
        QuickAddTodoControl()
        TodoCountControl()
        ToggleTodoControl()
        #endif
    }
}
