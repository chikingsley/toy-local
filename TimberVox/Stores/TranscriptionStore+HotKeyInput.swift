import TimberVoxCore
import Foundation

extension TranscriptionStore {
  func runHotKeyMonitoringLoop() async {
    let token = keyEventMonitor.handleInputEvent { [weak self] inputEvent in
      guard let self else { return false }
      return MainActor.assumeIsolated {
        self.handleHotKeyInputEvent(inputEvent)
      }
    }

    defer { token.cancel() }

    await withTaskCancellationHandler {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
      }
    } onCancel: {
      token.cancel()
    }
  }

  func handleHotKeyInputEvent(_ inputEvent: InputEvent) -> Bool {
    guard !settings.settings.alwaysOnEnabled else { return false }
    guard !settings.isSettingAnyHotKey else { return false }

    hotKeyProcessor.hotkey = settings.settings.hotkey
    hotKeyProcessor.useDoubleTapOnly = settings.settings.useDoubleTapOnly
    hotKeyProcessor.minimumKeyTime = settings.settings.minimumKeyTime

    switch inputEvent {
    case .keyboard(let keyEvent):
      return handleKeyboardInputEvent(keyEvent)
    case .mouseClick:
      return handleMouseClickInputEvent()
    }
  }

  func handleKeyboardInputEvent(_ keyEvent: KeyEvent) -> Bool {
    if keyEvent.key == .escape,
      keyEvent.modifiers.isEmpty,
      hotKeyProcessor.state == .idle
    {
      Task { @MainActor in cancel() }
      return false
    }

    let output = hotKeyProcessor.process(keyEvent: keyEvent)
    switch output {
    case .startRecording:
      if hotKeyProcessor.state == .doubleTapLock {
        Task { @MainActor in startRecording() }
      } else {
        Task { @MainActor in hotKeyPressed() }
      }
      return settings.settings.useDoubleTapOnly || keyEvent.key != nil
    case .stopRecording:
      Task { @MainActor in hotKeyReleased() }
      return false
    case .cancel:
      Task { @MainActor in cancel() }
      return true
    case .discard:
      Task { @MainActor in discard() }
      return false
    case .none:
      guard let pressedKey = keyEvent.key else { return false }
      return pressedKey == hotKeyProcessor.hotkey.key
        && keyEvent.modifiers == hotKeyProcessor.hotkey.modifiers
    }
  }

  func handleMouseClickInputEvent() -> Bool {
    switch hotKeyProcessor.processMouseClick() {
    case .cancel:
      Task { @MainActor in cancel() }
    case .discard:
      Task { @MainActor in discard() }
    case .startRecording, .stopRecording, .none:
      break
    }
    return false
  }
}
