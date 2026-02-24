import Inject
import SwiftUI

struct ModelSectionView: View {
	@ObserveInjection var inject
	var store: SettingsStore
	let shouldFlash: Bool

	var body: some View {
		Section("Transcription Model") {
			ModelDownloadView(
				store: store.modelDownload,
				shouldFlash: shouldFlash
			)
		}
		.enableInjection()
	}
}
