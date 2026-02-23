import CoreGraphics
import Foundation
import HexCore
import SwiftUI
import WhisperKit

private let transcriptionFeatureLogger = HexLog.transcription

// MARK: - Force Quit Command

private enum ForceQuitCommandDetector {
	static func matches(_ text: String) -> Bool {
		let normalized = normalize(text)
		return normalized == "force quit hex now" || normalized == "force quit hex"
	}

	private static func normalize(_ text: String) -> String {
		text
			.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
			.components(separatedBy: CharacterSet.alphanumerics.inverted)
			.filter { !$0.isEmpty }
			.joined(separator: " ")
	}
}

// MARK: - Transcription Store

@MainActor @Observable
final class TranscriptionStore {
	// MARK: - State

	var isRecording: Bool = false
	var isTranscribing: Bool = false
	var isPrewarming: Bool = false
	var error: String?
	var recordingStartTime: Date?
	var meter: Meter = .init(averagePower: 0, peakPower: 0)
	var sourceAppBundleID: String?
	var sourceAppName: String?

	// MARK: - Callbacks

	var onModelMissing: (() -> Void)?

	// MARK: - Dependencies

	private let settings: SettingsManager
	private let transcription: TranscriptionClientLive
	private let recording: RecordingClientLive
	private let pasteboard: PasteboardClientLive
	private let keyEventMonitor: KeyEventMonitorClientLive
	private let soundEffects: SoundEffectsClientLive
	private let sleepManagement: SleepManagementClientLive
	private let transcriptPersistence: TranscriptPersistenceClient

	// MARK: - Task Handles

	nonisolated(unsafe) private var meteringTask: Task<Void, Never>?
	nonisolated(unsafe) private var hotkeyMonitorTask: Task<Void, Never>?
	nonisolated(unsafe) private var transcriptionTask: Task<Void, Never>?

	// MARK: - Internal State

	private var hotKeyProcessor: HotKeyProcessor

	// MARK: - Init

	init(services: ServiceContainer) {
		self.settings = services.settings
		self.transcription = services.transcription
		self.recording = services.recording
		self.pasteboard = services.pasteboard
		self.keyEventMonitor = services.keyEventMonitor
		self.soundEffects = services.soundEffects
		self.sleepManagement = services.sleepManagement
		self.transcriptPersistence = services.transcriptPersistence
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

			let token = self.keyEventMonitor.handleInputEvent { [weak self] inputEvent in
				guard let self else { return false }

				return MainActor.assumeIsolated {
					// Skip if always-on mode is active
					if self.settings.settings.alwaysOnEnabled { return false }
					// Skip if setting a hotkey
					if self.settings.isSettingHotKey { return false }

					// Keep processor in sync
					self.hotKeyProcessor.hotkey = self.settings.settings.hotkey
					self.hotKeyProcessor.useDoubleTapOnly = self.settings.settings.useDoubleTapOnly
					self.hotKeyProcessor.minimumKeyTime = self.settings.settings.minimumKeyTime

					switch inputEvent {
					case .keyboard(let keyEvent):
						if keyEvent.key == .escape, keyEvent.modifiers.isEmpty,
						   self.hotKeyProcessor.state == .idle {
							Task { @MainActor in self.cancel() }
							return false
						}

						switch self.hotKeyProcessor.process(keyEvent: keyEvent) {
						case .startRecording:
							if self.hotKeyProcessor.state == .doubleTapLock {
								Task { @MainActor in self.startRecording() }
							} else {
								Task { @MainActor in self.hotKeyPressed() }
							}
							return self.settings.settings.useDoubleTapOnly || keyEvent.key != nil

						case .stopRecording:
							Task { @MainActor in self.hotKeyReleased() }
							return false

						case .cancel:
							Task { @MainActor in self.cancel() }
							return true

						case .discard:
							Task { @MainActor in self.discard() }
							return false

						case .none:
							if let pressedKey = keyEvent.key,
							   pressedKey == self.hotKeyProcessor.hotkey.key,
							   keyEvent.modifiers == self.hotKeyProcessor.hotkey.modifiers {
								return true
							}
							return false
						}

					case .mouseClick:
						switch self.hotKeyProcessor.processMouseClick() {
						case .cancel:
							Task { @MainActor in self.cancel() }
							return false
						case .discard:
							Task { @MainActor in self.discard() }
							return false
						case .startRecording, .stopRecording, .none:
							return false
						}
					}
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

		isRecording = true
		let startTime = Date()
		recordingStartTime = startTime

		if let activeApp = NSWorkspace.shared.frontmostApplication {
			sourceAppBundleID = activeApp.bundleIdentifier
			sourceAppName = activeApp.localizedName
		}
		transcriptionFeatureLogger.notice("Recording started at \(startTime.ISO8601Format())")

		let preventSleep = settings.settings.preventSystemSleep
		Task {
			await soundEffects.play(.startRecording)
			if preventSleep {
				await sleepManagement.preventSleep(reason: "Hex Voice Recording")
			}
			await recording.startRecording()
		}
	}

	func stopRecording() {
		isRecording = false

		let stopTime = Date()
		let startTime = recordingStartTime
		let duration = startTime.map { stopTime.timeIntervalSince($0) } ?? 0

		let hexSettings = settings.settings
		let decision = RecordingDecisionEngine.decide(
			.init(
				hotkey: hexSettings.hotkey,
				minimumKeyTime: hexSettings.minimumKeyTime,
				recordingStartTime: recordingStartTime,
				currentTime: stopTime
			)
		)

		let startStamp = startTime?.ISO8601Format() ?? "nil"
		let stopStamp = stopTime.ISO8601Format()
		transcriptionFeatureLogger.notice(
			"Recording stopped duration=\(String(format: "%.3f", duration))s start=\(startStamp) stop=\(stopStamp) decision=\(String(describing: decision))"
		)

		guard decision == .proceedToTranscription else {
			transcriptionFeatureLogger.notice("Discarding short recording per decision \(String(describing: decision))")
			Task {
				let url = await recording.stopRecording()
				try? FileManager.default.removeItem(at: url)
			}
			return
		}

		isTranscribing = true
		error = nil
		isPrewarming = true

		let model = hexSettings.selectedModel
		let language = hexSettings.outputLanguage
		let capturedSourceAppBundleID = sourceAppBundleID
		let capturedSourceAppName = sourceAppName

		transcriptionTask?.cancel()
		transcriptionTask = Task { [weak self] in
			guard let self else { return }
			await self.sleepManagement.allowSleep()

			do {
				await self.soundEffects.play(.stopRecording)
				let capturedURL = await self.recording.stopRecording()

				let decodeOptions = DecodingOptions(
					language: language,
					detectLanguage: language == nil,
					chunkingStrategy: .vad
				)

				let result = try await self.transcription.transcribe(
					url: capturedURL,
					model: model,
					options: decodeOptions
				) { _ in }

				transcriptionFeatureLogger.notice("Transcribed audio to text length \(result.count)")
				self.handleTranscriptionResult(
					result: result,
					audioURL: capturedURL,
					sourceAppBundleID: capturedSourceAppBundleID,
					sourceAppName: capturedSourceAppName
				)
			} catch {
				transcriptionFeatureLogger.error("Transcription failed: \(error.localizedDescription)")
				self.handleTranscriptionError(error: error)
			}
		}
	}

	// MARK: - Cancel/Discard

	func cancel() {
		guard isRecording || isTranscribing else { return }
		isTranscribing = false
		isRecording = false
		isPrewarming = false

		transcriptionTask?.cancel()
		transcriptionTask = nil

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

		Task {
			await sleepManagement.allowSleep()
			let url = await recording.stopRecording()
			try? FileManager.default.removeItem(at: url)
		}
	}

	// MARK: - Transcription Handlers

	private func handleTranscriptionResult(
		result: String,
		audioURL: URL,
		sourceAppBundleID: String?,
		sourceAppName: String?
	) {
		isTranscribing = false
		isPrewarming = false

		if ForceQuitCommandDetector.matches(result) {
			transcriptionFeatureLogger.fault("Force quit voice command recognized; terminating Hex.")
			Task {
				try? FileManager.default.removeItem(at: audioURL)
				NSApp.terminate(nil)
			}
			return
		}

		guard !result.isEmpty else { return }

		let hexSettings = settings.settings
		let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

		transcriptionFeatureLogger.info("Raw transcription: '\(result)'")

		let modifiedResult: String
		if settings.isRemappingScratchpadFocused {
			modifiedResult = result
			transcriptionFeatureLogger.info("Scratchpad focused; skipping word modifications")
		} else {
			var output = result
			if hexSettings.wordRemovalsEnabled {
				let removedResult = WordRemovalApplier.apply(output, removals: hexSettings.wordRemovals)
				if removedResult != output {
					let enabledRemovalCount = hexSettings.wordRemovals.filter(\.isEnabled).count
					transcriptionFeatureLogger.info("Applied \(enabledRemovalCount) word removal(s)")
				}
				output = removedResult
			}
			let remappedResult = WordRemappingApplier.apply(output, remappings: hexSettings.wordRemappings)
			if remappedResult != output {
				transcriptionFeatureLogger.info("Applied \(hexSettings.wordRemappings.count) word remapping(s)")
			}
			modifiedResult = remappedResult
		}

		guard !modifiedResult.isEmpty else { return }

		Task {
			await finalizeRecordingAndStoreTranscript(
				result: modifiedResult,
				duration: duration,
				sourceAppBundleID: sourceAppBundleID,
				sourceAppName: sourceAppName,
				audioURL: audioURL
			)
		}
	}

	private func handleTranscriptionError(error: Error) {
		isTranscribing = false
		isPrewarming = false
		self.error = error.localizedDescription
	}

	private func finalizeRecordingAndStoreTranscript(
		result: String,
		duration: TimeInterval,
		sourceAppBundleID: String?,
		sourceAppName: String?,
		audioURL: URL
	) async {
		let hexSettings = settings.settings

		if hexSettings.saveTranscriptionHistory {
			do {
				let transcript = try await transcriptPersistence.save(
					result,
					audioURL,
					duration,
					sourceAppBundleID,
					sourceAppName
				)

				settings.transcriptionHistory.history.insert(transcript, at: 0)

				if let maxEntries = hexSettings.maxHistoryEntries, maxEntries > 0 {
					while settings.transcriptionHistory.history.count > maxEntries {
						if let removedTranscript = settings.transcriptionHistory.history.popLast() {
							try? await transcriptPersistence.deleteAudio(removedTranscript)
						}
					}
				}
			} catch {
				transcriptionFeatureLogger.error("Failed to save transcript: \(error.localizedDescription)")
			}
		} else {
			try? FileManager.default.removeItem(at: audioURL)
		}

		await pasteboard.paste(text: result)
		await soundEffects.play(.pasteTranscript)
	}
}
