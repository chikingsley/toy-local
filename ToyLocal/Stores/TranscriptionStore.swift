import CoreGraphics
import Foundation
import ToyLocalCore
import SwiftUI
import WhisperKit
private let transcriptionFeatureLogger = ToyLocalLog.transcription

// MARK: - Force Quit Command

enum ForceQuitCommandDetector {
	static func matches(_ text: String) -> Bool {
		let normalized = normalize(text)
		return normalized == "force quit toy local now" || normalized == "force quit toy local"
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

	@ObservationIgnored private var meteringTask: Task<Void, Never>?
	@ObservationIgnored private var hotkeyMonitorTask: Task<Void, Never>?
	@ObservationIgnored private var transcriptionTask: Task<Void, Never>?

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
				await sleepManagement.preventSleep(reason: "ToyLocal Voice Recording")
			}
			await recording.startRecording()
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
			transcriptionFeatureLogger.fault("Force quit voice command recognized; terminating ToyLocal.")
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

		let didPaste = await pasteboard.paste(text: result)
		if didPaste {
			transcriptionFeatureLogger.notice("Paste completed for transcribed result (\(result.count) chars).")
			await soundEffects.play(.pasteTranscript)
		} else {
			transcriptionFeatureLogger.notice("Paste did not complete; transcript remains in clipboard.")
		}
	}
}

private extension TranscriptionStore {
	struct StopRecordingContext {
		let stopTime: Date
		let startTime: Date?
		let duration: TimeInterval
		let decision: RecordingDecisionEngine.Decision
		let settingsSnapshot: ToyLocalSettings
		let sourceAppBundleID: String?
		let sourceAppName: String?
	}

	func runHotKeyMonitoringLoop() async {
		let token = keyEventMonitor.handleInputEvent { [weak self] inputEvent in
			guard let self else { return false }
			return MainActor.assumeIsolated {
				self.handleHotKeyInputEvent(inputEvent)
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

	func handleHotKeyInputEvent(_ inputEvent: InputEvent) -> Bool {
		guard !settings.settings.alwaysOnEnabled else { return false }
		guard !settings.isSettingHotKey else { return false }

		hotKeyProcessor.hotkey = settings.settings.hotkey
		hotKeyProcessor.useDoubleTapOnly = settings.settings.useDoubleTapOnly
		hotKeyProcessor.minimumKeyTime = settings.settings.minimumKeyTime

		switch inputEvent {
		case .keyboard(let keyEvent):
			return handleKeyboardInputEvent(keyEvent)
		case .mouseClick:
			return handleMouseClickInputEvent()
		}
	}

	func handleKeyboardInputEvent(_ keyEvent: KeyEvent) -> Bool {
		if keyEvent.key == .escape,
		   keyEvent.modifiers.isEmpty,
		   hotKeyProcessor.state == .idle {
			Task { @MainActor in cancel() }
			return false
		}

		let output = hotKeyProcessor.process(keyEvent: keyEvent)
		switch output {
		case .startRecording:
			if hotKeyProcessor.state == .doubleTapLock {
				Task { @MainActor in startRecording() }
			} else {
				Task { @MainActor in hotKeyPressed() }
			}
			return settings.settings.useDoubleTapOnly || keyEvent.key != nil
		case .stopRecording:
			Task { @MainActor in hotKeyReleased() }
			return false
		case .cancel:
			Task { @MainActor in cancel() }
			return true
		case .discard:
			Task { @MainActor in discard() }
			return false
		case .none:
			guard let pressedKey = keyEvent.key else { return false }
			return pressedKey == hotKeyProcessor.hotkey.key
				&& keyEvent.modifiers == hotKeyProcessor.hotkey.modifiers
		}
	}

	func handleMouseClickInputEvent() -> Bool {
		switch hotKeyProcessor.processMouseClick() {
		case .cancel:
			Task { @MainActor in cancel() }
		case .discard:
			Task { @MainActor in discard() }
		case .startRecording, .stopRecording, .none:
			break
		}
		return false
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

		return StopRecordingContext(
			stopTime: stopTime,
			startTime: startTime,
			duration: duration,
			decision: decision,
			settingsSnapshot: settingsSnapshot,
			sourceAppBundleID: sourceAppBundleID,
			sourceAppName: sourceAppName
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
	}

	func startTranscriptionTask(_ context: StopRecordingContext) {
		let model = context.settingsSnapshot.selectedModel
		let language = context.settingsSnapshot.outputLanguage
		let capturedSourceAppBundleID = context.sourceAppBundleID
		let capturedSourceAppName = context.sourceAppName

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
}
