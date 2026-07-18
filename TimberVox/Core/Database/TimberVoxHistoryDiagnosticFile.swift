import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct TimberVoxHistoryDiagnosticFile: Codable, Equatable, Sendable {
  static let currentSchemaVersion = 1

  let schemaVersion: Int
  let exportedAt: Date
  let record: TranscriptRecord
  let transcriptionArtifact: TranscriptionArtifact?
  let contextSnapshot: DictationContextSnapshot?
  let transformation: TextTransformationCapture?

  init(record: TranscriptRecord, exportedAt: Date = .now) {
    schemaVersion = Self.currentSchemaVersion
    self.exportedAt = exportedAt
    self.record = record
    transcriptionArtifact = record.artifact
    contextSnapshot = record.contextSnapshot
    transformation = record.transformation
  }

  func encoded() throws -> Data {
    let encoder = TimberVoxJSONCoding.makeEncoder()
    encoder.keyEncodingStrategy = .useDefaultKeys
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  static func decode(_ data: Data) throws -> Self {
    let decoder = TimberVoxJSONCoding.makeDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    return try decoder.decode(Self.self, from: data)
  }
}

struct TimberVoxHistoryDiagnosticTransfer: Transferable, Sendable {
  let file: TimberVoxHistoryDiagnosticFile

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { transfer in
      try transfer.file.encoded()
    }
    .suggestedFileName { transfer in
      "TimberVox History \(transfer.file.record.id.map(String.init) ?? "Record").json"
    }
  }
}
