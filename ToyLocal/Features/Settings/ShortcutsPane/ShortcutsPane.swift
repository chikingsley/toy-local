import SwiftUI
import ToyLocalCore

struct ShortcutsPane: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Form {
      HotKeySectionView(store: store)

      Section {
        PasteLastTranscriptHotkeyRow(store: store)
      } header: {
        Text("History")
      }
    }
    .formStyle(.grouped)
  }
}

struct PasteLastTranscriptHotkeyRow: View {
  @Bindable var store: SettingsStore

  var body: some View {
    let pasteHotkey = store.toyLocalSettings.pasteLastTranscriptHotkey

    VStack(alignment: .leading, spacing: 12) {
      Label {
        VStack(alignment: .leading, spacing: 2) {
          Text("Paste Last Transcript")
            .font(.subheadline.weight(.semibold))
          Text("Assign a shortcut (modifier + key) to instantly paste your last transcription.")
            .settingsCaption()
        }
      } icon: {
        Image(systemName: "doc.on.clipboard")
      }

      let key = store.isSettingPasteLastTranscriptHotkey ? nil : pasteHotkey?.key
      let modifiers = store.isSettingPasteLastTranscriptHotkey ? store.currentPasteLastModifiers : (pasteHotkey?.modifiers ?? .init(modifiers: []))

      Button {
        store.startSettingPasteLastTranscriptHotkey()
      } label: {
        HStack {
          Spacer()
          ZStack {
            HotKeyView(modifiers: modifiers, key: key, isActive: store.isSettingPasteLastTranscriptHotkey)

            if !store.isSettingPasteLastTranscriptHotkey, pasteHotkey == nil {
              Text("Not set")
                .settingsCaption()
            }
          }
          Spacer()
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Set paste last transcript shortcut")

      if store.isSettingPasteLastTranscriptHotkey {
        Text("Use at least one modifier (\u{2318}, \u{2325}, \u{21E7}, \u{2303}) plus a key.")
          .settingsCaption()
      } else if pasteHotkey != nil {
        Button {
          store.clearPasteLastTranscriptHotkey()
        } label: {
          Label("Clear shortcut", systemImage: "xmark.circle")
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  ShortcutsPane(store: AppPreviewState.makeStore().settings)
    .frame(width: 660, height: 480)
}
