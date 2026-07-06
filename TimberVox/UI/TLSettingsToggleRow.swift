import SwiftUI

struct TLSettingsToggleRow: View {
  var icon: String?
  let title: String
  var subtitle = ""
  var hint = ""
  var showsAI = false
  @Binding var isOn: Bool

  var body: some View {
    TLSettingsRow(icon: icon, title: title, subtitle: subtitle, hint: hint) {
      HStack(spacing: 8) {
        if showsAI {
          Image(systemName: "atom")
            .font(.system(size: 10))
            .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
        }
        Toggle("", isOn: $isOn)
          .toggleStyle(.switch)
          .controlSize(.small)
          .labelsHidden()
      }
    }
  }
}
