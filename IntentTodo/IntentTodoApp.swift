//
//  IntentTodoApp.swift
//  IntentTodo
//
//  Created by 藤井陽介 on 2026/01/29.
//

import AppIntents
import os.log
import SwiftData
import SwiftUI
import TodoAppIntents
import UI
import UserNotifications

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "IntentTodoApp")

@main
struct IntentTodoApp: App {
    // MARK: - Properties

    // UIApplicationDelegate と NSApplicationDelegate は別プロトコルのため、
    // プラットフォームごとに Adaptor を分岐（デファクトパターン）。
    // 通知ハンドラ本体は NotificationHandler に集約し、両 Delegate から共通に利用する。
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    // Same instance stored in @State AND registered with AppDependencyManager.
    // Intents access it via @Dependency; views observe it via .environment().
    @State private var navigationModel: NavigationModel

    // MARK: - Initialization

    /// UI テストが渡す起動引数。指定されたときだけ in-memory ストアで起動する。
    ///
    /// UI テストは 1 件ごとにアプリを起こし直すが、共有ストアはプロセスを跨いで残る。
    /// そのため todo がテスト間で積み上がり、(1) 空状態を前提にしたテストが書けない、
    /// (2) 一覧の再描画が遅くなって待ち条件がタイムアウトしやすくなる、という 2 つの形で
    /// テストを不安定にしていた。DEBUG 限定なので出荷ビルドではこの分岐が存在しない。
    ///
    /// AppIntents のテスト（`IntentTodoUITest/AppIntents/`）はこの引数を渡さない。
    /// 実運用と同じ共有ストアの上で entity 解決 / Spotlight index を見たいため。
    #if DEBUG
    static let ephemeralStoreArgument = "-uitest-ephemeral-store"
    #endif

    init() {
        do {
            #if DEBUG
            let usesEphemeralStore = ProcessInfo.processInfo.arguments.contains(Self.ephemeralStoreArgument)
            let container = usesEphemeralStore
                ? try SharedModelContainer.createInMemoryContainer()
                : try SharedModelContainer.createContainer()
            #else
            let container = try SharedModelContainer.createContainer()
            #endif
            modelContainer = container
            AppDependencyManager.shared.add(dependency: container)

            // TodoAppEntity deferred properties fetch on demand via this shared
            // container (entities can't use @Dependency — that's intents-only).
            MainActor.assumeIsolated {
                TodoEntityStore.register(container: container)
            }
        } catch {
            logger.critical("ModelContainer init failed: \(String(reflecting: error))")
            if let nsError = error as NSError? {
                logger.critical("NSError domain=\(nsError.domain) code=\(nsError.code)")
                logger.critical("NSError userInfo=\(nsError.userInfo)")
            }
            fatalError("Could not create ModelContainer: \(String(reflecting: error))")
        }

        // TodoService は Intent からも View からも参照可能な唯一のビジネスロジック層。
        // Repository を内包するため、Intent 側は SwiftData を直接触らない。
        let todoService = TodoService.swiftDataBacked(container: modelContainer)
        AppDependencyManager.shared.add(dependency: todoService)

        // Spotlight index の初期投入 (IndexedEntity 準拠だけでは検索対象にならない).
        // mutation 側 (create / toggle / delete / snooze) は TodoService 内で差分 index.
        // 件数が増えても初回フレーム描画と競合しないよう、priority を低めに固定する。
        Task(priority: .utility) {
            await todoService.indexAllForSpotlight()
        }

        // パラメータ入りの App Shortcut フレーズ ("Complete <todo> in IntentTodo") は、
        // システムが一度 suggestedEntities を取得するまで機能しない。
        // 更新契機はパッケージ側 (TodoService) から通知されるので、その入口を登録し、
        // 起動時に 1 回自分で叩く (wwdc2023-10102 9:52)。
        MainActor.assumeIsolated {
            AppShortcutParameterUpdater.register {
                TodoAppShortcuts.updateAppShortcutParameters()
            }
            AppShortcutParameterUpdater.notifyEntitiesChanged()
        }

        // Same NavigationModel instance is stored in @State AND registered with
        // AppDependencyManager so intents can write navigation state via @Dependency.
        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)

        // 通知タップ時のナビゲーションも同じ NavigationModel を使う。
        #if os(iOS) || os(visionOS) || os(macOS)
        MainActor.assumeIsolated {
            NotificationHandler.shared.navigationModel = navigation
        }
        #endif
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            TodoListView()
                .environment(navigationModel)
                .task {
                    await requestNotificationPermission()
                }
                // アプリが動いていない間の Focus 遷移では TodoFocusFilterIntent の
                // perform() が呼ばれない（AppIntents Extension を持たないため。
                // wwdc2022-10121 9:29）。起動時と復帰時に current を取り直して埋める。
                .task {
                    await TodoFocusFilterStore.shared.syncFromSystem()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await TodoFocusFilterStore.shared.syncFromSystem() }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - URL Handling

    /// Handle deep link URLs from widgets and from `TodoAppEntity`'s URL
    /// representation (`intenttodo://todo/<id>`).
    ///
    /// URL の綴りは `TodoDeepLink` に集約してあるので、ここでは解釈結果だけを見る。
    private func handleURL(_ url: URL) {
        guard let link = TodoDeepLink(url: url) else { return }

        switch link {
        case .addTodo:
            navigationModel.navigateToRoot()
            navigationModel.showAddTodo()
        case .todo(let id):
            // 消された Todo の古いリンクを踏んだ場合は何もしない（エラーを見せる
            // 価値がなく、開いた画面が空になるより現状維持のほうが混乱しない）。
            let service = TodoService.swiftDataBacked(container: modelContainer)
            guard let todo = service.todo(id: id) else { return }
            navigationModel.navigateToRoot()
            navigationModel.showDetail(for: todo)
        }
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                logger.info("Notification permission granted")
                // 許可が戻ったら過去の取りこぼし記録は消す（設定誘導を出し続けない）。
                // 既に許可済みの起動でも `requestAuthorization` は true を返すので、
                // ここが毎起動の回収点になる。
                MissedFeedback.clear(.notification)
            } else {
                // 拒否されると Control / Widget から実行した Intent の失敗を伝える
                // 経路が無くなる（dialog も snippet も出ない）。ここでは催促せず、
                // 実際に取りこぼした時点で `MissedFeedback` 経由で一覧が設定誘導を出す。
                logger.warning("Notification permission denied: Control / Widget failures can't be surfaced")
            }
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription)")
        }
    }
}
