import SwiftUI

struct CuratedList: View {
  var store: ModelDownloadStore

  private var visibleModels: [CuratedModelInfo] {
    if store.showAllModels {
      return Array(store.curatedModels)
    } else {
      return store.curatedModels.filter(\.isRuntimeSelectable)
    }
  }

  private var hiddenModels: [CuratedModelInfo] {
    store.curatedModels.filter { !$0.isRuntimeSelectable }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(visibleModels) { model in
        CuratedRow(store: store, model: model)
      }

      // Show "Show more"/"Show less" button
      if !hiddenModels.isEmpty {
        Button(
          action: { store.toggleModelDisplay() },
          label: {
            HStack {
              Spacer()
              Text(store.showAllModels ? "Show less" : "Show more")
                .font(.subheadline)
              Spacer()
            }
          }
        )
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  CuratedList(store: AppPreviewState.makeStore().settings.modelDownload)
    .padding()
    .frame(width: 600, height: 380)
}
