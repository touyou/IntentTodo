import AppIntents
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "TestMinimalIntent")

public struct TestMinimalIntent: AppIntent {
    public static let title: LocalizedStringResource = "Test Minimal"
    public static let description = IntentDescription("Minimal test intent")
//    public static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Dependency
    var navigationModel: NavigationModel

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        logger.info("[TestMinimal] perform() entered")
        navigationModel.showAddTodo()
        logger.info("[TestMinimal] done")
        return .result()
    }
}
