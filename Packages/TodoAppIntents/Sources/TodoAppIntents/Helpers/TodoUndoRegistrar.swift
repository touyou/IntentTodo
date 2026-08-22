//
//  TodoUndoRegistrar.swift
//  TodoAppIntents
//
//  `UndoableIntent` の undo 登録を 1 箇所に集約する。削除系 Intent が 3 つ
//  （確認あり / 確認なし / バルク）あり、同じ登録をそれぞれに書くと片方だけ
//  直し忘れる形の壊れ方をするため。
//

import AppIntents
import Domain
import Foundation

/// Registers undo handlers for todo mutations performed by `UndoableIntent`s.
///
/// `undoManager` は Intent を走らせた面が用意する。用意されない呼出元（Widget の
/// `Button(intent:)` 等）では `nil` になるので、登録はすべて no-op になる。
/// これは失敗ではなく想定どおりの分岐。
enum TodoUndoRegistrar {
    /// 削除の取り消しを登録する。`snapshots` は**削除前**に取ったもの。
    ///
    /// `UndoManager.registerUndo(withTarget:handler:)` はハンドラごと `@MainActor`
    /// なので、`TodoService` をそのまま呼べる（Task へのホップは不要）。
    @MainActor
    static func registerRestore(
        _ snapshots: [TodoItemSnapshot],
        undoManager: UndoManager?,
        service: TodoService
    ) {
        guard let undoManager, !snapshots.isEmpty else { return }
        undoManager.registerUndo(withTarget: service) { service in
            for snapshot in snapshots {
                // 1 件戻せなくても残りは戻す。undo の途中で throw すると
                // 「一部だけ戻った」状態がユーザーから見えないまま残る。
                _ = try? service.restore(snapshot)
            }
        }
        undoManager.setActionName(
            String(localized: "Delete ^[\(snapshots.count) Todo](inflect: true)")
        )
    }

    /// 完了状態の変更の取り消しを登録する。
    ///
    /// 復元は「元の値へ戻す」(`setCompletion`)。トグルで戻すと、undo するまでの間に
    /// 別経路（Siri / ウィジェット / 別デバイスの CloudKit マージ）で状態が変わって
    /// いた場合に、意図と逆の値へ倒してしまう。
    @MainActor
    static func registerCompletionChange(
        todoId: String,
        previousValue: Bool,
        undoManager: UndoManager?,
        service: TodoService
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: service) { service in
            _ = try? service.setCompletion(todoId: todoId, isCompleted: previousValue)
        }
        undoManager.setActionName(
            previousValue
                ? String(localized: "Mark Todo Incomplete")
                : String(localized: "Complete Todo")
        )
    }
}
