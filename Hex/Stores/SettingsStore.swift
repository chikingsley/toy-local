import AVFoundation
import AppKit
import Foundation
import HexCore
import Sauce
import ServiceManagement
import SwiftUI

private let settingsLogger = HexLog.settings

@MainActor @Observable
final class SettingsStore {
	// MARK: - State

	var languages: [Language] = []
	var currentModifiers: Modifiers = .init(modifiers: [])
	var currentPasteLastModifiers: Modifiers = .init(modifiers: [])
	var remappingScratchpadText: String = ""
	var availableInputDevices: [AudioInputDevice] = []
	var defaultInputDeviceName: String?
	var shouldFlashModelSection = false

	// MARK: - Child Stores

	let modelDownload: ModelDownloadStore

	// MARK: - Dependencies

	private let settings: SettingsManager
	private let keyEventMonitor: KeyEventMonitorClientLive
	private let transcription: TranscriptionClientLive
	private let recording: RecordingClientLive
	private let permissions: PermissionClientLive

	// MARK: - Task Handles

	nonisolated(unsafe) private var keyEventTask: Task<Void, Never>?
	nonisolated(unsafe) private var deviceRefreshTask: Task<Void, Never>?
	nonisolated(unsafe) private var deviceConnectionObserver: Any?
	nonisolated(unsafe) private var deviceDisconnectionObserver: Any?
	nonisolated(unsafe) private var deviceUpdateTask: Task<Void, Never>?

	// MARK: - Init

	init(services: ServiceContainer) {
		self.settings = services.settings
		self.keyEventMonitor = services.keyEventMonitor
		self.transcription = services.transcription
		self.recording = services.recording
		self.permissions = services.permissions
		self.modelDownload = ModelDownloadStore(services: services)
	}

	deinit {
		keyEventTask?.cancel()
		deviceRefreshTask?.cancel()
		deviceUpdateTask?.cancel()
		if let obs = deviceConnectionObserver {
			NotificationCenter.default.removeObserver(obs)
		}
		if let obs = deviceDisconnectionObserver {
			NotificationCenter.default.removeObserver(obs)
		}
	}

	// MARK: - Convenience Accessors

	var hexSettings: HexSettings {
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
		loadLanguages()
		modelDownload.fetchModels()
		loadAvailableInputDevices()
		startDeviceRefresh()
		startDeviceConnectionObservers()
		startKeyEventListening()
	}

	// MARK: - Language Loading

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

	// MARK: - Key Event Listening

	private func startKeyEventListening() {
		keyEventTask?.cancel()
		keyEventTask = Task { [weak self] in
			guard let self else { return }
			do {
				for try await keyEvent in self.keyEventMonitor.listenForKeyPress() {
					self.handleKeyEvent(keyEvent)
				}
			} catch {
				// Stream ended or was cancelled
			}
		}
	}

	// MARK: - Hotkey Setting

	func startSettingHotKey() {
		settings.isSettingHotKey = true
	}

	func startSettingPasteLastTranscriptHotkey() {
		settings.isSettingPasteLastTranscriptHotkey = true
		currentPasteLastModifiers = .init(modifiers: [])
	}

	func clearPasteLastTranscriptHotkey() {
		hexSettings.pasteLastTranscriptHotkey = nil
	}

	func handleKeyEvent(_ keyEvent: KeyEvent) {
		// Handle paste last transcript hotkey setting
		if settings.isSettingPasteLastTranscriptHotkey {
			if keyEvent.key == .escape {
				settings.isSettingPasteLastTranscriptHotkey = false
				currentPasteLastModifiers = []
				return
			}

			currentPasteLastModifiers = keyEvent.modifiers.union(currentPasteLastModifiers)
			let mods = currentPasteLastModifiers
			if let key = keyEvent.key {
				guard !mods.isEmpty else { return }
				hexSettings.pasteLastTranscriptHotkey = HotKey(key: key, modifiers: mods.erasingSides())
				settings.isSettingPasteLastTranscriptHotkey = false
				currentPasteLastModifiers = []
			}
			return
		}

		// Handle main recording hotkey setting
		guard settings.isSettingHotKey else { return }

		if keyEvent.key == .escape {
			settings.isSettingHotKey = false
			currentModifiers = []
			return
		}

		currentModifiers = keyEvent.modifiers.union(currentModifiers)
		let mods = currentModifiers
		if let key = keyEvent.key {
			hexSettings.hotkey.key = key
			hexSettings.hotkey.modifiers = mods.erasingSides()
			settings.isSettingHotKey = false
			currentModifiers = []
		} else if keyEvent.modifiers.isEmpty {
			hexSettings.hotkey.key = nil
			hexSettings.hotkey.modifiers = mods.erasingSides()
			settings.isSettingHotKey = false
			currentModifiers = []
		}
	}

	// MARK: - Settings Toggles

	func toggleOpenOnLogin(_ enabled: Bool) {
		hexSettings.openOnLogin = enabled
		Task.detached {
			if enabled {
				try? SMAppService.mainApp.register()
			} else {
				try? SMAppService.mainApp.unregister()
			}
		}
	}

	func togglePreventSystemSleep(_ enabled: Bool) {
		hexSettings.preventSystemSleep = enabled
	}

	func setRecordingAudioBehavior(_ behavior: RecordingAudioBehavior) {
		hexSettings.recordingAudioBehavior = behavior
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

	func requestInputMonitoring() {
		settingsLogger.info("User requested input monitoring permission from settings")
		Task {
			_ = await permissions.requestInputMonitoring()
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
			self?.debounceDeviceUpdate()
		}

		deviceDisconnectionObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name(rawValue: "AVCaptureDeviceWasDisconnected"),
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.debounceDeviceUpdate()
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
		hexSettings.saveTranscriptionHistory = enabled

		if !enabled {
			let transcripts = settings.transcriptionHistory.history
			settings.transcriptionHistory.history.removeAll()

			Task.detached {
				for transcript in transcripts {
					try? FileManager.default.removeItem(at: transcript.audioPath)
				}
			}
		}
	}

	// MARK: - Word Removals/Remappings

	func addWordRemoval() {
		hexSettings.wordRemovals.append(.init(pattern: ""))
	}

	func removeWordRemoval(_ id: UUID) {
		hexSettings.wordRemovals.removeAll { $0.id == id }
	}

	func addWordRemapping() {
		hexSettings.wordRemappings.append(.init(match: "", replacement: ""))
	}

	func removeWordRemapping(_ id: UUID) {
		hexSettings.wordRemappings.removeAll { $0.id == id }
	}

	func setRemappingScratchpadFocused(_ isFocused: Bool) {
		settings.isRemappingScratchpadFocused = isFocused
	}

	// MARK: - Modifier Configuration

	func setModifierSide(_ kind: Modifier.Kind, _ side: Modifier.Side) {
		guard hexSettings.hotkey.key == nil else { return }
		hexSettings.hotkey.modifiers = hexSettings.hotkey.modifiers.setting(kind: kind, to: side)
	}

	// MARK: - Binding Change Handler

	func settingsBindingChanged() {
		NotificationCenter.default.post(name: .updateAppMode, object: nil)
	}
}
