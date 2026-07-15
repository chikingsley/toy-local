import Foundation
import GRDB

struct TranscriptRecord: Identifiable, Codable, Equatable, Sendable, FetchableRecord,
  MutablePersistableRecord
{
  static let databaseTableName = "transcripts"

  var id: Int64?
  var text: String
  var rawText: String?
  var createdAt: Date
  var durationSeconds: Double
  var wordCount: Int = 0
  var model: String
  var modeID: String?
  var modeName: String?
  var audioPath: String?
  var provider: String?
  var status: TranscriptRecordStatus
  var errorCode: String?
  var errorMessage: String?
  var wallLatencyMs: Double?
  var legacyProviderLatencyMs: Double?
  var language: String?
  var transformPreset: String?
  var transformModel: String?
  var transformationJSON: String?
  var transcriptionArtifactJSON: String?
  var contextSnapshotJSON: String?
  var legacySegmentsJSON: String?
  var sourceApplicationName: String?
  var sourceApplicationBundleIdentifier: String?
  var importSource: String?
  var importExternalID: String?

  var artifact: TranscriptionArtifact? {
    guard
      let transcriptionArtifactJSON,
      let data = transcriptionArtifactJSON.data(using: .utf8)
    else { return nil }
    let cacheKey = payloadCacheKey
    if let cacheKey, let cached = TranscriptArtifactCache.shared.artifact(forKey: cacheKey) {
      return cached.artifact
    }
    do {
      let artifact = try TranscriptionArtifactCoders.decode(data)
      if let cacheKey {
        TranscriptArtifactCache.shared.store(artifact, forKey: cacheKey)
      }
      return artifact
    } catch {
      TimberVoxLog.persistence.error(
        "Stored transcription artifact could not be decoded: \(error.localizedDescription)"
      )
      if let cacheKey {
        TranscriptArtifactCache.shared.store(nil, forKey: cacheKey)
      }
      return nil
    }
  }

  /// Rows are immutable per id, so id plus payload size identifies a decode result.
  /// Nil for unsaved records, which are never worth caching.
  var payloadCacheKey: String? {
    id.map { "\($0):\(transcriptionArtifactJSON?.utf8.count ?? 0)" }
  }

  var transformation: TextTransformationCapture? {
    guard
      let transformationJSON,
      let data = transformationJSON.data(using: .utf8)
    else { return nil }
    do {
      return try TextTransformationCaptureCoders.decode(data)
    } catch {
      TimberVoxLog.persistence.error(
        "Stored text transformation could not be decoded: \(error.localizedDescription)"
      )
      return nil
    }
  }

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}

/// Decoding the stored artifact JSON is expensive and SwiftUI re-reads
/// `artifact` on every render, so decode once per row and reuse.
final class TranscriptArtifactCache: @unchecked Sendable {
  static let shared = TranscriptArtifactCache()

  final class Entry {
    let artifact: TranscriptionArtifact?

    init(_ artifact: TranscriptionArtifact?) {
      self.artifact = artifact
    }
  }

  private let cache: NSCache<NSString, Entry> = {
    let cache = NSCache<NSString, Entry>()
    cache.countLimit = 24
    return cache
  }()

  func artifact(forKey key: String) -> Entry? {
    cache.object(forKey: key as NSString)
  }

  func store(_ artifact: TranscriptionArtifact?, forKey key: String) {
    cache.setObject(Entry(artifact), forKey: key as NSString)
  }
}
