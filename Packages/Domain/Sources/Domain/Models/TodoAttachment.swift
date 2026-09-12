//
//  TodoAttachment.swift
//  IntentTodo
//

import Foundation
import SwiftData

/// A file attached to a todo — an image handed over by Siri, Shortcuts, or the form.
///
/// Every attribute has a default value and the relationship is optional, for CloudKit
/// compatibility. The bytes use `.externalStorage` so SwiftData keeps them out of the
/// row and CloudKit syncs them as an asset rather than an inline field.
@Model
public final class TodoAttachment {
    // MARK: - Properties

    // Type annotations are kept for the same reason as in `TodoItem`.
    // swiftlint:disable redundant_type_annotation

    /// Unique identifier for the attachment.
    public var id: UUID = UUID()

    /// The name the file arrived under, used as its label.
    public var filename: String = ""

    /// The `UTType` identifier, when the sender provided one.
    ///
    /// Stored as a `String?` rather than a `UTType` for CloudKit compatibility, and
    /// rebuilt at the intent boundary.
    public var typeIdentifier: String?

    /// The file's bytes.
    @Attribute(.externalStorage)
    public var data: Data = Data()

    /// When the attachment was added.
    public var createdAt: Date = Date()

    /// The todo this file belongs to.
    ///
    /// The inverse is declared on `TodoItem.attachments`, which cascades: an attachment
    /// has no meaning without the todo it illustrates.
    public var todo: TodoItem?

    // swiftlint:enable redundant_type_annotation

    // MARK: - Initialization

    public init(filename: String, typeIdentifier: String? = nil, data: Data) {
        self.id = UUID()
        self.filename = filename
        self.typeIdentifier = typeIdentifier
        self.data = data
        self.createdAt = Date()
        self.todo = nil
    }

    /// Recreates an attachment with an explicit identifier.
    ///
    /// Counterpart to `TodoItem.init(id:…)`: attachments are cascade-deleted with their
    /// todo, so undoing a deletion has to bring them back under the same ids.
    public init(id: UUID, filename: String, typeIdentifier: String?, data: Data, createdAt: Date) {
        self.id = id
        self.filename = filename
        self.typeIdentifier = typeIdentifier
        self.data = data
        self.createdAt = createdAt
        self.todo = nil
    }
}

// MARK: - Value type

/// A `Sendable` copy of one attachment.
///
/// The write paths (intents, the form) and the undo snapshot all deal in this rather than
/// in `TodoAttachment`: a `@Model` is not `Sendable` and is meaningless once deleted.
public struct TodoAttachmentValue: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let filename: String
    public let typeIdentifier: String?
    public let data: Data

    public init(id: UUID = UUID(), filename: String, typeIdentifier: String? = nil, data: Data) {
        self.id = id
        self.filename = filename
        self.typeIdentifier = typeIdentifier
        self.data = data
    }

    @MainActor
    public init(_ attachment: TodoAttachment) {
        self.id = attachment.id
        self.filename = attachment.filename
        self.typeIdentifier = attachment.typeIdentifier
        self.data = attachment.data
    }

    /// Builds the stored model, keeping the value's identity so restoring is lossless.
    @MainActor
    public func makeAttachment(createdAt: Date = Date()) -> TodoAttachment {
        TodoAttachment(
            id: id,
            filename: filename,
            typeIdentifier: typeIdentifier,
            data: data,
            createdAt: createdAt
        )
    }
}
