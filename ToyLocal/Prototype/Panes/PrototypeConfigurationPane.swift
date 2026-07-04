import SwiftUI

struct PrototypeConfigurationPane: View {
  private static let retentionOptions = ["Forever", "One year", "Six months", "One month", "One week"]

  private enum ShortcutRecorder {
    case toggleRecording
    case cancelRecording
    case changeMode
    case pushToTalk
    case mouse
  }

  private static let defaultShortcutKeys: [ShortcutRecorder: [String]] = [
    .toggleRecording: ["⌥", "␣"],
    .cancelRecording: ["esc"],
    .changeMode: ["⌥", "⇧", "K"],
    .pushToTalk: ["⌘"],
    .mouse: [],
  ]

  @State private var shortcutKeys = defaultShortcutKeys
  @State private var route: ConfigurationRoute = .main
  @Binding var appearance: ColorScheme?

  init(appearance: Binding<ColorScheme?> = .constant(nil)) {
    self._appearance = appearance
  }

  private var theme: ConfigurationThemeChoice {
    switch appearance {
    case .light: .light
    case .dark: .dark
    default: .automatic
    }
  }
  @State private var recordingSurface: RecordingSurfaceChoice = .cursor
  @State private var autoUpdates = true
  @State private var autoDownloadUpdates = true
  @State private var launchOnLogin = false
  @State private var errorLogging = false
  @State private var retention = Self.retentionOptions[0]
  @State private var showDockIcon = false
  @State private var startOnMenuClick = false
  @State private var alwaysClose = false
  @State private var voiceModelDuration = "1 minute"
  @State private var pasteResult = true
  @State private var autoSendAfterPaste = false
  @State private var clipboardBehavior = "Default"
  @State private var simulateKeypresses = false
  @State private var experimentalModels = false

  var body: some View {
    VStack(spacing: 0) {
      header
      TLPane {
        switch route {
        case .main:
          mainContent
        case .advanced:
          advancedContent
        }
      }
      .id(route == .main ? "configuration-main" : "configuration-advanced")
    }
  }

  private var header: some View {
    TLHeader(control: headerControl) {
      EmptyView()
    } trailing: {
      if route == .main {
        HStack(spacing: 8) {
          ConfigurationHeaderPill(icon: "circle.lefthalf.filled", text: theme.label)
          ConfigurationHeaderPill(icon: recordingSurface.headerIcon, text: recordingSurface.label)
        }
      }
    }
  }

  private var headerControl: TLHeaderControl {
    route == .main ? .sidebarToggle : .back({ route = .main })
  }

  private var mainContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      appearanceSection
      shortcutsSection
      applicationSection
      permissionsSection
      updatesSection
      advancedEntryRow
    }
  }

  private var advancedContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      advancedApplicationSection
      advancedTextInputSection
      advancedVoiceModelSection
      advancedAppFolderSection
      advancedAgentPluginsSection
      advancedAIModelsSection
    }
  }

  private var appearanceSection: some View {
    TLSection(title: "Appearance") {
      TLSettingsCard {
        ConfigurationVisualRow(title: "Theme") {
          ConfigurationVisualChoiceGroup {
            ForEach(ConfigurationThemeChoice.allCases) { option in
              ConfigurationVisualChoice(label: option.label, selected: theme == option) {
                appearance = option.colorScheme
              } preview: {
                ConfigurationThemeThumbnail(choice: option)
              }
            }
          }
        }

        ConfigurationRecordingWindowRow(
          title: "Recording window",
          subtitle: "Choose where dictation feedback lives while recording."
        ) {
          LazyVGrid(
            columns: [
              GridItem(.fixed(118), spacing: 14),
              GridItem(.fixed(118), spacing: 14),
              GridItem(.fixed(118), spacing: 14),
            ],
            alignment: .trailing,
            spacing: 14
          ) {
            ForEach(RecordingSurfaceChoice.allCases) { option in
              ConfigurationVisualChoice(size: .large, label: option.label, selected: recordingSurface == option) {
                recordingSurface = option
              } preview: {
                RecordingSurfacePreview(choice: option, selected: recordingSurface == option)
              }
            }
          }
        }

        ConfigurationSurfaceDemoRow(choice: recordingSurface)

      }
    }
  }

  private var shortcutsSection: some View {
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
          .mouse,
          icon: "computermouse",
          title: "Mouse shortcut",
          subtitle: "Tap to toggle, or hold and release when done"
        )

      }
    }
  }

  private func shortcutRow(
    _ recorder: ShortcutRecorder,
    icon: String,
    title: String,
    subtitle: String
  ) -> some View {
    TLSettingsRow(icon: icon, title: title, subtitle: subtitle, height: 54) {
      TLShortcutRecorder(
        keys: Binding(
          get: { shortcutKeys[recorder] ?? [] },
          set: { shortcutKeys[recorder] = $0 }
        ),
        defaultKeys: Self.defaultShortcutKeys[recorder] ?? []
      )
    }
  }

  private var applicationSection: some View {
    TLSection(title: "Application") {
      TLSettingsCard {
        TLSettingsToggleRow(
          icon: "power",
          title: "Launch on login",
          hint: "If enabled, the Application will start when you log in to your Mac.",
          isOn: $launchOnLogin
        )
        TLSettingsToggleRow(
          icon: "ladybug",
          title: "Error logging",
          hint: "If enabled, errors you encounter will be automatically recorded and sent to our error tracker to assist with fixing the issue.",
          isOn: $errorLogging
        )
        ConfigurationMenuRow(
          icon: "clock.arrow.circlepath",
          title: "Keep recordings for",
          hint: "Sets the length of time that recording files are kept on disk. Older recordings will be automatically deleted.",
          options: Self.retentionOptions,
          selection: $retention
        )

      }
    }
  }

  private var permissionsSection: some View {
    TLSection(title: "Permissions") {
      TLCard {
        HStack(spacing: 12) {
          Image(systemName: "lock.shield")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 20)
          ConfigurationPermissionPill(name: "Microphone", granted: true)
          ConfigurationPermissionPill(name: "Accessibility", granted: true)
          ConfigurationPermissionPill(name: "Screen Recording", granted: false)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
      }
    }
  }

  private var updatesSection: some View {
    TLSection(title: "Updates") {
      TLSettingsCard {
        TLSettingsRow(icon: "shippingbox", title: "Version", subtitle: "0.9.2 (142)") {
          Button("Check for Updates...") {}
            .controlSize(.small)
        }
        TLSettingsToggleRow(
          icon: "arrow.clockwise",
          title: "Automatically check for updates",
          hint: "If enabled, ToyLocal will automatically check for updates every three hours.",
          isOn: $autoUpdates
        )
        TLSettingsToggleRow(
          icon: "arrow.down.circle",
          title: "Automatically download updates",
          hint: "Updates install quietly on next launch.",
          isOn: $autoDownloadUpdates
        )

      }
    }
  }

  private var advancedEntryRow: some View {
    Button {
      route = .advanced
    } label: {
      HStack {
        Text("Advanced settings")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 16)
      .frame(height: 50)
      .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: TLTheme.cardRadius))
    }
    .buttonStyle(.plain)
  }

  private var advancedApplicationSection: some View {
    TLSection(title: "Application") {
      TLSettingsCard {
        TLSettingsToggleRow(
          icon: "dock.rectangle",
          title: "Show in Dock",
          hint:
            "If enabled, the Application will show in the Dock when running. If disabled, the Application will only show in Dock when the settings window is open.",
          isOn: $showDockIcon
        )
        TLSettingsToggleRow(
          icon: "menubar.arrow.up.rectangle",
          title: "Start Recording on Menubar Click",
          hint: "If enabled, left clicking the menubar icon will start a new recording.",
          isOn: $startOnMenuClick
        )
        TLSettingsToggleRow(
          icon: "xmark.circle",
          title: "Always close",
          hint: "If enabled, when your dictation is complete, the recording window will be automatically closed. Even if we are not able to paste.",
          isOn: $alwaysClose
        )

      }
    }
  }

  private var advancedTextInputSection: some View {
    TLSection(title: "Text Input") {
      TLSettingsCard {
        TLSettingsToggleRow(
          icon: "doc.on.clipboard",
          title: "Paste result text",
          hint: "If enabled, the results of your dictation will be automatically pasted into the focused text input when your dictation completes.",
          isOn: $pasteResult
        )
        TLSettingsToggleRow(
          icon: "paperplane",
          title: "Hold shift to auto-send after paste",
          hint: "If enabled, hold shift as you're finishing your recording ToyLocal will send your message.",
          showsAI: true,
          isOn: $autoSendAfterPaste
        )
        ConfigurationMenuRow(
          icon: "doc.on.clipboard",
          title: "Clipboard behaviour",
          hint: "Controls how your clipboard is handled after pasting transcription text.",
          options: ["Default", "Paste", "Type"],
          selection: $clipboardBehavior
        )
        TLSettingsToggleRow(
          icon: "keyboard",
          title: "Simulate keypresses",
          hint:
            "Warning this is an Experimental feature, only Standard US QWERTY layout keyboards are supported. If enabled, instead of pasting the clipboard, the application will simulate key presses from your keyboard and text will stream from your cursor.",
          showsAI: true,
          isOn: $simulateKeypresses
        )

      }
    }
  }

  private var advancedVoiceModelSection: some View {
    TLSection(title: "Voice model") {
      TLCard {
        ConfigurationMenuRow(
          icon: "memorychip",
          title: "Voice model active duration",
          hint: "How many minutes should the Voice model be kept loaded and ready.",
          options: ["1 minute", "5 minutes", "15 minutes"],
          selection: $voiceModelDuration
        )
      }
    }
  }

  private var advancedAppFolderSection: some View {
    TLSection(title: "App folder location") {
      TLCard {
        TLSettingsRow(
          icon: "folder",
          title: "~/Documents/ToyLocal",
          height: 44
        ) {
          HStack(spacing: 8) {
            Button("Change folder...") {}
              .controlSize(.small)
            TLInfoHint(
              "The folder where all ToyLocal configuration, recordings and modes are saved. The default location is ~/Documents/ToyLocal."
            )
          }
        }
      }
    }
  }

  private var advancedAgentPluginsSection: some View {
    TLSection(title: "Agent Plugins") {
      TLSettingsCard {
        ConfigurationAgentRow(name: "Claude Code", asset: "agent-claudecode")
        ConfigurationAgentRow(name: "OpenCode", asset: "agent-opencode")
        ConfigurationAgentRow(name: "Codex", asset: "agent-codex")

      }
    }
  }

  private var advancedAIModelsSection: some View {
    TLSection(title: "AI Models") {
      TLCard {
        TLSettingsToggleRow(
          icon: "atom",
          title: "Show experimental models",
          hint: "If enabled, experimental AI models will be shown in the models list. These models may be unstable or in development.",
          showsAI: true,
          isOn: $experimentalModels
        )
      }
    }
  }
}

private enum ConfigurationRoute {
  case main, advanced
}

private enum ConfigurationThemeChoice: String, CaseIterable, Identifiable {
  case automatic, light, dark

  var id: String { rawValue }

  var colorScheme: ColorScheme? {
    switch self {
    case .automatic: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var label: String {
    switch self {
    case .automatic: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var assetName: String {
    switch self {
    case .automatic: "appearance-auto"
    case .light: "appearance-light"
    case .dark: "appearance-dark"
    }
  }
}

private enum RecordingSurfaceChoice: String, CaseIterable, Identifiable {
  case classic, mini, notch, cursor, input, none

  var id: String { rawValue }

  var label: String {
    switch self {
    case .classic: "Classic"
    case .mini: "Mini"
    case .notch: "Notch"
    case .cursor: "Cursor"
    case .input: "Input"
    case .none: "None"
    }
  }

  var headerIcon: String {
    switch self {
    case .classic: "waveform"
    case .mini: "waveform.circle"
    case .notch: "macbook"
    case .cursor: "cursorarrow.rays"
    case .input: "text.cursor"
    case .none: "eye.slash"
    }
  }
}

private struct ConfigurationVisualRow<Content: View>: View {
  let title: String
  var subtitle = ""
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      content
        .frame(maxWidth: 420, alignment: .trailing)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private struct ConfigurationVisualChoiceGroup<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      content
    }
  }
}

private struct ConfigurationVisualChoice<Preview: View>: View {
  enum Size {
    case regular, large

    var previewSize: CGSize {
      switch self {
      case .regular: CGSize(width: 82, height: 58)
      case .large: CGSize(width: 118, height: 76)
      }
    }

    var columnWidth: CGFloat {
      switch self {
      case .regular: 84
      case .large: 118
      }
    }
  }

  var size: Size = .regular
  let label: String
  let selected: Bool
  let action: () -> Void
  @ViewBuilder var preview: Preview
  @State private var hovering = false

  var body: some View {
    VStack(spacing: 6) {
      Button(action: action) {
        preview
          .frame(width: size.previewSize.width, height: size.previewSize.height)
          .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .strokeBorder(
                selected
                  ? Color.accentColor
                  : (hovering ? Color.primary.opacity(0.22) : TLTheme.borderStroke),
                lineWidth: selected ? 1.4 : 1
              )
          )
          .contentShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .onHover { hovering = $0 }

      Text(label)
        .font(.system(size: 11, weight: selected ? .semibold : .medium))
        .foregroundStyle(selected ? .primary : .secondary)
    }
    .frame(width: size.columnWidth)
  }
}

private struct ConfigurationRecordingWindowRow<Content: View>: View {
  let title: String
  var subtitle = ""
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }

      content
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private struct ConfigurationThemeThumbnail: View {
  let choice: ConfigurationThemeChoice

  var body: some View {
    Image(choice.assetName)
      .resizable()
      .scaledToFill()
      .frame(width: 82, height: 58)
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

private struct RecordingSurfacePreview: View {
  let choice: RecordingSurfaceChoice
  let selected: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))

      switch choice {
      case .classic:
        Capsule()
          .fill(.black.opacity(0.55))
          .frame(width: 92, height: 32)
          .overlay(ConfigurationMirroredWaveform(color: selected ? .accentColor : .secondary, bars: 28, height: 18))
      case .mini:
        RoundedRectangle(cornerRadius: 9)
          .fill(.black.opacity(0.55))
          .frame(width: 46, height: 36)
          .overlay(ConfigurationMirroredWaveform(color: selected ? .accentColor : .secondary, bars: 9, height: 20))
      case .notch:
        VStack(spacing: 4) {
          Capsule()
            .fill(.black)
            .frame(width: 58, height: 14)
          Capsule()
            .fill(.black.opacity(0.58))
            .frame(width: 94, height: 28)
            .overlay(ConfigurationMirroredWaveform(color: selected ? .accentColor : .secondary, bars: 18, height: 15))
        }
      case .cursor:
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 5)
            .fill(.white.opacity(0.07))
            .frame(width: 78, height: 42)
            .overlay(alignment: .leading) {
              Rectangle().fill(.white.opacity(0.65)).frame(width: 1, height: 26).padding(.leading, 27)
            }
          Capsule()
            .fill(.black.opacity(0.72))
            .frame(width: 52, height: 22)
            .overlay(ConfigurationMirroredWaveform(color: selected ? .accentColor : .secondary, bars: 9, height: 12))
            .offset(x: 42, y: -13)
        }
      case .input:
        RoundedRectangle(cornerRadius: 7)
          .fill(.white.opacity(0.07))
          .frame(width: 86, height: 30)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(.black.opacity(0.72))
              .frame(width: 44, height: 22)
              .overlay(ConfigurationMirroredWaveform(color: selected ? .accentColor : .secondary, bars: 8, height: 12))
              .padding(.leading, -5)
          }
      case .none:
        Image(systemName: "eye.slash")
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct ConfigurationSurfaceDemoRow: View {
  let choice: RecordingSurfaceChoice

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Preview")
          .font(.system(size: 13, weight: .semibold))
        Text(description)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      ConfigurationLiveSurfacePreview(choice: choice)
        .frame(width: 300, height: 146)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private var description: String {
    switch choice {
    case .classic:
      "A stable top overlay with waveform and the current transcript line."
    case .mini:
      "Compact feedback when you only need recording state and level."
    case .notch:
      "A notch-adjacent surface for laptops, drawn as our own Dynamic Island-style variant."
    case .cursor:
      "A small waveform beside the insertion point, backed by Accessibility caret bounds in the real app."
    case .input:
      "Attached to the focused input field when caret bounds are unavailable but the element frame is known."
    case .none:
      "No recording window. Sounds and menu-bar state carry the feedback."
    }
  }
}

private struct ConfigurationLiveSurfacePreview: View {
  let choice: RecordingSurfaceChoice

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.18))
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Circle().fill(.red.opacity(0.85)).frame(width: 7, height: 7)
          Circle().fill(.yellow.opacity(0.85)).frame(width: 7, height: 7)
          Circle().fill(.green.opacity(0.85)).frame(width: 7, height: 7)
        }
        RoundedRectangle(cornerRadius: 7)
          .fill(.white.opacity(0.08))
          .frame(height: 88)
          .overlay(previewOverlay)
      }
      .padding(12)
    }
  }

  @ViewBuilder private var previewOverlay: some View {
    switch choice {
    case .classic:
      VStack(spacing: 10) {
        Capsule()
          .fill(.black.opacity(0.76))
          .frame(width: 190, height: 32)
          .overlay(
            HStack(spacing: 10) {
              ConfigurationMirroredWaveform(color: .accentColor, bars: 32, height: 18)
              Text("turn that into a cleaner note")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            })
        Spacer()
      }
      .padding(.top, 8)
    case .mini:
      VStack {
        HStack {
          Spacer()
          RoundedRectangle(cornerRadius: 11)
            .fill(.black.opacity(0.76))
            .frame(width: 46, height: 34)
            .overlay(ConfigurationMirroredWaveform(color: .accentColor, bars: 9, height: 18))
        }
        Spacer()
      }
      .padding(10)
    case .notch:
      VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black)
          .frame(width: 76, height: 18)
        Capsule()
          .fill(.black.opacity(0.78))
          .frame(width: 168, height: 34)
          .overlay(
            HStack(spacing: 8) {
              ConfigurationMirroredWaveform(color: .accentColor, bars: 24, height: 16)
              Text("recording")
                .font(.system(size: 11, weight: .semibold))
            })
        Spacer()
      }
    case .cursor:
      ZStack(alignment: .topLeading) {
        Text("Write the summary here")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.top, 26)
          .padding(.leading, 46)
        Rectangle()
          .fill(.white.opacity(0.75))
          .frame(width: 1, height: 25)
          .padding(.top, 22)
          .padding(.leading, 74)
        Capsule()
          .fill(.black.opacity(0.82))
          .frame(width: 118, height: 26)
          .overlay(
            HStack(spacing: 7) {
              ConfigurationMirroredWaveform(color: .accentColor, bars: 9, height: 13)
              Text("capturing...")
                .font(.system(size: 10, weight: .semibold))
            }
          )
          .padding(.top, 5)
          .padding(.leading, 84)
      }
    case .input:
      VStack(spacing: 0) {
        Spacer()
        RoundedRectangle(cornerRadius: 9)
          .fill(.black.opacity(0.28))
          .frame(width: 220, height: 32)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(.black.opacity(0.82))
              .frame(width: 84, height: 24)
              .overlay(ConfigurationMirroredWaveform(color: .accentColor, bars: 14, height: 14))
              .offset(x: -8)
          }
        Spacer()
      }
    case .none:
      VStack(spacing: 8) {
        Image(systemName: "eye.slash")
          .font(.system(size: 20))
          .foregroundStyle(.secondary)
        Text("No overlay")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct ConfigurationMirroredWaveform: View {
  var color: Color
  var bars: Int
  var height: CGFloat

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.08)) { context in
      let phase = context.date.timeIntervalSinceReferenceDate
      HStack(alignment: .center, spacing: 1.5) {
        ForEach(0..<bars, id: \.self) { index in
          let midpoint = Double(max(1, bars - 1)) / 2
          let centerDistance = abs(Double(index) - midpoint) / midpoint
          let envelope = 0.45 + 0.55 * (1 - centerDistance)
          let movement = 0.55 + 0.45 * abs(sin(phase * 3.2 + Double(index) * 0.42))
          let barHeight = max(3, height * envelope * movement)

          Capsule()
            .fill(color.opacity(0.72 + 0.26 * movement))
            .frame(width: 2, height: barHeight)
        }
      }
      .frame(height: height)
    }
  }
}

private struct ConfigurationMenuRow: View {
  var icon: String?
  let title: String
  var hint = ""
  let options: [String]
  @Binding var selection: String

  var body: some View {
    TLSettingsRow(icon: icon, title: title, hint: hint) {
      TLOptionMenu(
        selection: $selection,
        options: options.map { TLMenuOption(value: $0, label: $0) }
      )
    }
  }
}

private struct ConfigurationAgentRow: View {
  let name: String
  let asset: String

  var body: some View {
    TLSettingsRow(title: name, height: 44) {
      HStack(spacing: 12) {
        Image(asset)
          .resizable()
          .scaledToFit()
          .frame(width: 20, height: 20)
          .clipShape(RoundedRectangle(cornerRadius: 4))
        Button("Install") {}
          .controlSize(.small)
      }
    }
  }
}

private struct ConfigurationHeaderPill: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .semibold))
      Text(text)
        .font(.system(size: 12, weight: .semibold))
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 9)
    .frame(height: 28)
    .background(TLTheme.fieldSurface, in: RoundedRectangle(cornerRadius: TLTheme.fieldRadius))
  }
}

private struct ConfigurationPermissionPill: View {
  let name: String
  let granted: Bool

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .font(.system(size: 10))
        .foregroundStyle(granted ? Color(hex: Shadcn.green500) : Color(hex: Shadcn.orange400))
      Text(name)
        .font(.system(size: 11))
        .foregroundStyle(granted ? .secondary : .primary)
      if !granted {
        Text("Grant")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Color(hex: Shadcn.orange400))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(granted ? TLTheme.fieldSurface : Color(hex: Shadcn.orange400).opacity(0.14), in: Capsule())
  }
}

#Preview("Configuration") {
  TLFloatingHost {
    PrototypeConfigurationPane()
      .frame(width: 660, height: 760)
      .background(TLTheme.windowBackground)
  }
}
