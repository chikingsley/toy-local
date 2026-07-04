import SwiftUI
import ToyLocalCore

struct MicrophoneSelectionSectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Section {
      Label {
        HStack(alignment: .center) {
          Text("Recording Source")
          Spacer()
          Picker(
            "",
            selection: Binding(
              get: { store.toyLocalSettings.recordingInputMode },
              set: { store.setRecordingInputMode($0) }
            )
          ) {
            Label("Microphone", systemImage: "mic")
              .tag(RecordingInputMode.microphone)
            Label("System Audio", systemImage: "speaker.wave.2")
              .tag(RecordingInputMode.systemAudio)
          }
          .pickerStyle(.menu)
        }
      } icon: {
        Image(systemName: "waveform")
      }

      if store.toyLocalSettings.recordingInputMode == .systemAudio {
        Text("Records audio playing through the Mac system output using macOS system audio capture.")
          .settingsCaption()
      }

      HStack {
        Label {
          let systemLabel: String = {
            if let name = store.defaultInputDeviceName, !name.isEmpty {
              return "System Default (\(name))"
            }
            return "System Default"
          }()
          Picker("Input Device", selection: $store.toyLocalSettings.selectedMicrophoneID) {
            Text(systemLabel).tag(nil as String?)
            ForEach(store.availableInputDevices) { device in
              Text(device.name).tag(device.id as String?)
            }
          }
          .pickerStyle(.menu)
          .id(store.availableInputDevices.map(\.id).joined(separator: "|"))
        } icon: {
          Image(systemName: "mic.circle")
        }

        Button(
          action: {
            store.loadAvailableInputDevices()
          },
          label: {
            Image(systemName: "arrow.clockwise")
          }
        )
        .buttonStyle(.borderless)
        .help("Refresh available input devices")
      }
      .disabled(store.toyLocalSettings.recordingInputMode != .microphone)

      // Show fallback note for selected device not connected
      if let selectedID = store.toyLocalSettings.selectedMicrophoneID,
        store.toyLocalSettings.recordingInputMode == .microphone,
        !store.availableInputDevices.contains(where: { $0.id == selectedID })
      {
        Text("Selected device not connected. System default will be used.")
          .settingsCaption()
      }
    } header: {
      Text("Recording Input")
    } footer: {
      Text("Microphone mode can override the system default input device. System Audio records the current output device.")
        .font(.footnote)
        .foregroundColor(.secondary)
    }
  }
}

#Preview {
  Form {
    MicrophoneSelectionSectionView(store: AppPreviewState.makeStore().settings)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
