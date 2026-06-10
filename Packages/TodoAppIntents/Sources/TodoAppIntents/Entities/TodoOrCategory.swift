//
//  TodoOrCategory.swift
//  TodoAppIntents
//
//  A union value (WWDC 2026 #345) letting a single intent parameter or result
//  carry either a todo or a category. The @UnionValue macro generates the
//  AppUnionValue / _IntentValueRepresentable conformances and a nested `Cases`
//  enum used by parameter summaries.
//

import AppIntents

/// Either a todo or a category — used as a heterogeneous Siri/Shortcuts result.
@UnionValue
public enum TodoOrCategory: Sendable {
    case todo(TodoAppEntity)
    case category(CategoryAppEntity)
}
