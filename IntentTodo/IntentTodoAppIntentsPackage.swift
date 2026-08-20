//
//  IntentTodoAppIntentsPackage.swift
//  IntentTodo
//
//  wwdc2025-244 (23:29–24:00) の公式手順: 共有パッケージの Intent / Entity を
//  使う側のターゲットでも `includedPackages` 付きで `AppIntentsPackage` を宣言する。
//  「You must register each target as an App Intents Package to ensure proper
//  indexing and validation.」
//
//  経緯: docs/devlog/03-app-intents-core.md（2026-08-12 の `includedPackages` 採用）
//

import AppIntents
import TodoAppIntents

struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
