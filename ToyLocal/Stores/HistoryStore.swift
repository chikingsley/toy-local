import AVFoundation
import AppKit
import ToyLocalCore
import SwiftUI

private let historyLogger = ToyLocalLog.history

// MARK: - Audio Player Controller

class AudioPlayerController: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
	private var player: AVAudioPlayer?
	var onPlaybackFinished: (() -> Void)?

	func play(url: URL) throws -> AVAudioPlayer {
		let player = try AVAudioPlayer(contentsOf: url)
		player.delegate = self
		player.play()
		self.player = player
		return player
	}

	func stop() {
		player?.stop()
		player = nil
	}

	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		self.player = nil
		Task { @MainActor in
			onPlaybackFinished?()
		}
	}
}

// MARK: - History Store

@MainActor @Observable
final class HistoryStore {
	// MARK: - State

	var playingTranscriptID: UUID?
	var audioPlayer: AVAudioPlayer?
	var audioPlayerController: AudioPlayerController?

	// MARK: - Callbacks

	var onNavigateToSettings: (() -> Void)?

	// MARK: - Dependencies

	private let settings: SettingsManager
	private let pasteboard: PasteboardClientLive

	// MARK: - Init

	init(services: ServiceContainer) {
		self.settings = services.settings
		self.pasteboard = services.pasteboard
	}

	// MARK: - Computed

	var transcriptionHistory: TranscriptionHistory {
		get { settings.transcriptionHistory }
		set { settings.transcriptionHistory = newValue }
	}

	var saveTranscriptionHistory: Bool {
		settings.settings.saveTranscriptionHistory
	}

	// MARK: - Methods

	func playTranscript(_ id: UUID) {
		if playingTranscriptID == id {
			stopPlayback()
			return
		}

		stopPlayback()

		guard let transcript = settings.transcriptionHistory.history.first(where: { $0.id == id }) else {
			return
		}

		do {
			let controller = AudioPlayerController()
			let player = try controller.play(url: transcript.audioPath)

			audioPlayer = player
			audioPlayerController = controller
			playingTranscriptID = id

			controller.onPlaybackFinished = { [weak self] in
				Task { @MainActor in
					self?.stopPlayback()
				}
			}
		} catch {
			historyLogger.error("Failed to play audio: \(error.localizedDescription)")
		}
	}

	func stopPlayback() {
		audioPlayerController?.stop()
		audioPlayer = nil
		audioPlayerController = nil
		playingTranscriptID = nil
	}

	func copyToClipboard(_ text: String) {
		Task {
			await pasteboard.copy(text: text)
		}
	}

	func deleteTranscript(_ id: UUID) {
		guard let index = settings.transcriptionHistory.history.firstIndex(where: { $0.id == id }) else {
			return
		}

		let transcript = settings.transcriptionHistory.history[index]

		if playingTranscriptID == id {
			stopPlayback()
		}

		settings.transcriptionHistory.history.remove(at: index)

		Task.detached {
			try? FileManager.default.removeItem(at: transcript.audioPath)
		}
	}

	func confirmDeleteAll() {
		let transcripts = settings.transcriptionHistory.history
		stopPlayback()
		settings.transcriptionHistory.history.removeAll()

		Task.detached {
			for transcript in transcripts {
				try? FileManager.default.removeItem(at: transcript.audioPath)
			}
		}
	}

	func navigateToSettings() {
		onNavigateToSettings?()
	}
}
