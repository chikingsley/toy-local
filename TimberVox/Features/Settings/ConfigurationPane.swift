import TimberVoxCore
import SwiftUI

struct ConfigurationPane: View {
  enum ShortcutRecorder {
    case toggleRecording
    case cancelRecording
    case changeMode
    case pushToTalk
    case pasteLastTranscript
    case mouse
  }

  static let defaultShortcutKeys: [ShortcutRecorder: [String]] = [
    .toggleRecording: ["⌥", "␣"],
    .cancelRecording: ["esc"],
    .changeMode: ["⌥", "⇧", "K"],
    .pushToTalk: ["⌘"],
    .mouse: [],
  ]

  @Bindable var store: SettingsStore
  let microphonePermission: PermissionStatus
  let accessibilityPermission: PermissionStatus
  let screenCapturePermission: PermissionStatus
  let updates: CheckForUpdatesViewModel

  init(
    store: SettingsStore,
    microphonePermission: PermissionStatus,
    accessibilityPermission: PermissionStatus,
    screenCapturePermission: PermissionStatus,
    updates: CheckForUpdatesViewModel = .shared
  ) {
    self.store = store
    self.microphonePermission = microphonePermission
    self.accessibilityPermission = accessibilityPermission
    self.screenCapturePermission = screenCapturePermission
    self.updates = updates
  }

  @State var shortcutKeys = defaultShortcutKeys
  @State private var route: ConfigurationRoute = .main
  @State private var recordingSurface: RecordingSurfaceChoice = .cursor

  private var theme: ConfigurationThemeChoice {
    switch store.timberVoxSettings.appearancePreference {
    case .light: .light
    case .dark: .dark
    case .automatic: .automatic
    }
  }

  private var appVersion: String {
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    return "\(short) (\(build))"
  }

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
    if route == .main {
      .sidebarToggle
    } else {
      .back {
        route = .main
      }
    }
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
    }
  }
}

private extension ConfigurationPane {
  private var appearanceSection: some View {
    TLSection(title: "Appearance") {
      TLSettingsCard {
        ConfigurationVisualRow(title: "Theme") {
          ConfigurationVisualChoiceGroup {
            ForEach(ConfigurationThemeChoice.allCases) { option in
              ConfigurationVisualChoice(label: option.label, selected: theme == option) {
                store.timberVoxSettings.appearancePreference = option.preference
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

  private var applicationSection: some View {
    TLSection(title: "Application") {
      TLSettingsCard {
        TLSettingsToggleRow(
          icon: "power",
          title: "Launch on login",
          hint: "If enabled, the Application will start when you log in to your Mac.",
          isOn: Binding(
            get: { store.timberVoxSettings.openOnLogin },
            set: { store.toggleOpenOnLogin($0) }
          )
        )
        ConfigurationMenuRow(
          icon: "clock.arrow.circlepath",
          title: "Keep recordings for",
          hint: "Sets the length of time that recording files are kept on disk. Older recordings will be automatically deleted.",
          options: RecordingRetention.allCases.map { TLMenuOption(value: $0, label: $0.displayName) },
          selection: $store.timberVoxSettings.recordingRetention
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
          ConfigurationPermissionPill(name: "Microphone", granted: microphonePermission == .granted)
          ConfigurationPermissionPill(name: "Accessibility", granted: accessibilityPermission == .granted)
          ConfigurationPermissionPill(name: "Screen Recording", granted: screenCapturePermission == .granted)
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
        #if MAS_BUILD
          TLSettingsRow(icon: "shippingbox", title: "Version", subtitle: appVersion) {
            EmptyView()
          }
        #else
          TLSettingsRow(icon: "shippingbox", title: "Version", subtitle: appVersion) {
            Button("Check for Updates...", action: updates.checkForUpdates)
              .controlSize(.small)
          }
          TLSettingsToggleRow(
            icon: "arrow.clockwise",
            title: "Automatically check for updates",
            hint: "If enabled, \(AppBrand.name) will automatically check for updates every three hours.",
            isOn: Binding(
              get: { updates.automaticallyChecksForUpdates },
              set: { updates.automaticallyChecksForUpdates = $0 }
            )
          )
          TLSettingsToggleRow(
            icon: "arrow.down.circle",
            title: "Automatically download updates",
            hint: "Updates install quietly on next launch.",
            isOn: Binding(
              get: { updates.automaticallyDownloadsUpdates },
              set: { updates.automaticallyDownloadsUpdates = $0 }
            )
          )
        #endif

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
}

private extension ConfigurationPane {
  private var advancedApplicationSection: some View {
    TLSection(title: "Application") {
      TLSettingsCard {
        TLSettingsToggleRow(
          icon: "dock.rectangle",
          title: "Show in Dock",
          hint:
            "If enabled, the Application will show in the Dock when running. "
            + "If disabled, the Application will only show in Dock when the settings window is open.",
          isOn: $store.timberVoxSettings.showDockIcon
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
          isOn: $store.timberVoxSettings.autoPasteResult
        )
        ConfigurationMenuRow(
          icon: "doc.on.clipboard",
          title: "Clipboard behaviour",
          hint: "Controls how your clipboard is handled after pasting transcription text.",
          options: ClipboardRestoreBehavior.allCases.map { TLMenuOption(value: $0, label: $0.displayName) },
          selection: $store.timberVoxSettings.clipboardRestoreBehavior
        )
        TLSettingsToggleRow(
          icon: "keyboard",
          title: "Simulate keypresses",
          hint:
            "Warning this is an Experimental feature, only Standard US QWERTY layout keyboards are supported. "
            + "If enabled, instead of pasting the clipboard, the application will simulate key presses from your "
            + "keyboard and text will stream from your cursor.",
          showsAI: true,
          isOn: Binding(
            get: { !store.timberVoxSettings.useClipboardPaste },
            set: { store.timberVoxSettings.useClipboardPaste = !$0 }
          )
        )

      }
    }
  }

}

#Preview("Configuration") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    ConfigurationPane(
      store: store.settings,
      microphonePermission: .granted,
      accessibilityPermission: .granted,
      screenCapturePermission: .notDetermined
    )
    .frame(width: 660, height: 760)
    .background(TLTheme.windowBackground)
  }
}
