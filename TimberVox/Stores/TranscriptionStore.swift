import TimberVoxCore
import CoreGraphics
import Foundation
import SwiftUI

private let transcriptionFeatureLogger = TimberVoxLog.transcription

// MARK: - Transcription Store

@MainActor @Observable
final class TranscriptionStore {
  // MARK: - State

  var isRecording: Bool = false
  var isTranscribing: Bool = false
  var isPrewarming: Bool = false
  var textTransformState: TextTransformRunState = .idle
  var error: String?
  var recordingStartTime: Date?
  var meter: Meter = .init(averagePower: 0, peakPower: 0)
  var sourceAppBundleID: String?
  var sourceAppName: String?
  var livePartialText: String?

  // MARK: - Callbacks

  var onModelMissing: (() -> Void)?

  // MARK: - Dependencies

  let settings: SettingsManager
  let transcriptionWorkflow: TranscriptionWorkflowService
  private let contextCapture: DictationContextCaptureClientLive
  let recording: RecordingClientLive
  private let pasteboard: PasteboardClientLive
  let keyEventMonitor: KeyEventMonitorClientLive
  private let soundEffects: SoundEffectsClientLive
  private let sleepManagement: SleepManagementClientLive
  private let transcriptPersistence: TranscriptPersistenceClient
  private let transcriptHistoryPersistence: TranscriptHistoryPersistence
  let cloudBaseURL: URL

  // MARK: - Task Handles

  @ObservationIgnored private var meteringTask: Task<Void, Never>?
  @ObservationIgnored private var hotkeyMonitorTask: Task<Void, Never>?
  @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
  @ObservationIgnored private var recordingStartTask: Task<Void, Never>?
  @ObservationIgnored var realtimeSession: RealtimeDictationSession?
  @ObservationIgnored private var contextCaptureSession: DictationContextCaptureSession?
  @ObservationIgnored private var activeContextSnapshot: DictationContextSnapshot?

  // MARK: - Internal State

  var hotKeyProcessor: HotKeyProcessor

  // MARK: - Init

  init(services: ServiceContainer) {
    self.settings = services.settings
    self.transcriptionWorkflow = services.transcriptionWorkflow
    self.contextCapture = services.contextCapture
    self.recording = services.recording
    self.pasteboard = services.pasteboard
    self.keyEventMonitor = services.keyEventMonitor
    self.soundEffects = services.soundEffects
    self.sleepManagement = services.sleepManagement
    self.transcriptPersistence = services.transcriptPersistence
    self.transcriptHistoryPersistence = services.transcriptHistoryPersistence
    self.cloudBaseURL = services.cloudBaseURL
    self.hotKeyProcessor = HotKeyProcessor(hotkey: HotKey(key: nil, modifiers: [.option]))
  }

  deinit {
    meteringTask?.cancel()
    hotkeyMonitorTask?.cancel()
    transcriptionTask?.cancel()
  }

  // MARK: - Lifecycle

  func start() {
    startMetering()
    startHotKeyMonitoring()
    warmUpRecorder()
  }

  // MARK: - Metering

  private func startMetering() {
    meteringTask?.cancel()
    meteringTask = Task { [weak self] in
      guard let self else { return }
      for await meter in await self.recording.observeAudioLevel() {
        self.meter = meter
      }
    }
  }

  // MARK: - HotKey Monitoring

  private func startHotKeyMonitoring() {
    hotkeyMonitorTask?.cancel()
    hotkeyMonitorTask = Task { [weak self] in
      guard let self else { return }
      await self.runHotKeyMonitoringLoop()
    }
  }

  private func warmUpRecorder() {
    Task {
      await recording.warmUpRecorder()
    }
  }

  // MARK: - HotKey Press/Release

  func hotKeyPressed() {
    if isTranscribing {
      cancel()
    }
    startRecording()
  }

  func hotKeyReleased() {
    if isRecording {
      stopRecording()
    }
  }

  // MARK: - Recording

  func startRecording() {
    guard settings.modelBootstrapState.isModelReady else {
      onModelMissing?()
      Task { await soundEffects.play(.cancel) }
      return
    }

    textTransformState = .idle
    isRecording = true
    let startTime = Date()
    recordingStartTime = startTime
    contextCaptureSession?.cancel()
    let currentSettings = settings.settings
    if currentSettings.textTransformMode.usesTextTransform,
      currentSettings.textTransformContextOptions.capturesAnyContext
    {
      contextCaptureSession = contextCapture.startSession(startedAt: startTime)
    } else {
      contextCaptureSession = nil
    }
    activeContextSnapshot = contextCaptureSession?.currentSnapshot

    if let activeApp = NSWorkspace.shared.frontmostApplication {
      sourceAppBundleID = activeApp.bundleIdentifier
      sourceAppName = activeApp.localizedName
    }
    transcriptionFeatureLogger.notice("Recording started at \(startTime.ISO8601Format())")

    let preventSleep = settings.settings.preventSystemSleep
    recordingStartTask?.cancel()
    recordingStartTask = Task {
      await soundEffects.play(.startRecording)
      if preventSleep {
        await sleepManagement.preventSleep(reason: AppBrand.voiceRecordingActivity)
      }
      guard !Task.isCancelled else {
        await sleepManagement.allowSleep()
        transcriptionFeatureLogger.notice("Recording start cancelled before capture began")
        return
      }
      await recording.startRecording()
      guard !Task.isCancelled else { return }
      await startRealtimeSessionIfAvailable(settings: currentSettings)
    }
  }

  func stopRecording() {
    isRecording = false
    let context = makeStopRecordingContext(at: Date())
    logStopRecording(context)

    guard context.decision == .proceedToTranscription else {
      discardRecordingAfterStop(decision: context.decision)
      return
    }

    prepareForTranscription()
    startTranscriptionTask(context)
  }

  // MARK: - Cancel/Discard

  func cancel() {
    guard isRecording || isTranscribing else { return }
    isTranscribing = false
    isRecording = false
    isPrewarming = false
    textTransformState = .idle

    recordingStartTask?.cancel()
    recordingStartTask = nil
    transcriptionTask?.cancel()
    transcriptionTask = nil
    tearDownRealtimeSession()
    contextCaptureSession?.cancel()
    contextCaptureSession = nil
    activeContextSnapshot = nil

    Task {
      await sleepManagement.allowSleep()
      let url = await recording.stopRecording()
      try? FileManager.default.removeItem(at: url)
      await soundEffects.play(.cancel)
    }
  }

  func discard() {
    guard isRecording else { return }
    isRecording = false
    isPrewarming = false
    textTransformState = .idle
    recordingStartTask?.cancel()
    recordingStartTask = nil
    tearDownRealtimeSession()
    contextCaptureSession?.cancel()
    contextCaptureSession = nil
    activeContextSnapshot = nil

    Task {
      await sleepManagement.allowSleep()
      let url = await recording.stopRecording()
      try? FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Transcription Handlers

  private func handleTranscriptionResult(
    result: String,
    settingsSnapshot: TimberVoxSettings,
    audioURL: URL,
    sourceAppBundleID: String?,
    sourceAppName: String?,
    contextSnapshot: DictationContextSnapshot?
  ) {
    isPrewarming = false

    if ForceQuitCommandDetector.matches(result) {
      isTranscribing = false
      transcriptionFeatureLogger.fault("Force quit voice command recognized; terminating \(AppBrand.name).")
      Task {
        try? FileManager.default.removeItem(at: audioURL)
        NSApp.terminate(nil)
      }
      return
    }

    guard !result.isEmpty else {
      isTranscribing = false
      isPrewarming = false
      textTransformState = .skipped(reason: "No speech detected in the recording.")
      error = "No speech detected in the recording."
      try? FileManager.default.removeItem(at: audioURL)
      return
    }

    let timberVoxSettings = settingsSnapshot
    let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

    transcriptionFeatureLogger.info("Raw transcription: '\(result)'")

    let modifiedResult = applyTranscriptModifications(result, settings: timberVoxSettings)

    guard !modifiedResult.isEmpty else {
      isTranscribing = false
      textTransformState = .skipped(reason: "No text remained after transcript modifications.")
      error = "No text remained after transcript modifications."
      try? FileManager.default.removeItem(at: audioURL)
      return
    }

    Task {
      do {
        let transformResult = try await applyTextTransformIfNeeded(
          to: modifiedResult,
          settings: timberVoxSettings,
          contextSnapshot: contextSnapshot
        )
        textTransformState = transformResult.state
        await finalizeRecordingAndStoreTranscript(
          TranscriptFinalizationPayload(
            finalText: transformResult.text,
            rawText: modifiedResult,
            modeName: timberVoxSettings.textTransformMode.displayName,
            duration: duration,
            sourceAppBundleID: sourceAppBundleID,
            sourceAppName: sourceAppName,
            audioURL: audioURL,
            contextSnapshot: contextSnapshot
          )
        )
      } catch {
        transcriptionFeatureLogger.error("Text transform failed: \(error.localizedDescription)")
        textTransformState = .failed(
          mode: timberVoxSettings.textTransformMode,
          modelID: timberVoxSettings.textTransformModel,
          inputCharacterCount: modifiedResult.count,
          message: error.localizedDescription
        )
        handleTranscriptionError(error: error)
      }
    }
  }

  private func finalizeRecordingAndStoreTranscript(_ payload: TranscriptFinalizationPayload) async {
    isTranscribing = false
    isPrewarming = false
    let timberVoxSettings = settings.settings

    if timberVoxSettings.saveTranscriptionHistory {
      do {
        let transcript = try await transcriptPersistence.save(
          payload.finalText,
          payload.audioURL,
          payload.duration,
          payload.sourceAppBundleID,
          payload.sourceAppName,
          payload.contextSnapshot
        )

        transcriptHistoryPersistence.appendSavedTranscript(
          transcript,
          rawText: payload.rawText,
          finalText: payload.finalText,
          modeName: payload.modeName,
          settingsSnapshot: timberVoxSettings
        )
      } catch {
        transcriptionFeatureLogger.error("Failed to save transcript: \(error.localizedDescription)")
      }
    } else {
      try? FileManager.default.removeItem(at: payload.audioURL)
    }

    guard timberVoxSettings.autoPasteResult else {
      await pasteboard.copy(text: payload.finalText)
      transcriptionFeatureLogger.notice("Auto paste disabled; transcript copied to clipboard only.")
      return
    }

    let didPaste = await pasteboard.paste(text: payload.finalText)
    if didPaste {
      transcriptionFeatureLogger.notice("Paste completed for transcribed result (\(payload.finalText.count) chars).")
      await soundEffects.play(.pasteTranscript)
    } else {
      transcriptionFeatureLogger.notice("Paste did not complete; transcript remains in clipboard.")
    }
  }
}

private extension TranscriptionStore {
  func handleTranscriptionError(error: Error) {
    isTranscribing = false
    isPrewarming = false
    self.error = error.localizedDescription
  }

  func makeStopRecordingContext(at stopTime: Date) -> StopRecordingContext {
    let settingsSnapshot = settings.settings
    let startTime = recordingStartTime
    let duration = startTime.map { stopTime.timeIntervalSince($0) } ?? 0
    let decision = RecordingDecisionEngine.decide(
      .init(
        hotkey: settingsSnapshot.hotkey,
        minimumKeyTime: settingsSnapshot.minimumKeyTime,
        recordingStartTime: recordingStartTime,
        currentTime: stopTime
      )
    )
    let contextSnapshot: DictationContextSnapshot?
    if decision == .proceedToTranscription {
      contextSnapshot = contextCaptureSession?.finish(endedAt: stopTime)
    } else {
      contextCaptureSession?.cancel()
      contextSnapshot = nil
    }
    contextCaptureSession = nil
    activeContextSnapshot = contextSnapshot

    return StopRecordingContext(
      stopTime: stopTime,
      startTime: startTime,
      duration: duration,
      decision: decision,
      settingsSnapshot: settingsSnapshot,
      sourceAppBundleID: sourceAppBundleID,
      sourceAppName: sourceAppName,
      contextSnapshot: contextSnapshot
    )
  }

  func logStopRecording(_ context: StopRecordingContext) {
    let startStamp = context.startTime?.ISO8601Format() ?? "nil"
    let stopStamp = context.stopTime.ISO8601Format()
    let duration = String(format: "%.3f", context.duration)
    transcriptionFeatureLogger.notice(
      "Recording stopped duration=\(duration)s start=\(startStamp) stop=\(stopStamp) decision=\(String(describing: context.decision))"
    )
  }

  func discardRecordingAfterStop(decision: RecordingDecisionEngine.Decision) {
    transcriptionFeatureLogger.notice("Discarding short recording per decision \(String(describing: decision))")
    Task {
      let url = await recording.stopRecording()
      try? FileManager.default.removeItem(at: url)
    }
  }

  func prepareForTranscription() {
    isTranscribing = true
    error = nil
    isPrewarming = true
    textTransformState = .idle
  }

  func startTranscriptionTask(_ context: StopRecordingContext) {
    let workflow = transcriptionWorkflowRequest(
      for: context.settingsSnapshot,
      contextSnapshot: context.contextSnapshot
    )
    let settingsSnapshot = context.settingsSnapshot
    let capturedSourceAppBundleID = context.sourceAppBundleID
    let capturedSourceAppName = context.sourceAppName
    let capturedContextSnapshot = context.contextSnapshot

    transcriptionTask?.cancel()
    transcriptionTask = Task { [weak self] in
      guard let self else { return }
      await self.sleepManagement.allowSleep()

      let realtimeSession = self.takeRealtimeSession()
      do {
        let capturedURL = await self.recording.stopRecording()
        await self.soundEffects.play(.stopRecording)
        let result = try await self.resolveTranscript(
          capturedURL: capturedURL,
          workflow: workflow,
          realtimeSession: realtimeSession
        )
        self.livePartialText = nil

        transcriptionFeatureLogger.notice("Transcribed audio to text length \(result.count)")
        if let capturedContextSnapshot {
          let clipboardItemCount = capturedContextSnapshot.clipboardTextItems.count
          let attachmentCount = capturedContextSnapshot.attachments.count
          transcriptionFeatureLogger.info(
            "Captured dictation context clipboardItems=\(clipboardItemCount) attachments=\(attachmentCount)"
          )
        }
        self.handleTranscriptionResult(
          result: result,
          settingsSnapshot: settingsSnapshot,
          audioURL: capturedURL,
          sourceAppBundleID: capturedSourceAppBundleID,
          sourceAppName: capturedSourceAppName,
          contextSnapshot: capturedContextSnapshot
        )
      } catch {
        realtimeSession?.cancel()
        self.livePartialText = nil
        transcriptionFeatureLogger.error("Transcription failed: \(error.localizedDescription)")
        self.handleTranscriptionError(error: error)
      }
    }
  }

}
