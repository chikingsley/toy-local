import SwiftUI

struct TLRow: View {
  let icon: String
  let title: String
  var subtitle: String = ""
  var detail: String = ""
  var iconTint: Color = .secondary

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 13))
        .foregroundStyle(iconTint)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 13)).lineLimit(1)
        if !subtitle.isEmpty {
          Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer()
      if !detail.isEmpty {
        TLKeyChip(detail)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }
}
