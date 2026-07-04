import SwiftUI

struct PrototypeHotMicPane: View {
  private enum Recorder: Hashable {
    case startStop
    case paste
    case dump
  }

  private static let defaultCommandKeys: [Recorder: [String]] = [
    .startStop: ["⌃", "⌥", "H"],
    .paste: ["fn"],
    .dump: ["⌃", "⌥", "D"],
  ]

  @State private var enabled = false
  @State private var microphone = TLMicrophoneSource.devices[0]
  @State private var commandKeys = defaultCommandKeys

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        EmptyView()
      } trailing: {
        TLHeaderMicrophoneMenu(selection: $microphone)
      }

      TLPane {
        hotMicStatusSection
        commandsSection
        voiceCommandsSection
      }
    }
  }

  private func keyRecorder(_ recorder: Recorder) -> some View {
    TLShortcutRecorder(
      keys: Binding(
        get: { commandKeys[recorder] ?? [] },
        set: { commandKeys[recorder] = $0 }
      ),
      defaultKeys: Self.defaultCommandKeys[recorder] ?? []
    )
  }

  private var hotMicStatusSection: some View {
    TLSection(title: "Hot Mic") {
      TLCard {
        VStack(spacing: 0) {
          TLSettingsToggleRow(
            title: "Enable Hot Mic",
            subtitle: "Allow Hot Mic to listen in the background when you turn it on.",
            isOn: $enabled
          )
        }
      }
    }
  }

  private var commandsSection: some View {
    HStack(alignment: .top, spacing: 10) {
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
      .opacity(0.7)
    }
  }

  private func voiceCommandRow(name: String, phrases: String) -> some View {
    TLSettingsRow(title: name, height: 44) {
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
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 7) {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 22, height: 22)
          .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
      }

      Text(subtitle)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 4)

      HStack {
        Spacer(minLength: 0)
        shortcut
        Spacer(minLength: 0)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.primary.opacity(hovering ? 0.09 : 0.055))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(tint.opacity(hovering ? 0.32 : 0.18), lineWidth: 1)
    )
    .onHover { hovering = $0 }
  }
}

#Preview("Hot Mic") {
  TLFloatingHost {
    PrototypeHotMicPane()
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
