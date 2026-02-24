import AVFoundation
import Foundation
import ToyLocalCore
import SwiftUI

public enum SoundEffect: String, CaseIterable, Sendable {
	case pasteTranscript
	case startRecording
	case stopRecording
	case cancel

	public var fileName: String {
		self.rawValue
	}

	var fileExtension: String {
		"mp3"
	}
}

actor SoundEffectsClientLive {
	private let logger = ToyLocalLog.sound
	private let baselineVolume = ToyLocalSettings.baseSoundEffectsVolume

	private let engine = AVAudioEngine()
	private let settingsManager: SettingsManager
	private var playerNodes: [SoundEffect: AVAudioPlayerNode] = [:]
	private var audioBuffers: [SoundEffect: AVAudioPCMBuffer] = [:]
	private var isEngineRunning = false

	init(settingsManager: SettingsManager) {
		self.settingsManager = settingsManager
	}

	func play(_ soundEffect: SoundEffect) async {
		let settings = await settingsManager.settings
		guard settings.soundEffectsEnabled else { return }
		guard let player = playerNodes[soundEffect], let buffer = audioBuffers[soundEffect] else {
			logger.error("Requested sound \(soundEffect.rawValue) not preloaded")
			return
		}
		prepareEngineIfNeeded()
		let clampedVolume = min(max(settings.soundEffectsVolume, 0), baselineVolume)
		player.volume = Float(clampedVolume)
		player.stop()
		player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in }
		player.play()
	}

	func stop(_ soundEffect: SoundEffect) {
		playerNodes[soundEffect]?.stop()
	}

	func stopAll() {
		playerNodes.values.forEach { $0.stop() }
	}

	func preloadSounds() async {
		guard !isSetup else { return }

		for soundEffect in SoundEffect.allCases {
			loadSound(soundEffect)
		}
		prepareEngineIfNeeded()

		isSetup = true
	}

	private var isSetup = false

	private func loadSound(_ soundEffect: SoundEffect) {
		guard let url = Bundle.main.url(
			forResource: soundEffect.fileName,
			withExtension: soundEffect.fileExtension
		) else {
			logger.error("Missing sound resource \(soundEffect.fileName).\(soundEffect.fileExtension)")
			return
		}

		do {
			let file = try AVAudioFile(forReading: url)
			let frameCount = AVAudioFrameCount(file.length)
			guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
				logger.error("Failed to allocate buffer for \(soundEffect.rawValue)")
				return
			}
			try file.read(into: buffer)
			audioBuffers[soundEffect] = buffer

			let player = AVAudioPlayerNode()
			engine.attach(player)
			engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
			playerNodes[soundEffect] = player
		} catch {
			logger.error("Failed to load sound \(soundEffect.rawValue): \(error.localizedDescription)")
		}
	}

	private func prepareEngineIfNeeded() {
		if !isEngineRunning || !engine.isRunning {
			engine.prepare()
			if #available(macOS 13.0, *) {
				engine.isAutoShutdownEnabled = false
			}
			do {
				try engine.start()
				isEngineRunning = true
			} catch {
				logger.error("Failed to start AVAudioEngine: \(error.localizedDescription)")
			}
		}
	}
}
