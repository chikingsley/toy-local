import XCTest

@testable import TimberVoxCore

final class TranscriptionWorkflowTests: XCTestCase {
  func testNativeAndLocalDiarizationAreDifferentStrategies() {
    let nativeCloud = TranscriptionWorkflowRequest(
      asrModelID: CloudTranscriptionModels.deepgramNova3.id,
      diarization: .native,
      outputFormats: [.text, .speakerSegments]
    )
    XCTAssertTrue(TranscriptionWorkflowValidator.validate(nativeCloud).isEmpty)

    let unsupportedNativeLocal = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      diarization: .native
    )
    XCTAssertEqual(
      TranscriptionWorkflowValidator.validate(unsupportedNativeLocal).map(\.code),
      [.nativeDiarizationUnsupported]
    )

    let localDiarization = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      diarization: .local(modelID: FluidAudioModels.sortformer.id),
      outputFormats: [.text, .speakerSegments]
    )
    XCTAssertTrue(TranscriptionWorkflowValidator.validate(localDiarization).isEmpty)
  }

  func testLocalSupportSelectionsMustUseSupportAssetRoles() {
    let wrongVAD = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      vad: .local(modelID: FluidAudioModels.parakeetTdtCtc110m.id)
    )
    XCTAssertEqual(
      TranscriptionWorkflowValidator.validate(wrongVAD).map(\.code),
      [.localVADModelWrongRole]
    )

    let validVAD = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      vad: .local(modelID: FluidAudioModels.sileroVad.id)
    )
    XCTAssertTrue(TranscriptionWorkflowValidator.validate(validVAD).isEmpty)
  }

  func testVocabularyCanBeNativeLocalKeywordOrTransformContext() {
    let nativeCloudVocabulary = TranscriptionWorkflowRequest(
      asrModelID: CloudTranscriptionModels.deepgramNova3.id,
      vocabulary: .native(terms: ["TimberVox", "FluidAudio"])
    )
    XCTAssertTrue(TranscriptionWorkflowValidator.validate(nativeCloudVocabulary).isEmpty)

    let unsupportedNativeLocalVocabulary = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      vocabulary: .native(terms: ["TimberVox"])
    )
    XCTAssertEqual(
      TranscriptionWorkflowValidator.validate(unsupportedNativeLocalVocabulary).map(\.code),
      [.nativeVocabularyUnsupported]
    )

    let localKeyword = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      vocabulary: .localKeywordSpotting(
        modelID: FluidAudioModels.customVocabularyCtc110m.id,
        terms: ["TimberVox"]
      )
    )
    XCTAssertTrue(TranscriptionWorkflowValidator.validate(localKeyword).isEmpty)

    let transformOnlyVocabulary = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      vocabulary: .textTransformContext(terms: ["TimberVox"]),
      textTransform: TranscriptTransformRequest(
        modelID: CloudLanguageModels.defaultModel.id,
        preset: .custom("Use provided vocabulary only for spelling.")
      )
    )
    XCTAssertTrue(TranscriptionWorkflowValidator.validate(transformOnlyVocabulary).isEmpty)
  }

  func testSpeakerOutputRequiresDiarization() {
    let request = TranscriptionWorkflowRequest(
      asrModelID: FluidAudioModels.parakeetTdtV3.id,
      outputFormats: [.speakerSegments]
    )

    XCTAssertEqual(
      TranscriptionWorkflowValidator.validate(request).map(\.code),
      [.speakerOutputNeedsDiarization]
    )
  }
}
