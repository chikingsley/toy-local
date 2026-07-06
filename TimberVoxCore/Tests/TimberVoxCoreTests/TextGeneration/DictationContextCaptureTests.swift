import XCTest

@testable import TimberVoxCore

final class DictationContextCaptureTests: XCTestCase {
  func testBuildsSnapshotWithApplicationSelectionFocusAndClipboardContext() {
    let startedAt = Date(timeIntervalSince1970: 10)
    var builder = DictationContextCaptureBuilder(
      startedAt: startedAt,
      context: DictationContext(
        application: ApplicationContext(name: "TextEdit", category: "editor"),
        focusedElement: FocusedElementContext(role: "AXTextArea", title: "Untitled"),
        selectedText: "selected paragraph",
        system: SystemContext(language: "English", currentTime: "July 2, 2026 at 10:00 AM"),
        user: UserContext(fullName: "Simon")
      )
    )

    builder.appendClipboardText(
      "copied before",
      source: .beforeRecording,
      capturedAt: Date(timeIntervalSince1970: 11)
    )
    builder.appendClipboardText(
      "copied during",
      source: .duringRecording,
      capturedAt: Date(timeIntervalSince1970: 12)
    )

    let snapshot = builder.snapshot(endedAt: Date(timeIntervalSince1970: 13))

    XCTAssertEqual(snapshot.startedAt, startedAt)
    XCTAssertEqual(snapshot.endedAt, Date(timeIntervalSince1970: 13))
    XCTAssertEqual(snapshot.context.application?.name, "TextEdit")
    XCTAssertEqual(snapshot.context.focusedElement?.role, "AXTextArea")
    XCTAssertEqual(snapshot.context.selectedText, "selected paragraph")
    XCTAssertEqual(snapshot.selectedTextItems.count, 0)
    XCTAssertEqual(snapshot.clipboardTextItems.map(\.source), [.beforeRecording, .duringRecording])
    XCTAssertEqual(
      snapshot.context.clipboardText,
      """
      Clipboard before recording:
      copied before

      Clipboard copied during recording:
      copied during
      """
    )
  }

  func testPreRecordingClipboardWindowExcludesStaleClipboard() {
    let limits = DictationContextCaptureLimits(preRecordingClipboardWindow: 3)
    let recordingStartedAt = Date(timeIntervalSince1970: 10)

    XCTAssertTrue(
      limits.includesPreRecordingClipboardItem(
        capturedAt: Date(timeIntervalSince1970: 7),
        recordingStartedAt: recordingStartedAt
      )
    )
    XCTAssertTrue(
      limits.includesPreRecordingClipboardItem(
        capturedAt: Date(timeIntervalSince1970: 10),
        recordingStartedAt: recordingStartedAt
      )
    )
    XCTAssertFalse(
      limits.includesPreRecordingClipboardItem(
        capturedAt: Date(timeIntervalSince1970: 6.99),
        recordingStartedAt: recordingStartedAt
      )
    )
    XCTAssertFalse(
      limits.includesPreRecordingClipboardItem(
        capturedAt: Date(timeIntervalSince1970: 10.01),
        recordingStartedAt: recordingStartedAt
      )
    )
  }

  func testAppendsSelectedTextAtStartAndDuringRecording() {
    var builder = DictationContextCaptureBuilder(
      startedAt: Date(timeIntervalSince1970: 10),
      limits: DictationContextCaptureLimits(maxSelectedTextItems: 2)
    )

    builder.appendSelectedText(" first selection ", source: .recordingStart, capturedAt: Date(timeIntervalSince1970: 10))
    builder.appendSelectedText("first selection", source: .duringRecording, capturedAt: Date(timeIntervalSince1970: 11))
    builder.appendSelectedText("second selection", source: .duringRecording, capturedAt: Date(timeIntervalSince1970: 12))
    builder.appendSelectedText("third selection", source: .duringRecording, capturedAt: Date(timeIntervalSince1970: 13))

    let snapshot = builder.snapshot()

    XCTAssertEqual(snapshot.selectedTextItems.map(\.text), ["second selection", "third selection"])
    XCTAssertEqual(
      snapshot.context.selectedText,
      """
      Selected text changed during recording:
      second selection

      Selected text changed during recording:
      third selection
      """
    )
  }

  func testDedupesAndLimitsClipboardText() {
    var builder = DictationContextCaptureBuilder(
      startedAt: Date(timeIntervalSince1970: 1),
      limits: DictationContextCaptureLimits(
        maxClipboardItems: 2,
        maxClipboardCharacters: 40,
        maxClipboardItemCharacters: 5
      )
    )

    builder.appendClipboardText(" first  ", source: .beforeRecording)
    builder.appendClipboardText("first", source: .duringRecording)
    builder.appendClipboardText("second", source: .duringRecording)
    builder.appendClipboardText("third", source: .duringRecording)

    let snapshot = builder.snapshot()

    XCTAssertEqual(snapshot.clipboardTextItems.map(\.text), ["secon", "third"])
    XCTAssertEqual(snapshot.context.clipboardText, "Clipboard copied during recording:\nsecon")
  }

  func testStoresAttachmentMetadataWithLimitsAndDedupe() {
    var builder = DictationContextCaptureBuilder(
      startedAt: Date(timeIntervalSince1970: 1),
      limits: DictationContextCaptureLimits(maxAttachments: 1)
    )
    let image = DictationContextAttachment(
      kind: .clipboardImage,
      source: .duringRecording,
      uniformTypeIdentifier: "public.png",
      filename: "clip.png",
      byteCount: 42,
      localPath: "ContextAttachments/clip.png",
      capturedAt: Date(timeIntervalSince1970: 2)
    )
    builder.appendAttachment(image)
    builder.appendAttachment(image)
    builder.appendAttachment(
      DictationContextAttachment(
        kind: .clipboardFile,
        source: .duringRecording,
        uniformTypeIdentifier: "public.file-url",
        filename: "notes.md",
        byteCount: nil,
        localPath: nil,
        capturedAt: Date(timeIntervalSince1970: 3)
      )
    )

    let attachments = builder.snapshot().attachments

    XCTAssertEqual(attachments.count, 1)
    XCTAssertEqual(attachments[0].kind, .clipboardFile)
    XCTAssertEqual(attachments[0].filename, "notes.md")
    XCTAssertEqual(
      builder.snapshot().context.clipboardText,
      """
      Clipboard copied during recording attachment:
      File: notes.md
      Type: public.file-url
      """
    )
  }

  func testScreenContextIsStoredSeparatelyFromClipboardContext() {
    var builder = DictationContextCaptureBuilder(
      startedAt: Date(timeIntervalSince1970: 1),
      context: DictationContext(application: ApplicationContext(name: "Mail"))
    )

    builder.appendScreenContext(
      text: "Visible email subject",
      attachment: DictationContextAttachment(
        kind: .screenImage,
        uniformTypeIdentifier: "public.png",
        filename: "screen.png",
        byteCount: 100,
        localPath: "/tmp/screen.png",
        capturedAt: Date(timeIntervalSince1970: 2)
      )
    )

    let snapshot = builder.snapshot()

    XCTAssertEqual(snapshot.context.application?.screenText, "Visible email subject")
    XCTAssertNil(snapshot.context.clipboardText)
    XCTAssertEqual(snapshot.attachments.count, 1)
    XCTAssertEqual(snapshot.attachments[0].kind, .screenImage)
  }

  func testUpdateContextPreservesScreenTextFromEarlierCapture() {
    var builder = DictationContextCaptureBuilder(
      startedAt: Date(timeIntervalSince1970: 1),
      context: DictationContext(application: ApplicationContext(name: "Mail"))
    )
    builder.appendScreenContext(text: "Screen OCR", attachment: nil)

    builder.updateContext(
      DictationContext(application: ApplicationContext(name: "Mail", windowTitle: "Inbox"))
    )

    XCTAssertEqual(builder.snapshot().context.application?.windowTitle, "Inbox")
    XCTAssertEqual(builder.snapshot().context.application?.screenText, "Screen OCR")
  }
}
