//
//  FocusFilterBanner.swift
//  UI
//
//  集中モードで一覧が絞られていることを示すバナー。
//

import SwiftUI
import TodoAppIntents

/// 集中モードで一覧が絞られていることを示し、その場で解除できるようにする。
///
/// 標準アプリ（カレンダー）が Focus filter 適用中に「Focus で絞り込み中」の表示と
/// 解除手段を並べて出しているのと同じ扱い（wwdc2022-10121 2:04）。表示だけ出して
/// 解除手段が無いと、絞られていることに気づいたユーザーが設定アプリまで行くしかない。
struct FocusFilterBanner: View {
    let store: TodoFocusFilterStore

    var body: some View {
        if store.filter.isActive {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.isSuspended ? .copy("Focus filter paused") : .copy("Filtered by Focus"))
                        .font(.footnote)
                    FocusFilterConditions(filter: store.filter)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.isSuspended ? .copy("Apply") : .copy("Show All")) {
                    store.isSuspended.toggle()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Liquid Glass 時代のクロームは自前で塗らずシステムマテリアルに任せる。
            .background(.bar)
            .accessibilityElement(children: .combine)
        }
    }
}

/// 効いている条件の内訳。文言を `String` に連結せず `Text` を並べることで、
/// 他の文言と同じくローカライズ対象のまま扱える
/// （カテゴリ名だけはユーザーデータなので `verbatim`）。
private struct FocusFilterConditions: View {
    let filter: TodoFocusFilter

    var body: some View {
        HStack(spacing: 6) {
            if let categoryName = filter.categoryName {
                Text(verbatim: categoryName)
            }
            if filter.showsUrgentOnly {
                Text(.copy("Urgent only"))
            }
            if filter.hidesCompleted {
                Text(.copy("Hiding completed"))
            }
        }
    }
}
