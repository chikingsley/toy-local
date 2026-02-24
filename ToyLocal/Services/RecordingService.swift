import AVFoundation
import CoreAudio
import Foundation
import ToyLocalCore

private let recordingLogger = ToyLocalLog.recording
private let mediaLogger = ToyLocalLog.media

/// Represents an audio input device
struct AudioInputDevice: Identifiable, Equatable {
	var id: String
	var name: String
}

/// Simple structure representing audio metering values.
struct Meter: Equatable {
	let averagePower: Double
	let peakPower: Double
}

actor RecordingClientLive {
	private var recorder: AVAudioRecorder?
	private let recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
	private var isRecorderPrimedForNextSession = false
	private var lastPrimedDeviceID: AudioDeviceID?
	private var recordingSessionID: UUID?
	private var mediaControlTask: Task<Void, Never>?
	private let recorderSettings: [String: Any] = [
		AVFormatIDKey: Int(kAudioFormatLinearPCM),
		AVSampleRateKey: 16000.0,
		AVNumberOfChannelsKey: 1,
		AVLinearPCMBitDepthKey: 32,
		AVLinearPCMIsFloatKey: true,
		AVLinearPCMIsBigEndianKey: false,
		AVLinearPCMIsNonInterleaved: false
	]
	private let (meterStream, meterContinuation) = AsyncStream<Meter>.makeStream()
	private var meterTask: Task<Void, Never>?

	private let settingsManager: SettingsManager

	/// Tracks whether media was paused using the media key when recording started.
	private var didPauseMedia: Bool = false

	/// Tracks whether media was toggled via MediaRemote
	private var didPauseViaMediaRemote: Bool = false

	/// Tracks which specific media players were paused
	private var pausedPlayers: [String] = []

	/// Tracks previous system volume when muted for recording
	private var previousVolume: Float?

	// Cache to store already-processed device information
	private var deviceCache: [AudioDeviceID: (hasInput: Bool, name: String?)] = [:]
	private var lastDeviceCheck = Date(timeIntervalSince1970: 0)

	private enum RecorderPreparationError: Error {
		case failedToPrepareRecorder
		case missingRecordingOnDisk
	}

	init(settingsManager: SettingsManager) {
		self.settingsManager = settingsManager
	}
}

extension RecordingClientLive {
	/// Gets all available input devices on the system
	func getAvailableInputDevices() async -> [AudioInputDevice] {
		// Reset cache if it's been more than 5 minutes since last full refresh
		let now = Date()
		if now.timeIntervalSince(lastDeviceCheck) > 300 {
			deviceCache.removeAll()
			lastDeviceCheck = now
		}

		let devices = RecordingAudioHardware.getAllAudioDevices()
		var inputDevices: [AudioInputDevice] = []

		for device in devices {
			let hasInput: Bool
			let name: String?

			if let cached = deviceCache[device] {
				hasInput = cached.hasInput
				name = cached.name
			} else {
				hasInput = RecordingAudioHardware.deviceHasInput(deviceID: device)
				name = hasInput ? RecordingAudioHardware.getDeviceName(deviceID: device) : nil
				deviceCache[device] = (hasInput, name)
			}

			if hasInput, let deviceName = name {
				inputDevices.append(AudioInputDevice(id: String(device), name: deviceName))
			}
		}

		return inputDevices
	}

	/// Gets the current system default input device name
	func getDefaultInputDeviceName() async -> String? {
		guard let deviceID = RecordingAudioHardware.getDefaultInputDevice() else { return nil }
		if let cached = deviceCache[deviceID], cached.hasInput, let name = cached.name {
			return name
		}
		let name = RecordingAudioHardware.getDeviceName(deviceID: deviceID)
		if let name {
			deviceCache[deviceID] = (hasInput: true, name: name)
		}
		return name
	}

	func requestMicrophoneAccess() async -> Bool {
		await AVCaptureDevice.requestAccess(for: .audio)
	}

	func startRecording() async {
		let settings = await settingsManager.settings
		RecordingAudioHardware.ensureInputDeviceUnmuted(settings: settings)

		let sessionID = beginRecordingSession()
		scheduleMediaControlTask(for: settings.recordingAudioBehavior, sessionID: sessionID)

		let targetDeviceID = resolvedTargetInputDeviceID(from: settings)
		applyInputDeviceSelection(targetDeviceID)
		startRecorder()
	}

	private func beginRecordingSession() -> UUID {
		let sessionID = UUID()
		recordingSessionID = sessionID
		mediaControlTask?.cancel()
		mediaControlTask = nil
		return sessionID
	}

	private func scheduleMediaControlTask(for behavior: RecordingAudioBehavior, sessionID: UUID) {
		switch behavior {
		case .pauseMedia:
			schedulePauseMediaControlTask(sessionID: sessionID)
		case .mute:
			scheduleMuteMediaControlTask(sessionID: sessionID)
		case .doNothing:
			break
		}
	}

	private func schedulePauseMediaControlTask(sessionID: UUID) {
		mediaControlTask = Task { [sessionID] in
			guard self.isCurrentSession(sessionID) else { return }
			if await self.pauseUsingMediaRemoteIfPossible(sessionID: sessionID) {
				return
			}

			let paused = pauseAllMediaApplications()
			self.updatePausedPlayers(paused, sessionID: sessionID)

			guard self.isCurrentSession(sessionID) else { return }
			if paused.isEmpty, await isAudioPlayingOnDefaultOutput() {
				mediaLogger.notice("Detected active audio on default output; sending media pause")
				await MainActor.run {
					sendMediaKey()
				}
				self.setDidPauseMedia(true, sessionID: sessionID)
				mediaLogger.notice("Paused media via media key fallback")
			} else if !paused.isEmpty {
				mediaLogger.notice("Paused media players: \(paused.joined(separator: ", "))")
			}
		}
	}

	private func scheduleMuteMediaControlTask(sessionID: UUID) {
		mediaControlTask = Task { [sessionID] in
			guard self.isCurrentSession(sessionID) else { return }
			let volume = RecordingAudioHardware.muteSystemVolume()
			self.setPreviousVolume(volume, sessionID: sessionID)
		}
	}

	private func resolvedTargetInputDeviceID(from settings: ToyLocalSettings) -> AudioDeviceID? {
		if let selectedDeviceIDString = settings.selectedMicrophoneID,
		   let selectedDeviceID = AudioDeviceID(selectedDeviceIDString) {
			let devices = RecordingAudioHardware.getAllAudioDevices()
			if devices.contains(selectedDeviceID),
			   RecordingAudioHardware.deviceHasInput(deviceID: selectedDeviceID) {
				return selectedDeviceID
			}

			recordingLogger.notice("Selected device \(selectedDeviceID) missing; using system default")
		}

		return nil
	}

	private func applyInputDeviceSelection(_ targetDeviceID: AudioDeviceID?) {
		let currentDefaultDevice = RecordingAudioHardware.getDefaultInputDevice()
		if let primedDevice = lastPrimedDeviceID, primedDevice != currentDefaultDevice {
			recordingLogger.notice("Default input changed from \(primedDevice) to \(currentDefaultDevice ?? 0); invalidating primed state")
			invalidatePrimedState()
		}

		if let target = targetDeviceID {
			if target != currentDefaultDevice {
				recordingLogger.notice("Switching input device from \(currentDefaultDevice ?? 0) to \(target)")
				RecordingAudioHardware.setInputDevice(deviceID: target)
				invalidatePrimedState()
			} else {
				recordingLogger.debug("Device \(target) already set as default, skipping setInputDevice()")
			}
		} else {
			recordingLogger.debug("Using system default microphone")
		}
	}

	private func startRecorder() {
		do {
			let recorder = try ensureRecorderReadyForRecording()
			guard recorder.record() else {
				recordingLogger.error("AVAudioRecorder refused to start recording")
				endRecordingSession()
				return
			}
			startMeterTask()
			recordingLogger.notice("Recording started")
		} catch {
			recordingLogger.error("Failed to start recording: \(error.localizedDescription)")
			endRecordingSession()
		}
	}

	func stopRecording() async -> URL {
		let wasRecording = recorder?.isRecording == true
		recorder?.stop()
		stopMeterTask()
		endRecordingSession()
		if wasRecording {
			recordingLogger.notice("Recording stopped")
		} else {
			recordingLogger.notice("stopRecording() called while recorder was idle")
		}

		var exportedURL = recordingURL
		var didCopyRecording = false
		do {
			exportedURL = try duplicateCurrentRecording()
			didCopyRecording = true
		} catch {
			isRecorderPrimedForNextSession = false
			recordingLogger.error("Failed to copy recording: \(error.localizedDescription)")
		}

		if didCopyRecording {
			do {
				try primeRecorderForNextSession()
			} catch {
				isRecorderPrimedForNextSession = false
				recordingLogger.error("Failed to prime recorder: \(error.localizedDescription)")
			}
		}

		let playersToResume = pausedPlayers
		let shouldResumeMedia = didPauseMedia
		let shouldResumeViaMediaRemote = didPauseViaMediaRemote
		let volumeToRestore = previousVolume

		if !playersToResume.isEmpty || shouldResumeMedia || shouldResumeViaMediaRemote || volumeToRestore != nil {
			Task {
				if let volume = volumeToRestore {
					RecordingAudioHardware.restoreSystemVolume(volume)
				} else if !playersToResume.isEmpty {
					mediaLogger.notice("Resuming players: \(playersToResume.joined(separator: ", "))")
					resumeMediaApplications(playersToResume)
				} else if shouldResumeViaMediaRemote {
					if mediaRemoteController?.send(.play) == true {
						mediaLogger.notice("Resuming media via MediaRemote")
					} else {
						mediaLogger.error("Failed to resume via MediaRemote; falling back to media key")
						await MainActor.run {
							sendMediaKey()
						}
					}
				} else if shouldResumeMedia {
					await MainActor.run {
						sendMediaKey()
					}
					mediaLogger.notice("Resuming media via media key")
				}

				self.clearMediaState()
			}
		}

		return exportedURL
	}

	private func isCurrentSession(_ sessionID: UUID) -> Bool {
		recordingSessionID == sessionID
	}

	private func endRecordingSession() {
		recordingSessionID = nil
		mediaControlTask?.cancel()
		mediaControlTask = nil
	}

	private func invalidatePrimedState() {
		isRecorderPrimedForNextSession = false
		lastPrimedDeviceID = nil
	}

	private func updatePausedPlayers(_ players: [String], sessionID: UUID) {
		guard recordingSessionID == sessionID else { return }
		pausedPlayers = players
	}

	private func setDidPauseMedia(_ value: Bool, sessionID: UUID) {
		guard recordingSessionID == sessionID else { return }
		didPauseMedia = value
	}

	private func setDidPauseViaMediaRemote(_ value: Bool, sessionID: UUID) {
		guard recordingSessionID == sessionID else { return }
		didPauseViaMediaRemote = value
	}

	private func setPreviousVolume(_ volume: Float, sessionID: UUID) {
		guard recordingSessionID == sessionID else { return }
		previousVolume = volume
	}

	private func clearMediaState() {
		pausedPlayers = []
		didPauseMedia = false
		didPauseViaMediaRemote = false
		previousVolume = nil
	}

	@discardableResult
	private func pauseUsingMediaRemoteIfPossible(sessionID: UUID) async -> Bool {
		guard let controller = mediaRemoteController else {
			return false
		}

		let isPlaying = await controller.isMediaPlaying()
		guard isPlaying else {
			return false
		}

		guard controller.send(.pause) else {
			mediaLogger.error("Failed to send MediaRemote pause command")
			return false
		}

		setDidPauseViaMediaRemote(true, sessionID: sessionID)
		mediaLogger.notice("Paused media via MediaRemote")
		return true
	}

	private func ensureRecorderReadyForRecording() throws -> AVAudioRecorder {
		let recorder = try recorderOrCreate()

		if !isRecorderPrimedForNextSession {
			recordingLogger.notice("Recorder NOT primed, calling prepareToRecord() now")
			guard recorder.prepareToRecord() else {
				throw RecorderPreparationError.failedToPrepareRecorder
			}
		} else {
			recordingLogger.notice("Recorder already primed, skipping prepareToRecord()")
		}

		isRecorderPrimedForNextSession = false
		return recorder
	}

	private func recorderOrCreate() throws -> AVAudioRecorder {
		if let recorder {
			return recorder
		}

		let recorder = try AVAudioRecorder(url: recordingURL, settings: recorderSettings)
		recorder.isMeteringEnabled = true
		self.recorder = recorder
		return recorder
	}

	private func duplicateCurrentRecording() throws -> URL {
		let fm = FileManager.default

		guard fm.fileExists(atPath: recordingURL.path) else {
			throw RecorderPreparationError.missingRecordingOnDisk
		}

		let exportURL = recordingURL
			.deletingLastPathComponent()
			.appendingPathComponent("toy-local-recording-\(UUID().uuidString).wav")

		if fm.fileExists(atPath: exportURL.path) {
			try fm.removeItem(at: exportURL)
		}

		try fm.copyItem(at: recordingURL, to: exportURL)
		return exportURL
	}

	private func primeRecorderForNextSession() throws {
		let recorder = try recorderOrCreate()
		guard recorder.prepareToRecord() else {
			isRecorderPrimedForNextSession = false
			lastPrimedDeviceID = nil
			throw RecorderPreparationError.failedToPrepareRecorder
		}

		isRecorderPrimedForNextSession = true
		lastPrimedDeviceID = RecordingAudioHardware.getDefaultInputDevice()
		recordingLogger.debug("Recorder primed for device \(self.lastPrimedDeviceID ?? 0)")
	}

	func startMeterTask() {
		meterTask = Task {
			while !Task.isCancelled, let r = self.recorder, r.isRecording {
				r.updateMeters()
				let averagePower = r.averagePower(forChannel: 0)
				let averageNormalized = pow(10, averagePower / 20.0)
				let peakPower = r.peakPower(forChannel: 0)
				let peakNormalized = pow(10, peakPower / 20.0)
				meterContinuation.yield(Meter(averagePower: Double(averageNormalized), peakPower: Double(peakNormalized)))
				try? await Task.sleep(for: .milliseconds(100))
			}
		}
	}

	func stopMeterTask() {
		meterTask?.cancel()
		meterTask = nil
	}

	func observeAudioLevel() -> AsyncStream<Meter> {
		meterStream
	}

	func warmUpRecorder() async {
		do {
			try primeRecorderForNextSession()
		} catch {
			recordingLogger.error("Failed to warm up recorder: \(error.localizedDescription)")
		}
	}

	/// Release recorder resources. Call on app termination.
	func cleanup() {
		endRecordingSession()
		if let recorder {
			if recorder.isRecording {
				recorder.stop()
			}
			self.recorder = nil
		}
		isRecorderPrimedForNextSession = false
		lastPrimedDeviceID = nil
		recordingLogger.notice("RecordingClient cleaned up")
	}
}
