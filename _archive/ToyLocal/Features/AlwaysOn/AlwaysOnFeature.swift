import ComposableArchitecture
@preconcurrency import AVFoundation
import Foundation
import ToyLocalCore

private let logger = ToyLocalLog.streaming

/// Shared streaming transcription client instance (actor, thread-safe).
private let sharedStreamingClient = StreamingParakeetClient()

@Reducer
struct AlwaysOnFeature {
	@ObservableState
	struct State {
		var isListening: Bool = false
		var isModelLoaded: Bool = false
		var isModelLoading: Bool = false
		var modelDownloadProgress: Double = 0

		/// Full confirmed text from the latest EOU callback (replaces on each EOU, not appended).
		var confirmedText: String = ""
		/// Full partial text including confirmed + in-progress speech.
		var currentPartial: String = ""

		var error: String?

		@Shared(.hexSettings) var hexSettings: ToyLocalSettings
		@Shared(.transcriptionHistory) var transcriptionHistory: TranscriptionHistory

		/// Display text: partial includes everything (confirmed + in-progress).
		/// Falls back to confirmed text when no partial is available.
		var accumulatedText: String {
			currentPartial.isEmpty ? confirmedText : currentPartial
		}

		var hasText: Bool {
			!confirmedText.isEmpty || !currentPartial.isEmpty
		}
	}

	enum Action {
		case task

		// Lifecycle
		case startListening
		case stopListening
		case settingsChanged(alwaysOnEnabled: Bool)

		// Transcription events
		case partialTranscript(String)
		case confirmedUtterance(String)

		// User actions
		case pasteBuffer
		case dumpBuffer

		// Model
		case loadModel
		case modelDownloadProgress(Double)
		case modelLoaded(Result<Bool, Error>)

		case error(String)
	}

	enum CancelID {
		case audioCapture
		case partialObserver
		case utteranceObserver
		case hotkeyMonitor
		case settingsObserver
	}

	@Dependency(\.streamingAudio) var streamingAudio
	@Dependency(\.pasteboard) var pasteboard
	@Dependency(\.keyEventMonitor) var keyEventMonitor
	@Dependency(\.soundEffects) var soundEffect

	var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .task:
				return .merge(
					observeSettingsChanges(),
					state.hexSettings.alwaysOnEnabled ? .send(.loadModel) : .none
				)

			// MARK: - Settings

			case let .settingsChanged(enabled):
				if enabled && !state.isListening && !state.isModelLoading {
					return .send(.loadModel)
				} else if !enabled && state.isListening {
					return .send(.stopListening)
				}
				return .none

			// MARK: - Model Loading

			case .loadModel:
				guard !state.isModelLoading else { return .none }
				state.isModelLoading = true
				state.modelDownloadProgress = 0
				state.error = nil
				return .run { send in
					do {
						try await sharedStreamingClient.ensureLoaded { progress in
							let fraction = progress.fractionCompleted
							Task { @MainActor in
								await send(.modelDownloadProgress(fraction))
							}
						}
						await send(.modelLoaded(.success(true)))
					} catch {
						logger.error("Failed to load streaming model: \(error.localizedDescription)")
						await send(.modelLoaded(.failure(error)))
					}
				}

			case let .modelDownloadProgress(progress):
				state.modelDownloadProgress = progress
				return .none

			case .modelLoaded(.success):
				state.isModelLoading = false
				state.isModelLoaded = true
				return state.hexSettings.alwaysOnEnabled ? .send(.startListening) : .none

			case let .modelLoaded(.failure(error)):
				state.isModelLoading = false
				state.isModelLoaded = false
				state.error = error.localizedDescription
				return .none

			// MARK: - Listening Lifecycle

			case .startListening:
				guard state.isModelLoaded, !state.isListening else { return .none }
				state.isListening = true
				state.error = nil
				logger.notice("Always-on listening started")
				return .merge(
					startAudioCaptureEffect(),
					startHotkeyMonitoringEffect()
				)

			case .stopListening:
				state.isListening = false
				state.confirmedText = ""
				state.currentPartial = ""
				logger.notice("Always-on listening stopped")
				return .merge(
					.cancel(id: CancelID.audioCapture),
					.cancel(id: CancelID.partialObserver),
					.cancel(id: CancelID.utteranceObserver),
					.cancel(id: CancelID.hotkeyMonitor),
					.run { _ in
						await streamingAudio.stopCapture()
						await sharedStreamingClient.reset()
					}
				)

			// MARK: - Transcription Events

			case let .partialTranscript(text):
				state.currentPartial = text
				return .none

			case let .confirmedUtterance(text):
				let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmed.isEmpty else { return .none }

				// EOU callback returns FULL accumulated text — replace, don't append.
				state.confirmedText = trimmed
				state.currentPartial = ""
				logger.info("Confirmed (EOU): '\(trimmed, privacy: .private)'")
				return .none

			// MARK: - User Actions

			case .pasteBuffer:
				var text = state.accumulatedText
				guard !text.isEmpty else { return .none }

				// Apply word removals/remappings at paste time
				if state.hexSettings.wordRemovalsEnabled {
					text = WordRemovalApplier.apply(text, removals: state.hexSettings.wordRemovals)
				}
				text = WordRemappingApplier.apply(text, remappings: state.hexSettings.wordRemappings)
				guard !text.isEmpty else { return .none }

				// Save to history
				if state.hexSettings.saveTranscriptionHistory {
					let transcript = Transcript(
						timestamp: Date(),
						text: text,
						audioPath: URL(fileURLWithPath: ""),
						duration: 0
					)
					state.$transcriptionHistory.withLock { history in
						history.history.insert(transcript, at: 0)
						if let max = state.hexSettings.maxHistoryEntries, max > 0 {
							while history.history.count > max {
								history.history.removeLast()
							}
						}
					}
				}

				// Clear local state
				state.confirmedText = ""
				state.currentPartial = ""

				let finalText = text
				logger.notice("Pasting buffer (\(finalText.count) chars)")
				return .run { _ in
					// Reset streaming client so next speech starts fresh
					await sharedStreamingClient.reset()
					await pasteboard.paste(finalText)
					soundEffect.play(.pasteTranscript)
				}

			case .dumpBuffer:
				let hadText = state.hasText
				state.confirmedText = ""
				state.currentPartial = ""
				logger.notice("Buffer dumped")
				return hadText ? .run { _ in
					await sharedStreamingClient.reset()
					soundEffect.play(.cancel)
				} : .none

			case let .error(message):
				state.error = message
				return .none
			}
		}
	}
}

// MARK: - Effects

private extension AlwaysOnFeature {
	/// Observe changes to `alwaysOnEnabled` setting and start/stop accordingly.
	func observeSettingsChanges() -> Effect<Action> {
		.run { send in
			@Shared(.hexSettings) var hexSettings: ToyLocalSettings
			var lastEnabled = hexSettings.alwaysOnEnabled
			while !Task.isCancelled {
				try? await Task.sleep(for: .milliseconds(500))
				let current = hexSettings.alwaysOnEnabled
				if current != lastEnabled {
					lastEnabled = current
					await send(.settingsChanged(alwaysOnEnabled: current))
				}
			}
		}
		.cancellable(id: CancelID.settingsObserver)
	}

	/// Start audio capture and feed buffers to the streaming transcription client.
	func startAudioCaptureEffect() -> Effect<Action> {
		.run { send in
			try await sharedStreamingClient.ensureLoaded { _ in }

			// Set up callbacks
			let (partials, utterances) = await sharedStreamingClient.setupCallbacks()

			// Observe partials in parallel
			let partialTask = Task {
				for await partial in partials {
					await send(.partialTranscript(partial))
				}
			}

			// Observe utterances in parallel — EOU returns full accumulated
			// text, so we just replace state. Reset happens on paste/dump.
			let utteranceTask = Task {
				for await utterance in utterances {
					await send(.confirmedUtterance(utterance))
				}
			}

			defer {
				partialTask.cancel()
				utteranceTask.cancel()
			}

			// Start capture and process audio
			let audioStream = try await streamingAudio.startCapture()
			for await buffer in audioStream {
				try await sharedStreamingClient.processBuffer(buffer)
			}

			// Audio stream ended - finalize
			_ = try await sharedStreamingClient.finish()
		} catch: { error, send in
			logger.error("Audio capture error: \(error.localizedDescription)")
			await send(.error(error.localizedDescription))
		}
		.cancellable(id: CancelID.audioCapture, cancelInFlight: true)
	}

	/// Monitor paste and dump hotkeys.
	func startHotkeyMonitoringEffect() -> Effect<Action> {
		.run { send in
			@Shared(.hexSettings) var hexSettings: ToyLocalSettings
			@Shared(.isSettingHotKey) var isSettingHotKey: Bool

			// Capture Sendable Shared<T> values for the @Sendable closure
			let sharedSettings = $hexSettings
			let sharedIsSettingHotKey = $isSettingHotKey

			let token = keyEventMonitor.handleKeyEvent { keyEvent in
				if sharedIsSettingHotKey.wrappedValue { return false }
				guard sharedSettings.wrappedValue.alwaysOnEnabled else { return false }

				// Check paste hotkey
				if let pasteHotkey = sharedSettings.wrappedValue.alwaysOnPasteHotkey {
					let keyMatches: Bool
					if let hotkeyKey = pasteHotkey.key {
						keyMatches = keyEvent.key == hotkeyKey
					} else {
						// Modifier-only hotkey: match when all modifiers are held with no key
						keyMatches = keyEvent.key == nil
					}

					if keyMatches, keyEvent.modifiers.matchesExactly(pasteHotkey.modifiers) {
						Task { await send(.pasteBuffer) }
						return true
					}
				}

				// Check dump hotkey
				if let dumpHotkey = sharedSettings.wrappedValue.alwaysOnDumpHotkey {
					let keyMatches: Bool
					if let hotkeyKey = dumpHotkey.key {
						keyMatches = keyEvent.key == hotkeyKey
					} else {
						keyMatches = keyEvent.key == nil
					}

					if keyMatches, keyEvent.modifiers.matchesExactly(dumpHotkey.modifiers) {
						Task { await send(.dumpBuffer) }
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
		.cancellable(id: CancelID.hotkeyMonitor)
	}
}
