import SwiftUI

struct ModelSectionView: View {
  var store: SettingsStore
  let shouldFlash: Bool

  var body: some View {
    Section("Transcription Model") {
      ModelDownloadView(
        store: store.modelDownload,
        shouldFlash: shouldFlash
      )
    }
  }
}

#Preview {
  Form {
    ModelSectionView(store: AppPreviewState.makeStore().settings, shouldFlash: false)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 480)
}
