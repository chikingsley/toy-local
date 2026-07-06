import TimberVoxCore
import SwiftUI

struct SoundPane: View {
  private static let systemDefaultMicrophoneID = "system-default-input"
  private static let recordingAudioOptions = RecordingAudioBehavior.allCases.map {
    TLMenuOption(value: $0, label: $0.displayName)
  }
  private static let soundEffectStyles: [SoundEffectsStyle] = [.standard, .classic, .off]

  @Bindable var store: SettingsStore

  init(store: SettingsStore) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: SoundPaneMetrics.stackSpacing) {
      TLHeader {
        EmptyView()
      } trailing: {
        microphoneMenu
      }

      TLPane {
        recordingSection
        soundEffectsSection
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

  private var recordingSection: some View {
    TLSection(title: "Recording") {
      TLSettingsCard {
        TLSettingsToggleRow(
          title: "Automatically increase microphone volume",
          hint: "Sets microphone input volume to max when starting a recording. Only works if using system default device.",
          isOn: $store.timberVoxSettings.autoIncreaseMicrophoneVolume
        )
        TLSettingsToggleRow(
          title: "Super fast mode",
          hint:
            "Keeps the microphone engine warm so recordings start instantly, and prepends a short pre-roll so the first "
            + "word is never clipped. macOS keeps showing the microphone indicator while the engine is armed.",
          isOn: Binding(
            get: { store.timberVoxSettings.superFastModeEnabled },
            set: { enabled in
              store.timberVoxSettings.superFastModeEnabled = enabled
              store.warmUpRecorderForCaptureModeChange()
            }
          )
        )
        playbackRow

      }
    }
  }

  private var soundEffectsSection: some View {
    TLSection(title: "Sound Effects") {
      TLSettingsCard {
        soundEffectsRow
        volumeRow

      }
    }
  }

  private var playbackRow: some View {
    TLSettingsRow(
      title: "Playback when recording",
      hint: "Default playback behavior during recording. Individual modes can override this setting."
    ) {
      TLOptionMenu(
        selection: $store.timberVoxSettings.recordingAudioBehavior,
        options: Self.recordingAudioOptions
      )
    }
  }

  private var soundEffectsRow: some View {
    TLSettingsRow(title: "Sound effects") {
      Picker(
        "",
        selection: Binding(
          get: { store.timberVoxSettings.soundEffectsStyle },
          set: { store.setSoundEffectsStyle($0) }
        )
      ) {
        ForEach(Self.soundEffectStyles, id: \.self) { style in
          Text(style.displayName).tag(style)
        }
      }
      .pickerStyle(.segmented)
      .controlSize(.large)
      .frame(width: SoundPaneMetrics.soundStyleWidth)
    }
  }

  private var volumeRow: some View {
    TLSettingsRow(title: "Volume") {
      HStack(spacing: SoundPaneMetrics.volumeIconSpacing) {
        Image(systemName: "speaker.fill")
          .font(.system(size: SoundPaneMetrics.volumeIconSize))
          .foregroundStyle(.secondary)
        Slider(
          value: $store.timberVoxSettings.soundEffectsVolume,
          in: SoundPaneMetrics.minimumVolume...SoundPaneMetrics.maximumVolume
        ) { editing in
          if !editing {
            store.playSoundEffectsSample()
          }
        }
        .controlSize(.small)
        .frame(width: SoundPaneMetrics.volumeSliderWidth)
        Image(systemName: "speaker.wave.2.fill")
          .font(.system(size: SoundPaneMetrics.volumeIconSize))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private enum SoundPaneMetrics {
  static let stackSpacing: CGFloat = 0
  static let minimumVolume = 0.0
  static let maximumVolume = 1.0
  static let soundStyleWidth: CGFloat = 210
  static let volumeIconSpacing: CGFloat = 8
  static let volumeIconSize: CGFloat = 11
  static let volumeSliderWidth: CGFloat = 220
  static let previewWidth: CGFloat = 580
  static let previewHeight: CGFloat = 452
}

#Preview("Sound") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    SoundPane(store: store.settings)
      .frame(width: SoundPaneMetrics.previewWidth, height: SoundPaneMetrics.previewHeight)
      .background(TLTheme.windowBackground)
  }
}
