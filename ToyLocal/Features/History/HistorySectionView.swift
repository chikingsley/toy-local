import SwiftUI
import ToyLocalCore

struct HistorySectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Section {
      Label {
        Toggle(
          "Save Transcription History",
          isOn: Binding(
            get: { store.toyLocalSettings.saveTranscriptionHistory },
            set: { store.toggleSaveTranscriptionHistory($0) }
          ))
        Text("Save transcriptions and audio recordings for later access")
          .settingsCaption()
      } icon: {
        Image(systemName: "clock.arrow.circlepath")
      }

      if store.toyLocalSettings.saveTranscriptionHistory {
        Label {
          HStack {
            Text("Maximum History Entries")
            Spacer()
            Picker(
              "",
              selection: Binding(
                get: { store.toyLocalSettings.maxHistoryEntries ?? 0 },
                set: { newValue in
                  store.toyLocalSettings.maxHistoryEntries = newValue == 0 ? nil : newValue
                }
              )
            ) {
              Text("Unlimited").tag(0)
              Text("50").tag(50)
              Text("100").tag(100)
              Text("200").tag(200)
              Text("500").tag(500)
              Text("1000").tag(1000)
            }
            .pickerStyle(.menu)
            .frame(width: 120)
          }
        } icon: {
          Image(systemName: "number.square")
        }

        if store.toyLocalSettings.maxHistoryEntries != nil {
          Text("Oldest entries will be automatically deleted when limit is reached")
            .settingsCaption()
            .padding(.leading, 28)
        }
      }
    } header: {
      Text("History")
    } footer: {
      if !store.toyLocalSettings.saveTranscriptionHistory {
        Text("When disabled, transcriptions will not be saved and audio files will be deleted immediately after transcription.")
          .font(.footnote)
          .foregroundColor(.secondary)
      }
    }
  }
}

#Preview {
  Form {
    HistorySectionView(store: AppPreviewState.makeStore().settings)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
