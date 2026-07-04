import SwiftUI
import ToyLocalCore

/// Shared mock world for previews: granted permissions, populated devices and
/// model catalog, so page-level previews look like the real app rather than a
/// fresh install.
@MainActor
enum AppPreviewState {
  /// One-stop store factory for previews. SettingsManager detects preview mode
  /// and persists to a temp directory, so seeded data never touches real files.
  static func makeStore() -> AppStore {
    let services = ServiceContainer()
    services.settings.transcriptionHistory = TranscriptionHistory(history: [
      Transcript(
        timestamp: Date(),
        text: "Okay so the main thing I want to work on today is the sidebar organization and making sure the panes all land in the right place.",
        audioPath: URL(fileURLWithPath: "/tmp/preview-audio-1.m4a"),
        duration: 8.4,
        sourceAppBundleID: "com.apple.dt.Xcode",
        sourceAppName: "Xcode"
      ),
      Transcript(
        timestamp: Date().addingTimeInterval(-3600),
        text: "Hey, just following up on the release notes — I'll send the draft over this afternoon.",
        audioPath: URL(fileURLWithPath: "/tmp/preview-audio-2.m4a"),
        duration: 5.1,
        sourceAppBundleID: "com.apple.mail",
        sourceAppName: "Mail"
      ),
      Transcript(
        timestamp: Date().addingTimeInterval(-90000),
        text: "Remember to add Parakeet and FluidAudio to the vocabulary list so they stop getting misheard.",
        audioPath: URL(fileURLWithPath: "/tmp/preview-audio-3.m4a"),
        duration: 6.3,
        sourceAppBundleID: "com.apple.Notes",
        sourceAppName: "Notes"
      ),
    ])
    let store = AppStore(services: services)
    configure(store)
    return store
  }

  static func configure(_ store: AppStore) {
    store.microphonePermission = .granted
    store.accessibilityPermission = .granted
    store.screenCapturePermission = .granted

    store.settings.availableInputDevices = [
      AudioInputDevice(id: "system-default", name: "MacBook Air Microphone"),
      AudioInputDevice(id: "usb-preview", name: "USB Microphone"),
    ]
    store.settings.defaultInputDeviceName = "MacBook Air Microphone"

    let selected = FluidAudioModels.parakeetTdtCtc110m.id
    store.settings.toyLocalSettings.selectedModel = selected
    store.settings.modelDownload.availableModels = [
      ModelInfo(name: FluidAudioModels.parakeetTdtCtc110m.id, isDownloaded: true),
      ModelInfo(name: FluidAudioModels.parakeetTdtV3.id, isDownloaded: false),
    ]
    store.settings.modelDownload.curatedModels = [
      CuratedModelInfo(
        displayName: "Parakeet 110M",
        internalName: FluidAudioModels.parakeetTdtCtc110m.id,
        size: "110M",
        accuracyStars: 4,
        speedStars: 5,
        storageSize: "650 MB",
        isDownloaded: true
      ),
      CuratedModelInfo(
        displayName: "Parakeet TDT v3",
        internalName: FluidAudioModels.parakeetTdtV3.id,
        size: "0.6B",
        accuracyStars: 5,
        speedStars: 3,
        storageSize: "2.3 GB",
        isDownloaded: false
      ),
    ]
    store.settings.modelDownload.recommendedModel = selected
    store.settings.modelDownload.modelBootstrapState = ModelBootstrapState(
      isModelReady: true,
      progress: 1,
      lastError: nil,
      modelIdentifier: selected,
      modelDisplayName: "Parakeet 110M"
    )
  }
}
