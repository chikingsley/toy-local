import XCTest

@testable import TimberVox

final class TextTransformPromptBuilderTests: XCTestCase {
  func testEnabledContextSourcesAreAssembledInClientMessages() throws {
    let context = DictationContext(
      application: ApplicationContext(
        name: "Safari",
        category: "Web Browser",
        description: "Browser description",
        textInputFormat: "url",
        bundleIdentifier: "com.apple.Safari",
        documentURL: "https://example.com/context-fixture",
        windowTitle: "Context Fixture",
        visibleText: "VISIBLE_MARKER",
        screenText: "SCREEN_START_MARKER\n\nSCREEN_END_MARKER"
      ),
      focusedElement: FocusedElementContext(
        role: "AXTextArea",
        title: "Composer",
        description: "Message editor",
        content: "FOCUSED_MARKER"
      ),
      selectedText: "SELECTION_MARKER",
      clipboardText: "CLIPBOARD_MARKER",
      vocabulary: ["TimberVox"],
      system: SystemContext(
        language: "English",
        currentTime: "July 18, 2026 at 9:00 AM",
        timeZone: "America/Phoenix",
        locale: "en_US",
        computerName: "Team-Mac"
      ),
      user: UserContext(fullName: "Simon Peacock")
    )

    let messages = TextTransformPromptBuilder.messages(
      preset: try XCTUnwrap(TextTransformPreset.builtIn(id: .superPrompt)),
      transcript: "TRANSCRIPT_MARKER",
      context: context,
      contextOptions: .allAvailable
    )

    XCTAssertEqual(messages.map(\.role), [.system, .user])
    let prompt = try XCTUnwrap(messages.last?.content)
    XCTAssertTrue(prompt.contains("Document URL: https://example.com/context-fixture"))
    XCTAssertTrue(prompt.contains("Focused element content: FOCUSED_MARKER"))
    XCTAssertTrue(prompt.contains("Visible text: VISIBLE_MARKER"))
    XCTAssertFalse(prompt.contains("SCREEN_START_MARKER"))
    XCTAssertFalse(prompt.contains("SCREEN_END_MARKER"))
    XCTAssertTrue(prompt.contains("Selected Text Context: SELECTION_MARKER"))
    XCTAssertTrue(prompt.contains("CLIPBOARD_MARKER"))
    XCTAssertTrue(prompt.contains("Names and Usernames: TimberVox"))
    XCTAssertTrue(prompt.contains("USER MESSAGE:\nTRANSCRIPT_MARKER"))
  }

  func testLegacyScreenContextStillRendersWhenExplicitlyEnabled() {
    let context = DictationContext(
      application: ApplicationContext(
        name: "Historical app",
        screenText: "HISTORICAL_SCREEN_MARKER"
      )
    )
    let options = DictationContextOptions(includeScreenContext: true)

    let prompt = TextTransformPromptBuilder.userMessage(
      preset: .custom("Return the transcript."),
      transcript: "TRANSCRIPT_MARKER",
      context: context,
      contextOptions: options
    )

    XCTAssertTrue(prompt.contains("HISTORICAL_SCREEN_MARKER"))
  }

  func testCustomSourceFlagsDoNotLeakDisabledContextSections() throws {
    let context = DictationContext(
      application: ApplicationContext(
        name: "Warp",
        documentURL: "file:///private/tmp/APP_MARKER",
        screenText: "SCREEN_MARKER"
      ),
      selectedText: "SELECTION_MARKER",
      clipboardText: "CLIPBOARD_MARKER"
    )
    let options = DictationContextOptions(
      includeApplicationContext: false,
      includeSelectionContext: true,
      includeClipboardContext: false,
      includeScreenContext: false
    )

    let prompt = TextTransformPromptBuilder.userMessage(
      preset: .custom("Return the transcript."),
      transcript: "TRANSCRIPT_MARKER",
      context: context,
      contextOptions: options
    )

    XCTAssertFalse(prompt.contains("APP_MARKER"))
    XCTAssertFalse(prompt.contains("SCREEN_MARKER"))
    XCTAssertFalse(prompt.contains("CLIPBOARD_MARKER"))
    XCTAssertTrue(prompt.contains("SELECTION_MARKER"))
    XCTAssertTrue(prompt.contains("TRANSCRIPT_MARKER"))
  }
}
