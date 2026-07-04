import SwiftUI
import ToyLocalCore

struct GeneralSectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Section {
      Label {
        Toggle(
          "Open on Login",
          isOn: Binding(
            get: { store.toyLocalSettings.openOnLogin },
            set: { store.toggleOpenOnLogin($0) }
          ))
      } icon: {
        Image(systemName: "arrow.right.circle")
      }

      Label {
        Toggle("Show Dock Icon", isOn: $store.toyLocalSettings.showDockIcon)
      } icon: {
        Image(systemName: "dock.rectangle")
      }

      Label {
        Toggle("Use clipboard to insert", isOn: $store.toyLocalSettings.useClipboardPaste)
        Text(
          "Use clipboard to insert text. Fast but may not restore all clipboard content.\n"
            + "Turn off to use simulated keypresses. Slower, but doesn't need to restore clipboard."
        )
      } icon: {
        Image(systemName: "doc.on.doc.fill")
      }

      Label {
        Toggle("Copy to clipboard", isOn: $store.toyLocalSettings.copyToClipboard)
        Text("Copy transcription text to clipboard in addition to pasting it")
      } icon: {
        Image(systemName: "doc.on.clipboard")
      }

    } header: {
      Text("General")
    }
  }
}

#Preview {
  Form {
    GeneralSectionView(store: AppPreviewState.makeStore().settings)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
