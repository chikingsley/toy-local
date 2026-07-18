import Foundation

enum ClipboardContextSource: String, Codable, Equatable, Sendable {
  case beforeRecording
  case duringRecording
}

enum SelectionContextSource: String, Codable, Equatable, Sendable {
  case recordingStart
  case duringRecording
}

struct ClipboardTextItem: Codable, Equatable, Identifiable, Sendable {
  var id = UUID()
  var source: ClipboardContextSource
  var text: String
  var capturedAt: Date
}

struct SelectedTextItem: Codable, Equatable, Identifiable, Sendable {
  var id = UUID()
  var source: SelectionContextSource
  var text: String
  var capturedAt: Date
}

enum DictationContextAttachmentKind: String, Codable, Equatable, Sendable {
  case clipboardFile
  case clipboardImage
  case screenImage
}

struct DictationContextAttachment: Codable, Equatable, Identifiable, Sendable {
  var id = UUID()
  var kind: DictationContextAttachmentKind
  var source: ClipboardContextSource?
  var uniformTypeIdentifier: String?
  var filename: String?
  var byteCount: Int?
  var localPath: String?
  var capturedAt: Date
}

enum DictationContextAttachmentCleanup {
  static func removeOwnedFiles(
    in attachments: [DictationContextAttachment],
    fileManager: FileManager = .default
  ) {
    for attachment in attachments
    where attachment.kind == .clipboardImage || attachment.kind == .screenImage {
      guard let localPath = attachment.localPath else { continue }
      try? fileManager.removeItem(atPath: localPath)
    }
  }
}

struct DictationContextSnapshot: Codable, Equatable, Sendable {
  var startedAt: Date
  var endedAt: Date?
  var context: DictationContext
  var clipboardItems: [ClipboardTextItem]
  var selectedTextItems: [SelectedTextItem]
  var attachments: [DictationContextAttachment]
}

enum DictationContextSnapshotCoders {
  static func encode(_ snapshot: DictationContextSnapshot) throws -> Data {
    try TimberVoxJSONCoding.makeEncoder().encode(snapshot)
  }

  static func decode(_ data: Data) throws -> DictationContextSnapshot {
    try TimberVoxJSONCoding.makeDecoder().decode(DictationContextSnapshot.self, from: data)
  }
}

struct DictationContextCaptureLimits: Equatable, Sendable {
  var maxClipboardItems = 32
  var maxClipboardCharacters = 20_000
  var maxClipboardItemCharacters = 6_000
  var preRecordingClipboardWindow: TimeInterval = 3
  var clipboardHistoryRetention: TimeInterval = 30
  var maxSelectedTextItems = 8
  var maxSelectedTextCharacters = 12_000
  var maxSelectedTextItemCharacters = 6_000
  var maxScreenTextItems = 2
  var maxScreenTextCharacters = 24_000
  var maxScreenTextItemCharacters = 12_000
  var maxAttachments = 32

  func includesPreRecordingItem(capturedAt: Date, recordingStartedAt: Date) -> Bool {
    capturedAt >= recordingStartedAt.addingTimeInterval(-preRecordingClipboardWindow)
      && capturedAt <= recordingStartedAt
  }

  func shouldRetain(capturedAt: Date, now: Date) -> Bool {
    capturedAt >= now.addingTimeInterval(-clipboardHistoryRetention)
  }
}

struct DictationContextCaptureBuilder: Sendable {
  let startedAt: Date
  private(set) var context: DictationContext
  private(set) var clipboardItems: [ClipboardTextItem] = []
  private(set) var selectedTextItems: [SelectedTextItem] = []
  private(set) var screenTextItems: [(capturedAt: Date, text: String)] = []
  private(set) var attachments: [DictationContextAttachment] = []
  let limits: DictationContextCaptureLimits

  init(
    startedAt: Date,
    context: DictationContext,
    limits: DictationContextCaptureLimits = .init()
  ) {
    self.startedAt = startedAt
    self.context = context
    self.limits = limits
  }

  mutating func updateContext(_ newContext: DictationContext) {
    let clipboardText = context.clipboardText
    let selectedText = context.selectedText
    let screenText = context.application?.screenText
    context = newContext
    context.clipboardText = clipboardText
    context.selectedText = selectedText
    if context.application?.screenText == nil {
      context.application?.screenText = screenText
    }
  }

  mutating func appendClipboardText(
    _ text: String?,
    source: ClipboardContextSource,
    capturedAt: Date
  ) {
    guard let text = normalized(text) else { return }
    let clipped = String(text.prefix(limits.maxClipboardItemCharacters))
    guard !clipboardItems.contains(where: { $0.text == clipped }) else { return }
    clipboardItems.append(ClipboardTextItem(source: source, text: clipped, capturedAt: capturedAt))
    if clipboardItems.count > limits.maxClipboardItems {
      clipboardItems.removeFirst(clipboardItems.count - limits.maxClipboardItems)
    }
    renderClipboardContext()
  }

  mutating func appendSelectedText(
    _ text: String?,
    source: SelectionContextSource,
    capturedAt: Date
  ) {
    guard let text = normalized(text) else { return }
    let clipped = String(text.prefix(limits.maxSelectedTextItemCharacters))
    guard !selectedTextItems.contains(where: { $0.text == clipped }) else { return }
    selectedTextItems.append(SelectedTextItem(source: source, text: clipped, capturedAt: capturedAt))
    if selectedTextItems.count > limits.maxSelectedTextItems {
      selectedTextItems.removeFirst(selectedTextItems.count - limits.maxSelectedTextItems)
    }
    renderSelectionContext()
  }

  mutating func appendAttachment(_ attachment: DictationContextAttachment) {
    guard limits.maxAttachments > 0 else { return }
    guard
      !attachments.contains(where: { item in
        item.kind == attachment.kind && item.localPath == attachment.localPath
          && item.capturedAt == attachment.capturedAt
      })
    else { return }
    attachments.append(attachment)
    if attachments.count > limits.maxAttachments {
      attachments.removeFirst(attachments.count - limits.maxAttachments)
    }
    renderClipboardContext()
  }

  mutating func appendScreen(
    text: String?,
    attachment: DictationContextAttachment?,
    capturedAt: Date
  ) {
    if let text = normalized(text) {
      let clipped = String(text.prefix(limits.maxScreenTextItemCharacters))
      if !screenTextItems.contains(where: { $0.text == clipped }) {
        screenTextItems.append((capturedAt: capturedAt, text: clipped))
        if screenTextItems.count > limits.maxScreenTextItems {
          screenTextItems.removeFirst(screenTextItems.count - limits.maxScreenTextItems)
        }
        renderScreenContext()
      }
    }
    if let attachment {
      appendAttachment(attachment)
    }
  }

  func snapshot(endedAt: Date? = nil) -> DictationContextSnapshot {
    DictationContextSnapshot(
      startedAt: startedAt,
      endedAt: endedAt,
      context: context,
      clipboardItems: clipboardItems,
      selectedTextItems: selectedTextItems,
      attachments: attachments
    )
  }

  private mutating func renderClipboardContext() {
    var rendered = ""
    for item in clipboardItems.sorted(by: { $0.capturedAt < $1.capturedAt }) {
      let label =
        item.source == .beforeRecording
        ? "Clipboard before recording"
        : "Clipboard copied during recording"
      let section = "\(label):\n\(item.text)"
      let candidate = rendered.isEmpty ? section : "\(rendered)\n\n\(section)"
      guard candidate.count <= limits.maxClipboardCharacters else { break }
      rendered = candidate
    }
    for attachment in attachments where attachment.source != nil {
      let sourceLabel =
        attachment.source == .beforeRecording
        ? "Clipboard before recording attachment"
        : "Clipboard copied during recording attachment"
      let kindLabel = attachment.kind == .clipboardFile ? "File" : "Image"
      var details = ["\(kindLabel): \(attachment.filename ?? "unknown")"]
      if let uniformTypeIdentifier = attachment.uniformTypeIdentifier {
        details.append("Type: \(uniformTypeIdentifier)")
      }
      if let localPath = attachment.localPath {
        details.append("Path: \(localPath)")
      }
      let section = "\(sourceLabel):\n\(details.joined(separator: "\n"))"
      let candidate = rendered.isEmpty ? section : "\(rendered)\n\n\(section)"
      guard candidate.count <= limits.maxClipboardCharacters else { break }
      rendered = candidate
    }
    context.clipboardText = rendered.isEmpty ? nil : rendered
  }

  private mutating func renderSelectionContext() {
    var rendered = ""
    for item in selectedTextItems {
      let label =
        item.source == .recordingStart
        ? "Selected text at recording start"
        : "Selected text changed during recording"
      let section = selectedTextItems.count == 1 ? item.text : "\(label):\n\(item.text)"
      let candidate = rendered.isEmpty ? section : "\(rendered)\n\n\(section)"
      guard candidate.count <= limits.maxSelectedTextCharacters else { break }
      rendered = candidate
    }
    context.selectedText = rendered.isEmpty ? nil : rendered
  }

  private mutating func renderScreenContext() {
    var rendered = ""
    for item in screenTextItems.sorted(by: { $0.capturedAt < $1.capturedAt }) {
      let label = item.capturedAt <= startedAt ? "Screen at recording start" : "Screen at recording end"
      let section = screenTextItems.count == 1 ? item.text : "\(label):\n\(item.text)"
      let candidate = rendered.isEmpty ? section : "\(rendered)\n\n\(section)"
      guard candidate.count <= limits.maxScreenTextCharacters else { break }
      rendered = candidate
    }
    if context.application == nil {
      context.application = ApplicationContext(name: "Unknown Application")
    }
    context.application?.screenText = rendered.isEmpty ? nil : rendered
  }

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let value =
      text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}
