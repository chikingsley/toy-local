import AppKit
import Foundation

struct DictationWorkflowCallbacks: Sendable {
  var onLevel: @Sendable (Float) -> Void
  var onSamples: @Sendable ([Float]) -> Void
  var onLiveTranscript: @Sendable (String) -> Void
  var onProcessingText: @Sendable (String) -> Void = { _ in }
  var onRealtimeError: @Sendable (String) -> Void
  var onRecordingError: @Sendable (String) -> Void = { _ in }
}

struct DictationResult: Sendable {
  var rawText: String
  var finalText: String
  var model: String
  var modeID: String
  var modeName: String
  var provider: String?
  var language: String?
  var wallLatencyMs: Double?
  var duration: TimeInterval
  var audioURL: URL
  var deliveryNote: String
  var persistenceWarning: String?
}

enum DictationWorkflowError: LocalizedError {
  case alreadyRecording
  case applicationSupportDirectoryUnavailable
  case emptyTransformation
  case missingActivePlan
  case failedAttempt(
    failure: DictationFailure,
    recordingURL: URL,
    duration: TimeInterval,
    persistenceWarning: String?
  )

  var errorDescription: String? {
    switch self {
    case .alreadyRecording:
      "A dictation recording is already active."
    case .applicationSupportDirectoryUnavailable:
      "Application Support is unavailable."
    case .emptyTransformation:
      "Text processing completed without returning any text."
    case .missingActivePlan:
      "No dictation mode was active for this recording."
    case .failedAttempt(let failure, let url, _, let persistenceWarning):
      [
        failure.message,
        "The recording is safe at \(url.lastPathComponent).",
        persistenceWarning,
      ]
      .compactMap { $0 }
      .joined(separator: " ")
    }
  }

  var preservedRecording: (url: URL, duration: TimeInterval)? {
    guard case .failedAttempt(_, let url, let duration, _) = self else { return nil }
    return (url, duration)
  }

  var failure: DictationFailure? {
    guard case .failedAttempt(let failure, _, _, _) = self else { return nil }
    return failure
  }
}

@MainActor
final class DictationWorkflow {
  let logger = TimberVoxLog.dictation
  private let recorder: DictationAudioRecorder
  private let transcription: TranscriptionRuntime
  let textTransform: TextTransformAPIClient
  let textDelivery: TextDeliveryService
  let transcriptStore: TranscriptStore
  private let modeStore: ModeStore
  private let catalogStore: TranscriptionModelCatalogStore
  private let contextCaptureService: DictationContextCaptureService
  private let playbackPolicy = PlaybackPolicyCoordinator()

  private var activePlan: DictationExecutionPlan?
  var activeContext: DictationContext?
  var activeContextSnapshot: DictationContextSnapshot?
  private var activeContextSession: DictationContextCaptureSession?
  var activeContextWasPersisted = false
  var activeSourceApplication: SourceApplication?
  var activeCallbacks: DictationWorkflowCallbacks?

  init(
    recorder: DictationAudioRecorder = DictationAudioRecorder(),
    transcription: TranscriptionRuntime = .shared,
    textTransform: TextTransformAPIClient = .current,
    textDelivery: TextDeliveryService = TextDeliveryService(),
    transcriptStore: TranscriptStore = .shared,
    modeStore: ModeStore = .shared,
    catalogStore: TranscriptionModelCatalogStore = .shared
  ) {
    self.recorder = recorder
    self.transcription = transcription
    self.textTransform = textTransform
    self.textDelivery = textDelivery
    self.transcriptStore = transcriptStore
    self.modeStore = modeStore
    self.catalogStore = catalogStore
    contextCaptureService = DictationContextCaptureService()
  }

  func start(callbacks: DictationWorkflowCallbacks) async throws -> Date {
    guard activePlan == nil else { throw DictationWorkflowError.alreadyRecording }
    let sourceApplication = DictationWorkflowEnvironment.frontmostApplication()
    let plan = try await executionPlan(sourceApplication: sourceApplication)
    let startedAt = Date.now
    let contextSession = await contextCaptureService.startSession(
      mode: plan.mode,
      startedAt: startedAt
    )

    do {
      try await startRealtimeIfNeeded(plan: plan, callbacks: callbacks)
      let sampleHandler = makeSampleHandler(plan: plan, callbacks: callbacks)
      try await recorder.start(
        writingTo: DictationWorkflowEnvironment.newRecordingURL(),
        includesSystemAudio: plan.mode.includesSystemAudio,
        onLevel: callbacks.onLevel,
        onSamples: sampleHandler
      ) { error in
        callbacks.onRecordingError(error.localizedDescription)
      }
      playbackPolicy.apply(plan.mode.playbackPolicy)
      activePlan = plan
      activeContextWasPersisted = false
      activeContextSession = contextSession
      activeContext = contextSession?.currentContext
      activeSourceApplication = sourceApplication
      activeCallbacks = callbacks
      return startedAt
    } catch {
      contextSession?.cancel()
      await cancelRealtimeSessions()
      throw error
    }
  }

  func stop() async throws -> DictationResult? {
    guard let plan = activePlan else { throw DictationWorkflowError.missingActivePlan }
    do {
      let recording = try await finishRecording()
      guard let recording else {
        await cancelRealtimeSessions()
        clearActiveSession()
        return nil
      }
      defer { clearActiveSession() }
      let artifact = try await transcriptionArtifact(for: recording, plan: plan)
      let textOutput = try await textOutput(for: artifact, recording: recording, plan: plan)
      let persistenceWarning = persist(
        recording: recording,
        plan: plan,
        artifact: artifact,
        textOutput: textOutput
      )
      return await result(
        recording: recording,
        plan: plan,
        artifact: artifact,
        textOutput: textOutput,
        persistenceWarning: persistenceWarning
      )
    } catch {
      await cancelRealtimeSessions()
      await playbackPolicy.restore()
      clearActiveSession()
      throw error
    }
  }

  private func finishRecording() async throws -> (url: URL, duration: TimeInterval)? {
    if let activeContextSession {
      let snapshot = await activeContextSession.finish()
      activeContextSnapshot = snapshot
      activeContext = snapshot.context
    }
    let recording = try await recorder.finish()
    await playbackPolicy.restore()
    return recording
  }

  func cancel() async {
    await cancelRealtimeSessions()
    activeContextSession?.cancel()
    await recorder.cancel()
    await playbackPolicy.restore()
    clearActiveSession()
  }

  private func executionPlan(sourceApplication: SourceApplication?) async throws -> DictationExecutionPlan {
    await catalogStore.refreshIfNeeded()
    guard !catalogStore.models.isEmpty else {
      let reason = catalogStore.lastError ?? "The transcription catalog did not contain any models."
      throw TranscriptionRuntimeError.configuration("Transcription model catalog unavailable: \(reason)")
    }
    let currentMode = modeStore.mode(
      forSourceApplicationBundleIdentifier: sourceApplication?.bundleIdentifier
    )
    let normalizedMode = catalogStore.normalized(currentMode)
    if normalizedMode != currentMode {
      modeStore.updateMode(id: currentMode.id) { $0 = normalizedMode }
    }
    return try ModeCatalogResolver.executionPlan(
      for: normalizedMode,
      catalog: catalogStore.models
    )
  }

  private func startRealtimeIfNeeded(
    plan: DictationExecutionPlan,
    callbacks: DictationWorkflowCallbacks
  ) async throws {
    await cancelRealtimeSessions()
    guard plan.transport == .realtime else { return }
    try await transcription.startRealtime(
      route: plan.route,
      language: plan.mode.languageCode,
      diarize: plan.mode.diarizationEnabled,
      onTranscript: callbacks.onLiveTranscript,
      onError: callbacks.onRealtimeError
    )
  }

  private func makeSampleHandler(
    plan: DictationExecutionPlan,
    callbacks: DictationWorkflowCallbacks
  ) -> @Sendable ([Float]) -> Void {
    { [weak self] samples in
      callbacks.onSamples(samples)
      Task { @MainActor in
        await self?.sendRealtimePCM(samples, plan: plan)
      }
    }
  }

  func transcribe(
    recordingURL: URL,
    plan: DictationExecutionPlan
  ) async throws -> TranscriptionArtifact {
    if plan.transport == .realtime {
      return try await transcription.finishRealtime()
    }

    return try await transcription.transcribeBatch(
      audioURL: recordingURL,
      route: plan.route,
      language: plan.mode.languageCode,
      diarize: plan.mode.diarizationEnabled
    )
  }

  private func clearActiveSession() {
    if !activeContextWasPersisted {
      activeContextSession?.cleanupAttachments()
    }
    activePlan = nil
    activeContext = nil
    activeContextSnapshot = nil
    activeContextSession = nil
    activeContextWasPersisted = false
    activeSourceApplication = nil
    activeCallbacks = nil
  }

}

private extension DictationWorkflow {
  func sendRealtimePCM(
    _ samples: [Float],
    plan: DictationExecutionPlan
  ) async {
    guard plan.transport == .realtime else { return }
    await transcription.sendRealtimePCM(samples)
  }

  func cancelRealtimeSessions() async {
    await transcription.cancelRealtime()
  }
}
