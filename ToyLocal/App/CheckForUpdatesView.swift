import Combine
import Inject
import Sparkle
import SwiftUI

@Observable
@MainActor
final class CheckForUpdatesViewModel {
	init() {
		anyCancellable = controller.updater.publisher(for: \.canCheckForUpdates)
			.receive(on: RunLoop.main)
			.sink { self.canCheckForUpdates = $0 }
	}

	static let shared = CheckForUpdatesViewModel()

	let controller = SPUStandardUpdaterController(
		startingUpdater: true,
		updaterDelegate: nil,
		userDriverDelegate: nil
	)

	var anyCancellable: AnyCancellable?

	var canCheckForUpdates = false

	func checkForUpdates() {
		controller.updater.checkForUpdates()
	}
}

struct CheckForUpdatesView: View {
	let viewModel: CheckForUpdatesViewModel
	@ObserveInjection var inject

	init(viewModel: CheckForUpdatesViewModel = .shared) {
		self.viewModel = viewModel
	}

	var body: some View {
		Button("Check for Updates...", action: viewModel.checkForUpdates)
			.disabled(!viewModel.canCheckForUpdates)
			.enableInjection()
	}
}
