import Foundation

public enum DictationClipboardContextSource: String, Codable, Equatable, Sendable {
  case beforeRecording
  case duringRecording
}

public enum DictationSelectionContextSource: String, Codable, Equatable, Sendable {
  case recordingStart
  case duringRecording
}

public struct DictationClipboardTextItem: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var source: DictationClipboardContextSource
  public var text: String
  public var capturedAt: Date

  public init(
    id: UUID = UUID(),
    source: DictationClipboardContextSource,
    text: String,
    capturedAt: Date
  ) {
    self.id = id
    self.source = source
    self.text = text
    self.capturedAt = capturedAt
  }
}

public struct DictationSelectedTextItem: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var source: DictationSelectionContextSource
  public var text: String
  public var capturedAt: Date

  public init(
    id: UUID = UUID(),
    source: DictationSelectionContextSource,
    text: String,
    capturedAt: Date
  ) {
    self.id = id
    self.source = source
    self.text = text
    self.capturedAt = capturedAt
  }
}

public enum DictationContextAttachmentKind: String, Codable, Equatable, Sendable {
  case clipboardFile
  case clipboardImage
  case screenImage
}

public struct DictationContextAttachment: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var kind: DictationContextAttachmentKind
  public var source: DictationClipboardContextSource?
  public var uniformTypeIdentifier: String?
  public var filename: String?
  public var byteCount: Int?
  public var localPath: String?
  public var capturedAt: Date

  public init(
    id: UUID = UUID(),
    kind: DictationContextAttachmentKind,
    source: DictationClipboardContextSource? = nil,
    uniformTypeIdentifier: String? = nil,
    filename: String? = nil,
    byteCount: Int? = nil,
    localPath: String? = nil,
    capturedAt: Date
  ) {
    self.id = id
    self.kind = kind
    self.source = source
    self.uniformTypeIdentifier = uniformTypeIdentifier
    self.filename = filename
    self.byteCount = byteCount
    self.localPath = localPath
    self.capturedAt = capturedAt
  }
}

public struct DictationContextSnapshot: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var startedAt: Date
  public var endedAt: Date?
  public var context: DictationContext
  public var clipboardTextItems: [DictationClipboardTextItem]
  public var selectedTextItems: [DictationSelectedTextItem]
  public var attachments: [DictationContextAttachment]

  public init(
    id: UUID = UUID(),
    startedAt: Date,
    endedAt: Date? = nil,
    context: DictationContext,
    clipboardTextItems: [DictationClipboardTextItem] = [],
    selectedTextItems: [DictationSelectedTextItem] = [],
    attachments: [DictationContextAttachment] = []
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.context = context
    self.clipboardTextItems = clipboardTextItems
    self.selectedTextItems = selectedTextItems
    self.attachments = attachments
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case startedAt
    case endedAt
    case context
    case clipboardTextItems
    case selectedTextItems
    case attachments
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.startedAt = try container.decode(Date.self, forKey: .startedAt)
    self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
    self.context = try container.decode(DictationContext.self, forKey: .context)
    self.clipboardTextItems = try container.decodeIfPresent([DictationClipboardTextItem].self, forKey: .clipboardTextItems) ?? []
    self.selectedTextItems = try container.decodeIfPresent([DictationSelectedTextItem].self, forKey: .selectedTextItems) ?? []
    self.attachments = try container.decodeIfPresent([DictationContextAttachment].self, forKey: .attachments) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(startedAt, forKey: .startedAt)
    try container.encodeIfPresent(endedAt, forKey: .endedAt)
    try container.encode(context, forKey: .context)
    try container.encode(clipboardTextItems, forKey: .clipboardTextItems)
    try container.encode(selectedTextItems, forKey: .selectedTextItems)
    try container.encode(attachments, forKey: .attachments)
  }
}

public struct DictationContextCaptureLimits: Equatable, Sendable {
  public var maxClipboardItems: Int
  public var maxClipboardCharacters: Int
  public var maxClipboardItemCharacters: Int
  public var preRecordingClipboardWindow: TimeInterval
  public var clipboardHistoryRetention: TimeInterval
  public var maxSelectedTextItems: Int
  public var maxSelectedTextCharacters: Int
  public var maxSelectedTextItemCharacters: Int
  public var maxAttachments: Int

  public init(
    maxClipboardItems: Int = 32,
    maxClipboardCharacters: Int = 20_000,
    maxClipboardItemCharacters: Int = 6_000,
    preRecordingClipboardWindow: TimeInterval = 3,
    clipboardHistoryRetention: TimeInterval = 30,
    maxSelectedTextItems: Int = 8,
    maxSelectedTextCharacters: Int = 12_000,
    maxSelectedTextItemCharacters: Int = 6_000,
    maxAttachments: Int = 32
  ) {
    self.maxClipboardItems = max(0, maxClipboardItems)
    self.maxClipboardCharacters = max(0, maxClipboardCharacters)
    self.maxClipboardItemCharacters = max(0, maxClipboardItemCharacters)
    self.preRecordingClipboardWindow = max(0, preRecordingClipboardWindow)
    self.clipboardHistoryRetention = max(preRecordingClipboardWindow, clipboardHistoryRetention)
    self.maxSelectedTextItems = max(0, maxSelectedTextItems)
    self.maxSelectedTextCharacters = max(0, maxSelectedTextCharacters)
    self.maxSelectedTextItemCharacters = max(0, maxSelectedTextItemCharacters)
    self.maxAttachments = max(0, maxAttachments)
  }

  public func includesPreRecordingClipboardItem(capturedAt: Date, recordingStartedAt: Date) -> Bool {
    let earliest = recordingStartedAt.addingTimeInterval(-preRecordingClipboardWindow)
    return capturedAt >= earliest && capturedAt <= recordingStartedAt
  }

  public func shouldRetainClipboardItem(capturedAt: Date, now: Date) -> Bool {
    capturedAt >= now.addingTimeInterval(-clipboardHistoryRetention)
  }
}

public struct DictationContextCaptureBuilder: Equatable, Sendable {
  public private(set) var startedAt: Date
  public private(set) var context: DictationContext
  public private(set) var clipboardTextItems: [DictationClipboardTextItem]
  public private(set) var selectedTextItems: [DictationSelectedTextItem]
  public private(set) var attachments: [DictationContextAttachment]
  public var limits: DictationContextCaptureLimits

  public init(
    startedAt: Date,
    context: DictationContext = .init(),
    clipboardTextItems: [DictationClipboardTextItem] = [],
    selectedTextItems: [DictationSelectedTextItem] = [],
    attachments: [DictationContextAttachment] = [],
    limits: DictationContextCaptureLimits = .init()
  ) {
    self.startedAt = startedAt
    self.context = context
    self.clipboardTextItems = []
    self.selectedTextItems = []
    self.attachments = []
    self.limits = limits
    for item in clipboardTextItems {
      appendClipboardText(item.text, source: item.source, capturedAt: item.capturedAt)
    }
    for item in selectedTextItems {
      appendSelectedText(item.text, source: item.source, capturedAt: item.capturedAt)
    }
    for attachment in attachments {
      appendAttachment(attachment)
    }
  }

  public mutating func updateContext(_ context: DictationContext) {
    let clipboardText = self.context.clipboardText
    let selectedText = self.context.selectedText
    let screenText = self.context.application?.screenText
    self.context = context
    self.context.clipboardText = clipboardText
    self.context.selectedText = selectedText
    if self.context.application?.screenText == nil {
      self.context.application?.screenText = screenText
    }
  }

  public mutating func appendSelectedText(
    _ text: String?,
    source: DictationSelectionContextSource,
    capturedAt: Date = Date()
  ) {
    guard let text = normalizedText(text) else { return }
    let clipped = String(text.prefix(limits.maxSelectedTextItemCharacters))
    guard !selectedTextItems.contains(where: { $0.text == clipped }) else { return }
    selectedTextItems.append(
      DictationSelectedTextItem(source: source, text: clipped, capturedAt: capturedAt)
    )
    if selectedTextItems.count > limits.maxSelectedTextItems {
      selectedTextItems.removeFirst(selectedTextItems.count - limits.maxSelectedTextItems)
    }
    updateSelectionContextText()
  }

  public mutating func appendClipboardText(
    _ text: String?,
    source: DictationClipboardContextSource,
    capturedAt: Date = Date()
  ) {
    guard let text = normalizedText(text) else { return }
    let clipped = String(text.prefix(limits.maxClipboardItemCharacters))
    guard !clipboardTextItems.contains(where: { $0.text == clipped }) else { return }
    clipboardTextItems.append(
      DictationClipboardTextItem(source: source, text: clipped, capturedAt: capturedAt)
    )
    if clipboardTextItems.count > limits.maxClipboardItems {
      clipboardTextItems.removeFirst(clipboardTextItems.count - limits.maxClipboardItems)
    }
    updateClipboardContextText()
  }

  public mutating func appendAttachment(_ attachment: DictationContextAttachment) {
    guard limits.maxAttachments > 0 else { return }
    guard
      !attachments.contains(where: { existing in
        existing.kind == attachment.kind
          && existing.source == attachment.source
          && existing.uniformTypeIdentifier == attachment.uniformTypeIdentifier
          && existing.filename == attachment.filename
          && existing.byteCount == attachment.byteCount
      })
    else {
      return
    }
    attachments.append(attachment)
    if attachments.count > limits.maxAttachments {
      attachments.removeFirst(attachments.count - limits.maxAttachments)
    }
    updateClipboardContextText()
  }

  public mutating func appendScreenContext(
    text: String?,
    attachment: DictationContextAttachment?
  ) {
    if let text = normalizedText(text) {
      if context.application == nil {
        context.application = ApplicationContext(name: "Unknown Application")
      }
      context.application?.screenText = text
    }
    if let attachment {
      appendAttachment(attachment)
    }
  }

  public func snapshot(endedAt: Date? = nil) -> DictationContextSnapshot {
    DictationContextSnapshot(
      startedAt: startedAt,
      endedAt: endedAt,
      context: context,
      clipboardTextItems: clipboardTextItems,
      selectedTextItems: selectedTextItems,
      attachments: attachments
    )
  }

  private mutating func updateSelectionContextText() {
    let rendered = renderSelectedText()
    context.selectedText = rendered.isEmpty ? nil : rendered
  }

  private mutating func updateClipboardContextText() {
    let rendered = renderClipboardText()
    context.clipboardText = rendered.isEmpty ? nil : rendered
  }

  private func renderClipboardText() -> String {
    let sections =
      clipboardTextItems.map { item in
        ContextSection(
          capturedAt: item.capturedAt,
          text: "\(label(for: item.source)):\n\(item.text)"
        )
      }
      + attachments.compactMap { attachment -> ContextSection? in
        guard let source = attachment.source else { return nil }
        return ContextSection(
          capturedAt: attachment.capturedAt,
          text: "\(label(for: source)) attachment:\n\(attachmentSummary(attachment))"
        )
      }

    var rendered = ""
    for section in sections.sorted(by: { $0.capturedAt < $1.capturedAt }) {
      let candidate = rendered.isEmpty ? section.text : "\(rendered)\n\n\(section.text)"
      if candidate.count > limits.maxClipboardCharacters {
        break
      }
      rendered = candidate
    }
    return rendered
  }

  private func renderSelectedText() -> String {
    var rendered = ""
    for item in selectedTextItems {
      let section = selectedTextItems.count == 1 ? item.text : "\(label(for: item.source)):\n\(item.text)"
      let candidate = rendered.isEmpty ? section : "\(rendered)\n\n\(section)"
      if candidate.count > limits.maxSelectedTextCharacters {
        break
      }
      rendered = candidate
    }
    return rendered
  }

  private func label(for source: DictationClipboardContextSource) -> String {
    switch source {
    case .beforeRecording:
      return "Clipboard before recording"
    case .duringRecording:
      return "Clipboard copied during recording"
    }
  }

  private func label(for source: DictationSelectionContextSource) -> String {
    switch source {
    case .recordingStart:
      return "Selected text at recording start"
    case .duringRecording:
      return "Selected text changed during recording"
    }
  }

  private func attachmentSummary(_ attachment: DictationContextAttachment) -> String {
    var parts: [String] = []
    switch attachment.kind {
    case .clipboardFile:
      parts.append("File: \(attachment.filename ?? "unknown")")
    case .clipboardImage:
      parts.append("Image: \(attachment.filename ?? "clipboard image")")
    case .screenImage:
      parts.append("Screen image: \(attachment.filename ?? "screen image")")
    }
    if let uniformTypeIdentifier = attachment.uniformTypeIdentifier {
      parts.append("Type: \(uniformTypeIdentifier)")
    }
    if let byteCount = attachment.byteCount {
      parts.append("Bytes: \(byteCount)")
    }
    if let localPath = attachment.localPath {
      parts.append("Path: \(localPath)")
    }
    return parts.joined(separator: "\n")
  }
}

private struct ContextSection {
  var capturedAt: Date
  var text: String
}

private func normalizedText(_ text: String?) -> String? {
  guard let text else { return nil }
  let normalized =
    text
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  return normalized.isEmpty ? nil : normalized
}
