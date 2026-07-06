import Foundation
import TimberVoxCore
import XCTest

@testable import TimberVox

@MainActor
final class TranscriptStoreRuntimeTests: XCTestCase {
  private static let day: TimeInterval = 86_400

  func testServiceContainerImportsJSONHistoryIntoTranscriptStore() throws {
    let settings = SettingsManager()
    let transcript = makeTranscript(text: "Imported transcript")
    settings.transcriptionHistory = TranscriptionHistory(history: [transcript])

    let services = ServiceContainer(
      settings: settings,
      transcriptStore: try TranscriptStore.inMemory(),
      transcriptPersistence: makePersistence()
    )

    let record = try services.transcriptStore.record(id: transcript.id.uuidString)
    XCTAssertEqual(try services.transcriptStore.count(), 1)
    XCTAssertEqual(record?.rawText, "Imported transcript")
    XCTAssertEqual(record?.finalText, "Imported transcript")
  }

  func testServiceContainerStartupSweepEnforcesRetentionAndDeletesAudio() async throws {
    let settings = SettingsManager()
    var timberVoxSettings = settings.settings
    timberVoxSettings.recordingRetention = .oneWeek
    settings.settings = timberVoxSettings

    let expired = makeTranscript(
      timestamp: Date().addingTimeInterval(-8 * Self.day),
      text: "Expired transcript"
    )
    let retained = makeTranscript(
      timestamp: Date().addingTimeInterval(-Self.day),
      text: "Retained transcript"
    )
    settings.transcriptionHistory = TranscriptionHistory(history: [retained, expired])

    let recorder = DeleteAudioRecorder()
    let services = ServiceContainer(
      settings: settings,
      transcriptStore: try TranscriptStore.inMemory(),
      transcriptPersistence: makePersistence { transcript in
        await recorder.record(transcript)
      }
    )

    XCTAssertEqual(try services.transcriptStore.records().map(\.id), [retained.id.uuidString])
    try await waitForDeletedAudio(id: expired.id, recorder: recorder)
  }

  func testHistoryStoreDeleteRemovesTranscriptStoreRecord() throws {
    let settings = SettingsManager()
    let transcript = makeTranscript(text: "Delete me")
    settings.transcriptionHistory = TranscriptionHistory(history: [transcript])
    let services = ServiceContainer(
      settings: settings,
      transcriptStore: try TranscriptStore.inMemory(),
      transcriptPersistence: makePersistence()
    )
    let historyStore = HistoryStore(services: services)

    XCTAssertNotNil(try services.transcriptStore.record(id: transcript.id.uuidString))
    historyStore.deleteTranscript(transcript.id.uuidString)

    XCTAssertNil(try services.transcriptStore.record(id: transcript.id.uuidString))
    XCTAssertEqual(try services.transcriptStore.count(), 0)
  }

  private func makeTranscript(
    timestamp: Date = Date(),
    text: String,
    duration: TimeInterval = 1
  ) -> Transcript {
    Transcript(
      timestamp: timestamp,
      text: text,
      audioPath: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).wav"),
      duration: duration,
      sourceAppBundleID: "com.apple.dt.Xcode",
      sourceAppName: "Xcode"
    )
  }

  private func makePersistence(
    deleteAudio: @escaping @Sendable (Transcript) async -> Void = { _ in }
  ) -> TranscriptPersistenceClient {
    TranscriptPersistenceClient(
      save: { _, _, _, _, _, _ in
        throw NSError(domain: "TranscriptStoreRuntimeTests", code: 1)
      },
      deleteAudio: { transcript in
        await deleteAudio(transcript)
      }
    )
  }

  private func waitForDeletedAudio(id: UUID, recorder: DeleteAudioRecorder) async throws {
    for _ in 0..<20 {
      if await recorder.contains(id) {
        return
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTFail("Expected audio deletion for \(id.uuidString)")
  }
}

private actor DeleteAudioRecorder {
  private var deletedIDs: [UUID] = []

  func record(_ transcript: Transcript) {
    deletedIDs.append(transcript.id)
  }

  func contains(_ id: UUID) -> Bool {
    deletedIDs.contains(id)
  }
}
