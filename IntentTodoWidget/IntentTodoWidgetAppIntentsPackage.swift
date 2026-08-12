//
//  IntentTodoWidgetAppIntentsPackage.swift
//  IntentTodoWidget
//
//  共有パッケージ TodoAppIntents を使う各ターゲットで宣言する
//  （wwdc2025-244 の公式手順）。詳細は IntentTodoAppIntentsPackage.swift の
//  コメントと docs/devlog/03-app-intents-core.md を参照。
//

import AppIntents
import TodoAppIntents

struct IntentTodoWidgetAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
