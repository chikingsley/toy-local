import XCTest

@testable import TimberVox

final class DictationContextCaptureBuilderTests: XCTestCase {
  func testStartAndEndScreenOCRRemainInTheFinalContext() throws {
    let startedAt = Date(timeIntervalSince1970: 1_000)
    var builder = DictationContextCaptureBuilder(
      startedAt: startedAt,
      context: DictationContext(application: ApplicationContext(name: "Safari"))
    )

    builder.appendScreen(
      text: "SCREEN_START_MARKER",
      attachment: nil,
      capturedAt: startedAt
    )
    builder.appendScreen(
      text: "SCREEN_END_MARKER",
      attachment: nil,
      capturedAt: startedAt.addingTimeInterval(10)
    )

    let screenText = try XCTUnwrap(builder.snapshot().context.application?.screenText)
    XCTAssertEqual(
      screenText,
      "Screen at recording start:\nSCREEN_START_MARKER\n\n"
        + "Screen at recording end:\nSCREEN_END_MARKER"
    )
  }

  func testDuplicateScreenOCRIsStoredOnce() throws {
    let startedAt = Date(timeIntervalSince1970: 1_000)
    var builder = DictationContextCaptureBuilder(
      startedAt: startedAt,
      context: DictationContext()
    )

    builder.appendScreen(text: "UNCHANGED_SCREEN", attachment: nil, capturedAt: startedAt)
    builder.appendScreen(
      text: "UNCHANGED_SCREEN",
      attachment: nil,
      capturedAt: startedAt.addingTimeInterval(10)
    )

    XCTAssertEqual(builder.screenTextItems.count, 1)
    XCTAssertEqual(
      try XCTUnwrap(builder.snapshot().context.application?.screenText),
      "UNCHANGED_SCREEN"
    )
  }

  func testClipboardAndSelectionChangesKeepSourceProvenance() throws {
    let startedAt = Date(timeIntervalSince1970: 1_000)
    var builder = DictationContextCaptureBuilder(
      startedAt: startedAt,
      context: DictationContext()
    )

    builder.appendClipboardText(
      "BEFORE_CLIPBOARD",
      source: .beforeRecording,
      capturedAt: startedAt.addingTimeInterval(-1)
    )
    builder.appendClipboardText(
      "DURING_CLIPBOARD",
      source: .duringRecording,
      capturedAt: startedAt.addingTimeInterval(1)
    )
    builder.appendSelectedText(
      "START_SELECTION",
      source: .recordingStart,
      capturedAt: startedAt
    )
    builder.appendSelectedText(
      "CHANGED_SELECTION",
      source: .duringRecording,
      capturedAt: startedAt.addingTimeInterval(2)
    )

    let snapshot = builder.snapshot()
    let clipboard = try XCTUnwrap(snapshot.context.clipboardText)
    let selection = try XCTUnwrap(snapshot.context.selectedText)
    XCTAssertTrue(clipboard.contains("Clipboard before recording:\nBEFORE_CLIPBOARD"))
    XCTAssertTrue(clipboard.contains("Clipboard copied during recording:\nDURING_CLIPBOARD"))
    XCTAssertTrue(selection.contains("Selected text at recording start:\nSTART_SELECTION"))
    XCTAssertTrue(selection.contains("Selected text changed during recording:\nCHANGED_SELECTION"))
  }
}
