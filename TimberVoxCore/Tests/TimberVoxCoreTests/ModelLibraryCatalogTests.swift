import XCTest

@testable import TimberVoxCore

final class ModelLibraryCatalogTests: XCTestCase {
  func testSectionsMatchPrototypeProductGroups() {
    let sectionIDs = ModelLibraryCatalog.sections.map(\.id)

    XCTAssertEqual(sectionIDs, ModelLibrarySectionID.allCases)
    XCTAssertFalse(ModelLibraryCatalog.entries(in: .localDictation).isEmpty)
    XCTAssertFalse(ModelLibraryCatalog.entries(in: .cloudDictation).isEmpty)
    XCTAssertFalse(ModelLibraryCatalog.entries(in: .streamingPreview).isEmpty)
    XCTAssertFalse(ModelLibraryCatalog.entries(in: .cloudText).isEmpty)
    XCTAssertFalse(ModelLibraryCatalog.entries(in: .supportAssets).isEmpty)
  }

  func testLocalDictationOnlyContainsLocalBatchASR() {
    for entry in ModelLibraryCatalog.entries(in: .localDictation) {
      XCTAssertEqual(entry.runtime, .local)
      XCTAssertEqual(entry.assetRole, .primaryASR)
      XCTAssertEqual(entry.kind, .transcription)
      XCTAssertTrue(entry.isSelectable)
      XCTAssertTrue(entry.isDownloadable)
    }
  }

  func testStreamingPreviewIsSeparateFromBatchDictation() {
    let streamingIDs = Set(ModelLibraryCatalog.entries(in: .streamingPreview).map(\.id))
    let localDictationIDs = Set(ModelLibraryCatalog.entries(in: .localDictation).map(\.id))

    XCTAssertTrue(streamingIDs.contains(FluidAudioModels.parakeetEou160.id))
    XCTAssertFalse(localDictationIDs.contains(FluidAudioModels.parakeetEou160.id))
    XCTAssertFalse(streamingIDs.contains(FluidAudioModels.parakeetTdtV3.id))
  }

  func testCloudTextModelsAreAvailableForTransformUI() {
    let cloudTextIDs = Set(ModelLibraryCatalog.entries(in: .cloudText).map(\.id))

    XCTAssertEqual(cloudTextIDs, Set(CloudLanguageModels.all.map(\.id)))
    XCTAssertTrue(ModelLibraryCatalog.entries(in: .cloudText).allSatisfy { $0.kind == .textGeneration })
    XCTAssertTrue(ModelLibraryCatalog.entries(in: .cloudText).allSatisfy { $0.runtime == .cloud })
  }

  func testSupportAssetsAreNotNormalDictationChoices() {
    let supportRows = ModelLibraryCatalog.entries(in: .supportAssets)

    XCTAssertTrue(supportRows.contains { $0.assetRole == .vad })
    XCTAssertTrue(supportRows.contains { $0.assetRole == .diarization })
    XCTAssertTrue(supportRows.contains { $0.assetRole == .keywordSpotting })
    XCTAssertTrue(supportRows.allSatisfy { !$0.isSelectable })
  }

  func testLocalRowsCarrySourceBackedMetrics() throws {
    let localRows = ModelLibraryCatalog.entries(in: .localDictation)
    let parakeet110 = try XCTUnwrap(localRows.first { $0.id == FluidAudioModels.parakeetTdtCtc110m.id })

    XCTAssertEqual(parakeet110.metricSummary.primaryLabel, "WER")
    XCTAssertEqual(parakeet110.metricSummary.primaryValue, "3.01%")
    XCTAssertEqual(parakeet110.metricSummary.speedLabel, "Speed")
    XCTAssertEqual(parakeet110.metricSummary.speedValue, "96.50x")
    XCTAssertFalse(parakeet110.metricProfile?.sources.isEmpty ?? true)
  }
}
