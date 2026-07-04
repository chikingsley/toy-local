import SwiftUI
import ToyLocalCore

struct RecordingPane: View {
  @Bindable var store: SettingsStore
  var alwaysOnStore: AlwaysOnStore
  let microphonePermission: PermissionStatus

  var body: some View {
    Form {
      if microphonePermission == .granted && !store.availableInputDevices.isEmpty {
        MicrophoneSelectionSectionView(store: store)
      }

      SoundSectionView(store: store)

      RecordingBehaviorSectionView(store: store)

      AlwaysOnSectionView(store: store, alwaysOnStore: alwaysOnStore)
    }
    .formStyle(.grouped)
  }
}

private struct RecordingBehaviorSectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Section {
      Label {
        Toggle(
          "Prevent System Sleep while Recording",
          isOn: Binding(
            get: { store.toyLocalSettings.preventSystemSleep },
            set: { store.togglePreventSystemSleep($0) }
          )
        )
      } icon: {
        Image(systemName: "zzz")
      }

      Label {
        HStack(alignment: .center) {
          Text("Audio Behavior while Recording")
          Spacer()
          Picker(
            "",
            selection: Binding(
              get: { store.toyLocalSettings.recordingAudioBehavior },
              set: { store.setRecordingAudioBehavior($0) }
            )
          ) {
            Label("Pause Media", systemImage: "pause")
              .tag(RecordingAudioBehavior.pauseMedia)
            Label("Mute Volume", systemImage: "speaker.slash")
              .tag(RecordingAudioBehavior.mute)
            Label("Do Nothing", systemImage: "hand.raised.slash")
              .tag(RecordingAudioBehavior.doNothing)
          }
          .pickerStyle(.menu)
        }
      } icon: {
        Image(systemName: "speaker.wave.2")
      }
    } header: {
      Text("Behavior")
    }
  }
}

#Preview {
  let store = AppPreviewState.makeStore()
  RecordingPane(
    store: store.settings,
    alwaysOnStore: store.alwaysOn,
    microphonePermission: .granted
  )
  .frame(width: 660, height: 560)
}
