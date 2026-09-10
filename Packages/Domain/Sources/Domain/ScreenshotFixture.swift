//
//  ScreenshotFixture.swift
//  Domain
//

#if DEBUG
import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "ScreenshotFixture")

/// Deterministic sample data for the App Store screenshot run.
///
/// The store the screenshot tests launch against is in-memory, so every capture starts from
/// the same list regardless of what the previous run left behind.
///
/// The titles are **not** in a string catalog on purpose: they are fixture data, not UI copy,
/// and adding them would oblige every one of the shipping catalogs to carry a translation.
/// They are still per-language because a Japanese App Store screenshot full of English todo
/// titles reads as an untranslated app.
public enum ScreenshotFixture {
    /// Launch argument that asks an app target to seed this fixture.
    public static let launchArgument = "-uitest-screenshot-fixture"

    /// Whether the current process was launched with ``launchArgument``.
    public static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Identifier of the first todo, fixed so a capture run can open its detail screen
    /// without having to find the row first.
    public static let featuredTodoID = stableID(at: 0)

    /// A screen the app can be asked to open straight after launch.
    ///
    /// visionOS is captured with `simctl io screenshot` rather than XCUITest, so there is
    /// nothing to tap with. Deep links are not an alternative: a URL arriving from outside
    /// the app puts a "Open in …?" confirmation over the screen being captured.
    public enum Screen: String {
        case list
        case detail
        case add
    }

    /// Launch argument that selects ``Screen``, e.g. `-uitest-screenshot-screen detail`.
    public static let screenArgument = "-uitest-screenshot-screen"

    /// The screen this process was asked to open, defaulting to the list.
    public static var requestedScreen: Screen {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: screenArgument),
              let raw = arguments[safe: index + 1],
              let screen = Screen(rawValue: raw) else {
            return .list
        }
        return screen
    }

    // MARK: - Seeding

    @MainActor
    private static var hasSeeded = false

    /// Seeds `container` when the process asked for the fixture, otherwise does nothing.
    ///
    /// **Call this from the scene, not from `App.init()`.** `ModelContainer.init` returns
    /// before the store finishes loading, so on a first launch after install — which is
    /// every UI-test launch — touching `mainContext` that early aborts the process with
    /// `NSInternalInconsistencyException: No eligible connection available`. The test then
    /// reports nothing but "the app crashed".
    @MainActor
    public static func seedIfRequested(into container: ModelContainer, now: Date = Date()) async {
        guard isRequested else { return }
        // Once per process. The scene's `.task` runs again whenever the view is rebuilt.
        guard !hasSeeded else { return }
        hasSeeded = true

        // The store finishes loading after `ModelContainer.init` returns, and a fetch issued
        // before that comes back empty even though rows are there. On macOS that meant the
        // wipe below deleted nothing while the inserts landed, so every run stacked another
        // six todos on the last. `deleteAllData()` is not the way out: it invalidates the
        // contexts, and using `mainContext` straight after traps inside SwiftData.
        try? await Task.sleep(for: .seconds(1))

        do {
            try seed(into: container.mainContext, now: now)
        } catch {
            logger.critical("Seeding the screenshot fixture failed: \(String(reflecting: error))")
        }
    }

    /// Inserts the fixture into `context`, replacing whatever is already there.
    ///
    /// - Parameters:
    ///   - context: The context to seed.
    ///   - now: The reference date the relative due dates are built from.
    public static func seed(into context: ModelContext, now: Date = Date()) throws {
        // Deleted one by one rather than with `delete(model:)`: the batch form goes through
        // `NSBatchDeleteRequest`, which aborts with an Objective-C exception — the app dies
        // with SIGABRT before the first frame, and the UI test only reports "app crashed".
        for todo in try context.fetch(FetchDescriptor<TodoItem>()) {
            context.delete(todo)
        }
        for category in try context.fetch(FetchDescriptor<Category>()) {
            context.delete(category)
        }

        let copy = Copy.current
        let categories = copy.categoryNames.map { Category(name: $0.name, colorHex: $0.colorHex) }
        for category in categories {
            context.insert(category)
        }

        let calendar = Calendar.current
        for (index, item) in copy.todos.enumerated() {
            let todo = TodoItem(
                title: item.title,
                todoDescription: item.detail,
                isCompleted: item.isCompleted,
                isFavorite: item.isFavorite,
                // Offset a few hours so the same-day item reads as "later today" instead of
                // rendering as "Overdue by 0m".
                dueDate: item.dueInDays
                    .map { calendar.date(byAdding: .day, value: $0, to: now) ?? now }
                    .map { $0.addingTimeInterval(3 * 60 * 60) }
            )
            todo.id = stableID(at: index)
            todo.tags = item.tags
            todo.sortIndex = index
            // The list sorts newest first by default, so the fixture order only holds if
            // each item is stamped a minute older than the one before it.
            let createdAt = now.addingTimeInterval(TimeInterval(-60 * index))
            todo.createdAt = createdAt
            todo.modifiedAt = createdAt
            todo.category = item.categoryIndex.map { categories[$0] }
            todo.subTasks = item.subTasks.enumerated().map { offset, title in
                SubTask(title: title, isCompleted: offset == 0, orderIndex: offset)
            }
            if item.isCompleted {
                todo.completionDate = now
            }
            context.insert(todo)
        }

        try context.save()
    }

    /// A per-position identifier, so a re-seed reuses the same ids as the run before it.
    ///
    /// `featuredTodoID` is index 0 of this sequence.
    private static func stableID(at index: Int) -> UUID {
        UUID(uuidString: String(format: "5C7EE9A0-0001-4000-8000-00000000A%03d", index + 1)) ?? UUID()
    }

    // MARK: - Fixture Content

    private struct Item {
        let title: String
        let detail: String?
        let isCompleted: Bool
        let isFavorite: Bool
        /// Days from the reference date, or `nil` for no due date.
        let dueInDays: Int?
        let categoryIndex: Int?
        let tags: [String]
        let subTasks: [String]

        init(
            title: String,
            detail: String? = nil,
            isCompleted: Bool = false,
            isFavorite: Bool = false,
            dueInDays: Int? = nil,
            categoryIndex: Int? = nil,
            tags: [String] = [],
            subTasks: [String] = []
        ) {
            self.title = title
            self.detail = detail
            self.isCompleted = isCompleted
            self.isFavorite = isFavorite
            self.dueInDays = dueInDays
            self.categoryIndex = categoryIndex
            self.tags = tags
            self.subTasks = subTasks
        }
    }

    private struct Copy {
        let categoryNames: [(name: String, colorHex: String?)]
        let todos: [Item]

        /// The set matching the process's current language, falling back to English.
        static var current: Copy {
            Locale.current.language.languageCode?.identifier == "ja" ? japanese : english
        }

        static let english = Copy(
            categoryNames: [
                (name: "Work", colorHex: "#4C6EF5"),
                (name: "Errands", colorHex: "#12B886"),
                (name: "Personal", colorHex: "#F76707")
            ],
            todos: [
                Item(
                    title: "Rehearse the App Intents talk",
                    detail: "Run the demo end to end, including the Siri phrases.",
                    isFavorite: true,
                    dueInDays: 0,
                    categoryIndex: 0,
                    tags: ["talk"],
                    subTasks: ["Check the slide order", "Time the live demo"]
                ),
                Item(
                    title: "Ship the 1.0 build",
                    detail: "Upload from Xcode Cloud and fill in the release notes.",
                    isFavorite: true,
                    dueInDays: 1,
                    categoryIndex: 0,
                    tags: ["release"]
                ),
                Item(title: "Book the dentist", dueInDays: 2, categoryIndex: 2),
                Item(title: "Buy oat milk", dueInDays: 3, categoryIndex: 1, tags: ["grocery"]),
                Item(title: "Reply to the venue email", categoryIndex: 0),
                Item(title: "Water the plants", isCompleted: true, categoryIndex: 2)
            ]
        )

        static let japanese = Copy(
            categoryNames: [
                (name: "仕事", colorHex: "#4C6EF5"),
                (name: "買いもの", colorHex: "#12B886"),
                (name: "プライベート", colorHex: "#F76707")
            ],
            todos: [
                Item(
                    title: "登壇のリハーサルをする",
                    detail: "Siri の発話まで含めてデモを通しで確認する。",
                    isFavorite: true,
                    dueInDays: 0,
                    categoryIndex: 0,
                    tags: ["登壇"],
                    subTasks: ["スライドの順番を確認", "デモの時間を計る"]
                ),
                Item(
                    title: "1.0 のビルドを提出する",
                    detail: "Xcode Cloud からアップロードして、リリースノートを書く。",
                    isFavorite: true,
                    dueInDays: 1,
                    categoryIndex: 0,
                    tags: ["リリース"]
                ),
                Item(title: "歯医者を予約する", dueInDays: 2, categoryIndex: 2),
                Item(title: "オーツミルクを買う", dueInDays: 3, categoryIndex: 1, tags: ["食品"]),
                Item(title: "会場からのメールに返信する", categoryIndex: 0),
                Item(title: "観葉植物に水をやる", isCompleted: true, categoryIndex: 2)
            ]
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
