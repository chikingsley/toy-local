import SwiftUI
import Inject

struct LanguageSectionView: View {
	@ObserveInjection var inject
	@Bindable var store: SettingsStore

	var body: some View {
		Label {
			Picker("Output Language", selection: $store.hexSettings.outputLanguage) {
				ForEach(store.languages, id: \.id) { language in
					Text(language.name).tag(language.code)
				}
			}
			.pickerStyle(.menu)
		} icon: {
			Image(systemName: "globe")
		}
		.enableInjection()
	}
}
