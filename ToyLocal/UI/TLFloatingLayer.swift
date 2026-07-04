import SwiftUI

enum TLFloatingPlacement {
  case right
  case left
  case bottomLeading
  case bottomTrailing
}

struct TLFloatingPresentation: Identifiable {
  let id: AnyHashable
  let anchor: CGRect
  let placement: TLFloatingPlacement
  let spacing: CGFloat
  let estimatedSize: CGSize
  let blocksBackground: Bool
  let allowsHitTesting: Bool
  let content: AnyView
}

@MainActor
final class TLFloatingLayerModel: ObservableObject {
  @Published var presentations: [TLFloatingPresentation] = []

  func present<Content: View>(
    id: AnyHashable,
    anchor: CGRect,
    placement: TLFloatingPlacement,
    spacing: CGFloat = 8,
    estimatedSize: CGSize,
    blocksBackground: Bool = false,
    allowsHitTesting: Bool = true,
    @ViewBuilder content: () -> Content
  ) {
    let presentation = TLFloatingPresentation(
      id: id,
      anchor: anchor,
      placement: placement,
      spacing: spacing,
      estimatedSize: estimatedSize,
      blocksBackground: blocksBackground,
      allowsHitTesting: allowsHitTesting,
      content: AnyView(content())
    )

    if let index = presentations.firstIndex(where: { $0.id == id }) {
      presentations[index] = presentation
    } else {
      presentations.append(presentation)
    }
  }

  func dismiss(id: AnyHashable) {
    presentations.removeAll { $0.id == id }
  }

  func dismissAll() {
    presentations.removeAll()
  }

  func contains(id: AnyHashable) -> Bool {
    presentations.contains { $0.id == id }
  }
}

private struct TLFloatingLayerKey: EnvironmentKey {
  static let defaultValue: TLFloatingLayerModel? = nil
}

private struct TLFloatingCoordinateSpaceKey: EnvironmentKey {
  static let defaultValue = "TLFloatingLayer"
}

extension EnvironmentValues {
  var tlFloatingLayer: TLFloatingLayerModel? {
    get { self[TLFloatingLayerKey.self] }
    set { self[TLFloatingLayerKey.self] = newValue }
  }

  var tlFloatingCoordinateSpace: String {
    get { self[TLFloatingCoordinateSpaceKey.self] }
    set { self[TLFloatingCoordinateSpaceKey.self] = newValue }
  }
}

struct TLFloatingHost<Content: View>: View {
  @StateObject private var layer = TLFloatingLayerModel()
  @State private var measuredSizes: [String: CGSize] = [:]

  private static var usesChildWindows: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
  }

  private let coordinateSpaceName = "TLFloatingLayer"
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        content
          .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
          .environment(\.tlFloatingLayer, layer)
          .environment(\.tlFloatingCoordinateSpace, coordinateSpaceName)

        if layer.presentations.contains(where: \.blocksBackground) {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              layer.dismissAll()
            }
            .zIndex(9_000)
        }

        if Self.usesChildWindows {
          TLFloatingWindowBridge(layer: layer)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .allowsHitTesting(false)
        } else {
          ForEach(Array(layer.presentations.enumerated()), id: \.element.id) { index, presentation in
            let sizeKey = String(describing: presentation.id)
            let measuredSize = measuredSizes[sizeKey] ?? presentation.estimatedSize
            let origin = floatingOrigin(
              for: presentation,
              measuredSize: measuredSize,
              bounds: CGRect(origin: .zero, size: proxy.size)
            )

            presentation.content
              .fixedSize()
              .onGeometryChange(for: CGSize.self) { contentProxy in
                contentProxy.size
              } action: { size in
                measuredSizes[sizeKey] = size
              }
              .allowsHitTesting(presentation.allowsHitTesting)
              .offset(x: origin.x, y: origin.y)
              .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
              .transition(.opacity)
              .zIndex(10_000 + Double(index))
          }
        }
      }
      .coordinateSpace(name: coordinateSpaceName)
    }
  }

  private func floatingOrigin(
    for presentation: TLFloatingPresentation,
    measuredSize: CGSize,
    bounds: CGRect
  ) -> CGPoint {
    let inset: CGFloat = 8
    var x: CGFloat
    var y: CGFloat

    switch presentation.placement {
    case .right:
      x = presentation.anchor.maxX + presentation.spacing
      y = presentation.anchor.midY - measuredSize.height / 2
    case .left:
      x = presentation.anchor.minX - measuredSize.width - presentation.spacing
      y = presentation.anchor.midY - measuredSize.height / 2
    case .bottomLeading:
      x = presentation.anchor.minX
      y = presentation.anchor.maxY + presentation.spacing
      if y + measuredSize.height > bounds.maxY - inset {
        y = presentation.anchor.minY - measuredSize.height - presentation.spacing
      }
    case .bottomTrailing:
      x = presentation.anchor.maxX - measuredSize.width
      y = presentation.anchor.maxY + presentation.spacing
      if y + measuredSize.height > bounds.maxY - inset {
        y = presentation.anchor.minY - measuredSize.height - presentation.spacing
      }
    }

    x = min(max(x, bounds.minX + inset), max(bounds.minX + inset, bounds.maxX - measuredSize.width - inset))
    y = min(max(y, bounds.minY + inset), max(bounds.minY + inset, bounds.maxY - measuredSize.height - inset))

    return CGPoint(x: x, y: y)
  }
}

extension View {
  func tlFloatingAnchor(_ frame: Binding<CGRect>, in coordinateSpace: String) -> some View {
    onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .named(coordinateSpace))
    } action: { newFrame in
      frame.wrappedValue = newFrame
    }
  }
}
