import AppKit
import Combine
import SwiftUI

struct TLFloatingWindowBridge: NSViewRepresentable {
  @ObservedObject var layer: TLFloatingLayerModel

  func makeNSView(context: Context) -> TLFloatingBridgeView {
    let view = TLFloatingBridgeView()
    view.layerModel = layer
    return view
  }

  func updateNSView(_ nsView: TLFloatingBridgeView, context: Context) {
    nsView.layerModel = layer
    nsView.reconcile()
  }
}

final class TLFloatingBridgeView: NSView {
  var layerModel: TLFloatingLayerModel? {
    didSet {
      guard layerModel !== oldValue else { return }
      subscription = layerModel?.$presentations.sink { [weak self] _ in
        DispatchQueue.main.async {
          self?.reconcile()
        }
      }
    }
  }

  private var subscription: AnyCancellable?
  private var panels: [AnyHashable: NSPanel] = [:]

  private enum Metrics {
    static let screenInset: CGFloat = 8
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    reconcile()
  }

  override func layout() {
    super.layout()
    reconcile()
  }

  func reconcile() {
    guard let window, let layerModel else {
      removeAllPanels()
      return
    }

    let presentations = layerModel.presentations
    let liveIDs = Set(presentations.map(\.id))
    for (id, panel) in panels where !liveIDs.contains(id) {
      window.removeChildWindow(panel)
      panel.orderOut(nil)
      panels[id] = nil
    }

    for presentation in presentations {
      let panel = panels[presentation.id] ?? makePanel(for: presentation)
      panels[presentation.id] = panel

      let hosting = panel.contentView as? NSHostingView<AnyView>
      hosting?.rootView = AnyView(
        presentation.content
          .fixedSize()
      )
      let size = hosting?.fittingSize ?? presentation.estimatedSize
      let frame = panelFrame(for: presentation, size: size, window: window)
      panel.setFrame(frame, display: true)
      panel.ignoresMouseEvents = !presentation.allowsHitTesting

      if panel.parent == nil {
        window.addChildWindow(panel, ordered: .above)
      }
    }
  }

  private func makePanel(for presentation: TLFloatingPresentation) -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = true
    panel.contentView = NSHostingView(rootView: AnyView(presentation.content))
    return panel
  }

  private func panelFrame(for presentation: TLFloatingPresentation, size: CGSize, window: NSWindow) -> CGRect {
    let anchorInView = CGRect(
      x: presentation.anchor.origin.x,
      y: bounds.height - presentation.anchor.maxY,
      width: presentation.anchor.width,
      height: presentation.anchor.height
    )
    let anchorInWindow = convert(anchorInView, to: nil)
    let anchorOnScreen = window.convertToScreen(anchorInWindow)

    var x: CGFloat
    var y: CGFloat
    switch presentation.placement {
    case .right:
      x = anchorOnScreen.maxX + presentation.spacing
      y = anchorOnScreen.midY - size.height / 2
    case .left:
      x = anchorOnScreen.minX - size.width - presentation.spacing
      y = anchorOnScreen.midY - size.height / 2
    case .bottomLeading:
      x = anchorOnScreen.minX
      y = anchorOnScreen.minY - presentation.spacing - size.height
    case .bottomTrailing:
      x = anchorOnScreen.maxX - size.width
      y = anchorOnScreen.minY - presentation.spacing - size.height
    }

    if let visible = window.screen?.visibleFrame {
      if case .bottomLeading = presentation.placement, y < visible.minY + Metrics.screenInset {
        y = anchorOnScreen.maxY + presentation.spacing
      }
      if case .bottomTrailing = presentation.placement, y < visible.minY + Metrics.screenInset {
        y = anchorOnScreen.maxY + presentation.spacing
      }
      x = min(max(x, visible.minX + Metrics.screenInset), visible.maxX - size.width - Metrics.screenInset)
      y = min(max(y, visible.minY + Metrics.screenInset), visible.maxY - size.height - Metrics.screenInset)
    }

    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }

  private func removeAllPanels() {
    for panel in panels.values {
      panel.parent?.removeChildWindow(panel)
      panel.orderOut(nil)
    }
    panels.removeAll()
  }
}
