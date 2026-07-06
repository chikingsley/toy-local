import TimberVoxCore
import Foundation

@MainActor
enum DebugStateReporter {
  static var stateURL: URL {
    get throws {
      try URL.timberVoxApplicationSupport.appending(component: "debug-state.json")
    }
  }

  @discardableResult
  static func writeSnapshot(
    appStore: AppStore,
    mainExperienceStarted: Bool,
    visibleWindows: [String],
    localTranscription: DebugStateSnapshot.LocalTranscriptionSnapshot? = nil
  ) -> DebugStateSnapshot? {
    do {
      let snapshot = makeSnapshot(
        appStore: appStore,
        mainExperienceStarted: mainExperienceStarted,
        visibleWindows: visibleWindows,
        localTranscription: localTranscription
      )
      let data = try JSONEncoder.debugStateEncoder.encode(snapshot)
      let destinationURL = try stateURL
      try data.write(to: destinationURL, options: [.atomic])
      TimberVoxLog.app.info("Wrote debug state to \(destinationURL.path)")
      return snapshot
    } catch {
      TimberVoxLog.app.error("Failed to write debug state: \(error.localizedDescription)")
      return nil
    }
  }

  static func makeSnapshot(
    appStore: AppStore,
    mainExperienceStarted: Bool,
    visibleWindows: [String],
    localTranscription: DebugStateSnapshot.LocalTranscriptionSnapshot? = nil
  ) -> DebugStateSnapshot {
    DebugStateSnapshot(
      bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
      processIdentifier: ProcessInfo.processInfo.processIdentifier,
      mainExperienceStarted: mainExperienceStarted,
      visibleWindows: visibleWindows.sorted(),
      permissions: .init(
        microphone: appStore.microphonePermission.debugName,
        accessibility: appStore.accessibilityPermission.debugName,
        screenCapture: appStore.screenCapturePermission.debugName
      ),
      transcription: .init(
        isRecording: appStore.transcription.isRecording,
        isTranscribing: appStore.transcription.isTranscribing,
        isPrewarming: appStore.transcription.isPrewarming,
        textTransform: appStore.transcription.textTransformState.debugSnapshot,
        error: appStore.transcription.error
      ),
      model: .init(
        displayName: appStore.settings.modelDownload.modelBootstrapState.modelDisplayName,
        error: appStore.settings.modelDownload.modelBootstrapState.lastError,
        identifier: appStore.settings.modelDownload.modelBootstrapState.modelIdentifier,
        isDownloading: appStore.settings.modelDownload.isDownloading,
        isReady: appStore.settings.modelDownload.modelBootstrapState.isModelReady,
        progress: appStore.settings.modelDownload.modelBootstrapState.progress
      ),
      localTranscription: localTranscription,
      activeTab: appStore.activeTab.debugName,
      generatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }
}

private extension TextTransformRunState {
  var debugSnapshot: DebugStateSnapshot.TranscriptionSnapshot.TextTransformSnapshot {
    DebugStateSnapshot.TranscriptionSnapshot.TextTransformSnapshot(
      phase: phase.rawValue,
      mode: mode?.rawValue,
      requestedModelID: requestedModelID,
      responseModelID: responseModelID,
      providerID: providerID,
      inputCharacterCount: inputCharacterCount,
      outputCharacterCount: outputCharacterCount,
      outputPreview: outputPreview,
      error: error
    )
  }
}

private extension JSONEncoder {
  static var debugStateEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}

private extension PermissionStatus {
  var debugName: String {
    switch self {
    case .notDetermined:
      "notDetermined"
    case .granted:
      "granted"
    case .denied:
      "denied"
    }
  }
}
