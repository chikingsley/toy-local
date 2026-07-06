import SwiftUI

extension Text {
  /// Applies caption font with secondary color, commonly used for helper/description text in settings.
  func settingsCaption() -> some View {
    self.font(.caption).foregroundStyle(.secondary)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 8) {
    Text("A regular settings label")
    Text("A helper caption under a control, in secondary color")
      .settingsCaption()
  }
  .padding()
}
