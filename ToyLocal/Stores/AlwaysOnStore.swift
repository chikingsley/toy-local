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
	var meter: Meter = .init(averagePower: 0, peakPower: 0)
	var error: String?

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

	// MARK: - Task Handles

	@ObservationIgnored private var settingsObserverTask: Task<Void, Never>?
	@ObservationIgnored private var audioCaptureTask: Task<Void, Never>?
	@ObservationIgnored private var hotkeyMonitorTask: Task<Void, Never>?

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
				if self.settings.settings.alwaysOnEnabled {
					self.startListening()
				}
			} catch {
				logger.error("Failed to load streaming model: \(error.localizedDescription)")
				self.isModelLoading = false
				self.isModelLoaded = false
				self.error = error.localizedDescription
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
		confirmedText = ""
		currentPartial = ""
		meter = .init(averagePower: 0, peakPower: 0)
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
		var text = accumulatedText
		guard !text.isEmpty else { return }

		let hexSettings = settings.settings

		// Apply word removals/remappings at paste time
		if hexSettings.wordRemovalsEnabled {
			text = WordRemovalApplier.apply(text, removals: hexSettings.wordRemovals)
		}
		text = WordRemappingApplier.apply(text, remappings: hexSettings.wordRemappings)
		guard !text.isEmpty else { return }

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
			await pasteboard.paste(text: finalText)
			await soundEffects.play(.pasteTranscript)
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
						self.currentPartial = partial
					}
				}

				let utteranceTask = Task { [weak self] in
					for await utterance in utterances {
						guard let self else { return }
						let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
						guard !trimmed.isEmpty else { continue }
						self.confirmedText = trimmed
						self.currentPartial = ""
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
		let rms = sqrt(sumSquares / Float(count))
		meter = Meter(averagePower: Double(rms), peakPower: Double(peak))
	}

	// MARK: - Hotkey Monitoring

	private func startHotkeyMonitoring() {
		hotkeyMonitorTask?.cancel()
		hotkeyMonitorTask = Task { [weak self] in
			guard let self else { return }

			let token = self.keyEventMonitor.handleKeyEvent { [weak self] keyEvent in
				guard let self else { return false }

				// Must be on MainActor to read settings
				let shouldHandle = MainActor.assumeIsolated {
					if self.settings.isSettingHotKey { return false }
					guard self.settings.settings.alwaysOnEnabled else { return false }
					return true
				}
				guard shouldHandle else { return false }

				let hexSettings = MainActor.assumeIsolated { self.settings.settings }

				// Check paste hotkey
				if let pasteHotkey = hexSettings.alwaysOnPasteHotkey {
					let keyMatches: Bool
					if let hotkeyKey = pasteHotkey.key {
						keyMatches = keyEvent.key == hotkeyKey
					} else {
						keyMatches = keyEvent.key == nil
					}
					if keyMatches, keyEvent.modifiers.matchesExactly(pasteHotkey.modifiers) {
						Task { @MainActor [weak self] in self?.pasteBuffer() }
						return true
					}
				}

				// Check dump hotkey
				if let dumpHotkey = hexSettings.alwaysOnDumpHotkey {
					let keyMatches: Bool
					if let hotkeyKey = dumpHotkey.key {
						keyMatches = keyEvent.key == hotkeyKey
					} else {
						keyMatches = keyEvent.key == nil
					}
					if keyMatches, keyEvent.modifiers.matchesExactly(dumpHotkey.modifiers) {
						Task { @MainActor [weak self] in self?.dumpBuffer() }
						return true
					}
				}

				return false
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
