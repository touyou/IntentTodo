//
//  AboutView.swift
//  UI
//
//  The build, your statistics, feedback and the legal links, pushed from Settings.
//

#if os(iOS) || os(visionOS) || os(macOS)
import Domain
import SwiftUI
import TodoAppIntents

struct AboutView: View {
    let todos: [TodoItem]
    let organize: TodoOrganizeSnapshot?

    var body: some View {
        Form {
            AboutHeaderSection()
            StatisticsSection(todos: todos, organize: organize)

            Section {
                AboutLinkRow(title: .copy("Rate Intento"), systemImage: "star", destination: AboutLinks.writeReview)
                AboutLinkRow(title: .copy("Feedback & Bug Reports"), systemImage: "envelope", destination: AboutLinks.support)
                ShareLink(item: AboutLinks.appStore) {
                    Label(.copy("Share Intento"), systemImage: "square.and.arrow.up")
                }
            } header: {
                Text(.copy("Feedback"))
            }

            Section {
                AboutLinkRow(title: .copy("Developer"), systemImage: "person", destination: AboutLinks.developer)
            }

            Section {
                AboutLinkRow(title: .copy("Privacy Policy"), systemImage: "hand.raised", destination: AboutLinks.privacy)
                NavigationLink {
                    LicensesView()
                } label: {
                    Label(.copy("Open Source Licenses"), systemImage: "doc.text")
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(.copy("About"))
    }
}

private struct AboutHeaderSection: View {
    /// Read from the bundle rather than kept as a constant: the point of showing it is to
    /// identify the build a report came from.
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Section {
            LabeledContent(.copy("Version")) {
                Text(verbatim: version)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }
        } footer: {
            Text(.copy("Everything this app can do is an App Intent, so Siri, Shortcuts, widgets, controls and Spotlight all reach the same actions. Made by one developer in Japan."))
        }
    }
}

private struct StatisticsSection: View {
    let todos: [TodoItem]
    let organize: TodoOrganizeSnapshot?

    private var completed: Int { todos.count { $0.isCompleted } }
    private var favorites: Int { todos.count { $0.isFavorite } }

    var body: some View {
        Section {
            LabeledContent(.copy("Total")) { Text(todos.count, format: .number) }
            LabeledContent(.copy("Incomplete")) { Text(todos.count - completed, format: .number) }
            LabeledContent(.copy("Completed")) { Text(completed, format: .number) }
            LabeledContent(.copy("Favorites")) { Text(favorites, format: .number) }
            if let organize {
                LabeledContent(.copy("Uncategorized")) {
                    Text(organize.todoCount(inList: CategoryAppEntity.uncategorizedID), format: .number)
                }
            }
        } header: {
            Text(.copy("Your Todos"))
        }
    }
}

/// A row that leaves the app (Safari or the App Store), marked with an arrow so that is
/// clear before the tap.
private struct AboutLinkRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct LicensesView: View {
    // Update Licenses.txt when a dependency is added.
    private let text: String = {
        guard let url = Bundle.module.url(forResource: "Licenses", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }()

    var body: some View {
        ScrollView {
            Text(verbatim: text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .navigationTitle(.copy("Open Source Licenses"))
    }
}

private enum AboutLinks {
    static let appStore = URL(string: "https://apps.apple.com/app/id6788623037")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id6788623037?action=write-review")!
    static let support = URL(string: "https://touyou.dev/intento/support")!
    static let privacy = URL(string: "https://touyou.dev/intento/privacy")!
    static let developer = URL(string: "https://touyou.dev")!
}
#endif
