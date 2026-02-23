import Inject
import Sparkle
import SwiftUI

struct AboutView: View {
  @ObserveInjection var inject
  var store: SettingsStore
  private let viewModel: CheckForUpdatesViewModel = .shared
  @State private var showingChangelog = false
  private static let gitHubURL = URL(string: "https://github.com/kitlangton/ToyLocal/")
  private static let sponsorURL = URL(string: "https://github.com/sponsors/kitlangton")

  var body: some View {
    Form {
      Section {
        HStack {
          Label("Version", systemImage: "info.circle")
          Spacer()
          Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
          Button("Check for Updates") {
            viewModel.checkForUpdates()
          }
          .buttonStyle(.bordered)
        }
        HStack {
          Label("Changelog", systemImage: "doc.text")
          Spacer()
          Button("Show Changelog") {
            showingChangelog.toggle()
          }
          .buttonStyle(.bordered)
          .sheet(
            isPresented: $showingChangelog,
            onDismiss: {
              showingChangelog = false
            },
            content: {
              ChangelogView()
            })
        }
        HStack {
          Label("ToyLocal is open source", systemImage: "apple.terminal.on.rectangle")
          Spacer()
          if let gitHubURL = Self.gitHubURL {
            Link("Visit our GitHub", destination: gitHubURL)
          } else {
            Text("Visit our GitHub")
          }
        }

        HStack {
          Label("Support the developer", systemImage: "heart")
          Spacer()
          if let sponsorURL = Self.sponsorURL {
            Link("Become a Sponsor", destination: sponsorURL)
          } else {
            Text("Become a Sponsor")
          }
        }
      }
    }
    .formStyle(.grouped)
    .enableInjection()
  }
}
