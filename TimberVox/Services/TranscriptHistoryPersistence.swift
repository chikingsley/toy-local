import TimberVoxCore
import Foundation

private let transcriptHistoryPersistenceLogger = TimberVoxLog.history

@MainActor
final class TranscriptHistoryPersistence {
  var onDidChange: (() -> Void)?

  private let settings: SettingsManager
  private let transcriptStore: TranscriptStore
  private let transcriptPersistence: TranscriptPersistenceClient

  init(
    settings: SettingsManager,
    transcriptStore: TranscriptStore,
    transcriptPersistence: TranscriptPersistenceClient
  ) {
    self.settings = settings
    self.transcriptStore = transcriptStore
    self.transcriptPersistence = transcriptPersistence
  }

  func runStartupImportAndSweep() {
    do {
      let imported = try transcriptStore.importLegacy(settings.transcriptionHistory.history)
      let removed = try transcriptStore.sweep(retention: settings.settings.recordingRetention)
      deleteAudio(for: removed)
      transcriptHistoryPersistenceLogger.info(
        "TranscriptStore startup import=\(imported) sweepRemoved=\(removed.count)"
      )
    } catch {
      transcriptHistoryPersistenceLogger.error("TranscriptStore startup sync failed: \(error.localizedDescription)")
    }
  }

  func appendSavedTranscript(
    _ transcript: Transcript,
    rawText: String,
    finalText: String,
    modeName: String?,
    settingsSnapshot: TimberVoxSettings
  ) {
    insertRecord(for: transcript, rawText: rawText, finalText: finalText, modeName: modeName)
    trimHistory(maxEntries: settingsSnapshot.maxHistoryEntries)
    notifyChange()
  }

  func appendStreamingTranscript(_ text: String, settingsSnapshot: TimberVoxSettings) {
    let transcript = Transcript(
      timestamp: Date(),
      text: text,
      audioPath: URL(fileURLWithPath: ""),
      duration: 0
    )
    insertRecord(for: transcript, rawText: text, finalText: text, modeName: nil)
    trimHistory(maxEntries: settingsSnapshot.maxHistoryEntries)
    notifyChange()
  }

  @discardableResult
  func deleteRecord(id: UUID) -> TranscriptRecord? {
    deleteRecord(id: id.uuidString)
  }

  @discardableResult
  func deleteRecord(id: String) -> TranscriptRecord? {
    do {
      let record = try transcriptStore.delete(id: id)
      if let record {
        deleteAudio(for: [record])
      }
      notifyChange()
      return record
    } catch {
      transcriptHistoryPersistenceLogger.error("Failed to delete transcript record \(id): \(error.localizedDescription)")
      return nil
    }
  }

  func deleteAllRecords() {
    let records = (try? transcriptStore.records()) ?? []
    for record in records {
      deleteRecord(id: record.id)
    }
  }

  private func insertRecord(
    for transcript: Transcript,
    rawText: String,
    finalText: String,
    modeName: String?
  ) {
    do {
      try transcriptStore.insert(
        makeRecord(for: transcript, rawText: rawText, finalText: finalText, modeName: modeName)
      )
    } catch {
      transcriptHistoryPersistenceLogger.error("Failed to insert transcript record \(transcript.id.uuidString): \(error.localizedDescription)")
    }
  }

  private func trimHistory(maxEntries: Int?) {
    guard let maxEntries, maxEntries > 0 else { return }
    guard let records = try? transcriptStore.records(), records.count > maxEntries else { return }
    for record in records.suffix(records.count - maxEntries) {
      deleteRecord(id: record.id)
    }
  }

  private func deleteAudio(for records: [TranscriptRecord]) {
    deleteAudio(for: records.compactMap(audioTranscript(for:)))
  }

  private func deleteAudio(for transcripts: [Transcript]) {
    let transcriptsWithAudio = transcripts.filter(hasDeletableAudio)
    guard !transcriptsWithAudio.isEmpty else { return }
    let transcriptPersistence = self.transcriptPersistence
    Task.detached {
      for transcript in transcriptsWithAudio {
        try? await transcriptPersistence.deleteAudio(transcript)
      }
    }
  }

  private func makeRecord(
    for transcript: Transcript,
    rawText: String,
    finalText: String,
    modeName: String?
  ) -> TranscriptRecord {
    let context = try? JSONEncoder().encode(transcript.contextSnapshot)
    return TranscriptRecord(
      id: transcript.id.uuidString,
      createdAt: transcript.timestamp,
      duration: transcript.duration,
      rawText: rawText,
      finalText: finalText,
      modeName: modeName,
      sourceAppBundleID: transcript.sourceAppBundleID,
      sourceAppName: transcript.sourceAppName,
      audioPath: hasDeletableAudio(transcript) ? transcript.audioPath.path : nil,
      contextJSON: transcript.contextSnapshot == nil ? nil : context
    )
  }

  private func audioTranscript(for record: TranscriptRecord) -> Transcript? {
    guard record.duration > 0,
      let audioPath = record.audioPath,
      !audioPath.isEmpty
    else {
      return nil
    }
    return Transcript(
      id: UUID(uuidString: record.id) ?? UUID(),
      timestamp: record.createdAt,
      text: record.finalText,
      audioPath: URL(fileURLWithPath: audioPath),
      duration: record.duration,
      sourceAppBundleID: record.sourceAppBundleID,
      sourceAppName: record.sourceAppName,
      contextSnapshot: record.contextSnapshot
    )
  }

  private func hasDeletableAudio(_ transcript: Transcript) -> Bool {
    transcript.duration > 0 && !transcript.audioPath.path.isEmpty
  }

  private func notifyChange() {
    onDidChange?()
  }
}
