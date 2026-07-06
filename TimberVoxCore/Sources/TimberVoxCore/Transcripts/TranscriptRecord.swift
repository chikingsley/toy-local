import Foundation
import GRDB

public struct TranscriptRecord: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var createdAt: Date
  public var duration: TimeInterval
  public var title: String?
  public var rawText: String
  public var finalText: String
  public var modeName: String?
  public var sourceAppBundleID: String?
  public var sourceAppName: String?
  public var audioPath: String?
  public var contextJSON: Data?

  public init(
    id: String = UUID().uuidString,
    createdAt: Date,
    duration: TimeInterval,
    title: String? = nil,
    rawText: String,
    finalText: String,
    modeName: String? = nil,
    sourceAppBundleID: String? = nil,
    sourceAppName: String? = nil,
    audioPath: String? = nil,
    contextJSON: Data? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.duration = duration
    self.title = title
    self.rawText = rawText
    self.finalText = finalText
    self.modeName = modeName
    self.sourceAppBundleID = sourceAppBundleID
    self.sourceAppName = sourceAppName
    self.audioPath = audioPath
    self.contextJSON = contextJSON
  }
}

extension TranscriptRecord: FetchableRecord, PersistableRecord {
  public static let databaseTableName = "recording"
}

extension TranscriptRecord {
  public init(legacy transcript: Transcript) {
    let context = try? JSONEncoder().encode(transcript.contextSnapshot)
    self.init(
      id: transcript.id.uuidString,
      createdAt: transcript.timestamp,
      duration: transcript.duration,
      rawText: transcript.text,
      finalText: transcript.text,
      sourceAppBundleID: transcript.sourceAppBundleID,
      sourceAppName: transcript.sourceAppName,
      audioPath: transcript.audioPath.path,
      contextJSON: transcript.contextSnapshot == nil ? nil : context
    )
  }

  public var contextSnapshot: DictationContextSnapshot? {
    guard let contextJSON else { return nil }
    return try? JSONDecoder().decode(DictationContextSnapshot.self, from: contextJSON)
  }
}
