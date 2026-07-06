import AppKit
import TimberVoxCore
import Foundation
import SwiftUI

@MainActor @Observable
final class AppStore {
  // MARK: - State

  var activeTab: ActiveTab = .home
  var microphonePermission: PermissionStatus = .notDetermined
  var accessibilityPermission: PermissionStatus = .notDetermined
  var screenCapturePermission: PermissionStatus = .notDetermined

  // MARK: - Child Stores

  let transcription: TranscriptionStore
  let settings: SettingsStore
  let history: HistoryStore
  let alwaysOn: AlwaysOnStore
  var onRequiredPermissionsMissing: (() -> Void)?

  // MARK: - Dependencies

  private let settingsManager: SettingsManager
  private let transcriptStore: TranscriptStore
  private let keyEventMonitor: KeyEventMonitorClientLive
  private let pasteboard: PasteboardClientLive
  private let transcriptionClient: TranscriptionClientLive
  private let permissions: PermissionClientLive

  // MARK: - Task Handles

  @ObservationIgnored private var pasteLastTranscriptTask: Task<Void, Never>?
  @ObservationIgnored private var typingSessionMonitorTask: Task<Void, Never>?
  @ObservationIgnored private var typingSessionEventPumpTask: Task<Void, Never>?
  @ObservationIgnored private var typingSessionEventContinuation: AsyncStream<KeyEvent>.Continuation?
  @ObservationIgnored private var permissionMonitorTask: Task<Void, Never>?
  @ObservationIgnored private var modelReadinessTask: Task<Void, Never>?
  @ObservationIgnored private var selectedModelPrewarmTask: Task<Void, Never>?
  @ObservationIgnored private var typingSessionTracker = TypingSessionTracker()
  @ObservationIgnored private var lastObservedAppBundleID: String?
  @ObservationIgnored private var hasStarted = false

  // MARK: - Init

  init(services: ServiceContainer) {
    self.settingsManager = services.settings
    self.transcriptStore = services.transcriptStore
    self.keyEventMonitor = services.keyEventMonitor
    self.pasteboard = services.pasteboard
    self.transcriptionClient = services.transcription
    self.permissions = services.permissions

    self.transcription = TranscriptionStore(services: services)
    self.settings = SettingsStore(services: services)
    self.history = HistoryStore(services: services)
    self.alwaysOn = AlwaysOnStore(services: services)
    self.alwaysOn.onModelStateChanged = { [weak self] in
      self?.settings.modelDownload.fetchModels()
    }

    // Wire up child callbacks
    transcription.onModelMissing = { [weak self] in
      self?.handleModelMissing()
    }
  }

  deinit {
    pasteLastTranscriptTask?.cancel()
    typingSessionMonitorTask?.cancel()
    typingSessionEventPumpTask?.cancel()
    typingSessionEventContinuation?.finish()
    permissionMonitorTask?.cancel()
    modelReadinessTask?.cancel()
    selectedModelPrewarmTask?.cancel()
  }

  // MARK: - Lifecycle

  func start() {
    guard !hasStarted else { return }
    hasStarted = true

    transcription.start()
    settings.start()
    alwaysOn.start()
    startPasteLastTranscriptMonitoring()
    startTypingSessionMonitoring()
    ensureSelectedModelReadiness()
    startPermissionMonitoring()
  }

  // MARK: - Tab Navigation

  func setActiveTab(_ tab: ActiveTab) {
    activeTab = tab
  }

  // MARK: - Permissions

  func checkPermissions() {
    Task {
      async let mic = permissions.microphoneStatus()
      async let acc = permissions.accessibilityStatus()
      async let screen = permissions.screenCaptureStatus()
      let (micResult, accResult, screenResult) = await (mic, acc, screen)
      microphonePermission = micResult
      accessibilityPermission = accResult
      screenCapturePermission = screenResult
      if micResult != .granted || accResult != .granted || screenResult != .granted {
        onRequiredPermissionsMissing?()
      }
    }
  }

  func requestMicrophone() {
    Task {
      _ = await permissions.requestMicrophone()
      checkPermissions()
    }
  }

  func requestAccessibility() {
    Task {
      await permissions.requestAccessibility()
      for _ in 0..<10 {
        try? await Task.sleep(for: .seconds(1))
        checkPermissions()
      }
    }
  }

  func requestScreenCapture() {
    Task {
      _ = await permissions.requestScreenCapture()
      checkPermissions()
    }
  }

  func openSystemAudioCaptureSettings() {
    Task {
      await permissions.openSystemAudioCaptureSettings()
    }
  }

  func openAutomationSettings() {
    Task {
      await permissions.openAutomationSettings()
    }
  }

  // MARK: - Private

  private func handleModelMissing() {
    TimberVoxLog.app.notice("Model missing - activating app and switching to settings")
    activeTab = .models
    settings.shouldFlashModelSection = true
    NSApplication.shared.activate(ignoringOtherApps: true)

    Task {
      try? await Task.sleep(for: .seconds(2))
      settings.shouldFlashModelSection = false
    }
  }

  private func startPasteLastTranscriptMonitoring() {
    pasteLastTranscriptTask?.cancel()
    pasteLastTranscriptTask = Task { [weak self] in
      guard let self else { return }

      let token = self.keyEventMonitor.handleKeyEvent { [weak self] keyEvent in
        guard let self else { return false }

        return MainActor.assumeIsolated {
          if self.settingsManager.isSettingAnyHotKey { return false }

          guard let pasteHotkey = self.settingsManager.settings.pasteLastTranscriptHotkey,
            let key = keyEvent.key,
            key == pasteHotkey.key,
            keyEvent.modifiers.matchesExactly(pasteHotkey.modifiers)
          else {
            return false
          }

          self.pasteLastTranscript()
          return true
        }
      }

      defer { token.cancel() }

      await withTaskCancellationHandler {
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(60))
        }
      } onCancel: {
        token.cancel()
      }
    }
  }

  private func startTypingSessionMonitoring() {
    typingSessionMonitorTask?.cancel()
    typingSessionEventPumpTask?.cancel()
    typingSessionEventContinuation?.finish()
    typingSessionEventContinuation = nil

    var continuation: AsyncStream<KeyEvent>.Continuation?
    let stream = AsyncStream<KeyEvent>(bufferingPolicy: .bufferingNewest(512)) { createdContinuation in
      continuation = createdContinuation
    }
    guard let continuation else { return }
    typingSessionEventContinuation = continuation

    typingSessionEventPumpTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await keyEvent in stream {
        self.handleTypingSessionKeyEvent(keyEvent)
      }
    }

    typingSessionMonitorTask = Task { [weak self] in
      guard let self else { return }

      let token = self.keyEventMonitor.handleKeyEvent { keyEvent in
        continuation.yield(keyEvent)
        return false
      }

      defer {
        token.cancel()
        continuation.finish()
      }

      await withTaskCancellationHandler {
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(60))
        }
      } onCancel: {
        token.cancel()
        continuation.finish()
      }
    }
  }

  private func handleTypingSessionKeyEvent(_ keyEvent: KeyEvent) {
    let appBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

    if appBundleID != lastObservedAppBundleID {
      let appChangeEvents = typingSessionTracker.appDidChange(to: appBundleID)
      logTypingSessionEvents(appChangeEvents, fallbackAppBundleID: appBundleID)
      lastObservedAppBundleID = appBundleID
    }

    let events = typingSessionTracker.process(keyEvent: keyEvent, appBundleID: appBundleID)
    logTypingSessionEvents(events, fallbackAppBundleID: appBundleID)
  }

  private func logTypingSessionEvents(
    _ events: [TypingSessionTracker.Event],
    fallbackAppBundleID: String?
  ) {
    guard !events.isEmpty else { return }

    for event in events {
      switch event {
      case .trackingStarted(let appBundleID):
        TimberVoxLog.keyEvent.notice(
          "Typing session started app=\(appBundleID ?? fallbackAppBundleID ?? "unknown")"
        )
      case .textUpdated(let text, let appBundleID):
        TimberVoxLog.keyEvent.info(
          "Typing session updated chars=\(text.count) app=\(appBundleID ?? fallbackAppBundleID ?? "unknown")"
        )
      case .submitted(let text, let appBundleID):
        TimberVoxLog.keyEvent.notice(
          "Typing session submitted chars=\(text.count) app=\(appBundleID ?? fallbackAppBundleID ?? "unknown") text=\(text, privacy: .private)"
        )
      case .canceled(let text, let appBundleID):
        TimberVoxLog.keyEvent.notice(
          "Typing session canceled chars=\(text.count) app=\(appBundleID ?? fallbackAppBundleID ?? "unknown") text=\(text, privacy: .private)"
        )
      }
    }
  }

  private func ensureSelectedModelReadiness() {
    modelReadinessTask?.cancel()
    modelReadinessTask = Task { [weak self] in
      guard let self else { return }
      let selectedModel = self.settingsManager.settings.selectedModel
      guard !selectedModel.isEmpty else { return }

      let isReady = await self.transcriptionClient.isModelDownloaded(selectedModel)
      self.settingsManager.modelBootstrapState.modelIdentifier = selectedModel
      if self.settingsManager.modelBootstrapState.modelDisplayName?.isEmpty ?? true {
        self.settingsManager.modelBootstrapState.modelDisplayName = selectedModel
      }
      self.settingsManager.modelBootstrapState.isModelReady = isReady
      if isReady {
        self.settingsManager.modelBootstrapState.lastError = nil
        self.settingsManager.modelBootstrapState.progress = 1
        self.prewarmSelectedModelIfNeeded(selectedModel)
      } else {
        self.settingsManager.modelBootstrapState.progress = 0
        self.selectedModelPrewarmTask?.cancel()
        self.selectedModelPrewarmTask = nil
      }
    }
  }

  private func prewarmSelectedModelIfNeeded(_ modelID: String) {
    selectedModelPrewarmTask?.cancel()
    selectedModelPrewarmTask = nil

    guard settingsManager.settings.localModelPrewarmEnabled else {
      TimberVoxLog.transcription.info("Skipping selected model prewarm because local model prewarm is disabled.")
      return
    }
    guard let model = TranscriptionModelCatalog.model(id: modelID) else {
      TimberVoxLog.transcription.notice("Skipping selected model prewarm; model is not in catalog: \(modelID)")
      return
    }
    guard model.runtime == .local,
      model.provider == .fluidAudio,
      model.assetRole == .primaryASR,
      model.capabilities.fileInput,
      model.capabilities.batch
    else {
      TimberVoxLog.transcription.info("Skipping selected model prewarm; model is not local batch ASR: \(modelID)")
      return
    }

    selectedModelPrewarmTask = Task { [weak self] in
      guard let self else { return }
      TimberVoxLog.transcription.notice("Prewarming selected local ASR model=\(modelID)")
      do {
        try await self.transcriptionClient.downloadAndLoadModel(variant: modelID) { _ in }
        guard !Task.isCancelled else { return }
        TimberVoxLog.transcription.notice("Selected local ASR model is warm model=\(modelID)")
      } catch {
        guard !Task.isCancelled else { return }
        TimberVoxLog.transcription.error("Selected local ASR prewarm failed model=\(modelID) error=\(error.localizedDescription)")
      }
    }
  }

  private func startPermissionMonitoring() {
    permissionMonitorTask?.cancel()
    permissionMonitorTask = Task { [weak self] in
      guard let self else { return }
      self.checkPermissions()

      for await activation in self.permissions.observeAppActivation() {
        if case .didBecomeActive = activation {
          self.checkPermissions()
        }
      }
    }
  }
}

extension AppStore {
  var lastTranscriptText: String? {
    guard let record = try? transcriptStore.records(limit: 1).first else { return nil }
    return record.finalText
  }

  func pasteLastTranscript() {
    guard let lastTranscript = lastTranscriptText else {
      return
    }
    Task {
      _ = await pasteboard.paste(text: lastTranscript)
    }
  }
}
