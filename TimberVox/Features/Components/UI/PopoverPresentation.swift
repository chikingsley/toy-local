// ============================================================
// PopoverPresentation.swift — swiftcn-ui
// Supplemental source for: popover
// ============================================================
import SwiftUI

struct SCPopoverPresentationHost<PopoverContent: View>: ViewModifier {
  @Environment(\.layoutDirection) private var layoutDirection

  let isPresented: Binding<Bool>
  let position: SCPopoverPosition
  let compactAdaptation: SCPopoverCompactAdaptation
  let popoverContent: PopoverContent

  func body(content: Content) -> some View {
    content.popover(
      isPresented: isPresented,
      attachmentAnchor: position.attachmentAnchor(layoutDirection: layoutDirection),
      arrowEdge: position.arrowEdge(layoutDirection: layoutDirection)
    ) {
      popoverContent.modifier(
        SCPopoverCompactAdaptationModifier(adaptation: compactAdaptation)
      )
    }
  }
}

private struct SCPopoverCompactAdaptationModifier: ViewModifier {
  let adaptation: SCPopoverCompactAdaptation

  @ViewBuilder
  func body(content: Content) -> some View {
    switch adaptation {
    case .popover:
      content.presentationCompactAdaptation(.popover)
    case .sheet:
      content.presentationCompactAdaptation(.sheet)
    case .automatic:
      content
    }
  }
}
