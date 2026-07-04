import SwiftUI

struct PrototypeSoundPane: View {
  private static let playbackOptions = ["Pause", "Lower volume", "Do nothing"]

  @State private var inputDevice = TLMicrophoneSource.devices[0]
  @State private var increaseMicrophoneVolume = true
  @State private var silenceRemoval = false
  @State private var dynamicNormalization = false
  @State private var playbackWhenRecording = Self.playbackOptions[0]
  @State private var soundStyle: SoundStyle = .classic
  @State private var volume = 0.84

  var body: some View {
    VStack(spacing: 0) {
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
  }

  private var microphoneMenu: some View {
    TLHeaderMicrophoneMenu(selection: $inputDevice)
  }

  private var recordingSection: some View {
    TLSection(title: "Recording") {
      TLSettingsCard {
        TLSettingsToggleRow(
          title: "Automatically increase microphone volume",
          hint: "Sets microphone input volume to max when starting a recording. Only works if using system default device.",
          isOn: $increaseMicrophoneVolume
        )
        TLSettingsToggleRow(
          title: "Silence removal",
          hint:
            "If enabled, silence will be removed from your recordings before processing, improving accuracy and reducing hallucinations. For long recordings with a lot of silence, this significantly improves processing times.",
          isOn: $silenceRemoval
        )
        TLSettingsToggleRow(
          title: "Dynamic normalization",
          hint:
            "If enabled, recordings will be normalized and filtered dynamically based on the particular characteristics of the audio. This feature is intended to maintain consistent loudness levels and speech intelligibility across recordings.",
          isOn: $dynamicNormalization
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
        selection: $playbackWhenRecording,
        options: Self.playbackOptions.map { TLMenuOption(value: $0, label: $0) }
      )
    }
  }

  private var soundEffectsRow: some View {
    TLSettingsRow(title: "Sound effects") {
      Picker("", selection: $soundStyle) {
        ForEach(SoundStyle.allCases) { style in
          Text(style.label).tag(style)
        }
      }
      .pickerStyle(.segmented)
      .controlSize(.large)
      .frame(width: 210)
    }
  }

  private var volumeRow: some View {
    TLSettingsRow(title: "Volume") {
      HStack(spacing: 8) {
        Image(systemName: "speaker.fill")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Slider(value: $volume, in: 0...1)
          .controlSize(.small)
          .frame(width: 220)
        Image(systemName: "speaker.wave.2.fill")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
    }
  }
}

private enum SoundStyle: String, CaseIterable, Identifiable {
  case simple, classic, off

  var id: String { rawValue }

  var label: String {
    switch self {
    case .simple: "Simple"
    case .classic: "Classic"
    case .off: "Off"
    }
  }
}

#Preview("Sound") {
  TLFloatingHost {
    PrototypeSoundPane()
      .frame(width: 580, height: 452)
      .background(TLTheme.windowBackground)
  }
}
