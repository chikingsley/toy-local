import AppKit
import SwiftUI

/// Owns the always-on pill window. Window pattern follows VoiceInk's recipe
/// (studied, not copied): a non-activating floating panel, deliberately larger
/// than the visible pill so state morphs never move or resize the window.
@MainActor
final class RecordingIndicatorManager {
  private let panel: NSPanel
  private static let hostSize = CGSize(width: 480, height: 220)
  private static let bottomOffset: CGFloat = 24

  init(dictation: DictationController) {
    panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: Self.hostSize),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.hidesOnDeactivate = false
    panel.isFloatingPanel = true
    panel.isMovable = false
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false

    let hosting = NSHostingView(rootView: RecordingPillView(dictation: dictation))
    hosting.wantsLayer = true
    hosting.layer?.backgroundColor = .clear
    panel.contentView = hosting

    reposition()
    panel.orderFrontRegardless()

    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.reposition()
        self?.panel.orderFrontRegardless()
      }
    }
  }

  private func reposition() {
    guard let screen = NSScreen.main else { return }
    let frame = NSRect(
      x: screen.visibleFrame.midX - Self.hostSize.width / 2,
      y: screen.visibleFrame.minY + Self.bottomOffset,
      width: Self.hostSize.width,
      height: Self.hostSize.height
    )
    panel.setFrame(frame, display: true)
  }
}
