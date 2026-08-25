//
//  AppIntentsTestCase.swift
//  IntentTodoUITest
//
//  AppIntentsTesting (#295) を使うテストの共通基盤。
//
//  これらのテストはアプリを別プロセスで動かし、Siri / Shortcuts / Spotlight と
//  同じ App Intents スタックを通す。そのため unit test ターゲットではなく
//  UI テストバンドルに置く必要がある（Apple 公式要件）。
//
//  各テストは一意タイトルの todo を作って最後に消す自己クリーンアップ設計。
//  アプリの SwiftData ストアを触るので、後片付けを怠ると次のテストに漏れる。
//

import AppIntents
import AppIntentsTesting
import XCTest

/// テスト本体を持たない共通基底。サブクラス側にテストを書く。
class AppIntentsTestCase: XCTestCase {
    /// アプリターゲットの PRODUCT_BUNDLE_IDENTIFIER と一致させること。
    static let appBundleID = "dev.touyou.IntentTodo"

    // setUp で組み立て tearDown で捨てる XCTest の fixture。特に `definitions` は
    // インスタンス生成時ではなく setUp の中（アプリを activate した後）に作る必要がある
    // ので、宣言時の初期化には置き換えられない。
    // swiftlint:disable implicitly_unwrapped_optional
    var app: XCUIApplication!
    var definitions: IntentDefinitions!
    // swiftlint:enable implicitly_unwrapped_optional

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // `launch()` は起動中のアプリを terminate して再起動するため、テスト数が増えると
        // シミュレータが "did not return a process handle nor launch error" で散発的に
        // 落ちる。`activate()` は未起動なら起動、起動済みなら前面化するだけなので、
        // テストごとの再起動を避けられる。
        app.activate()
        // アプリが登録している intents / entities / enums / queries を発見する。
        definitions = IntentDefinitions(bundleIdentifier: Self.appBundleID)
        try await waitUntilIntentsAreDiscoverable()
    }

    /// アプリを入れ直した直後は App Intents のメタデータサービスがまだアプリを
    /// 認識しておらず、`IntentDefinitions` 経由の呼び出しが
    /// `AppIntentsServicesMetadataErrorDomain Code=400 "<bundle id> is not present"`
    /// で落ちる。クリーンビルド後の最初のテストだけが落ちるという分かりにくい失敗に
    /// なるので、認識されるまで待ってからテスト本体に入る。
    private func waitUntilIntentsAreDiscoverable(timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        while Date() < deadline {
            do {
                _ = try await todoEntity.suggestedEntities()
                return
            } catch {
                lastError = error
                try await Task.sleep(for: .milliseconds(500))
            }
        }
        throw XCTSkip("App Intents metadata never became available: \(String(describing: lastError))")
    }

    override func tearDown() {
        app = nil
        definitions = nil
    }

    // MARK: - Definition ショートカット

    var todoEntity: AppEntityDefinition { definitions.entities["TodoAppEntity"] }
    var categoryEntity: AppEntityDefinition { definitions.entities["CategoryAppEntity"] }

    func intent(_ typeName: String) -> AppIntentDefinition { definitions.intents[typeName] }

    // MARK: - Helpers

    func uniqueTitle(_ prefix: String) -> String {
        "\(prefix) \(UUID().uuidString)"
    }

    /// todo を 1 件作って entity を返す。
    @discardableResult
    func addTodo(title: String) async throws -> AnyAppEntity {
        try await intent("AddTodoIntent").makeIntent(title: title).run().value
    }

    /// `AnyAppEntity` の id。`@Property` ではないので dynamic member lookup
    /// （`entity.id`）では取れない — 型消去側が持つ `identifier` から読む。
    func identifier(of entity: AnyAppEntity) -> String {
        entity.identifier.instanceIdentifier
    }

    /// タイトルが一致する todo をすべて削除し、ストアを元に戻す。
    func deleteTodos(matching title: String) async throws {
        let matches = try await todoEntity.entities(matching: title)
        for match in matches {
            try await intent("DeleteTodoIntent").makeIntent(todo: match).run()
        }
    }

    /// 非同期に反映される結果（Spotlight index 等）を待つ。
    func pollUntil<T>(
        timeout: TimeInterval,
        interval: TimeInterval = 0.5,
        _ produce: () async throws -> T,
        until isSatisfied: (T) -> Bool
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = try await produce()
        while !isSatisfied(latest), Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            latest = try await produce()
        }
        return latest
    }
}
