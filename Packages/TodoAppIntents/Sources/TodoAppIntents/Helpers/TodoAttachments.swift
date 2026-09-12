//
//  TodoAttachments.swift
//  TodoAppIntents
//

import AppIntents
import Domain
import Foundation
import UniformTypeIdentifiers

/// Bridges between the App Intents `IntentFile` type and the CloudKit-safe value the
/// model stores (`TodoAttachmentValue`). Same shape as `TodoPlace` and `TodoRecurrence`.
enum TodoAttachments {
    /// Reads a file handed over by Siri, Shortcuts, or the form.
    ///
    /// The id is generated here — `IntentFile` carries none — so identity across an edit
    /// is re-established by `TodoService.applyAttachments`, which matches the incoming set
    /// against the stored rows.
    static func value(from file: IntentFile) -> TodoAttachmentValue {
        TodoAttachmentValue(
            filename: file.filename,
            typeIdentifier: file.type?.identifier,
            data: file.data
        )
    }

    /// Wraps a stored attachment back up as an `IntentFile`.
    ///
    /// The form sends the todo's whole attachment set on every save, so the ones already
    /// stored have to make the round trip. `removedOnCompletion` is off because these
    /// bytes are the app's own, not a temporary file the system handed in.
    static func intentFile(from value: TodoAttachmentValue) -> IntentFile {
        var file = IntentFile(
            data: value.data,
            filename: value.filename,
            type: value.typeIdentifier.flatMap(UTType.init(_:))
        )
        file.removedOnCompletion = false
        return file
    }
}
