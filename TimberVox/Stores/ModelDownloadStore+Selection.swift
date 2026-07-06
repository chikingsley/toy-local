import TimberVoxCore
import Foundation

extension ModelDownloadStore {
  var timberVoxSettings: TimberVoxSettings {
    get { settings.settings }
    set { settings.settings = newValue }
  }

  var modelBootstrapState: ModelBootstrapState {
    get { settings.modelBootstrapState }
    set { settings.modelBootstrapState = newValue }
  }

  var selectedModel: String { timberVoxSettings.selectedModel }

  func selectedIdentifier(for model: CuratedModelInfo) -> String {
    if FluidAudioModels.model(id: model.internalName)?.isStreamingASR == true {
      return timberVoxSettings.alwaysOnStreamingModel
    }
    return timberVoxSettings.selectedModel
  }

  var selectedModelIsDownloaded: Bool {
    availableModels.first { $0.id == selectedModel }?.isDownloaded ?? false
  }

  var anyModelDownloaded: Bool {
    availableModels.contains { $0.isDownloaded }
  }

  var modelLibrarySections: [ModelLibrarySectionViewModel] {
    ModelLibraryAdapter.sections(
      availableModels: availableModels,
      settings: timberVoxSettings,
      downloadingModelID: downloadingModelName,
      downloadProgress: downloadProgress
    )
  }

  var preferredParakeetIdentifier: String {
    prefersEnglishParakeet ? FluidAudioModels.parakeetTdtCtc110m.id : FluidAudioModels.parakeetTdtV3.id
  }

  private var prefersEnglishParakeet: Bool {
    guard let language = timberVoxSettings.outputLanguage?.lowercased(), !language.isEmpty else {
      return false
    }
    return language.hasPrefix("en")
  }
}
