import SwiftUI

struct TLCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: TLTheme.cardRadius))
  }
}
