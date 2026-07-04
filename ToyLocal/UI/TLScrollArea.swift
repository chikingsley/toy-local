import SwiftUI

struct TLScrollArea<Content: View>: View {
  var contentPadding = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
  var spacing: CGFloat = 16
  @ViewBuilder var content: Content

  private struct ScrollInfo: Equatable {
    var progress: CGFloat = 0
    var thumbRatio: CGFloat = 1
  }

  @State private var scrollInfo = ScrollInfo()
  @State private var pillVisible = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: spacing) {
        content
      }
      .padding(contentPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollIndicators(.never)
    .onScrollGeometryChange(for: ScrollInfo.self) { geometry in
      let scrollable = geometry.contentSize.height - geometry.containerSize.height
      return ScrollInfo(
        progress: scrollable > 0 ? min(1, max(0, geometry.contentOffset.y / scrollable)) : 0,
        thumbRatio: geometry.contentSize.height > 0
          ? min(1, geometry.containerSize.height / geometry.contentSize.height) : 1
      )
    } action: { old, new in
      scrollInfo = new
      if abs(new.progress - old.progress) > 0.0001, new.thumbRatio < 1 {
        withAnimation(.easeOut(duration: 0.12)) { pillVisible = true }
      }
    }
    .overlay {
      if scrollInfo.thumbRatio < 1 {
        GeometryReader { proxy in
          let track = proxy.size.height - 24
          let thumb = max(44, min(track * scrollInfo.thumbRatio, track * 0.5))
          Capsule()
            .fill(.primary.opacity(0.25))
            .frame(width: 5, height: thumb)
            .offset(y: 12 + (track - thumb) * scrollInfo.progress)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 5)
            .opacity(pillVisible ? 1 : 0)
        }
        .allowsHitTesting(false)
      }
    }
    .task(id: scrollInfo) {
      if !pillVisible, scrollInfo.thumbRatio < 1 {
        withAnimation(.easeOut(duration: 0.12)) { pillVisible = true }
      }
      try? await Task.sleep(for: .seconds(1.2))
      withAnimation(.easeOut(duration: 0.5)) { pillVisible = false }
    }
  }
}

struct TLPane<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    TLScrollArea {
      content
    }
  }
}
