import AppKit
import Foundation
import ToyLocalCore
import SwiftUI

enum ActiveTab: Equatable {
	case settings
	case remappings
	case history
	case about
}

@MainActor @Observable
final class AppStore {
	// MARK: - State

	var activeTab: ActiveTab = .settings
	var microphonePermission: PermissionStatus = .notDetermined
	var accessibilityPermission: PermissionStatus = .notDetermined
	var inputMonitoringPermission: PermissionStatus = .notDetermined

	// MARK: - Child Stores

	let transcription: TranscriptionStore
	let settings: SettingsStore
	let history: HistoryStore
	let alwaysOn: AlwaysOnStore

	// MARK: - Dependencies

	private let settingsManager: SettingsManager
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
	@ObservationIgnored private var typingSessionTracker = TypingSessionTracker()
	@ObservationIgnored private var lastObservedAppBundleID: String?
	@ObservationIgnored private var hasStarted = false

	// MARK: - Init

	init(services: ServiceContainer) {
		self.settingsManager = services.settings
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
		history.onNavigateToSettings = { [weak self] in
			self?.activeTab = .settings
		}
	}

	deinit {
		pasteLastTranscriptTask?.cancel()
		typingSessionMonitorTask?.cancel()
		typingSessionEventPumpTask?.cancel()
		typingSessionEventContinuation?.finish()
		permissionMonitorTask?.cancel()
		modelReadinessTask?.cancel()
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

	// MARK: - Paste Last Transcript

	func pasteLastTranscript() {
		guard let lastTranscript = settingsManager.transcriptionHistory.history.first?.text else {
			return
		}
		Task {
			_ = await pasteboard.paste(text: lastTranscript)
		}
	}

	// MARK: - Permissions

	func checkPermissions() {
		Task {
			async let mic = permissions.microphoneStatus()
			async let acc = permissions.accessibilityStatus()
			async let input = permissions.inputMonitoringStatus()
			let (micResult, accResult, inputResult) = await (mic, acc, input)
			microphonePermission = micResult
			accessibilityPermission = accResult
			inputMonitoringPermission = inputResult
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

	func requestInputMonitoring() {
		Task {
			_ = await permissions.requestInputMonitoring()
			for _ in 0..<10 {
				try? await Task.sleep(for: .seconds(1))
				checkPermissions()
			}
		}
	}

	// MARK: - Private

	private func handleModelMissing() {
		ToyLocalLog.app.notice("Model missing - activating app and switching to settings")
		activeTab = .settings
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
					if self.settingsManager.isSettingPasteLastTranscriptHotkey { return false }

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
				ToyLocalLog.keyEvent.notice(
					"Typing session started app=\(appBundleID ?? fallbackAppBundleID ?? "unknown")"
				)
			case .textUpdated(let text, let appBundleID):
				ToyLocalLog.keyEvent.info(
					"Typing session updated chars=\(text.count) app=\(appBundleID ?? fallbackAppBundleID ?? "unknown")"
				)
			case .submitted(let text, let appBundleID):
				ToyLocalLog.keyEvent.notice(
					"Typing session submitted chars=\(text.count) app=\(appBundleID ?? fallbackAppBundleID ?? "unknown") text=\(text, privacy: .private)"
				)
			case .canceled(let text, let appBundleID):
				ToyLocalLog.keyEvent.notice(
					"Typing session canceled chars=\(text.count) app=\(appBundleID ?? fallbackAppBundleID ?? "unknown") text=\(text, privacy: .private)"
				)
			}
		}
	}

	private func ensureSelectedModelReadiness() {
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
			} else {
				self.settingsManager.modelBootstrapState.progress = 0
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
