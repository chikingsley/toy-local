import SwiftUI

/// Hosts the history list plus its settings, so "History" has one home:
/// the save/limit controls live in a gear popover instead of a settings tab.
struct HistoryPane: View {
  var historyStore: HistoryStore
  @Bindable var settingsStore: SettingsStore
  @State private var showingHistorySettings = false

  var body: some View {
    HistoryView(store: historyStore) {
      settingsStore.toggleSaveTranscriptionHistory(true)
    }
    .toolbar {
      Button {
        showingHistorySettings.toggle()
      } label: {
        Label("History Settings", systemImage: "gearshape")
      }
      .help("History settings")
      .popover(isPresented: $showingHistorySettings, arrowEdge: .bottom) {
        Form {
          HistorySectionView(store: settingsStore)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 200)
      }
    }
  }
}

#Preview {
  let store = AppPreviewState.makeStore()
  NavigationStack {
    HistoryPane(historyStore: store.history, settingsStore: store.settings)
      .navigationTitle("History")
  }
  .frame(width: 700, height: 560)
}
