@preconcurrency import AVFoundation
import Foundation
import ToyLocalCore

private let logger = ToyLocalLog.streaming

/// Shared streaming transcription client instance (actor, thread-safe).
private let sharedStreamingClient = StreamingParakeetClient()

@MainActor @Observable
final class AlwaysOnStore {
	// MARK: - State

	var isListening: Bool = false
	var isModelLoaded: Bool = false
	var isModelLoading: Bool = false
	var modelDownloadProgress: Double = 0
	var confirmedText: String = ""
	var currentPartial: String = ""
	var isAwaitingPasteFinalization: Bool = false
	var meter: Meter = .init(averagePower: 0, peakPower: 0)
	var error: String?
	var onModelStateChanged: (() -> Void)?

	/// Display text: partial includes everything (confirmed + in-progress).
	var accumulatedText: String {
		currentPartial.isEmpty ? confirmedText : currentPartial
	}

	var hasText: Bool {
		!confirmedText.isEmpty || !currentPartial.isEmpty
	}

	// MARK: - Dependencies

	private let settings: SettingsManager
	private let streamingAudio: StreamingAudioClientLive
	private let pasteboard: PasteboardClientLive
	private let keyEventMonitor: KeyEventMonitorClientLive
	private let soundEffects: SoundEffectsClientLive
	private let pasteStabilizationDelayMilliseconds = 1_000

	// MARK: - Task Handles

	@ObservationIgnored private var settingsObserverTask: Task<Void, Never>?
	@ObservationIgnored private var audioCaptureTask: Task<Void, Never>?
	@ObservationIgnored private var hotkeyMonitorTask: Task<Void, Never>?
	@ObservationIgnored private var pasteHotkeyWasPressed = false
	@ObservationIgnored private var dumpHotkeyWasPressed = false

	// MARK: - Init

	init(services: ServiceContainer) {
		self.settings = services.settings
		self.streamingAudio = services.streamingAudio
		self.pasteboard = services.pasteboard
		self.keyEventMonitor = services.keyEventMonitor
		self.soundEffects = services.soundEffects
	}

	deinit {
		settingsObserverTask?.cancel()
		audioCaptureTask?.cancel()
		hotkeyMonitorTask?.cancel()
	}

	// MARK: - Lifecycle

	func start() {
		startSettingsObserver()
		if settings.settings.alwaysOnEnabled {
			loadModel()
		}
	}

	// MARK: - Settings Observer

	private func startSettingsObserver() {
		settingsObserverTask?.cancel()
		settingsObserverTask = Task { [weak self] in
			guard let self else { return }
			var lastEnabled = self.settings.settings.alwaysOnEnabled
			while !Task.isCancelled {
				try? await Task.sleep(for: .milliseconds(500))
				let current = self.settings.settings.alwaysOnEnabled
				if current != lastEnabled {
					lastEnabled = current
					self.handleSettingsChanged(alwaysOnEnabled: current)
				}
			}
		}
	}

	private func handleSettingsChanged(alwaysOnEnabled: Bool) {
		if alwaysOnEnabled && !isListening && !isModelLoading {
			loadModel()
		} else if !alwaysOnEnabled && isListening {
			stopListening()
		}
	}

	// MARK: - Model Loading

	func loadModel() {
		guard !isModelLoading else { return }
		isModelLoading = true
		modelDownloadProgress = 0
		error = nil

		Task { [weak self] in
			guard let self else { return }
			do {
				try await sharedStreamingClient.ensureLoaded { [weak self] progress in
					Task { @MainActor [weak self] in
						self?.modelDownloadProgress = progress.fractionCompleted
					}
				}
				self.isModelLoading = false
				self.isModelLoaded = true
				self.onModelStateChanged?()
				if self.settings.settings.alwaysOnEnabled {
					self.startListening()
				}
			} catch {
				logger.error("Failed to load streaming model: \(error.localizedDescription)")
				self.isModelLoading = false
				self.isModelLoaded = false
				self.error = error.localizedDescription
				self.onModelStateChanged?()
			}
		}
	}

	// MARK: - Listening Lifecycle

	func startListening() {
		guard isModelLoaded, !isListening else { return }
		isListening = true
		error = nil
		logger.notice("Always-on listening started")
		startAudioCapture()
		startHotkeyMonitoring()
	}

	func stopListening() {
		isListening = false
		isAwaitingPasteFinalization = false
		confirmedText = ""
		currentPartial = ""
		meter = .init(averagePower: 0, peakPower: 0)
		resetHotkeyLatchState()
		logger.notice("Always-on listening stopped")

		audioCaptureTask?.cancel()
		audioCaptureTask = nil
		hotkeyMonitorTask?.cancel()
		hotkeyMonitorTask = nil

		Task {
			await streamingAudio.stopCapture()
			await sharedStreamingClient.reset()
		}
	}

	// MARK: - User Actions

	func pasteBuffer() {
		guard !isAwaitingPasteFinalization else {
			logger.notice("Always-on paste hotkey pressed while a stabilization wait is already pending.")
			return
		}

		isAwaitingPasteFinalization = true
		logger.notice("Always-on paste hotkey pressed; waiting \(self.pasteStabilizationDelayMilliseconds)ms before paste attempt.")
		Task { @MainActor [weak self] in
			await self?.performDeferredPasteAttempt()
		}
	}

	func dumpBuffer() {
		let hadText = hasText
		confirmedText = ""
		currentPartial = ""
		logger.notice("Buffer dumped")
		if hadText {
			Task {
				await sharedStreamingClient.reset()
				await soundEffects.play(.cancel)
			}
		}
	}

	// MARK: - Audio Capture

	private func startAudioCapture() {
		audioCaptureTask?.cancel()
		audioCaptureTask = Task { [weak self] in
			guard let self else { return }
			do {
				try await sharedStreamingClient.ensureLoaded { _ in }

				let (partials, utterances) = await sharedStreamingClient.setupCallbacks()

				let partialTask = Task { [weak self] in
					for await partial in partials {
						guard let self else { return }
						let wasBufferEmpty = self.currentPartial.isEmpty && self.confirmedText.isEmpty
						self.currentPartial = partial
						if wasBufferEmpty, !partial.isEmpty {
							logger.notice("Always-on buffer now has partial text (\(partial.count) chars).")
						}
					}
				}

				let utteranceTask = Task { [weak self] in
					for await utterance in utterances {
						guard let self else { return }
						let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
						guard !trimmed.isEmpty else { continue }
						self.confirmedText = trimmed
						self.currentPartial = ""
						logger.notice("Always-on utterance confirmed (\(trimmed.count) chars).")
						logger.info("Confirmed (EOU): '\(trimmed, privacy: .private)'")
					}
				}

				defer {
					partialTask.cancel()
					utteranceTask.cancel()
				}

				let audioStream = try await self.streamingAudio.startCapture()
				for await buffer in audioStream {
					self.updateMeter(from: buffer)
					try await sharedStreamingClient.processBuffer(buffer)
				}

				_ = try await sharedStreamingClient.finish()
			} catch is CancellationError {
				// Intentional cancellation from stopListening — don't restart
				return
			} catch {
				logger.error("Audio capture error: \(error.localizedDescription)")
			}

			// If we're still supposed to be listening but the pipeline died,
			// restart it after a brief delay to avoid tight retry loops.
			guard !Task.isCancelled, self.isListening else { return }
			logger.notice("Audio capture ended unexpectedly — restarting")
			self.meter = .init(averagePower: 0, peakPower: 0)
			try? await Task.sleep(for: .milliseconds(300))
			guard !Task.isCancelled, self.isListening else { return }
			self.startAudioCapture()
		}
	}

	// MARK: - Metering

	private func updateMeter(from buffer: AVAudioPCMBuffer) {
		guard let channelData = buffer.floatChannelData?[0] else { return }
		let count = Int(buffer.frameLength)
		guard count > 0 else { return }

		var sumSquares: Float = 0
		var peak: Float = 0
		for i in 0..<count {
			let sample = abs(channelData[i])
			sumSquares += sample * sample
			if sample > peak { peak = sample }
		}
		let rms = Double(sqrt(sumSquares / Float(count)))
		let rawPeak = Double(peak)

		// Smooth meter transitions so the indicator remains fluid even with 160ms chunks.
		let averageAlpha = 0.35
		let smoothedAverage = meter.averagePower + ((rms - meter.averagePower) * averageAlpha)

		let peakRiseAlpha = 0.6
		let peakFallMultiplier = 0.88
		let smoothedPeak: Double
		if rawPeak > meter.peakPower {
			smoothedPeak = meter.peakPower + ((rawPeak - meter.peakPower) * peakRiseAlpha)
		} else {
			smoothedPeak = meter.peakPower * peakFallMultiplier
		}

		meter = Meter(
			averagePower: max(0, min(1, smoothedAverage)),
			peakPower: max(0, min(1, smoothedPeak))
		)
	}

	// MARK: - Hotkey Monitoring

	private func startHotkeyMonitoring() {
		hotkeyMonitorTask?.cancel()
		hotkeyMonitorTask = Task { [weak self] in
			guard let self else { return }

				let token = self.keyEventMonitor.handleKeyEvent { [weak self] keyEvent in
					guard let self else { return false }
					let action = MainActor.assumeIsolated {
						self.resolveHotkeyAction(for: keyEvent)
					}

					switch action {
					case .paste:
						Task { @MainActor [weak self] in self?.pasteBuffer() }
						return true
					case .dump:
						Task { @MainActor [weak self] in self?.dumpBuffer() }
						return true
					case .none:
						return false
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

}

private extension AlwaysOnStore {
	func performDeferredPasteAttempt() async {
		defer { isAwaitingPasteFinalization = false }

		try? await Task.sleep(for: .milliseconds(pasteStabilizationDelayMilliseconds))
		guard isListening else {
			logger.notice("Always-on deferred paste canceled because listening is no longer active.")
			return
		}
		logger.notice("Always-on paste stabilization wait elapsed; evaluating buffered text.")

		let bufferedText = accumulatedText
		if !bufferedText.isEmpty {
			logger.notice("Always-on deferred paste found buffered text (\(bufferedText.count) chars).")
			pasteResolvedBuffer(bufferedText)
			return
		}

		logger.notice("Always-on deferred paste found empty buffer; attempting stream flush.")
		do {
			let flushed = try await sharedStreamingClient.finish()
				.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !flushed.isEmpty else {
				logger.notice("Always-on paste hotkey pressed, but buffer is empty.")
				return
			}

			logger.notice("Always-on stream flush produced \(flushed.count) chars for paste.")
			pasteResolvedBuffer(flushed)
		} catch {
			logger.error("Always-on stream flush failed: \(error.localizedDescription)")
			logger.notice("Always-on paste hotkey pressed, but buffer is empty.")
		}
	}

	func pasteResolvedBuffer(_ initialText: String) {
		var text = initialText
		let hexSettings = settings.settings

		// Apply word removals/remappings at paste time
		if hexSettings.wordRemovalsEnabled {
			text = WordRemovalApplier.apply(text, removals: hexSettings.wordRemovals)
		}
		text = WordRemappingApplier.apply(text, remappings: hexSettings.wordRemappings)
		guard !text.isEmpty else {
			logger.notice("Always-on paste discarded: processed text became empty after remap/removal.")
			return
		}

		// Save to history
		if hexSettings.saveTranscriptionHistory {
			let transcript = Transcript(
				timestamp: Date(),
				text: text,
				audioPath: URL(fileURLWithPath: ""),
				duration: 0
			)
			settings.transcriptionHistory.history.insert(transcript, at: 0)
			if let max = hexSettings.maxHistoryEntries, max > 0 {
				while settings.transcriptionHistory.history.count > max {
					settings.transcriptionHistory.history.removeLast()
				}
			}
		}

		confirmedText = ""
		currentPartial = ""

		let finalText = text
		logger.notice("Pasting buffer (\(finalText.count) chars)")
		Task {
			await sharedStreamingClient.reset()
			let didPaste = await pasteboard.paste(text: finalText)
			if didPaste {
				logger.notice("Always-on paste completed (\(finalText.count) chars)")
				await soundEffects.play(.pasteTranscript)
			} else {
				logger.notice("Always-on paste did not complete; transcript remains in clipboard.")
			}
		}
	}
}

private extension AlwaysOnStore {
	@MainActor
	enum AlwaysOnHotkeyAction {
		case none
		case paste
		case dump
	}

	@MainActor
	func resolveHotkeyAction(for keyEvent: KeyEvent) -> AlwaysOnHotkeyAction {
		if settings.isSettingHotKey || !settings.settings.alwaysOnEnabled {
			resetHotkeyLatchState()
			return .none
		}

		let currentSettings = settings.settings
		let pastePressedNow = isPressed(hotkey: currentSettings.alwaysOnPasteHotkey, with: keyEvent)
		let dumpPressedNow = isPressed(hotkey: currentSettings.alwaysOnDumpHotkey, with: keyEvent)

		let shouldPaste = pastePressedNow && !pasteHotkeyWasPressed
		let shouldDump = dumpPressedNow && !dumpHotkeyWasPressed

		pasteHotkeyWasPressed = pastePressedNow
		dumpHotkeyWasPressed = dumpPressedNow

		if shouldPaste {
			logger.notice("Always-on paste hotkey triggered.")
			return .paste
		}
		if shouldDump {
			logger.notice("Always-on dump hotkey triggered.")
			return .dump
		}
		return .none
	}

	@MainActor
	func resetHotkeyLatchState() {
		pasteHotkeyWasPressed = false
		dumpHotkeyWasPressed = false
	}

	@MainActor
	func isPressed(hotkey: HotKey?, with keyEvent: KeyEvent) -> Bool {
		guard let hotkey else { return false }
		let keyMatches: Bool
		if let hotkeyKey = hotkey.key {
			keyMatches = keyEvent.key == hotkeyKey
		} else {
			keyMatches = keyEvent.key == nil
		}
		return keyMatches && keyEvent.modifiers.matchesExactly(hotkey.modifiers)
	}
}
