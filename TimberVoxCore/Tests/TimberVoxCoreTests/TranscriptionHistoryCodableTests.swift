import XCTest

@testable import TimberVoxCore

final class TranscriptionHistoryCodableTests: XCTestCase {
  func testTranscriptDecodesOlderRowsWithoutContextSnapshot() throws {
    let json = """
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "timestamp": 1782980000,
        "text": "hello",
        "audioPath": "file:///tmp/hello.wav",
        "duration": 1.25,
        "sourceAppBundleID": "com.apple.TextEdit",
        "sourceAppName": "TextEdit"
      }
      """

    let transcript = try JSONDecoder().decode(Transcript.self, from: Data(json.utf8))

    XCTAssertEqual(transcript.text, "hello")
    XCTAssertEqual(transcript.sourceAppName, "TextEdit")
    XCTAssertNil(transcript.contextSnapshot)
  }

  func testTranscriptRoundTripsContextSnapshot() throws {
    let transcriptID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
    let transcript = Transcript(
      id: transcriptID,
      timestamp: Date(timeIntervalSince1970: 1),
      text: "hello",
      audioPath: URL(fileURLWithPath: "/tmp/hello.wav"),
      duration: 1.25,
      contextSnapshot: DictationContextSnapshot(
        startedAt: Date(timeIntervalSince1970: 2),
        context: DictationContext(
          application: ApplicationContext(name: "TextEdit"),
          selectedText: "selected text",
          clipboardText: "Clipboard before recording:\nclipboard text"
        ),
        clipboardTextItems: [
          DictationClipboardTextItem(
            source: .beforeRecording,
            text: "clipboard text",
            capturedAt: Date(timeIntervalSince1970: 3)
          )
        ]
      )
    )

    let data = try JSONEncoder().encode(transcript)
    let decoded = try JSONDecoder().decode(Transcript.self, from: data)

    XCTAssertEqual(decoded.contextSnapshot?.context.application?.name, "TextEdit")
    XCTAssertEqual(decoded.contextSnapshot?.context.selectedText, "selected text")
    XCTAssertEqual(decoded.contextSnapshot?.clipboardTextItems.first?.text, "clipboard text")
  }
}
