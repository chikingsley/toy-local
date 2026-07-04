import SwiftUI
import ToyLocalCore

struct AlwaysOnSectionView: View {
  @Bindable var store: SettingsStore
  var alwaysOnStore: AlwaysOnStore

  var body: some View {
    Section {
      Toggle("Enable Always-On Mode", isOn: $store.toyLocalSettings.alwaysOnEnabled)

      if store.toyLocalSettings.alwaysOnEnabled {
        // Model status
        if alwaysOnStore.isModelLoading {
          HStack(spacing: 8) {
            ProgressView(value: alwaysOnStore.modelDownloadProgress)
              .progressViewStyle(.linear)
            Text(alwaysOnStore.modelDownloadProgress, format: .percent.precision(.fractionLength(0)))
              .font(.caption)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          Text("Downloading streaming model...")
            .settingsCaption()
        } else if alwaysOnStore.isModelLoaded {
          if alwaysOnStore.isListening {
            Label("Listening", systemImage: "waveform")
              .foregroundStyle(.green)
              .font(.caption)
          } else {
            Label("Model ready", systemImage: "checkmark.circle")
              .foregroundStyle(.green)
              .font(.caption)
          }
        } else if let error = alwaysOnStore.error {
          Label(error, systemImage: "exclamation.triangle")
            .foregroundStyle(.red)
            .font(.caption)
        }

        Text("Mic is always listening. Transcriptions accumulate until you paste or dump.")
          .settingsCaption()

        HStack {
          Text("Paste Hotkey")
          Spacer()
          Text(hotkeyLabel(store.toyLocalSettings.alwaysOnPasteHotkey))
            .foregroundStyle(.secondary)
        }

        HStack {
          Text("Dump Hotkey")
          Spacer()
          if let dumpHotkey = store.toyLocalSettings.alwaysOnDumpHotkey {
            Text(hotkeyLabel(dumpHotkey))
              .foregroundStyle(.secondary)
          } else {
            Text("Not set")
              .foregroundStyle(.tertiary)
          }
        }

        Text("Push-to-talk is disabled while always-on mode is active.")
          .settingsCaption()
      }
    } header: {
      Label("Always-On", systemImage: "waveform.circle")
    }
  }

  private func hotkeyLabel(_ hotkey: HotKey?) -> String {
    guard let hotkey else { return "Not set" }
    let modifiers = hotkey.modifiers.sorted.map(\.stringValue).joined()
    let key = hotkey.key?.toString ?? ""
    let label = modifiers + key
    return label.isEmpty ? "Fn" : label
  }
}

#Preview {
  let store = AppPreviewState.makeStore()
  Form {
    AlwaysOnSectionView(store: store.settings, alwaysOnStore: store.alwaysOn)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
