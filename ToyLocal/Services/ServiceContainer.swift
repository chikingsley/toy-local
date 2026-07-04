import Foundation
import ToyLocalCore

/// Creates and owns all long-lived services. Instantiated once at app launch.
@MainActor
final class ServiceContainer {
  let settings: SettingsManager
  let permissions: PermissionClientLive
  let sleepManagement: SleepManagementClientLive
  let transcriptPersistence: TranscriptPersistenceClient
  let transcriptStore: TranscriptStore
  let transcriptHistoryPersistence: TranscriptHistoryPersistence
  let recording: RecordingClientLive
  let keyEventMonitor: KeyEventMonitorClientLive
  let transcription: TranscriptionClientLive
  let transcriptionWorkflow: TranscriptionWorkflowService
  let contextCapture: DictationContextCaptureClientLive
  let cloud: ToyLocalCloudClient
  let pasteboard: PasteboardClientLive
  let soundEffects: SoundEffectsClientLive
  let streamingAudio: StreamingAudioClientLive

  init(
    settings: SettingsManager = SettingsManager(),
    transcriptStore storeOverride: TranscriptStore? = nil,
    transcriptPersistence: TranscriptPersistenceClient = .live
  ) {
    self.settings = settings
    self.permissions = PermissionClientLive()
    self.sleepManagement = SleepManagementClientLive()
    self.transcriptPersistence = transcriptPersistence
    let transcriptStore = storeOverride ?? Self.makeTranscriptStore()
    self.transcriptStore = transcriptStore
    self.transcriptHistoryPersistence = TranscriptHistoryPersistence(
      settings: settings,
      transcriptStore: transcriptStore,
      transcriptPersistence: transcriptPersistence
    )
    self.recording = RecordingClientLive(settingsManager: settings)
    self.keyEventMonitor = KeyEventMonitorClientLive(settingsManager: settings)
    let transcription = TranscriptionClientLive()
    let cloud = ToyLocalCloudClient(baseURL: Self.cloudBaseURL())
    self.transcription = transcription
    self.transcriptionWorkflow = TranscriptionWorkflowService(transcription: transcription, cloud: cloud)
    self.contextCapture = DictationContextCaptureClientLive(settingsManager: settings)
    self.cloud = cloud
    self.pasteboard = PasteboardClientLive(settingsManager: settings)
    self.soundEffects = SoundEffectsClientLive(settingsManager: settings)
    self.streamingAudio = StreamingAudioClientLive()
    self.transcriptHistoryPersistence.runStartupImportAndSweep()
  }

  private static func makeTranscriptStore() -> TranscriptStore {
    do {
      if AppStorageContext.usesInMemoryTranscriptStore {
        return try TranscriptStore.inMemory()
      }
      let databaseURL = try URL.toyLocalApplicationSupport.appendingPathComponent("transcripts.sqlite")
      return try TranscriptStore(databaseURL: databaseURL)
    } catch {
      ToyLocalLog.history.error("Failed to open TranscriptStore: \(error.localizedDescription)")
      do {
        return try TranscriptStore.inMemory()
      } catch {
        fatalError("Failed to create in-memory TranscriptStore: \(error.localizedDescription)")
      }
    }
  }

  private static func cloudBaseURL() -> URL {
    if let rawURL = ProcessInfo.processInfo.environment["TOY_LOCAL_CLOUD_API_URL"],
      let url = URL(string: rawURL)
    {
      return url
    }
    return URL(string: "http://127.0.0.1:8787")!
  }
}
