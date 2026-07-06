import SwiftUI

struct TLSettingsCard<Content: View>: View {
  var dividerInset: CGFloat = 16
  @ViewBuilder var content: Content

  var body: some View {
    TLCard {
      VStack(spacing: 0) {
        Group(subviews: content) { subviews in
          ForEach(subviews) { subview in
            if subview.id != subviews.first?.id {
              TLDivider(leadingInset: dividerInset, trailingInset: dividerInset)
            }
            subview
          }
        }
      }
    }
  }
}
