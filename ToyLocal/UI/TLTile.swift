import SwiftUI

struct TLTile: View {
  let icon: String
  let title: String
  var tint: Color = .primary.opacity(0.06)
  var prominent = false
  var action: () -> Void = {}
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 14))
        Text(title)
          .font(.system(size: 13, weight: .medium))
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .frame(height: 56)
      .background(
        prominent
          ? AnyShapeStyle(Color.accentColor.opacity(hovering ? 1.0 : 0.85))
          : AnyShapeStyle(tint.opacity(hovering ? 1.6 : 1.0)),
        in: RoundedRectangle(cornerRadius: 10)
      )
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}
