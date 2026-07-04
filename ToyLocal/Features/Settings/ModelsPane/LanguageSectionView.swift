import SwiftUI

struct LanguageSectionView: View {
  @Bindable var store: SettingsStore

  var body: some View {
    Label {
      Picker("Output Language", selection: $store.toyLocalSettings.outputLanguage) {
        ForEach(store.languages, id: \.id) { language in
          Text(language.name).tag(language.code)
        }
      }
      .pickerStyle(.menu)
    } icon: {
      Image(systemName: "globe")
    }
  }
}

#Preview {
  Form {
    LanguageSectionView(store: AppPreviewState.makeStore().settings)
  }
  .formStyle(.grouped)
  .frame(width: 640, height: 320)
}
