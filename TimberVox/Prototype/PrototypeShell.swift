import SwiftUI

struct PrototypeWindow: View {
  @State private var store = AppPreviewState.makeStore()

  var body: some View {
    AppShellView(store: store)
      .frame(width: 820, height: 680)
      .background(TLTheme.windowBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(.white.opacity(0.12), lineWidth: 1)
      )
      .overlay(alignment: .topLeading) {
        PrototypeTrafficLights()
          .padding(.leading, 12)
          .padding(.top, 16)
      }
      .shadow(color: .black.opacity(0.4), radius: 28, y: 12)
      .padding(40)
      .background(Color(white: 0.06))
  }
}

private struct PrototypeTrafficLights: View {
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 8) {
      light(color: Color(hex: 0xFF5F57), glyph: "xmark")
      light(color: Color(hex: 0xFEBC2E), glyph: "minus")
    }
    .padding(.leading, 8)
    .onHover { hovering = $0 }
  }

  private func light(color: Color, glyph: String) -> some View {
    ZStack {
      Circle().fill(color).frame(width: 12, height: 12)
      if hovering {
        Image(systemName: glyph)
          .font(.system(size: 6.5, weight: .black))
          .foregroundStyle(.black.opacity(0.55))
      }
    }
    .contentShape(Circle())
  }
}

#Preview("Prototype window") {
  PrototypeWindow()
}
