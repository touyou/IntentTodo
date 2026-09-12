//
//  QueryCallLogView.swift
//  UI
//
//  Debug screen for the calls the system made into the app's queries.
//

#if DEBUG
#if os(iOS) || os(visionOS) || os(macOS)
import SwiftUI
import TodoAppIntents

/// Lists what `QueryCallLog` recorded: which query method the system called, from which
/// process, and how many values came back.
///
/// A row with a request count but nothing returned is the signature worth looking for —
/// the system asked and the app answered with nothing, which every surface renders
/// identically to never having been asked.
///
/// DEBUG only, hence `Text(verbatim:)` throughout: this screen never ships, so putting its
/// copy through the 12 string catalogs would be work with no reader.
struct QueryCallLogView: View {
    @State private var entries: [QueryCallLogEntry] = []

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: "No query calls")
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                } description: {
                    Text(verbatim: "Calls the system makes into the app's entity queries appear here.")
                }
            } else {
                // Newest first: the call being investigated is the one that just happened.
                ForEach(entries.reversed()) { entry in
                    QueryCallLogRow(entry: entry)
                }
            }
        }
        .navigationTitle(Text(verbatim: "Query Calls"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    QueryCallLog.clear()
                    entries = []
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(entries.isEmpty)
                .accessibilityIdentifier("queryCallLogClearButton")
            }
        }
        .refreshable { load() }
        .task { load() }
    }

    /// Reads straight from the App Group defaults rather than observing: entries are written
    /// by other processes, which publishes nothing this view could subscribe to.
    private func load() {
        entries = QueryCallLog.entries()
    }
}

/// One recorded call.
private struct QueryCallLogRow: View {
    let entry: QueryCallLogEntry

    /// The system asked for something and got nothing back.
    private var isEmptyAnswer: Bool {
        (entry.requested ?? 0) > 0 && entry.returned == 0
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: entry.caller)
                    .font(.headline)
                Text(verbatim: "\(entry.query) · \(entry.process)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(verbatim: countSummary)
                .font(.body.monospacedDigit())
                .foregroundStyle(isEmptyAnswer ? .red : .secondary)
        }
        .padding(.vertical, 4)
    }

    /// `3 → 0` for calls that take identifiers, plain `12` for the ones that do not.
    private var countSummary: String {
        guard let requested = entry.requested else { return "\(entry.returned)" }
        return "\(requested) → \(entry.returned)"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QueryCallLogView()
    }
}
#endif
#endif
