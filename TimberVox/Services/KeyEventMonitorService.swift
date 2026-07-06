import AppKit
@preconcurrency import ApplicationServices
import TimberVoxCore
import Carbon
import CoreGraphics
import Foundation
import Sauce

private let logger = TimberVoxLog.keyEvent
private let axTrustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"

struct KeyEventMonitorToken: Sendable {
  private let cancelHandler: @Sendable () -> Void

  init(cancel: @escaping @Sendable () -> Void) {
    self.cancelHandler = cancel
  }

  func cancel() {
    cancelHandler()
  }

  static let noop = KeyEventMonitorToken {}
}

public extension KeyEvent {
  init(cgEvent: CGEvent, type: CGEventType, isFnPressed: Bool) {
    let keyCode = Int(cgEvent.getIntegerValueField(.keyboardEventKeycode))
    let key: Key?
    if cgEvent.type == .keyDown {
      if Thread.isMainThread {
        key = Sauce.shared.key(for: keyCode)
      } else {
        key = DispatchQueue.main.sync { Sauce.shared.key(for: keyCode) }
      }
    } else {
      key = nil
    }

    var modifiers = Modifiers.from(carbonFlags: cgEvent.flags)
    if !isFnPressed {
      // Treat Fn as active only when we have seen a real flagsChanged press.
      // Some non-Fn key events (notably arrows) can still carry the Fn mask bit.
      modifiers = modifiers.removing(kind: .fn)
    }
    self.init(key: key, modifiers: modifiers)
  }
}

class KeyEventMonitorClientLive: @unchecked Sendable {
  private var eventTapPort: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var continuations: [UUID: @Sendable (KeyEvent) -> Bool] = [:]
  private var inputContinuations: [UUID: @Sendable (InputEvent) -> Bool] = [:]
  private let queue = DispatchQueue(label: "com.chiejimofor.timbervox.KeyEventMonitor", attributes: .concurrent)
  private var isMonitoring = false
  private var wantsMonitoring = false
  private var accessibilityTrusted = false
  private var trustMonitorTask: Task<Void, Never>?
  private var isFnPressed = false
  private var hasPromptedForAccessibilityTrust = false
  private let settingsManager: SettingsManager

  private let trustCheckIntervalNanoseconds: UInt64 = 100_000_000  // 100ms

  init(settingsManager: SettingsManager) {
    self.settingsManager = settingsManager
    logger.info("Initializing HotKeyClient with CGEvent tap.")
  }

  deinit {
    self.stopMonitoring()
  }

  private var hasRequiredPermissions: Bool {
    queue.sync { accessibilityTrusted }
  }

  private var hasHandlers: Bool {
    queue.sync { !(continuations.isEmpty && inputContinuations.isEmpty) }
  }

  private func setMonitoringIntent(_ value: Bool) {
    queue.async(flags: .barrier) { [weak self] in
      self?.wantsMonitoring = value
    }
  }

  private func desiredMonitoringState() -> Bool {
    queue.sync {
      wantsMonitoring
        && accessibilityTrusted
        && !(continuations.isEmpty && inputContinuations.isEmpty)
    }
  }

  /// Provide a stream of key events.
  func listenForKeyPress() -> AsyncThrowingStream<KeyEvent, Error> {
    AsyncThrowingStream { continuation in
      let uuid = UUID()

      queue.async(flags: .barrier) { [weak self] in
        guard let self = self else { return }
        self.continuations[uuid] = { event in
          continuation.yield(event)
          return false
        }
        let shouldStart = self.continuations.count == 1 && self.inputContinuations.isEmpty

        if shouldStart {
          self.startMonitoring()
        }
      }

      continuation.onTermination = { [weak self] _ in
        self?.removeHandlerContinuation(uuid: uuid)
      }
    }
  }

  private func removeHandlerContinuation(uuid: UUID) {
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.continuations[uuid] = nil
      if self.continuations.isEmpty && self.inputContinuations.isEmpty {
        self.stopMonitoring()
      }
    }
  }

  private func removeInputContinuation(uuid: UUID) {
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.inputContinuations[uuid] = nil
      if self.continuations.isEmpty && self.inputContinuations.isEmpty {
        self.stopMonitoring()
      }
    }
  }

  func startMonitoring() {
    setMonitoringIntent(true)
    startTrustMonitorIfNeeded()
    refreshTrustedFlag(promptIfUntrusted: true)
    Task { [weak self] in
      await self?.refreshMonitoringState(reason: "startMonitoring")
    }
  }

  func handleKeyEvent(_ handler: @Sendable @escaping (KeyEvent) -> Bool) -> KeyEventMonitorToken {
    let uuid = UUID()

    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.continuations[uuid] = handler
      let shouldStart = self.continuations.count == 1 && self.inputContinuations.isEmpty

      if shouldStart {
        self.startMonitoring()
      }
    }

    return KeyEventMonitorToken { [weak self] in
      self?.removeHandlerContinuation(uuid: uuid)
    }
  }

  func handleInputEvent(_ handler: @Sendable @escaping (InputEvent) -> Bool) -> KeyEventMonitorToken {
    let uuid = UUID()

    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.inputContinuations[uuid] = handler
      let shouldStart = self.inputContinuations.count == 1 && self.continuations.isEmpty

      if shouldStart {
        self.startMonitoring()
      }
    }

    return KeyEventMonitorToken { [weak self] in
      self?.removeInputContinuation(uuid: uuid)
    }
  }

  func stopMonitoring() {
    setMonitoringIntent(false)
    Task { [weak self] in
      await self?.refreshMonitoringState(reason: "stopMonitoring")
    }
    cancelTrustMonitorIfNeeded()
  }

  private func startTrustMonitorIfNeeded() {
    queue.async(flags: .barrier) { [weak self] in
      guard let self else { return }
      guard self.trustMonitorTask == nil else { return }
      self.trustMonitorTask = Task { [weak self] in
        await self?.watchPermissions()
      }
    }
  }

  private func cancelTrustMonitorIfNeeded() {
    queue.async(flags: .barrier) { [weak self] in
      guard let self else { return }
      guard !self.wantsMonitoring else { return }
      self.trustMonitorTask?.cancel()
      self.trustMonitorTask = nil
    }
  }

  private func watchPermissions() async {
    var last = currentAccessibilityTrust()
    await handlePermissionChange(accessibility: last, reason: "initial")

    while !Task.isCancelled {
      try? await Task.sleep(nanoseconds: trustCheckIntervalNanoseconds)
      let current = currentAccessibilityTrust()

      if current != last {
        let reason: String
        if current && !last {
          reason = "regained"
        } else if !current && last {
          reason = "revoked"
        } else {
          reason = "updated"
        }
        await handlePermissionChange(accessibility: current, reason: reason)
        last = current
      } else if current {
        await ensureTapIsRunning()
      }
    }
  }

  private func handlePermissionChange(accessibility: Bool, reason: String) async {
    setPermissionFlags(accessibility: accessibility)
    logger.notice("Permission update: accessibility=\(accessibility), reason=\(reason)")
    if accessibility {
      logger.notice("Accessibility permission grants keyboard event access (\(reason)); hotkeys can run.")
    } else {
      logger.error("Accessibility permission missing (\(reason)); waiting before restarting hotkeys.")
    }
    await refreshMonitoringState(reason: "trust_\(reason)")
  }

  private func ensureTapIsRunning() async {
    guard desiredMonitoringState() else { return }
    await activateTapOnMain(reason: "watchdog_keepalive")
  }

  private func refreshMonitoringState(reason: String) async {
    let shouldMonitor = desiredMonitoringState()
    if shouldMonitor {
      await activateTapOnMain(reason: reason)
    } else {
      await deactivateTapOnMain(reason: reason)
    }
  }

  private func setPermissionFlags(accessibility: Bool) {
    queue.async(flags: .barrier) { [weak self] in
      self?.accessibilityTrusted = accessibility
    }
    recordSharedPermissionState(accessibility: accessibility)
  }

  private func recordSharedPermissionState(accessibility: Bool) {
    Task { @MainActor [settingsManager] in
      settingsManager.hotkeyPermissionState.accessibility = accessibility ? .granted : .denied
      settingsManager.hotkeyPermissionState.lastUpdated = Date()
    }
  }

  private func activateTapOnMain(reason: String) async {
    await MainActor.run {
      self.activateTapIfNeeded(reason: reason)
    }
  }

  private func deactivateTapOnMain(reason: String) async {
    await MainActor.run {
      self.deactivateTap(reason: reason)
    }
  }

  @MainActor
  private func activateTapIfNeeded(reason: String) {
    guard !isMonitoring, hasHandlers else { return }
    guard canActivateTap(reason: reason) else { return }
    guard let eventTap = createEventTap(reason: reason) else { return }
    installEventTap(eventTap, reason: reason)
  }

  @MainActor
  private func deactivateTap(reason: String) {
    guard isMonitoring || eventTapPort != nil else { return }

    if let runLoopSource = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      self.runLoopSource = nil
    }

    if let eventTapPort = eventTapPort {
      CGEvent.tapEnable(tap: eventTapPort, enable: false)
      self.eventTapPort = nil
    }

    isMonitoring = false
    logger.info("Suspended key event monitoring (reason: \(reason)).")
  }

}

extension KeyEventMonitorClientLive {
  fileprivate func updateFnStateIfNeeded(type: CGEventType, cgEvent: CGEvent) {
    guard type == .flagsChanged else { return }
    isFnPressed = cgEvent.flags.contains(.maskSecondaryFn)
  }

  fileprivate func refreshTrustedFlag(promptIfUntrusted: Bool) {
    var accessibilityTrusted = currentAccessibilityTrust()
    if !accessibilityTrusted && promptIfUntrusted && !hasPromptedForAccessibilityTrust {
      accessibilityTrusted = requestAccessibilityTrustPrompt()
      hasPromptedForAccessibilityTrust = true
      logger.notice("Prompted for accessibility trust")
    }

    setPermissionFlags(accessibility: accessibilityTrusted)
  }

  fileprivate func currentAccessibilityTrust() -> Bool {
    AXIsProcessTrustedWithOptions([axTrustedCheckOptionPromptKey: false] as CFDictionary)
  }

  private func requestAccessibilityTrustPrompt() -> Bool {
    AXIsProcessTrustedWithOptions([axTrustedCheckOptionPromptKey: true] as CFDictionary)
  }

}

private extension KeyEventMonitorClientLive {
  @MainActor
  func canActivateTap(reason: String) -> Bool {
    let accessibilityTrusted = currentAccessibilityTrust()
    setPermissionFlags(accessibility: accessibilityTrusted)

    guard accessibilityTrusted else {
      logger.error("Cannot start key event monitoring (reason: \(reason)); Accessibility is not granted.")
      return false
    }

    return true
  }

  @MainActor
  func createEventTap(reason: String) -> CFMachPort? {
    let callback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
      guard let userInfo else {
        return Unmanaged.passUnretained(cgEvent)
      }
      let client = Unmanaged<KeyEventMonitorClientLive>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
      return client.processTapEvent(type: type, cgEvent: cgEvent)
    }

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: monitoredEventMask,
        callback: callback,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      )
    else {
      logger.error("Failed to create event tap (reason: \(reason)).")
      return nil
    }

    return eventTap
  }

  @MainActor
  func installEventTap(_ eventTap: CFMachPort, reason: String) {
    eventTapPort = eventTap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    isMonitoring = true
    logger.info("Started monitoring key events via CGEvent tap (reason: \(reason)).")
  }

  var monitoredEventMask: CGEventMask {
    CGEventMask(1 << CGEventType.keyDown.rawValue)
      | CGEventMask(1 << CGEventType.keyUp.rawValue)
      | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
      | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
      | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
  }

  func processTapEvent(type: CGEventType, cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
      handleTapDisabledEvent(type)
      return Unmanaged.passUnretained(cgEvent)
    }

    guard hasRequiredPermissions else {
      return Unmanaged.passUnretained(cgEvent)
    }

    if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
      _ = processInputEvent(.mouseClick)
      return Unmanaged.passUnretained(cgEvent)
    }

    updateFnStateIfNeeded(type: type, cgEvent: cgEvent)
    let keyEvent = KeyEvent(cgEvent: cgEvent, type: type, isFnPressed: isFnPressed)
    let handledByKeyHandler = processKeyEvent(keyEvent)
    let handledByInputHandler = processInputEvent(.keyboard(keyEvent))
    return (handledByKeyHandler || handledByInputHandler) ? nil : Unmanaged.passUnretained(cgEvent)
  }

  func handleTapDisabledEvent(_ type: CGEventType) {
    let reason = type == .tapDisabledByTimeout ? "timeout" : "userInput"
    logger.error("Event tap disabled by \(reason); scheduling restart.")
    Task { [weak self] in
      guard let self else { return }
      await self.refreshMonitoringState(reason: "tap_disabled_\(reason)")
    }
  }

  func processEvent<T>(_ event: T, handlers: [UUID: @Sendable (T) -> Bool]) -> Bool {
    let handlerList = queue.sync { Array(handlers.values) }
    var handled = false
    for handler in handlerList where handler(event) {
      handled = true
    }
    return handled
  }

  func processKeyEvent(_ keyEvent: KeyEvent) -> Bool {
    processEvent(keyEvent, handlers: continuations)
  }

  func processInputEvent(_ inputEvent: InputEvent) -> Bool {
    processEvent(inputEvent, handlers: inputContinuations)
  }
}
