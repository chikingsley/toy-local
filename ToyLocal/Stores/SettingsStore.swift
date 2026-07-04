import AVFoundation
import AppKit
import Foundation
import Sauce
import ServiceManagement
import SwiftUI
import ToyLocalCore

private let settingsLogger = ToyLocalLog.settings

@MainActor @Observable
final class SettingsStore {
  // MARK: - State

  var languages: [Language] = []
  var currentModifiers: Modifiers = .init(modifiers: [])
  var currentPasteLastModifiers: Modifiers = .init(modifiers: [])
  var currentAlwaysOnPasteModifiers: Modifiers = .init(modifiers: [])
  var currentAlwaysOnDumpModifiers: Modifiers = .init(modifiers: [])
  var remappingScratchpadText: String = ""
  var availableInputDevices: [AudioInputDevice] = []
  var defaultInputDeviceName: String?
  var shouldFlashModelSection = false

  // MARK: - Child Stores

  let modelDownload: ModelDownloadStore

  // MARK: - Dependencies

  private let settings: SettingsManager
  let keyEventMonitor: KeyEventMonitorClientLive
  private let transcription: TranscriptionClientLive
  private let recording: RecordingClientLive
  private let permissions: PermissionClientLive
  private let transcriptHistoryPersistence: TranscriptHistoryPersistence
  private let soundEffects: SoundEffectsClientLive

  // MARK: - Task Handles

  @ObservationIgnored private var deviceRefreshTask: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var deviceConnectionObserver: Any?
  @ObservationIgnored nonisolated(unsafe) private var deviceDisconnectionObserver: Any?
  @ObservationIgnored private var deviceUpdateTask: Task<Void, Never>?
  @ObservationIgnored var shortcutCaptureToken: KeyEventMonitorToken?
  @ObservationIgnored private var hasStarted = false

  // MARK: - Init

  init(services: ServiceContainer) {
    self.settings = services.settings
    self.keyEventMonitor = services.keyEventMonitor
    self.transcription = services.transcription
    self.recording = services.recording
    self.permissions = services.permissions
    self.transcriptHistoryPersistence = services.transcriptHistoryPersistence
    self.soundEffects = services.soundEffects
    self.modelDownload = ModelDownloadStore(services: services)
  }

  deinit {
    deviceRefreshTask?.cancel()
    deviceUpdateTask?.cancel()
    shortcutCaptureToken?.cancel()
    if let obs = deviceConnectionObserver {
      NotificationCenter.default.removeObserver(obs)
    }
    if let obs = deviceDisconnectionObserver {
      NotificationCenter.default.removeObserver(obs)
    }
  }

  // MARK: - Convenience Accessors

  var toyLocalSettings: ToyLocalSettings {
    get { settings.settings }
    set { settings.settings = newValue }
  }

  var isSettingHotKey: Bool {
    get { settings.isSettingHotKey }
    set { settings.isSettingHotKey = newValue }
  }

  var isSettingPasteLastTranscriptHotkey: Bool {
    get { settings.isSettingPasteLastTranscriptHotkey }
    set { settings.isSettingPasteLastTranscriptHotkey = newValue }
  }

  var isSettingAlwaysOnPasteHotkey: Bool {
    get { settings.isSettingAlwaysOnPasteHotkey }
    set { settings.isSettingAlwaysOnPasteHotkey = newValue }
  }

  var isSettingAlwaysOnDumpHotkey: Bool {
    get { settings.isSettingAlwaysOnDumpHotkey }
    set { settings.isSettingAlwaysOnDumpHotkey = newValue }
  }

  var isRemappingScratchpadFocused: Bool {
    get { settings.isRemappingScratchpadFocused }
    set { settings.isRemappingScratchpadFocused = newValue }
  }

  var transcriptionHistory: TranscriptionHistory {
    get { settings.transcriptionHistory }
    set { settings.transcriptionHistory = newValue }
  }

  var hotkeyPermissionState: HotkeyPermissionState {
    settings.hotkeyPermissionState
  }

  // MARK: - Lifecycle

  func start() {
    guard !hasStarted else { return }
    hasStarted = true

    loadLanguages()
    modelDownload.fetchModels()
    loadAvailableInputDevices()
    startDeviceRefresh()
    startDeviceConnectionObservers()
  }

  private func loadLanguages() {
    if let url = Bundle.main.url(forResource: "languages", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let langs = try? JSONDecoder().decode([Language].self, from: data)
    {
      languages = langs
    } else {
      settingsLogger.error("Failed to load languages JSON from bundle")
    }
  }

  // MARK: - Settings Toggles

  func toggleOpenOnLogin(_ enabled: Bool) {
    toyLocalSettings.openOnLogin = enabled
    Task.detached {
      if enabled {
        try? SMAppService.mainApp.register()
      } else {
        try? SMAppService.mainApp.unregister()
      }
    }
  }

  func togglePreventSystemSleep(_ enabled: Bool) {
    toyLocalSettings.preventSystemSleep = enabled
  }

  func setRecordingAudioBehavior(_ behavior: RecordingAudioBehavior) {
    toyLocalSettings.recordingAudioBehavior = behavior
  }

  func setRecordingInputMode(_ mode: RecordingInputMode) {
    toyLocalSettings.recordingInputMode = mode
  }

  func setSoundEffectsStyle(_ style: SoundEffectsStyle) {
    toyLocalSettings.soundEffectsStyle = style
    playSoundEffectsSample()
  }

  func playSoundEffectsSample() {
    Task {
      await soundEffects.play(.startRecording)
    }
  }

  // MARK: - Permissions

  func requestMicrophone() {
    settingsLogger.info("User requested microphone permission from settings")
    Task {
      _ = await permissions.requestMicrophone()
    }
  }

  func requestAccessibility() {
    settingsLogger.info("User requested accessibility permission from settings")
    Task {
      await permissions.requestAccessibility()
    }
  }

  func requestScreenCapture() {
    settingsLogger.info("User requested screen recording permission from settings")
    Task {
      _ = await permissions.requestScreenCapture()
    }
  }

  func openSystemAudioCaptureSettings() {
    settingsLogger.info("User opened system audio capture settings")
    Task {
      await permissions.openSystemAudioCaptureSettings()
    }
  }

  func openAutomationSettings() {
    settingsLogger.info("User opened automation settings")
    Task {
      await permissions.openAutomationSettings()
    }
  }

  // MARK: - Microphone Devices

  func loadAvailableInputDevices() {
    Task {
      let devices = await recording.getAvailableInputDevices()
      let defaultName = await recording.getDefaultInputDeviceName()
      self.availableInputDevices = devices
      self.defaultInputDeviceName = defaultName
    }
  }

  private func startDeviceRefresh() {
    deviceRefreshTask?.cancel()
    deviceRefreshTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(120))
        guard let self, NSApplication.shared.isActive else { continue }
        self.loadAvailableInputDevices()
      }
    }
  }

  private func startDeviceConnectionObservers() {
    deviceConnectionObserver = NotificationCenter.default.addObserver(
      forName: NSNotification.Name(rawValue: "AVCaptureDeviceWasConnected"),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.debounceDeviceUpdate()
      }
    }

    deviceDisconnectionObserver = NotificationCenter.default.addObserver(
      forName: NSNotification.Name(rawValue: "AVCaptureDeviceWasDisconnected"),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.debounceDeviceUpdate()
      }
    }
  }

  private func debounceDeviceUpdate() {
    deviceUpdateTask?.cancel()
    deviceUpdateTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 500_000_000)
      guard !Task.isCancelled, let self else { return }
      self.loadAvailableInputDevices()
    }
  }

  // MARK: - History Management

  func toggleSaveTranscriptionHistory(_ enabled: Bool) {
    toyLocalSettings.saveTranscriptionHistory = enabled

    if !enabled {
      let transcripts = settings.transcriptionHistory.history
      settings.transcriptionHistory.history.removeAll()
      for transcript in transcripts {
        transcriptHistoryPersistence.deleteRecord(id: transcript.id)
        transcriptHistoryPersistence.deleteAudio(for: transcript)
      }
    }
  }

  // MARK: - Word Removals/Remappings

  func addWordRemoval() {
    toyLocalSettings.wordRemovals.append(.init(pattern: ""))
  }

  func removeWordRemoval(_ id: UUID) {
    toyLocalSettings.wordRemovals.removeAll { $0.id == id }
  }

  func addWordRemapping() {
    toyLocalSettings.wordRemappings.append(.init(match: "", replacement: ""))
  }

  func removeWordRemapping(_ id: UUID) {
    toyLocalSettings.wordRemappings.removeAll { $0.id == id }
  }

  func setRemappingScratchpadFocused(_ isFocused: Bool) {
    settings.isRemappingScratchpadFocused = isFocused
  }

  // MARK: - Modifier Configuration

  func setModifierSide(_ kind: Modifier.Kind, _ side: Modifier.Side) {
    guard toyLocalSettings.hotkey.key == nil else { return }
    toyLocalSettings.hotkey.modifiers = toyLocalSettings.hotkey.modifiers.setting(kind: kind, to: side)
  }

  // MARK: - Binding Change Handler

  func settingsBindingChanged() {
    NotificationCenter.default.post(name: .updateAppMode, object: nil)
  }
}
