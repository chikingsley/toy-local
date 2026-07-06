import XCTest

@testable import TimberVoxCore

final class FluidAudioModelCatalogTests: XCTestCase {
  func testCatalogContainsTargetLocalModelsAndNoLegacyV2() {
    let ids = Set(FluidAudioModels.all.map(\.id))

    XCTAssertTrue(ids.contains("parakeet-tdt-0.6b-v3-coreml"))
    XCTAssertTrue(ids.contains("parakeet-tdt-ctc-110m-coreml"))
    XCTAssertTrue(ids.contains("cohere-transcribe-03-2026-coreml"))
    XCTAssertTrue(ids.contains("nemotron-2240ms"))
    XCTAssertTrue(ids.contains("nemotron-multilingual-2240ms"))
    XCTAssertTrue(ids.contains("parakeet-ctc-110m-keyword-spotting"))
    XCTAssertTrue(ids.contains("silero-vad-coreml"))
    XCTAssertTrue(ids.contains("sortformer"))
    XCTAssertEqual(ids.count, FluidAudioModels.all.count)
  }

  func testUserSelectableCatalogOnlyContainsASRModels() {
    XCTAssertTrue(
      FluidAudioModels.userSelectableASR.allSatisfy {
        $0.role == .slidingWindowASR || $0.role == .streamingASR
      }
    )
    XCTAssertFalse(FluidAudioModels.userSelectableASR.contains { $0.role == .vad || $0.role == .diarization })
  }

  func testDefaultModelsHaveExpectedRoles() {
    XCTAssertEqual(FluidAudioModels.parakeetTdtV3.role, .slidingWindowASR)
    XCTAssertEqual(FluidAudioModels.parakeetEou160.role, .streamingASR)
    XCTAssertEqual(FluidAudioModels.sileroVad.role, .vad)
    XCTAssertEqual(FluidAudioModels.sortformer.role, .diarization)
  }

  func testCatalogSeparatesPrimaryASRFromSupportAssets() {
    XCTAssertTrue(FluidAudioModels.primaryASR.allSatisfy { $0.assetRole == .primaryASR })
    XCTAssertTrue(FluidAudioModels.supportAssets.allSatisfy { $0.assetRole != .primaryASR })
    XCTAssertTrue(FluidAudioModels.supportAssets.contains { $0.assetRole == .vad })
    XCTAssertTrue(FluidAudioModels.supportAssets.contains { $0.assetRole == .diarization })
    XCTAssertTrue(FluidAudioModels.supportAssets.contains { $0.assetRole == .keywordSpotting })
  }

  func testEveryCatalogModelHasASourceBackedMetricProfile() {
    let profileIDs = Set(FluidAudioModelMetrics.profiles.map(\.modelID))
    let modelIDs = Set(FluidAudioModels.all.map(\.id))

    XCTAssertEqual(profileIDs, modelIDs)
    XCTAssertTrue(
      FluidAudioModelMetrics.profiles.allSatisfy {
        !$0.sources.isEmpty && $0.sources.allSatisfy { !$0.url.isEmpty && !$0.title.isEmpty }
      }
    )
  }

  func testCoreModelsExposePublishedQualityAndSpeedMetrics() {
    let parakeet110 = FluidAudioModels.parakeetTdtCtc110m.metricProfile
    XCTAssertEqual(parakeet110.metrics(named: .wordErrorRatePercent).first?.value, 3.01)
    XCTAssertEqual(parakeet110.metrics(named: .realTimeFactor).first?.value, 96.5)

    let cohere = FluidAudioModels.cohereTranscribe.metricProfile
    XCTAssertEqual(cohere.metrics(named: .wordErrorRatePercent).first?.value, 1.77)
    XCTAssertEqual(cohere.metrics(named: .maxAudioSeconds).first?.value, 35)
  }

  func testDownloadProfilesKeepCacheAndSourceInformation() {
    for profile in FluidAudioModelMetrics.profiles {
      XCTAssertNotNil(profile.download, profile.modelID)
      XCTAssertFalse(profile.download?.repository?.isEmpty ?? true, profile.modelID)
      XCTAssertFalse(profile.download?.cacheDirectory?.isEmpty ?? true, profile.modelID)
      XCTAssertNotNil(profile.download?.source, profile.modelID)
    }
  }
}
