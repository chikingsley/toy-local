import SwiftUI
import ToyLocalCore

struct SoundSectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    let sliderBinding = Binding<Double>(
      get: { volumePercentage(for: store.toyLocalSettings.soundEffectsVolume) },
      set: { store.toyLocalSettings.soundEffectsVolume = actualVolume(fromPercentage: $0) }
    )

    return Section {
      Label {
        Toggle("Sound Effects", isOn: $store.toyLocalSettings.soundEffectsEnabled)
      } icon: {
        Image(systemName: "speaker.wave.2.fill")
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Volume")
          Spacer()
          Text(formattedVolume(for: store.toyLocalSettings.soundEffectsVolume))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        Slider(value: sliderBinding, in: 0...1)
          .disabled(!store.toyLocalSettings.soundEffectsEnabled)
      }
    } header: {
      Text("Sound")
    }
  }
}

private func formattedVolume(for actualVolume: Double) -> String {
  let percent = volumePercentage(for: actualVolume)
  return "\(Int(round(percent * 100)))%"
}

private func volumePercentage(for actualVolume: Double) -> Double {
  guard ToyLocalSettings.baseSoundEffectsVolume > 0 else { return 0 }
  let ratio = actualVolume / ToyLocalSettings.baseSoundEffectsVolume
  return max(0, min(1, ratio))
}

private func actualVolume(fromPercentage percentage: Double) -> Double {
  let clampedPercentage = max(0, min(1, percentage))
  return clampedPercentage * ToyLocalSettings.baseSoundEffectsVolume
}

#Preview {
  Form {
    SoundSectionView(store: AppPreviewState.makeStore().settings)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
