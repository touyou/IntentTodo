//
//  IntentTodoAppIntentsPackage.swift
//  IntentTodo
//
//  wwdc2025-244 (23:29–24:00) の公式手順: 共有パッケージの Intent / Entity を
//  使う側のターゲットでも `includedPackages` 付きで `AppIntentsPackage` を宣言する。
//  「You must register each target as an App Intents Package to ensure proper
//  indexing and validation.」
//
//  かつては「アプリ側にも宣言すると Shortcuts のルーティングが壊れる」として
//  意図的に外していたが、2026-08-12 の再検証で (1) 各バンドルの
//  Metadata.appintents の件数が宣言の有無で完全一致、(2) 宣言した状態で
//  AppIntentsTesting 全テストがグリーン、を確認して採用した。
//  経緯: docs/devlog/03-app-intents-core.md
//

import AppIntents
import TodoAppIntents

struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
