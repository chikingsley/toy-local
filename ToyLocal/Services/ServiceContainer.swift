import Foundation
import ToyLocalCore

/// Creates and owns all long-lived services. Instantiated once at app launch.
@MainActor
final class ServiceContainer {
	let settings: SettingsManager
	let permissions: PermissionClientLive
	let sleepManagement: SleepManagementClientLive
	let transcriptPersistence: TranscriptPersistenceClient
	let recording: RecordingClientLive
	let keyEventMonitor: KeyEventMonitorClientLive
	let transcription: TranscriptionClientLive
	let pasteboard: PasteboardClientLive
	let soundEffects: SoundEffectsClientLive
	let streamingAudio: StreamingAudioClientLive

	init() {
		let settings = SettingsManager()
		self.settings = settings
		self.permissions = PermissionClientLive()
		self.sleepManagement = SleepManagementClientLive()
		self.transcriptPersistence = .live
		self.recording = RecordingClientLive(settingsManager: settings)
		self.keyEventMonitor = KeyEventMonitorClientLive(settingsManager: settings)
		self.transcription = TranscriptionClientLive()
		self.pasteboard = PasteboardClientLive(settingsManager: settings)
		self.soundEffects = SoundEffectsClientLive(settingsManager: settings)
		self.streamingAudio = StreamingAudioClientLive()
	}
}
