import Foundation

public struct Transcript: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var timestamp: Date
  public var text: String
  public var audioPath: URL
  public var duration: TimeInterval
  public var sourceAppBundleID: String?
  public var sourceAppName: String?
  public var contextSnapshot: DictationContextSnapshot?

  public init(
    id: UUID = UUID(),
    timestamp: Date,
    text: String,
    audioPath: URL,
    duration: TimeInterval,
    sourceAppBundleID: String? = nil,
    sourceAppName: String? = nil,
    contextSnapshot: DictationContextSnapshot? = nil
  ) {
    self.id = id
    self.timestamp = timestamp
    self.text = text
    self.audioPath = audioPath
    self.duration = duration
    self.sourceAppBundleID = sourceAppBundleID
    self.sourceAppName = sourceAppName
    self.contextSnapshot = contextSnapshot
  }
}

public struct TranscriptionHistory: Codable, Equatable, Sendable {
  public var history: [Transcript] = []

  public init(history: [Transcript] = []) {
    self.history = history
  }
}
