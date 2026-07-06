#if MAS_BUILD
  import SwiftUI

  @Observable
  @MainActor
  final class CheckForUpdatesViewModel {
    static let shared = CheckForUpdatesViewModel()

    let isUpdaterAvailable = false
    var canCheckForUpdates = false
    var automaticallyChecksForUpdates = false
    var automaticallyDownloadsUpdates = false

    func checkForUpdates() {}
  }

  struct CheckForUpdatesView: View {
    let viewModel: CheckForUpdatesViewModel

    init(viewModel: CheckForUpdatesViewModel = .shared) {
      self.viewModel = viewModel
    }

    var body: some View {
      EmptyView()
    }
  }
#else
  import Combine
  import Sparkle
  import SwiftUI

  @Observable
  @MainActor
  final class CheckForUpdatesViewModel {
    init() {
      guard isUpdaterAvailable else { return }

      let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
      )
      self.controller = controller
      anyCancellable = controller.updater.publisher(for: \.canCheckForUpdates)
        .receive(on: RunLoop.main)
        .sink { self.canCheckForUpdates = $0 }
    }

    static let shared = CheckForUpdatesViewModel()

    let isUpdaterAvailable = !ProcessInfo.processInfo.environment.keys.contains("TIMBERVOX_DISABLE_SPARKLE")

    var controller: SPUStandardUpdaterController?

    var anyCancellable: AnyCancellable?

    var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
      get { controller?.updater.automaticallyChecksForUpdates ?? false }
      set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
      get { controller?.updater.automaticallyDownloadsUpdates ?? false }
      set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    func checkForUpdates() {
      controller?.updater.checkForUpdates()
    }
  }

  struct CheckForUpdatesView: View {
    let viewModel: CheckForUpdatesViewModel

    init(viewModel: CheckForUpdatesViewModel = .shared) {
      self.viewModel = viewModel
    }

    var body: some View {
      Button("Check for Updates...", action: viewModel.checkForUpdates)
        .disabled(!viewModel.canCheckForUpdates)
    }
  }
#endif
