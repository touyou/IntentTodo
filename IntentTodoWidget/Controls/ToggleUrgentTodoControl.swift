//
//  ToggleUrgentTodoControl.swift
//  IntentTodoWidget
//
//  Control Center widget for toggling the most urgent todo.
//

#if !os(visionOS)
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

/// Control widget for toggling the most urgent todo.
///
/// Displays the most urgent (earliest due date) incomplete todo.
/// Tap to toggle its completion status.
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in
            ControlWidgetButton(action: ToggleUrgentTodoIntent()) {
                Label {
                    Text(snapshot.title ?? "No urgent todo")
                } icon: {
                    Image(systemName: snapshot.isCompleted
                        ? "checkmark.circle.fill"
                        : "clock.badge.exclamationmark")
                }
            }
        }
        .displayName("Urgent Todo")
        .description("Toggle completion of the most urgent todo.")
    }
}

extension ToggleUrgentTodoControl {
    /// Snapshot fed to the control body. body 内で直接 fetch するより、
    /// ControlValueProvider 経由で値を渡した方が WidgetKit と整合する。
    struct Snapshot: Sendable {
        let title: String?
        let isCompleted: Bool

        static let empty = Snapshot(title: nil, isCompleted: false)
    }

    struct Provider: ControlValueProvider {
        var previewValue: Snapshot {
            Snapshot(title: "Finish report", isCompleted: false)
        }

        func currentValue() async throws -> Snapshot {
            try await MainActor.run {
                let context = sharedWidgetModelContainer.mainContext
                var descriptor = FetchDescriptor<TodoItem>(
                    predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
                    sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
                )
                descriptor.fetchLimit = 1
                guard let todo = try? context.fetch(descriptor).first else {
                    return .empty
                }
                return Snapshot(title: todo.title, isCompleted: todo.isCompleted)
            }
        }
    }
}
#endif
