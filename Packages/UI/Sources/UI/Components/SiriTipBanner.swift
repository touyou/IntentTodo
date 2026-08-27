//
//  SiriTipBanner.swift
//  UI
//
//  App Shortcut のフレーズを、追加操作の直後に一度だけ知らせるバナー。
//

import AppIntents
import SwiftUI
import TodoAppIntents

/// App Shortcut の存在をアプリ内で知らせる一時バナー。
///
/// App Shortcut は Spotlight / Siri / Shortcuts から自動で見つかるが、**ユーザーが
/// 「言えること」を知らない**限り使われない。`SiriTipView` は渡した Intent に対応する
/// フレーズをそのまま表示してくれるので、フレーズを View 側にハードコードせずに済む
/// （`TodoAppShortcuts` を直せば追従する）。
///
/// **`List` の中ではなく一覧の上端（`safeAreaInset`）に置く**。理由は 2 つ:
/// - 常設ではなく「今だけ出ている」ものとして読ませたい。同じ枠の `FocusFilterBanner` /
///   `MissedFeedbackBanner` と同じ扱いになる
/// - `List` の行にすると `.appEntityIdentifier(forSelectionType:)` の対象コンテナと
///   `.reorderable()` の兄弟に Todo でない行が混ざる
///
/// 出す / 引っ込めるの判断は ``SiriTipModel``。
///
/// **macOS では出さない**: `SiriTipView` / `SiriTipViewStyle` は SDK で
/// `@available(macOS, unavailable)`。`ShortcutsLink` も macOS SDK に型が無いため、
/// Mac のアプリ内導線は無く、Shortcuts アプリ側の一覧が導線になる。
/// 詳細: docs/insights/04-ui-integration.md
struct SiriTipBanner: View {
    let model: SiriTipModel

    var body: some View {
        #if os(macOS)
        EmptyView()
        #else
        if model.isPresented {
            SiriTipView(
                intent: AddTodoIntent(),
                // 閉じるボタンが false を書いてくる。以後出さない扱いにする。
                isVisible: Binding(
                    get: { model.isPresented },
                    set: { isVisible in
                        guard !isVisible else { return }
                        model.dismiss()
                    }
                )
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Liquid Glass 時代のクロームは自前で塗らずシステムマテリアルに任せる。
            .background(.bar)
        }
        #endif
    }
}
