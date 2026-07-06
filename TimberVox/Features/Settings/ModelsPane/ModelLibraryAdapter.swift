import TimberVoxCore
import Foundation

enum ModelLibraryDownloadState: Equatable {
  case cloud
  case downloaded
  case downloading(Double)
  case notDownloaded
}

struct ModelLibraryRow: Equatable, Identifiable {
  let entry: ModelLibraryEntry
  let downloadState: ModelLibraryDownloadState
  let isSelected: Bool

  var id: String { entry.id }
}

struct ModelLibrarySectionViewModel: Equatable, Identifiable {
  let id: ModelLibrarySectionID
  let title: String
  let rows: [ModelLibraryRow]
}

enum ModelLibraryAdapter {
  static func sections(
    entries: [ModelLibraryEntry] = ModelLibraryCatalog.entries,
    availableModels: [ModelInfo],
    settings: TimberVoxSettings,
    downloadingModelID: String?,
    downloadProgress: Double
  ) -> [ModelLibrarySectionViewModel] {
    let downloadedIDs = Set(availableModels.filter(\.isDownloaded).map(\.id))

    return ModelLibrarySectionID.allCases.map { sectionID in
      let rows =
        entries
        .filter { $0.sectionID == sectionID }
        .map {
          ModelLibraryRow(
            entry: $0,
            downloadState: downloadState(
              for: $0,
              downloadedIDs: downloadedIDs,
              downloadingModelID: downloadingModelID,
              downloadProgress: downloadProgress
            ),
            isSelected: isSelected($0, settings: settings)
          )
        }
      return ModelLibrarySectionViewModel(id: sectionID, title: sectionID.title, rows: rows)
    }
  }

  private static func downloadState(
    for entry: ModelLibraryEntry,
    downloadedIDs: Set<String>,
    downloadingModelID: String?,
    downloadProgress: Double
  ) -> ModelLibraryDownloadState {
    guard entry.runtime == .local else {
      return .cloud
    }
    if downloadingModelID == entry.id {
      return .downloading(downloadProgress)
    }
    if downloadedIDs.contains(entry.id) {
      return .downloaded
    }
    return .notDownloaded
  }

  private static func isSelected(_ entry: ModelLibraryEntry, settings: TimberVoxSettings) -> Bool {
    switch entry.sectionID {
    case .localDictation, .cloudDictation:
      settings.selectedModel == entry.id
    case .streamingPreview:
      settings.alwaysOnStreamingModel == entry.id
    case .cloudText:
      settings.textTransformModel == entry.id
    case .supportAssets:
      false
    }
  }
}
