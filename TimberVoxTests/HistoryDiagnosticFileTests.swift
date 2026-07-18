import XCTest

@testable import TimberVox

final class HistoryDiagnosticFileTests: XCTestCase {
  func testDiagnosticExportIncludesStoredRowArtifactAndContext() throws {
    let artifact = TestTranscriptionArtifact.make(text: "diagnostic transcript")
    let snapshot = DictationContextSnapshot(
      startedAt: Date(timeIntervalSince1970: 1_700_000_000),
      endedAt: Date(timeIntervalSince1970: 1_700_000_005),
      context: DictationContext(
        application: ApplicationContext(name: "Notes", bundleIdentifier: "com.apple.Notes"),
        selectedText: "selected context",
        clipboardText: "copied context"
      ),
      clipboardItems: [],
      selectedTextItems: [],
      attachments: []
    )
    let record = try makeRecord(artifact: artifact, snapshot: snapshot)
    let exportedAt = Date(timeIntervalSince1970: 1_700_000_100)

    let file = TimberVoxHistoryDiagnosticFile(record: record, exportedAt: exportedAt)
    let decoded = try TimberVoxHistoryDiagnosticFile.decode(file.encoded())

    XCTAssertEqual(decoded.schemaVersion, 1)
    XCTAssertEqual(decoded.exportedAt, exportedAt)
    XCTAssertEqual(decoded.record, record)
    XCTAssertEqual(decoded.transcriptionArtifact, artifact)
    XCTAssertEqual(decoded.contextSnapshot, snapshot)
    XCTAssertNil(decoded.transformation)
  }

  private func makeRecord(
    artifact: TranscriptionArtifact,
    snapshot: DictationContextSnapshot
  ) throws -> TranscriptRecord {
    let artifactData = try TranscriptionArtifactCoders.encode(artifact)
    let contextData = try DictationContextSnapshotCoders.encode(snapshot)
    return TranscriptRecord(
      id: 42,
      text: "diagnostic transcript",
      rawText: nil,
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      durationSeconds: 5,
      wordCount: 2,
      model: "test-model",
      modeID: "test-mode",
      modeName: "Test Mode",
      audioPath: nil,
      provider: "test",
      status: .succeeded,
      errorCode: nil,
      errorMessage: nil,
      wallLatencyMs: 500,
      legacyProviderLatencyMs: nil,
      language: "en",
      transformPreset: nil,
      transformModel: nil,
      transformationJSON: nil,
      transcriptionArtifactJSON: try XCTUnwrap(String(data: artifactData, encoding: .utf8)),
      contextSnapshotJSON: try XCTUnwrap(String(data: contextData, encoding: .utf8)),
      legacySegmentsJSON: nil,
      sourceApplicationName: "Notes",
      sourceApplicationBundleIdentifier: "com.apple.Notes",
      importSource: nil,
      importExternalID: nil
    )
  }
}
