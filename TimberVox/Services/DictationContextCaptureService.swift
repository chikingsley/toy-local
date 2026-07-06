import AppKit
import ApplicationServices
import TimberVoxCore
import Foundation

private let contextCaptureLogger = TimberVoxLog.transcription

@MainActor
final class DictationContextCaptureClientLive {
  let settingsManager: SettingsManager
  private let attachmentDirectory: URL?
  private let clipboardMonitor: DictationClipboardMonitor
  private let limits: DictationContextCaptureLimits
  private var clipboardMonitorStateTask: Task<Void, Never>?

  init(
    settingsManager: SettingsManager,
    pasteboard: NSPasteboard = .general,
    limits: DictationContextCaptureLimits = .init()
  ) {
    self.settingsManager = settingsManager
    self.limits = limits
    self.attachmentDirectory = Self.attachmentDirectory()
    self.clipboardMonitor = DictationClipboardMonitor(
      pasteboard: pasteboard,
      attachmentDirectory: self.attachmentDirectory,
      limits: limits
    )
    syncClipboardMonitorState()
    startClipboardMonitorStateTask()
  }

  deinit {
    let monitor = clipboardMonitor
    clipboardMonitorStateTask?.cancel()
    Task { @MainActor in
      monitor.stop()
    }
  }

  func startSession(startedAt: Date = Date()) -> DictationContextCaptureSession {
    let settings = settingsManager.settings
    syncClipboardMonitorState(for: settings)
    if settings.textTransformContextOptions.includeClipboardContext {
      clipboardMonitor.captureCurrentPasteboardIfChanged(capturedAt: startedAt)
    }
    let session = DictationContextCaptureSession(
      startedAt: startedAt,
      settings: settings,
      clipboardMonitor: clipboardMonitor,
      attachmentDirectory: attachmentDirectory,
      limits: limits
    )
    session.startContextMonitoring()
    return session
  }

  private static func attachmentDirectory() -> URL? {
    do {
      let directory = try URL.timberVoxApplicationSupport.appending(component: "ContextAttachments", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
    } catch {
      contextCaptureLogger.error("Failed to prepare context attachment directory: \(error.localizedDescription)")
      return nil
    }
  }

  private func startClipboardMonitorStateTask() {
    clipboardMonitorStateTask?.cancel()
    clipboardMonitorStateTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(500))
        self?.syncClipboardMonitorState()
      }
    }
  }

  private func syncClipboardMonitorState() {
    syncClipboardMonitorState(for: settingsManager.settings)
  }

  private func syncClipboardMonitorState(for settings: TimberVoxSettings) {
    let shouldMonitor =
      settings.textTransformMode.usesTextTransform
      && settings.textTransformContextOptions.includeClipboardContext
    if shouldMonitor {
      clipboardMonitor.start()
    } else {
      clipboardMonitor.stop(clearSnapshots: true)
    }
  }
}

@MainActor
final class DictationContextCaptureSession {
  private var builder: DictationContextCaptureBuilder
  private let settings: TimberVoxSettings
  private let clipboardMonitor: DictationClipboardMonitor
  private let attachmentDirectory: URL?
  private var importedClipboardChangeCounts: Set<Int> = []
  private var contextTask: Task<Void, Never>?

  init(
    startedAt: Date,
    settings: TimberVoxSettings,
    clipboardMonitor: DictationClipboardMonitor,
    attachmentDirectory: URL?,
    limits: DictationContextCaptureLimits
  ) {
    self.settings = settings
    self.clipboardMonitor = clipboardMonitor
    self.attachmentDirectory = attachmentDirectory
    let context = Self.currentContext(settings: settings, capturedAt: startedAt)
    self.builder = DictationContextCaptureBuilder(
      startedAt: startedAt,
      context: context,
      limits: limits
    )
    if settings.textTransformContextOptions.includeSelectionContext {
      builder.appendSelectedText(context.selectedText, source: .recordingStart, capturedAt: startedAt)
    }
    if settings.textTransformContextOptions.includeClipboardContext {
      importClipboardSnapshots(upTo: startedAt)
    }
    captureScreenContext(capturedAt: startedAt)
  }

  deinit {
    contextTask?.cancel()
  }

  func startContextMonitoring() {
    contextTask?.cancel()
    contextTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(300))
        self?.refreshDuringRecordingContext()
      }
    }
  }

  func cancel() {
    contextTask?.cancel()
    contextTask = nil
  }

  func finish(endedAt: Date = Date()) -> DictationContextSnapshot {
    refreshDuringRecordingContext(capturedAt: endedAt)
    captureScreenContext(capturedAt: endedAt)
    cancel()
    return builder.snapshot(endedAt: endedAt)
  }

  var currentSnapshot: DictationContextSnapshot {
    builder.snapshot()
  }

  private func refreshDuringRecordingContext(capturedAt: Date = Date()) {
    if settings.textTransformContextOptions.includeClipboardContext {
      clipboardMonitor.captureCurrentPasteboardIfChanged(capturedAt: capturedAt)
      importClipboardSnapshots(upTo: capturedAt)
    }
    let context = Self.currentContext(settings: settings, capturedAt: capturedAt)
    builder.updateContext(context)
    if settings.textTransformContextOptions.includeSelectionContext {
      builder.appendSelectedText(context.selectedText, source: .duringRecording, capturedAt: capturedAt)
    }
  }

  private func captureScreenContext(capturedAt: Date) {
    guard settings.textTransformMode.usesTextTransform else { return }
    guard settings.textTransformContextOptions.includeApplicationContext else { return }
    let result = ScreenContextCapture.capture(
      attachmentDirectory: attachmentDirectory,
      capturedAt: capturedAt
    )
    builder.appendScreenContext(text: result.text, attachment: result.attachment)
  }

  private func importClipboardSnapshots(upTo now: Date) {
    guard settings.textTransformContextOptions.includeClipboardContext else { return }
    let snapshots = clipboardMonitor.snapshotsForRecording(startedAt: builder.startedAt, now: now)
    for snapshot in snapshots where !importedClipboardChangeCounts.contains(snapshot.changeCount) {
      let source: DictationClipboardContextSource = snapshot.capturedAt <= builder.startedAt ? .beforeRecording : .duringRecording
      importedClipboardChangeCounts.insert(snapshot.changeCount)
      builder.appendClipboardText(snapshot.text, source: source, capturedAt: snapshot.capturedAt)
      for attachment in snapshot.attachments {
        var imported = attachment
        imported.source = source
        builder.appendAttachment(imported)
      }
    }
  }

  private static func currentContext(settings: TimberVoxSettings, capturedAt: Date) -> DictationContext {
    let options = settings.textTransformContextOptions
    let app = options.includeApplicationContext ? NSWorkspace.shared.frontmostApplication : nil
    let focusedElement = options.includeApplicationContext ? focusedElementContext() : nil
    return DictationContext(
      application: app.map(applicationContext),
      focusedElement: focusedElement,
      selectedText: options.includeSelectionContext ? selectedText() : nil,
      vocabulary: vocabulary(from: settings),
      system: systemContext(settings: settings, capturedAt: capturedAt),
      user: userContext()
    )
  }

  private static func applicationContext(_ app: NSRunningApplication) -> ApplicationContext {
    let window = focusedWindow(for: app)
    let windowTitle = window.flatMap { stringAttribute(kAXTitleAttribute, element: $0) }
    return ApplicationContext(
      name: app.localizedName ?? app.bundleIdentifier ?? "Unknown Application",
      category: nil,
      description: nil,
      textInputFormat: nil,
      bundleIdentifier: app.bundleIdentifier,
      windowTitle: windowTitle,
      visibleText: window.flatMap { visibleText(from: $0) }
    )
  }

  private static func focusedElementContext() -> FocusedElementContext? {
    guard let focusedElement = focusedElement() else { return nil }
    return FocusedElementContext(
      role: stringAttribute(kAXRoleAttribute, element: focusedElement),
      title: stringAttribute(kAXTitleAttribute, element: focusedElement),
      description: stringAttribute(kAXDescriptionAttribute, element: focusedElement),
      content: stringAttribute(kAXValueAttribute, element: focusedElement).map { String($0.prefix(4_000)) }
    )
  }

  private static func selectedText() -> String? {
    guard let element = focusedElement() else { return nil }
    if let selectedText = stringAttribute(kAXSelectedTextAttribute, element: element) {
      return String(selectedText.prefix(6_000))
    }
    if let markerRange = copyAttribute("AXSelectedTextMarkerRange", element: element),
      let selectedText = parameterizedStringAttribute(
        "AXStringForTextMarkerRange",
        parameter: markerRange,
        element: element
      )
    {
      return String(selectedText.prefix(6_000))
    }
    if let selectedRange = copyAttribute(kAXSelectedTextRangeAttribute, element: element),
      let selectedText = parameterizedStringAttribute(
        kAXStringForRangeParameterizedAttribute,
        parameter: selectedRange,
        element: element
      )
    {
      return String(selectedText.prefix(6_000))
    }
    return nil
  }

  private static func focusedElement() -> AXUIElement? {
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElementRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
      systemWideElement,
      kAXFocusedUIElementAttribute as CFString,
      &focusedElementRef
    )
    guard result == .success,
      let focusedElementRef,
      CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID()
    else {
      return nil
    }
    return unsafeDowncast(focusedElementRef, to: AXUIElement.self)
  }

  private static func focusedWindow(for app: NSRunningApplication) -> AXUIElement? {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windowRef: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        appElement,
        kAXFocusedWindowAttribute as CFString,
        &windowRef
      ) == .success,
      let windowRef,
      CFGetTypeID(windowRef) == AXUIElementGetTypeID()
    else {
      return nil
    }
    return unsafeDowncast(windowRef, to: AXUIElement.self)
  }

  private static func stringAttribute(_ attribute: String, element: AXUIElement) -> String? {
    guard let value = copyAttribute(attribute, element: element) else { return nil }
    if CFGetTypeID(value) == CFStringGetTypeID() {
      guard let string = value as? String else { return nil }
      let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    return nil
  }

  private static func copyAttribute(_ attribute: String, element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  private static func parameterizedStringAttribute(
    _ attribute: String,
    parameter: CFTypeRef,
    element: AXUIElement
  ) -> String? {
    var value: CFTypeRef?
    guard
      AXUIElementCopyParameterizedAttributeValue(
        element,
        attribute as CFString,
        parameter,
        &value
      ) == .success,
      let value,
      CFGetTypeID(value) == CFStringGetTypeID(),
      let string = value as? String
    else {
      return nil
    }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func visibleText(from root: AXUIElement) -> String? {
    var collector = AXVisibleTextCollector(maxNodes: 240, maxCharacters: 10_000)
    collector.collect(from: root)
    return collector.renderedText
  }

  private static func systemContext(settings: TimberVoxSettings, capturedAt: Date) -> SystemContext {
    SystemContext(
      language: settings.outputLanguage,
      currentTime: capturedAt.formatted(date: .complete, time: .complete),
      timeZone: TimeZone.current.identifier,
      locale: Locale.current.identifier,
      computerName: Host.current().localizedName
    )
  }

  private static func userContext() -> UserContext {
    let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
    return UserContext(fullName: fullName.isEmpty ? nil : fullName)
  }

  private static func vocabulary(from settings: TimberVoxSettings) -> [String] {
    settings.wordRemappings
      .flatMap { [$0.match, $0.replacement] }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .uniqued()
  }
}

private extension Array where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
