import Foundation
import ToyLocalCore

extension SettingsStore {
  private enum ShortcutCaptureTarget {
    case recording
    case pasteLastTranscript
    case alwaysOnPaste
    case alwaysOnDump

    var allowsModifierOnly: Bool {
      self != .pasteLastTranscript
    }

    var allowsKeyWithoutModifier: Bool {
      self != .pasteLastTranscript
    }
  }

  var isSettingAnyHotKey: Bool {
    isSettingHotKey
      || isSettingPasteLastTranscriptHotkey
      || isSettingAlwaysOnPasteHotkey
      || isSettingAlwaysOnDumpHotkey
  }

  var recordingHotKeyKeys: [String] {
    Self.displayKeys(for: toyLocalSettings.hotkey)
  }

  var pasteLastTranscriptHotKeyKeys: [String] {
    Self.displayKeys(for: toyLocalSettings.pasteLastTranscriptHotkey)
  }

  var alwaysOnPasteHotKeyKeys: [String] {
    Self.displayKeys(for: toyLocalSettings.alwaysOnPasteHotkey)
  }

  var alwaysOnDumpHotKeyKeys: [String] {
    Self.displayKeys(for: toyLocalSettings.alwaysOnDumpHotkey)
  }

  var defaultRecordingHotKeyKeys: [String] {
    Self.displayKeys(for: ToyLocalSettings().hotkey)
  }

  var defaultPasteLastTranscriptHotKeyKeys: [String] {
    Self.displayKeys(for: ToyLocalSettings.defaultPasteLastTranscriptHotkey)
  }

  var defaultAlwaysOnPasteHotKeyKeys: [String] {
    Self.displayKeys(for: HotKey(key: nil, modifiers: [.fn]))
  }

  func startSettingHotKey() {
    clearShortcutCaptureState()
    isSettingHotKey = true
  }

  func startSettingPasteLastTranscriptHotkey() {
    clearShortcutCaptureState()
    isSettingPasteLastTranscriptHotkey = true
    currentPasteLastModifiers = .init(modifiers: [])
  }

  func startSettingAlwaysOnPasteHotkey() {
    clearShortcutCaptureState()
    isSettingAlwaysOnPasteHotkey = true
    currentAlwaysOnPasteModifiers = .init(modifiers: [])
  }

  func startSettingAlwaysOnDumpHotkey() {
    clearShortcutCaptureState()
    isSettingAlwaysOnDumpHotkey = true
    currentAlwaysOnDumpModifiers = .init(modifiers: [])
  }

  func beginRecordingHotKeyCapture() {
    startSettingHotKey()
    startShortcutCaptureMonitoring()
  }

  func beginPasteLastTranscriptHotkeyCapture() {
    startSettingPasteLastTranscriptHotkey()
    startShortcutCaptureMonitoring()
  }

  func beginAlwaysOnPasteHotkeyCapture() {
    startSettingAlwaysOnPasteHotkey()
    startShortcutCaptureMonitoring()
  }

  func beginAlwaysOnDumpHotkeyCapture() {
    startSettingAlwaysOnDumpHotkey()
    startShortcutCaptureMonitoring()
  }

  func cancelShortcutCapture() {
    shortcutCaptureToken?.cancel()
    shortcutCaptureToken = nil
    clearShortcutCaptureState()
  }

  func clearPasteLastTranscriptHotkey() {
    toyLocalSettings.pasteLastTranscriptHotkey = nil
  }

  func clearAlwaysOnPasteHotkey() {
    toyLocalSettings.alwaysOnPasteHotkey = nil
  }

  func clearAlwaysOnDumpHotkey() {
    toyLocalSettings.alwaysOnDumpHotkey = nil
  }

  func resetRecordingHotKey() {
    toyLocalSettings.hotkey = ToyLocalSettings().hotkey
  }

  func resetPasteLastTranscriptHotkey() {
    toyLocalSettings.pasteLastTranscriptHotkey = ToyLocalSettings.defaultPasteLastTranscriptHotkey
  }

  func resetAlwaysOnPasteHotkey() {
    toyLocalSettings.alwaysOnPasteHotkey = HotKey(key: nil, modifiers: [.fn])
  }

  @discardableResult
  func handleKeyEvent(_ keyEvent: KeyEvent) -> Bool {
    guard let target = shortcutCaptureTarget else { return false }
    if keyEvent.key == .escape {
      finishShortcutCapture(target)
      return true
    }

    let mods = keyEvent.modifiers.union(captureModifiers(for: target))
    setCurrentModifiers(mods, for: target)
    if let key = keyEvent.key {
      guard target.allowsKeyWithoutModifier || !mods.isEmpty else { return false }
      setCapturedHotKey(HotKey(key: key, modifiers: mods.erasingSides()), for: target)
      finishShortcutCapture(target)
      return true
    } else if target.allowsModifierOnly, keyEvent.modifiers.isEmpty, !mods.isEmpty {
      setCapturedHotKey(HotKey(key: nil, modifiers: mods.erasingSides()), for: target)
      finishShortcutCapture(target)
      return true
    }
    return false
  }

  private var shortcutCaptureTarget: ShortcutCaptureTarget? {
    if isSettingHotKey { return .recording }
    if isSettingPasteLastTranscriptHotkey { return .pasteLastTranscript }
    if isSettingAlwaysOnPasteHotkey { return .alwaysOnPaste }
    if isSettingAlwaysOnDumpHotkey { return .alwaysOnDump }
    return nil
  }

  private func startShortcutCaptureMonitoring() {
    shortcutCaptureToken?.cancel()
    let token = keyEventMonitor.handleKeyEvent { [weak self] keyEvent in
      guard let self else { return false }
      return MainActor.assumeIsolated {
        guard self.shortcutCaptureTarget != nil else { return false }
        let didFinish = self.handleKeyEvent(keyEvent)
        if didFinish {
          self.finishShortcutCaptureMonitoring()
        }
        return true
      }
    }
    shortcutCaptureToken = token
  }

  private func finishShortcutCaptureMonitoring() {
    shortcutCaptureToken?.cancel()
    shortcutCaptureToken = nil
  }

  private func clearShortcutCaptureState() {
    isSettingHotKey = false
    isSettingPasteLastTranscriptHotkey = false
    isSettingAlwaysOnPasteHotkey = false
    isSettingAlwaysOnDumpHotkey = false
    currentModifiers = []
    currentPasteLastModifiers = []
    currentAlwaysOnPasteModifiers = []
    currentAlwaysOnDumpModifiers = []
  }

  private func finishShortcutCapture(_ target: ShortcutCaptureTarget) {
    switch target {
    case .recording:
      isSettingHotKey = false
      currentModifiers = []
    case .pasteLastTranscript:
      isSettingPasteLastTranscriptHotkey = false
      currentPasteLastModifiers = []
    case .alwaysOnPaste:
      isSettingAlwaysOnPasteHotkey = false
      currentAlwaysOnPasteModifiers = []
    case .alwaysOnDump:
      isSettingAlwaysOnDumpHotkey = false
      currentAlwaysOnDumpModifiers = []
    }
  }

  private func captureModifiers(for target: ShortcutCaptureTarget) -> Modifiers {
    switch target {
    case .recording: currentModifiers
    case .pasteLastTranscript: currentPasteLastModifiers
    case .alwaysOnPaste: currentAlwaysOnPasteModifiers
    case .alwaysOnDump: currentAlwaysOnDumpModifiers
    }
  }

  private func setCurrentModifiers(_ modifiers: Modifiers, for target: ShortcutCaptureTarget) {
    switch target {
    case .recording:
      currentModifiers = modifiers
    case .pasteLastTranscript:
      currentPasteLastModifiers = modifiers
    case .alwaysOnPaste:
      currentAlwaysOnPasteModifiers = modifiers
    case .alwaysOnDump:
      currentAlwaysOnDumpModifiers = modifiers
    }
  }

  private func setCapturedHotKey(_ hotKey: HotKey, for target: ShortcutCaptureTarget) {
    switch target {
    case .recording:
      toyLocalSettings.hotkey = hotKey
    case .pasteLastTranscript:
      toyLocalSettings.pasteLastTranscriptHotkey = hotKey
    case .alwaysOnPaste:
      toyLocalSettings.alwaysOnPasteHotkey = hotKey
    case .alwaysOnDump:
      toyLocalSettings.alwaysOnDumpHotkey = hotKey
    }
  }

  private static func displayKeys(for hotKey: HotKey?) -> [String] {
    guard let hotKey else { return [] }
    return hotKey.modifiers.sorted.map { $0.stringValue } + [hotKey.key?.toString].compactMap { $0 }
  }
}
