import AppIntents
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "LaunchAppIntent")

public enum AppScreenTarget: String, AppEnum {
    case addTodo
    case todoList
    case incompleteTodos
    case favoriteTodos

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "App Screen"

    public static let caseDisplayRepresentations: [AppScreenTarget: DisplayRepresentation] = [
        .addTodo: "Add Todo",
        .todoList: "Todo List",
        .incompleteTodos: "Incomplete Todos",
        .favoriteTodos: "Favorite Todos"
    ]
}

public struct LaunchAppIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Todo App"
    public static let description = IntentDescription("Opens the Todo app to a specific screen")
    public static let supportedModes: IntentModes = [.foreground(.immediate)]

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @Parameter(title: "Target")
    public var target: AppScreenTarget

    @Dependency
    var navigationModel: NavigationModel

    public init() {
        self.target = .todoList
    }

    public init(target: AppScreenTarget) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        logger.info("[1] perform() entered, target=\(target.rawValue)")
        navigationModel.navigateToRoot()
        logger.info("[2] navigateToRoot done")
        switch target {
        case .addTodo:
            navigationModel.showAddTodo()
            logger.info("[3] showAddTodo done")
        case .todoList, .incompleteTodos, .favoriteTodos:
            logger.info("[3] no-op for \(target.rawValue)")
        }
        return .result()
    }
}

#if os(iOS) || os(visionOS)
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif

public extension LaunchAppIntent {
    static func addTodo() -> LaunchAppIntent { LaunchAppIntent(target: .addTodo) }
    static func todoList() -> LaunchAppIntent { LaunchAppIntent(target: .todoList) }
    static func incompleteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .incompleteTodos) }
    static func favoriteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .favoriteTodos) }
}
