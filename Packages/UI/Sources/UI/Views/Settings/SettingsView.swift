//
//  SettingsView.swift
//  UI
//
//  Organising, system integration, the About screen, and the diagnostics.
//

#if os(iOS) || os(visionOS) || os(macOS)
import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// The app's settings.
///
/// Four things, in the order they are likely to be wanted:
///
/// 1. **Manage** — the lists and tags a todo can be filed under. Editing them lives here
///    and *browsing* them lives in the todo list (`TodoListsBrowseView`): renaming a list is
///    a rare, settings-shaped job, while switching to a list is part of reading your todos.
///    Putting both on one screen left the destructive actions in the path of ordinary
///    browsing.
/// 2. **Siri & Shortcuts** — `ShortcutsLink` is for *exploring* the App Shortcuts, "great
///    if your app has a lot of App Shortcuts and you want to let users explore all of them"
///    [Apple: wwdc2022-10170 20:19], which is a settings-shaped job.
/// 3. **About** — a pushed screen (`AboutView`) with the build, the statistics, feedback
///    and the legal links, so this form keeps only what changes how the app behaves.
/// 4. **Diagnostics** — debug and TestFlight builds only. See `DiagnosticsAvailability`.
///
/// `ShortcutsLink` does not exist in the macOS SDK, so that one section is conditional; the
/// rest of the screen is shared, and macOS reaches it through the standard Settings scene.
public struct SettingsView: View {
    public init() {}

    public var body: some View {
        OrganizeSnapshotReader { snapshot in
            SettingsForm(organize: snapshot)
        }
    }
}

// MARK: - Form

private struct SettingsForm: View {
    let organize: TodoOrganizeSnapshot?

    /// Statistics are read straight off the query: every field below is a scalar, which
    /// stays readable even for the deleted object a `@Query` result can hold for one frame.
    @Query private var todos: [TodoItem]

    #if os(iOS) || os(visionOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ListManagementView()
                } label: {
                    LabeledContent {
                        Text(verbatim: organize.map { "\($0.lists.count)" } ?? "")
                    } label: {
                        Label(.copy("Lists"), systemImage: "folder")
                    }
                }
                .accessibilityIdentifier("manageListsLink")

                NavigationLink {
                    TagManagementView()
                } label: {
                    LabeledContent {
                        Text(verbatim: organize.map { "\($0.tags.count)" } ?? "")
                    } label: {
                        Label(.copy("Tags"), systemImage: "number")
                    }
                }
                .accessibilityIdentifier("manageTagsLink")
            } header: {
                Text(.copy("Manage"))
            } footer: {
                // Says what this screen is *not*, because the two screens share the word
                // "Lists": here you change what exists, in the todo list you choose what to
                // look at.
                Text(.copy("Rename, merge and delete lists and tags. To browse by list, use the folder button in your todo list."))
            }

            #if os(iOS) || os(visionOS)
            Section {
                ShortcutsLink()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("shortcutsLink")
            } header: {
                Text(.copy("Siri & Shortcuts"))
            } footer: {
                Text(.copy("Browse every action this app adds to Shortcuts, then combine them into your own automations."))
            }
            #endif

            Section {
                NavigationLink {
                    AboutView(todos: todos, organize: organize)
                } label: {
                    Label(.copy("About"), systemImage: "info.circle")
                }
                .accessibilityIdentifier("aboutLink")
            }

            if DiagnosticsAvailability.isEnabled {
                DiagnosticsSection()
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 440)
        #endif
        .navigationTitle(.copy("Settings"))
        #if os(iOS) || os(visionOS)
        .toolbar {
            // Nothing here is confirmed — settings apply as they change — so this is the
            // close seat, not the confirming one.
            ToolbarItem(placement: .cancellationAction) {
                // The standard close symbol rather than the word "Done": the HIG asks for
                // symbols in toolbars, and names Back and Close as the two that have to be
                // the standard ones.
                Button(role: .close) {
                    dismiss()
                } label: {
                    Label(.copy("Done"), systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("settingsDoneButton")
            }
        }
        #endif
    }
}

// MARK: - Diagnostics

/// Developer-facing, so the copy is `Text(verbatim:)` throughout.
///
/// The audience is whoever is debugging this build, and `DiagnosticsAvailability` keeps the
/// section out of App Store builds entirely — putting it through the string catalogs would
/// be work with no reader.
private struct DiagnosticsSection: View {
    @Environment(\.modelContext) private var modelContext

    /// The last action's outcome, so a tap that did something is distinguishable from one
    /// that silently didn't.
    @State private var lastAction: String?

    private var appGroupPath: String {
        SharedModelContainer.sharedContainerURL?.path(percentEncoded: false) ?? "unavailable"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "—"
    }

    private var footer: String {
        lastAction ?? "Shown in debug and TestFlight builds only."
    }

    var body: some View {
        Section {
            NavigationLink {
                QueryCallLogView()
            } label: {
                Text(verbatim: "Query Calls")
            }
            .accessibilityIdentifier("queryCallLogLink")

            Button {
                WidgetReloader.reloadAllWidgets()
                lastAction = "Asked WidgetKit and Control Center to reload"
            } label: {
                Text(verbatim: "Reload Widgets and Controls")
            }

            Button {
                AppShortcutParameterUpdater.notifyEntitiesChanged()
                lastAction = "Asked the system to refetch App Shortcut parameters"
            } label: {
                Text(verbatim: "Refresh App Shortcut Parameters")
            }

            Button {
                let service = TodoService.swiftDataBacked(container: modelContext.container)
                Task {
                    await service.indexAllForSpotlight()
                    lastAction = "Spotlight reindex finished — it skips when nothing changed"
                }
            } label: {
                Text(verbatim: "Reindex Spotlight")
            }

            LabeledContent {
                Text(verbatim: bundleIdentifier)
                    .textSelection(.enabled)
            } label: {
                Text(verbatim: "Bundle ID")
            }

            LabeledContent {
                Text(verbatim: appGroupPath)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            } label: {
                Text(verbatim: "App Group")
            }
        } header: {
            Text(verbatim: "Diagnostics")
        } footer: {
            Text(verbatim: footer)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
#endif
