import SwiftUI

struct TLStat: View {
  let value: String
  let label: String
  var showsGear = false

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(.system(size: 15, weight: .semibold))
      HStack(spacing: 4) {
        Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        if showsGear {
          Image(systemName: "gearshape")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
  }
}
