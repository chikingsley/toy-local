import AppKit
import TimberVoxCore
import Foundation

private let clipboardContextCaptureLogger = TimberVoxLog.transcription

@MainActor
final class DictationClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let attachmentDirectory: URL?
  private let limits: DictationContextCaptureLimits
  private var lastPasteboardChangeCount: Int
  private var snapshots: [DictationClipboardSnapshot] = []
  private var task: Task<Void, Never>?
  private(set) var isRunning = false

  init(
    pasteboard: NSPasteboard,
    attachmentDirectory: URL?,
    limits: DictationContextCaptureLimits
  ) {
    self.pasteboard = pasteboard
    self.attachmentDirectory = attachmentDirectory
    self.limits = limits
    self.lastPasteboardChangeCount = pasteboard.changeCount
  }

  func start() {
    guard !isRunning else { return }
    isRunning = true
    lastPasteboardChangeCount = pasteboard.changeCount
    task?.cancel()
    task = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(300))
        self?.captureCurrentPasteboardIfChanged()
      }
    }
  }

  func stop(clearSnapshots: Bool = false) {
    task?.cancel()
    task = nil
    isRunning = false
    if clearSnapshots {
      snapshots.removeAll()
    }
  }

  func captureCurrentPasteboardIfChanged(capturedAt: Date = Date()) {
    let changeCount = pasteboard.changeCount
    guard changeCount != lastPasteboardChangeCount else {
      pruneSnapshots(now: capturedAt)
      return
    }
    lastPasteboardChangeCount = changeCount
    snapshots.append(snapshot(changeCount: changeCount, capturedAt: capturedAt))
    pruneSnapshots(now: capturedAt)
  }

  func snapshotsForRecording(startedAt: Date, now: Date) -> [DictationClipboardSnapshot] {
    snapshots.filter { snapshot in
      limits.includesPreRecordingClipboardItem(capturedAt: snapshot.capturedAt, recordingStartedAt: startedAt)
        || (snapshot.capturedAt > startedAt && snapshot.capturedAt <= now)
    }
  }

  private func pruneSnapshots(now: Date) {
    snapshots.removeAll { snapshot in
      !limits.shouldRetainClipboardItem(capturedAt: snapshot.capturedAt, now: now)
    }
  }

  private func snapshot(changeCount: Int, capturedAt: Date) -> DictationClipboardSnapshot {
    var attachments: [DictationContextAttachment] = []
    for item in pasteboard.pasteboardItems ?? [] {
      if let attachment = fileAttachment(item, capturedAt: capturedAt) {
        attachments.append(attachment)
      }
      if let attachment = imageAttachment(item, capturedAt: capturedAt) {
        attachments.append(attachment)
      }
    }
    return DictationClipboardSnapshot(
      changeCount: changeCount,
      text: pasteboard.string(forType: .string),
      attachments: attachments,
      capturedAt: capturedAt
    )
  }

  private func fileAttachment(_ item: NSPasteboardItem, capturedAt: Date) -> DictationContextAttachment? {
    guard let rawURL = item.string(forType: .fileURL),
      let url = URL(string: rawURL)
    else {
      return nil
    }
    return DictationContextAttachment(
      kind: .clipboardFile,
      uniformTypeIdentifier: NSPasteboard.PasteboardType.fileURL.rawValue,
      filename: url.lastPathComponent,
      localPath: url.path,
      capturedAt: capturedAt
    )
  }

  private func imageAttachment(_ item: NSPasteboardItem, capturedAt: Date) -> DictationContextAttachment? {
    for type in [NSPasteboard.PasteboardType.png, .tiff] {
      guard let data = item.data(forType: type) else { continue }
      let relativePath = saveAttachment(data: data, fileExtension: type == .png ? "png" : "tiff")
      return DictationContextAttachment(
        kind: .clipboardImage,
        uniformTypeIdentifier: type.rawValue,
        filename: relativePath.map { URL(fileURLWithPath: $0).lastPathComponent },
        byteCount: data.count,
        localPath: relativePath,
        capturedAt: capturedAt
      )
    }
    return nil
  }

  private func saveAttachment(data: Data, fileExtension: String) -> String? {
    guard let attachmentDirectory else { return nil }
    let filename = "\(UUID().uuidString).\(fileExtension)"
    let url = attachmentDirectory.appending(component: filename)
    do {
      try data.write(to: url, options: .atomic)
      return "ContextAttachments/\(filename)"
    } catch {
      clipboardContextCaptureLogger.error("Failed to save context attachment: \(error.localizedDescription)")
      return nil
    }
  }
}

struct DictationClipboardSnapshot {
  var changeCount: Int
  var text: String?
  var attachments: [DictationContextAttachment]
  var capturedAt: Date
}
