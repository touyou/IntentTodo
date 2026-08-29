//
//  TodoAttributes.swift
//  TodoAppIntents
//

import Foundation

/// Normalisation for the collection-shaped attributes the reminders schema exposes.
///
/// The write paths (Siri / Shortcuts / the app's own forms) all hand in raw arrays,
/// and the model stores arrays because CloudKit can't hold a `Set`. Normalising in one
/// place keeps the stored value and the schema-visible value from disagreeing:
/// `TodoAppEntity.tags` is a `Set<String>`, so anything that survives to the model as
/// a duplicate or an empty string is silently dropped on the read path instead — which
/// reads as "the tag I typed didn't save".
public enum TodoAttributes {
    /// Whether two tags are the same tag.
    ///
    /// Two tags that differ only in case or diacritics count as one — the same relation
    /// `localizedStandardContains(_:)` uses when searching, so a tag that search can't
    /// tell apart isn't stored twice.
    ///
    /// **Not `localizedStandardCompare(_:)`**: that is the Finder *sort* order, where
    /// case is a tiebreaker rather than ignored (`"Work"` vs `"WORK"` is
    /// `.orderedAscending`, not `.orderedSame`). `lowercased()` is wrong for the same
    /// reason it is wrong in search — it is locale-independent.
    ///
    /// `public` because the app's tag field has to reject a duplicate with **this**
    /// relation. Using a narrower one there (e.g. case-only) lets a tag be accepted in
    /// the form and then silently dropped when this file normalises it on save.
    public static func isSameTag(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(
            rhs,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: nil,
            locale: .current
        ) == .orderedSame
    }

    /// Trims each tag, drops empties, and removes duplicates while keeping the order
    /// the caller supplied. The first spelling wins (a person who types `Work` means `Work`).
    static func normalized(tags: [String]) -> [String] {
        var seen: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !seen.contains(where: { isSameTag($0, trimmed) }) {
                seen.append(trimmed)
            }
        }
        return seen
    }

    /// Removes duplicate links, keeping the order the caller supplied.
    ///
    /// No trimming here — a `URL` is already parsed by the time it reaches this layer.
    static func normalized(urls: [URL]) -> [URL] {
        var seen: [URL] = []
        for url in urls where !seen.contains(url) {
            seen.append(url)
        }
        return seen
    }
}
