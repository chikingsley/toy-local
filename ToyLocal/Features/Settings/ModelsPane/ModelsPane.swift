import SwiftUI

struct ModelsPane: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Form {
      ModelSectionView(store: store, shouldFlash: store.shouldFlashModelSection)
    }
    .formStyle(.grouped)
  }
}

#Preview {
  ModelsPane(store: AppPreviewState.makeStore().settings)
    .frame(width: 660, height: 560)
}
