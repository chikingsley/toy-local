import SwiftUI

extension ConfigurationPane {
  var shortcutsSection: some View {
    TLSection(title: "Keyboard Shortcuts") {
      TLSettingsCard {
        shortcutRow(
          .toggleRecording,
          icon: "record.circle",
          title: "Toggle Recording",
          subtitle: "Starts and stops recordings"
        )
        shortcutRow(
          .cancelRecording,
          icon: "xmark.circle",
          title: "Cancel Recording",
          subtitle: "Discards the active recording"
        )
        shortcutRow(
          .changeMode,
          icon: "arrow.triangle.2.circlepath",
          title: "Change mode",
          subtitle: "Activates the mode switcher"
        )
        shortcutRow(
          .pushToTalk,
          icon: "hand.tap",
          title: "Push to Talk",
          subtitle: "Hold to record, release when done"
        )
        shortcutRow(
          .pasteLastTranscript,
          icon: "doc.on.clipboard",
          title: "Paste Last Transcript",
          subtitle: "Pastes the most recent transcript"
        )
        shortcutRow(
          .mouse,
          icon: "computermouse",
          title: "Mouse shortcut",
          subtitle: "Tap to toggle, or hold and release when done"
        )
      }
    }
  }

  func shortcutRow(
    _ recorder: ShortcutRecorder,
    icon: String,
    title: String,
    subtitle: String
  ) -> some View {
    TLSettingsRow(icon: icon, title: title, subtitle: subtitle, height: 54) {
      shortcutRecorder(recorder)
    }
  }

  @ViewBuilder
  func shortcutRecorder(_ recorder: ShortcutRecorder) -> some View {
    switch recorder {
    case .pushToTalk:
      TLShortcutRecorder(
        keys: Binding(get: { store.recordingHotKeyKeys }, set: { _ in }),
        defaultKeys: store.defaultRecordingHotKeyKeys,
        isRecording: Binding(
          get: { store.isSettingHotKey },
          set: { $0 ? store.beginRecordingHotKeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginRecordingHotKeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onReset: store.resetRecordingHotKey
      )
    case .pasteLastTranscript:
      TLShortcutRecorder(
        keys: Binding(get: { store.pasteLastTranscriptHotKeyKeys }, set: { _ in }),
        defaultKeys: store.defaultPasteLastTranscriptHotKeyKeys,
        isRecording: Binding(
          get: { store.isSettingPasteLastTranscriptHotkey },
          set: { $0 ? store.beginPasteLastTranscriptHotkeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginPasteLastTranscriptHotkeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onReset: store.resetPasteLastTranscriptHotkey
      )
    default:
      TLShortcutRecorder(
        keys: Binding(
          get: { shortcutKeys[recorder] ?? [] },
          set: { shortcutKeys[recorder] = $0 }
        ),
        defaultKeys: Self.defaultShortcutKeys[recorder] ?? []
      )
    }
  }
}
