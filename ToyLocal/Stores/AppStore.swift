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
	@ObservationIgnored private var permissionMonitorTask: Task<Void, Never>?
	@ObservationIgnored private var modelReadinessTask: Task<Void, Never>?

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
		permissionMonitorTask?.cancel()
		modelReadinessTask?.cancel()
	}

	// MARK: - Lifecycle

	func start() {
		transcription.start()
		settings.start()
		alwaysOn.start()
		startPasteLastTranscriptMonitoring()
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
			await pasteboard.paste(text: lastTranscript)
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
