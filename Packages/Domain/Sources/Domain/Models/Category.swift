//
//  Category.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A category for organizing todo items.
///
/// CloudKit 互換のため、すべての属性は宣言時にデフォルト値を持ち、
/// to-many リレーションは空配列デフォルト。
@Model
public final class Category {
    // MARK: - Properties

    // 型注釈を省かない理由は `TodoItem` と同じ（永続化スキーマの一覧として読む）。
    // swiftlint:disable redundant_type_annotation

    /// Unique identifier for the category.
    public var id: UUID = UUID()

    /// The name of the category.
    public var name: String = ""

    /// Optional hex color code for the category (e.g., "#FF5733").
    public var colorHex: String?

    /// Todo items belonging to this category.
    ///
    /// CloudKit 互換のため optional `[TodoItem]?`。読み取りは `todos ?? []` で
    /// nil 安全に扱う。
    public var todos: [TodoItem]? = []

    // swiftlint:enable redundant_type_annotation

    // MARK: - Initialization

    /// Creates a new category with the specified name.
    /// - Parameters:
    ///   - name: The name of the category.
    ///   - colorHex: Optional hex color code for visual distinction.
    public init(name: String, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.todos = []
    }
}
