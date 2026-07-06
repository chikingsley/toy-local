import SwiftUI

struct AppView: View {
  @Bindable var store: AppStore

  var body: some View {
    AppShellView(store: store)
  }
}

#Preview("Main Window") {
  AppViewPreviewContainer()
}

@MainActor
private struct AppViewPreviewContainer: View {
  @State private var store = AppPreviewState.makeStore()

  var body: some View {
    AppView(store: store)
      .frame(width: 820, height: 680)
  }
}
