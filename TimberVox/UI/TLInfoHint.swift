import SwiftUI

struct TLInfoHint: View {
  let text: String
  var width: CGFloat = 288

  @State private var hovering = false
  @State private var anchorFrame: CGRect = .zero
  @State private var presentationID = UUID()
  @Environment(\.tlFloatingLayer) private var floatingLayer
  @Environment(\.tlFloatingCoordinateSpace) private var coordinateSpace

  init(_ text: String, width: CGFloat = 288) {
    self.text = text
    self.width = width
  }

  var body: some View {
    Image(systemName: "questionmark.circle")
      .font(.system(size: 12))
      .foregroundStyle(hovering ? .primary : .tertiary)
      .frame(width: 16, height: 16)
      .contentShape(Circle())
      .tlFloatingAnchor($anchorFrame, in: coordinateSpace)
      .onHover { isHovering in
        hovering = isHovering
        if isHovering {
          present()
        } else {
          floatingLayer?.dismiss(id: presentationID)
        }
      }
      .onChange(of: anchorFrame) { _, _ in
        if hovering {
          present()
        }
      }
      .onDisappear {
        floatingLayer?.dismiss(id: presentationID)
      }
      .help(text)
      .accessibilityLabel("More information")
  }

  private func present() {
    guard anchorFrame != .zero else { return }
    floatingLayer?.present(
      id: presentationID,
      anchor: anchorFrame,
      placement: .right,
      spacing: 10,
      estimatedSize: CGSize(width: width, height: estimatedHeight),
      allowsHitTesting: false
    ) {
      TLPopoverCard(
        width: width,
        padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
      ) {
        Text(text)
          .font(.system(size: 12, weight: .medium))
          .lineSpacing(3)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var estimatedHeight: CGFloat {
    let approximateCharactersPerLine = max(24, Int(width / 6.8))
    let lineCount = max(1, (text.count + approximateCharactersPerLine - 1) / approximateCharactersPerLine)
    return CGFloat(lineCount) * 18 + 28
  }
}
