import TimberVoxCore
import SwiftUI

struct HotMicPane: View {
  private enum Recorder: Hashable {
    case startStop
    case paste
    case dump
  }

  private static let systemDefaultMicrophoneID = "system-default-input"
  private static let fallbackCommandKeys: [Recorder: [String]] = [
    .startStop: ["⌃", "⌥", "H"]
  ]

  @Bindable var store: SettingsStore
  @State private var commandKeys = fallbackCommandKeys

  init(store: SettingsStore) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: HotMicPaneMetrics.stackSpacing) {
      TLHeader {
        EmptyView()
      } trailing: {
        microphoneMenu
      }

      TLPane {
        hotMicStatusSection
        commandsSection
        voiceCommandsSection
      }
    }
    .onAppear {
      store.loadAvailableInputDevices()
    }
  }

  private var microphoneMenu: some View {
    TLHeaderMicrophoneMenu(selection: microphoneSelection, options: microphoneOptions)
  }

  private var microphoneSelection: Binding<String> {
    Binding(
      get: { store.timberVoxSettings.selectedMicrophoneID ?? Self.systemDefaultMicrophoneID },
      set: { selectedID in
        store.timberVoxSettings.selectedMicrophoneID = selectedID == Self.systemDefaultMicrophoneID ? nil : selectedID
      }
    )
  }

  private var microphoneOptions: [TLMenuOption<String>] {
    var options = [
      TLMenuOption(
        value: Self.systemDefaultMicrophoneID,
        label: defaultMicrophoneLabel,
        systemImage: "headphones"
      )
    ]

    options.append(
      contentsOf: store.availableInputDevices.map { device in
        TLMenuOption(value: device.id, label: device.name, systemImage: "headphones")
      }
    )

    if let selectedID = store.timberVoxSettings.selectedMicrophoneID,
      !options.contains(where: { $0.value == selectedID })
    {
      options.append(
        TLMenuOption(
          value: selectedID,
          label: "Unavailable microphone",
          systemImage: "headphones",
          accessoryText: "Missing"
        )
      )
    }

    return options
  }

  private var defaultMicrophoneLabel: String {
    if let name = store.defaultInputDeviceName, !name.isEmpty {
      return "System Default (\(name))"
    }
    return "System Default"
  }

  private func keyRecorder(_ recorder: Recorder) -> some View {
    switch recorder {
    case .startStop:
      TLShortcutRecorder(
        keys: Binding(
          get: { commandKeys[recorder] ?? [] },
          set: { commandKeys[recorder] = $0 }
        ),
        defaultKeys: Self.fallbackCommandKeys[recorder] ?? []
      )
    case .paste:
      TLShortcutRecorder(
        keys: Binding(get: { store.alwaysOnPasteHotKeyKeys }, set: { _ in }),
        defaultKeys: store.defaultAlwaysOnPasteHotKeyKeys,
        isRecording: Binding(
          get: { store.isSettingAlwaysOnPasteHotkey },
          set: { $0 ? store.beginAlwaysOnPasteHotkeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginAlwaysOnPasteHotkeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onReset: store.resetAlwaysOnPasteHotkey
      )
    case .dump:
      TLShortcutRecorder(
        keys: Binding(get: { store.alwaysOnDumpHotKeyKeys }, set: { _ in }),
        isRecording: Binding(
          get: { store.isSettingAlwaysOnDumpHotkey },
          set: { $0 ? store.beginAlwaysOnDumpHotkeyCapture() : store.cancelShortcutCapture() }
        ),
        onBeginRecording: store.beginAlwaysOnDumpHotkeyCapture,
        onCancelRecording: store.cancelShortcutCapture,
        onClear: store.clearAlwaysOnDumpHotkey
      )
    }
  }

  private var hotMicStatusSection: some View {
    TLSection(title: "Hot Mic") {
      TLCard {
        VStack(spacing: HotMicPaneMetrics.stackSpacing) {
          TLSettingsToggleRow(
            title: "Enable Hot Mic",
            subtitle: "Allow Hot Mic to listen in the background when you turn it on.",
            isOn: $store.timberVoxSettings.alwaysOnEnabled
          )
        }
      }
    }
  }

  private var commandsSection: some View {
    HStack(alignment: .top, spacing: HotMicPaneMetrics.commandSpacing) {
      HotMicCommandTile(
        icon: "power",
        title: "Start / Stop",
        subtitle: "Turn Hot Mic listening completely on or off.",
        tint: TLTheme.accentBlue
      ) {
        keyRecorder(.startStop)
      }

      HotMicCommandTile(
        icon: "text.insert",
        title: "Paste",
        subtitle: "Paste what Hot Mic heard recently.",
        tint: Color(hex: Shadcn.green500)
      ) {
        keyRecorder(.paste)
      }

      HotMicCommandTile(
        icon: "arrow.down.to.line",
        title: "Dump",
        subtitle: "Clear what Hot Mic heard so you can start fresh.",
        tint: Color(hex: Shadcn.orange400)
      ) {
        keyRecorder(.dump)
      }
    }
  }

  private var voiceCommandsSection: some View {
    TLSection(title: "Voice Commands", trailing: "Later") {
      TLSettingsCard {
        voiceCommandRow(name: "Cancel", phrases: "stop, abort")
        voiceCommandRow(name: "Paste", phrases: "paste that")
        voiceCommandRow(name: "Dump", phrases: "dump, clear it")
      }
      .opacity(HotMicPaneMetrics.disabledOpacity)
    }
  }

  private func voiceCommandRow(name: String, phrases: String) -> some View {
    TLSettingsRow(title: name, height: HotMicPaneMetrics.voiceCommandRowHeight) {
      TLKeyChip(phrases)
    }
  }

}

private struct HotMicCommandTile<Shortcut: View>: View {
  let icon: String
  let title: String
  let subtitle: String
  let tint: Color
  @ViewBuilder var shortcut: Shortcut
  @State private var hovering = false

  var body: some View {
    VStack(alignment: .leading, spacing: HotMicPaneMetrics.tileStackSpacing) {
      HStack(spacing: HotMicPaneMetrics.tileIconSpacing) {
        Image(systemName: icon)
          .font(.system(size: HotMicPaneMetrics.tileIconFontSize, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: HotMicPaneMetrics.tileIconFrameSize, height: HotMicPaneMetrics.tileIconFrameSize)
          .background(
            tint.opacity(HotMicPaneMetrics.tileIconBackgroundOpacity), in: RoundedRectangle(cornerRadius: HotMicPaneMetrics.tileIconCornerRadius))
        Text(title)
          .font(.system(size: HotMicPaneMetrics.tileTitleFontSize, weight: .semibold))
          .lineLimit(HotMicPaneMetrics.singleLineLimit)
      }

      Text(subtitle)
        .font(.system(size: HotMicPaneMetrics.tileSubtitleFontSize))
        .foregroundStyle(.secondary)
        .lineLimit(HotMicPaneMetrics.subtitleLineLimit)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: HotMicPaneMetrics.tileSpacerMinLength)

      HStack {
        Spacer(minLength: HotMicPaneMetrics.stackSpacing)
        shortcut
        Spacer(minLength: HotMicPaneMetrics.stackSpacing)
      }
    }
    .padding(HotMicPaneMetrics.tilePadding)
    .frame(maxWidth: .infinity, minHeight: HotMicPaneMetrics.tileMinHeight, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: HotMicPaneMetrics.tileCornerRadius)
        .fill(.primary.opacity(hovering ? HotMicPaneMetrics.tileHoverOpacity : HotMicPaneMetrics.tileOpacity))
    )
    .overlay(
      RoundedRectangle(cornerRadius: HotMicPaneMetrics.tileCornerRadius)
        .strokeBorder(
          tint.opacity(hovering ? HotMicPaneMetrics.tileHoverStrokeOpacity : HotMicPaneMetrics.tileStrokeOpacity),
          lineWidth: HotMicPaneMetrics.tileStrokeWidth)
    )
    .onHover { hovering = $0 }
  }
}

private enum HotMicPaneMetrics {
  static let stackSpacing: CGFloat = 0
  static let commandSpacing: CGFloat = 10
  static let disabledOpacity = 0.7
  static let voiceCommandRowHeight: CGFloat = 44
  static let tileStackSpacing: CGFloat = 9
  static let tileIconSpacing: CGFloat = 7
  static let tileIconFontSize: CGFloat = 12
  static let tileIconFrameSize: CGFloat = 22
  static let tileIconCornerRadius: CGFloat = 6
  static let tileIconBackgroundOpacity = 0.14
  static let tileTitleFontSize: CGFloat = 13
  static let singleLineLimit = 1
  static let tileSubtitleFontSize: CGFloat = 11
  static let subtitleLineLimit = 3
  static let tileSpacerMinLength: CGFloat = 4
  static let tilePadding: CGFloat = 10
  static let tileMinHeight: CGFloat = 128
  static let tileCornerRadius: CGFloat = 10
  static let tileHoverOpacity = 0.09
  static let tileOpacity = 0.055
  static let tileHoverStrokeOpacity = 0.32
  static let tileStrokeOpacity = 0.18
  static let tileStrokeWidth: CGFloat = 1
  static let previewWidth: CGFloat = 620
  static let previewHeight: CGFloat = 700
}

#Preview("Hot Mic") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    HotMicPane(store: store.settings)
      .frame(width: HotMicPaneMetrics.previewWidth, height: HotMicPaneMetrics.previewHeight)
      .background(TLTheme.windowBackground)
  }
}
