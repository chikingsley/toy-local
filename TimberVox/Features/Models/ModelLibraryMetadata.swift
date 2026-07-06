import TimberVoxCore
import Foundation

enum ModelLibraryFilter: String, CaseIterable, Hashable {
  case voice
  case language
  case cloud
  case offline
  case downloaded

  var label: String {
    switch self {
    case .voice: "Voice models"
    case .language: "Language models"
    case .cloud: "Cloud"
    case .offline: "Offline"
    case .downloaded: "Downloaded"
    }
  }
}

struct ModelLibraryMetricItem: Equatable, Identifiable {
  let label: String
  let value: String

  var id: String { "\(label)-\(value)" }
}

extension ModelLibraryRow {
  var provider: TLProvider {
    TLProvider(modelLibraryProviderName: entry.providerName)
  }

  var downloadControlState: TLModelDownloadState {
    switch downloadState {
    case .cloud:
      .cloud
    case .downloaded:
      .downloaded
    case .downloading(let progress):
      .downloading(progress)
    case .notDownloaded:
      .notDownloaded
    }
  }

  var isDownloaded: Bool {
    if case .downloaded = downloadState { return true }
    return false
  }

  var capabilityLabels: [String] {
    var labels = [runtimeLabel, roleLabel, languageLabel].compactMap(\.self)
    if entry.kind == .textGeneration {
      labels.append("Text")
    }
    return Array(labels.prefix(MetadataLimits.maximumCapabilityLabels))
  }

  var metricItems: [ModelLibraryMetricItem] {
    var items: [ModelLibraryMetricItem] = []
    appendMetric(
      label: entry.metricSummary.primaryLabel,
      value: entry.metricSummary.primaryValue,
      to: &items
    )
    appendMetric(
      label: entry.metricSummary.speedLabel,
      value: entry.metricSummary.speedValue,
      to: &items
    )
    return items
  }

  func matches(query: String, filter: ModelLibraryFilter?) -> Bool {
    let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if !searchText.isEmpty, !searchCorpus.localizedCaseInsensitiveContains(searchText) {
      return false
    }

    guard let filter else { return true }
    switch filter {
    case .voice:
      return entry.kind == .transcription
    case .language:
      return entry.kind == .textGeneration
    case .cloud:
      return entry.runtime == .cloud
    case .offline:
      return entry.runtime == .local
    case .downloaded:
      return isDownloaded
    }
  }

  private var runtimeLabel: String? {
    switch entry.runtime {
    case .local:
      "Local"
    case .cloud:
      "Cloud"
    case nil:
      nil
    }
  }

  private var roleLabel: String? {
    switch entry.sectionID {
    case .localDictation:
      "Batch"
    case .cloudDictation:
      "Batch"
    case .streamingPreview:
      "Realtime"
    case .cloudText:
      nil
    case .supportAssets:
      supportRoleLabel
    }
  }

  private var supportRoleLabel: String {
    switch entry.assetRole {
    case .vad:
      "Silence removal"
    case .diarization:
      "Speaker recognition"
    case .keywordSpotting:
      "Vocabulary"
    case .primaryASR, nil:
      "Support"
    }
  }

  private var languageLabel: String? {
    let count = entry.supportedLanguages.count
    guard count > 0 else { return nil }
    if entry.supportedLanguages == ["en"] {
      return "English"
    }
    return "\(count) languages"
  }

  private var searchCorpus: String {
    ([
      entry.displayName,
      entry.providerName,
      entry.sectionID.title,
    ] + capabilityLabels + metricItems.flatMap { [$0.label, $0.value] })
    .joined(separator: " ")
  }

  private func appendMetric(label: String?, value: String?, to items: inout [ModelLibraryMetricItem]) {
    guard let label, let value else { return }
    let item = ModelLibraryMetricItem(label: label, value: value)
    if !items.contains(item) {
      items.append(item)
    }
  }
}

private enum MetadataLimits {
  static let maximumCapabilityLabels = 3
}

extension TLProvider {
  init(modelLibraryProviderName: String) {
    switch modelLibraryProviderName.lowercased().replacingOccurrences(of: " ", with: "") {
    case "fluidaudio":
      self = .fluidAudio
    case "nvidia":
      self = .nvidia
    case "openai":
      self = .openAI
    case "deepgram":
      self = .deepgram
    case "elevenlabs":
      self = .elevenLabs
    case "cohere":
      self = .cohere
    case "anthropic":
      self = .anthropic
    case "mistral":
      self = .mistral
    case "superwhisper":
      self = .superwhisper
    default:
      self = .fluidAudio
    }
  }
}
