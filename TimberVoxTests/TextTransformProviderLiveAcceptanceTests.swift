import XCTest

@testable import TimberVox

@MainActor
final class TextTransformProviderLiveAcceptanceTests: XCTestCase {
  func testVoiceLabTransformMatrixReturnsStructuredText() async throws {
    try requireLiveTransformAcceptance()
    let artifacts = try makeArtifactsDirectory()
    let modes: [(ModeTextTransformPreset, String)] = [
      (.superPrompt, "um send alice the timber vox update tomorrow"),
      (.message, "tell alice the timber vox build passed and ask if ten works"),
      (.note, "remember timber vox build passed follow up with alice tomorrow"),
      (.email, "email alice that timber vox passed and propose ten tomorrow"),
      (.custom, "timber vox audio capture and provider tests passed"),
    ]

    for (preset, transcript) in modes {
      let mode = Self.mode(for: preset)
      let request = try XCTUnwrap(
        mode.textTransformRequest(rawTranscript: transcript, context: Self.context)
      )
      let outcome = try await TextTransformAPIClient.current.transform(request: request)
      let text = outcome.text.trimmingCharacters(in: .whitespacesAndNewlines)

      XCTAssertFalse(text.isEmpty, "\(preset.label) returned empty structured text")
      XCTAssertFalse(text.contains("<super>"), "Legacy response tags returned for \(preset.label)")
      try APIConnectorCoders.encode(request).write(
        to: artifacts.appendingPathComponent("\(preset.rawValue)-request.json")
      )
      try text.write(
        to: artifacts.appendingPathComponent("\(preset.rawValue)-result.txt"),
        atomically: true,
        encoding: .utf8
      )
    }
  }

  private static func mode(for preset: ModeTextTransformPreset) -> DictationMode {
    DictationMode(
      id: preset.rawValue,
      name: preset.label,
      audioModelID: DictationModeDefaults.batchModelID,
      languageCode: "en",
      realtimeEnabled: false,
      diarizationEnabled: false,
      textTransformPreset: preset,
      textTransformModelID: "mistral-mistral-small-latest",
      customTextTransformInstructions: "Return a five-word title only.",
      textTransformContextOptions: .init(
        includeApplicationContext: true,
        includeSelectionContext: true,
        includeClipboardContext: true,
        includeScreenContext: false
      )
    )
  }

  private static let context = DictationContext(
    application: ApplicationContext(
      name: "Codex",
      bundleIdentifier: "com.openai.codex",
      windowTitle: "TimberVox",
      screenText: "The TimberVox project is open."
    ),
    selectedText: "Alice is the release reviewer.",
    clipboardText: "The latest build passed every gate.",
    system: SystemContext(language: "English")
  )

  private func requireLiveTransformAcceptance() throws {
    let enabled =
      ProcessInfo.processInfo.environment["TIMBERVOX_LIVE_TRANSFORM_ACCEPTANCE"] == "1"
      || FileManager.default.fileExists(atPath: "/tmp/timbervox-live-transform-acceptance")
    if !enabled {
      throw XCTSkip("Run `just test-transform-live` for the Voice Lab transform matrix.")
    }
  }

  private func makeArtifactsDirectory() throws -> URL {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let directory = URL(fileURLWithPath: "/tmp/timbervox-acceptance")
      .appendingPathComponent("\(formatter.string(from: .now))-transforms")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
