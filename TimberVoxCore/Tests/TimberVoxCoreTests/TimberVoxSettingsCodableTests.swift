import XCTest

@testable import TimberVoxCore

final class TimberVoxSettingsCodableTests: XCTestCase {
  func testEncodeDecodeRoundTripPreservesDefaults() throws {
    let settings = TimberVoxSettings()
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(TimberVoxSettings.self, from: data)
    XCTAssertEqual(decoded, settings)
    XCTAssertEqual(decoded.textTransformMode, .voiceToText)
    XCTAssertEqual(decoded.textTransformMode.rawValue, "voice_to_text")
    XCTAssertTrue(decoded.localModelPrewarmEnabled)
  }

  func testEncodeDecodeRoundTripPreservesTextTransformSettings() throws {
    let settings = TimberVoxSettings(
      textTransformMode: .superPrompt,
      textTransformModel: "mistral-mistral-small-latest",
      customTextTransformInstructions: "Use the window context.",
      textTransformContextOptions: DictationContextOptions(
        includeApplicationContext: true,
        includeSelectionContext: true,
        includeClipboardContext: false
      )
    )

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(TimberVoxSettings.self, from: data)

    XCTAssertEqual(decoded.textTransformMode, .superPrompt)
    XCTAssertEqual(decoded.textTransformModel, "mistral-mistral-small-latest")
    XCTAssertEqual(decoded.customTextTransformInstructions, "Use the window context.")
    XCTAssertEqual(decoded.textTransformContextOptions.includeApplicationContext, true)
    XCTAssertEqual(decoded.textTransformContextOptions.includeSelectionContext, true)
    XCTAssertEqual(decoded.textTransformContextOptions.includeClipboardContext, false)
  }
}
