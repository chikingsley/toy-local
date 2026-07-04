import Foundation
import ToyLocalCore

extension ModelDownloadStore {
  var toyLocalSettings: ToyLocalSettings {
    get { settings.settings }
    set { settings.settings = newValue }
  }

  var modelBootstrapState: ModelBootstrapState {
    get { settings.modelBootstrapState }
    set { settings.modelBootstrapState = newValue }
  }

  var selectedModel: String { toyLocalSettings.selectedModel }

  func selectedIdentifier(for model: CuratedModelInfo) -> String {
    if FluidAudioModels.model(id: model.internalName)?.isStreamingASR == true {
      return toyLocalSettings.alwaysOnStreamingModel
    }
    return toyLocalSettings.selectedModel
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
      settings: toyLocalSettings,
      downloadingModelID: downloadingModelName,
      downloadProgress: downloadProgress
    )
  }

  var preferredParakeetIdentifier: String {
    prefersEnglishParakeet ? FluidAudioModels.parakeetTdtCtc110m.id : FluidAudioModels.parakeetTdtV3.id
  }

  private var prefersEnglishParakeet: Bool {
    guard let language = toyLocalSettings.outputLanguage?.lowercased(), !language.isEmpty else {
      return false
    }
    return language.hasPrefix("en")
  }
}
