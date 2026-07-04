import SwiftUI

struct TLSearchField: View {
  var placeholder = "Search"
  var icon = "magnifyingglass"
  @Binding var text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
      TextField(placeholder, text: $text)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(TLTheme.fieldSurface, in: RoundedRectangle(cornerRadius: TLTheme.fieldRadius))
  }
}
