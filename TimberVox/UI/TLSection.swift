import SwiftUI

struct TLSection<Content: View>: View {
  let title: String
  var trailing: String = ""
  var hint: String = ""
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 5) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
        if !hint.isEmpty {
          TLInfoHint(hint)
        }
        Spacer()
        if !trailing.isEmpty {
          Text(trailing)
            .font(.system(size: 11))
            .foregroundStyle(Color.accentColor)
        }
      }
      content
    }
  }
}
