import Foundation

@MainActor
final class DictationContextCaptureService {
  private let attachmentDirectory: URL?
  private let clipboardMonitor: DictationClipboardMonitor
  private let limits: DictationContextCaptureLimits

  init(limits: DictationContextCaptureLimits = .init()) {
    self.limits = limits
    attachmentDirectory = Self.makeAttachmentDirectory()
    clipboardMonitor = DictationClipboardMonitor(
      attachmentDirectory: attachmentDirectory,
      limits: limits
    )
    clipboardMonitor.start()
  }

  func startSession(mode: DictationMode, startedAt: Date = .now) async -> DictationContextCaptureSession? {
    let options = mode.effectiveTextTransformContextOptions
    guard mode.usesTextTransform, options.capturesAnyContext else {
      return nil
    }
    if options.includeClipboardContext {
      clipboardMonitor.captureIfChanged(capturedAt: startedAt, force: true)
    }
    let session = DictationContextCaptureSession(
      mode: mode,
      startedAt: startedAt,
      clipboardMonitor: clipboardMonitor,
      attachmentDirectory: attachmentDirectory,
      limits: limits
    )
    await session.prepare()
    session.startMonitoring()
    return session
  }

  private static func makeAttachmentDirectory() -> URL? {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else { return nil }
    let directory = applicationSupport.appendingPathComponent(
      "TimberVox/ContextAttachments",
      isDirectory: true
    )
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
    } catch {
      TimberVoxLog.dictation.error("Context attachment directory failed: \(error.localizedDescription)")
      return nil
    }
  }
}

@MainActor
final class DictationContextCaptureSession {
  private let mode: DictationMode
  private let clipboardMonitor: DictationClipboardMonitor
  private let attachmentDirectory: URL?
  private var builder: DictationContextCaptureBuilder
  private var importedClipboardChangeCounts: Set<Int> = []
  private var task: Task<Void, Never>?

  init(
    mode: DictationMode,
    startedAt: Date,
    clipboardMonitor: DictationClipboardMonitor,
    attachmentDirectory: URL?,
    limits: DictationContextCaptureLimits
  ) {
    self.mode = mode
    self.clipboardMonitor = clipboardMonitor
    self.attachmentDirectory = attachmentDirectory
    let context = SystemDictationContextProvider.capture(for: mode)
    builder = DictationContextCaptureBuilder(
      startedAt: startedAt,
      context: context,
      limits: limits
    )
    if mode.effectiveTextTransformContextOptions.includeSelectionContext {
      builder.appendSelectedText(
        context.selectedText,
        source: .recordingStart,
        capturedAt: startedAt
      )
    }
    importClipboardSnapshots(through: startedAt)
  }

  func prepare() async {
    await captureScreen(capturedAt: builder.startedAt)
  }

  func startMonitoring() {
    task?.cancel()
    task = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(300))
        self?.refresh(capturedAt: .now)
      }
    }
  }

  func finish(endedAt: Date = .now) async -> DictationContextSnapshot {
    refresh(capturedAt: endedAt)
    await captureScreen(capturedAt: endedAt)
    stopMonitoring()
    return builder.snapshot(endedAt: endedAt)
  }

  func cancel() {
    stopMonitoring()
    cleanupAttachments()
  }

  func cleanupAttachments() {
    DictationContextAttachmentCleanup.removeOwnedFiles(
      in: builder.snapshot().attachments
    )
  }

  private func stopMonitoring() {
    task?.cancel()
    task = nil
  }

  var currentContext: DictationContext {
    builder.snapshot().context
  }

  private func refresh(capturedAt: Date) {
    let options = mode.effectiveTextTransformContextOptions
    if options.includeClipboardContext {
      clipboardMonitor.captureIfChanged(capturedAt: capturedAt)
      importClipboardSnapshots(through: capturedAt)
    }
    let context = SystemDictationContextProvider.capture(for: mode)
    builder.updateContext(context)
    if options.includeSelectionContext {
      builder.appendSelectedText(
        context.selectedText,
        source: .duringRecording,
        capturedAt: capturedAt
      )
    }
  }

  private func importClipboardSnapshots(through now: Date) {
    guard mode.effectiveTextTransformContextOptions.includeClipboardContext else { return }
    for snapshot in clipboardMonitor.snapshots(startedAt: builder.startedAt, through: now)
    where !importedClipboardChangeCounts.contains(snapshot.changeCount) {
      importedClipboardChangeCounts.insert(snapshot.changeCount)
      let source: ClipboardContextSource =
        snapshot.capturedAt <= builder.startedAt
        ? .beforeRecording
        : .duringRecording
      builder.appendClipboardText(snapshot.text, source: source, capturedAt: snapshot.capturedAt)
      for attachment in snapshot.attachments {
        var contextualAttachment = attachment
        contextualAttachment.source = source
        builder.appendAttachment(contextualAttachment)
      }
    }
  }

  private func captureScreen(capturedAt: Date) async {
    guard mode.effectiveTextTransformContextOptions.includeScreenContext else { return }
    let result = await ScreenContextCapture.capture(
      attachmentDirectory: attachmentDirectory,
      capturedAt: capturedAt
    )
    builder.appendScreen(
      text: result.text,
      attachment: result.attachment,
      capturedAt: capturedAt
    )
  }
}
