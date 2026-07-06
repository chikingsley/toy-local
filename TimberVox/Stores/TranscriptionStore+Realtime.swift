import TimberVoxCore
import Foundation

private let realtimeStoreLogger = TimberVoxLog.transcription

extension TranscriptionStore {
  func startRealtimeSessionIfAvailable(settings currentSettings: TimberVoxSettings) async {
    guard let routeID = RealtimeModelRouting.realtimeRouteID(forModelID: currentSettings.selectedModel) else {
      return
    }
    guard isRecording else { return }

    let session = RealtimeDictationSession(baseURL: cloudBaseURL, recording: recording)
    session.onPartial = { [weak self] text in
      self?.livePartialText = text
    }

    do {
      try await session.start(routeID: routeID, language: currentSettings.outputLanguage)
      attachRealtimeSession(session)
    } catch {
      realtimeStoreLogger.notice(
        "Realtime session unavailable (\(error.localizedDescription)); dictation continues with batch transcription"
      )
    }
  }

  func attachRealtimeSession(_ session: RealtimeDictationSession) {
    guard isRecording else {
      session.cancel()
      return
    }
    realtimeSession = session
  }

  func takeRealtimeSession() -> RealtimeDictationSession? {
    defer { realtimeSession = nil }
    return realtimeSession
  }

  func tearDownRealtimeSession() {
    realtimeSession?.cancel()
    realtimeSession = nil
    livePartialText = nil
  }

  func resolveTranscript(
    capturedURL: URL,
    workflow: TranscriptionWorkflowRequest,
    realtimeSession: RealtimeDictationSession?
  ) async throws -> String {
    let signal = try RecordedAudioInspector.analyze(capturedURL)
    realtimeStoreLogger.notice("Audio signal rms=\(signal.rms) peak=\(signal.peak) nonZero=\(signal.nonZeroSamples)")
    guard !signal.isSilent else {
      realtimeSession?.cancel()
      try? FileManager.default.removeItem(at: capturedURL)
      throw SilentRecordingError()
    }

    if let realtimeSession, let realtimeText = await realtimeSession.finish(),
      !realtimeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      realtimeStoreLogger.notice("Using realtime transcript (\(realtimeText.count) chars)")
      return realtimeText
    }

    if realtimeSession != nil {
      realtimeStoreLogger.notice("Realtime session produced no transcript; falling back to batch")
    }
    let draft = try await transcriptionWorkflow.transcribe(
      source: AudioSource(url: capturedURL, contentType: "audio/wav"),
      workflow: workflow
    ) { _ in }
    return draft.text
  }
}
