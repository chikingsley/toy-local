import Foundation

public enum ModelLibrarySectionID: String, Codable, CaseIterable, Sendable {
  case localDictation = "local_dictation"
  case cloudDictation = "cloud_dictation"
  case streamingPreview = "streaming_preview"
  case cloudText = "cloud_text"
  case supportAssets = "support_assets"

  public var title: String {
    switch self {
    case .localDictation:
      "Local Dictation"
    case .cloudDictation:
      "Cloud Dictation"
    case .streamingPreview:
      "Always-On / Streaming Preview"
    case .cloudText:
      "Cloud Text"
    case .supportAssets:
      "Support Models"
    }
  }
}

public enum ModelLibraryEntryKind: String, Codable, Sendable {
  case transcription
  case textGeneration
  case supportAsset
}

public struct ModelLibraryMetricSummary: Codable, Equatable, Sendable {
  public let primaryLabel: String?
  public let primaryValue: String?
  public let speedLabel: String?
  public let speedValue: String?

  public init(
    primaryLabel: String?,
    primaryValue: String?,
    speedLabel: String?,
    speedValue: String?
  ) {
    self.primaryLabel = primaryLabel
    self.primaryValue = primaryValue
    self.speedLabel = speedLabel
    self.speedValue = speedValue
  }
}

public struct ModelLibraryEntry: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let displayName: String
  public let providerName: String
  public let sectionID: ModelLibrarySectionID
  public let kind: ModelLibraryEntryKind
  public let runtime: TranscriptionRuntime?
  public let assetRole: TranscriptionAssetRole?
  public let supportedLanguages: Set<String>
  public let storageSizeText: String?
  public let approximateSizeMB: Double?
  public let metricSummary: ModelLibraryMetricSummary
  public let metricProfile: ModelMetricProfile?
  public let isSelectable: Bool
  public let isDownloadable: Bool

  public init(
    id: String,
    displayName: String,
    providerName: String,
    sectionID: ModelLibrarySectionID,
    kind: ModelLibraryEntryKind,
    runtime: TranscriptionRuntime?,
    assetRole: TranscriptionAssetRole?,
    supportedLanguages: Set<String>,
    storageSizeText: String?,
    approximateSizeMB: Double?,
    metricSummary: ModelLibraryMetricSummary,
    metricProfile: ModelMetricProfile?,
    isSelectable: Bool,
    isDownloadable: Bool
  ) {
    self.id = id
    self.displayName = displayName
    self.providerName = providerName
    self.sectionID = sectionID
    self.kind = kind
    self.runtime = runtime
    self.assetRole = assetRole
    self.supportedLanguages = supportedLanguages
    self.storageSizeText = storageSizeText
    self.approximateSizeMB = approximateSizeMB
    self.metricSummary = metricSummary
    self.metricProfile = metricProfile
    self.isSelectable = isSelectable
    self.isDownloadable = isDownloadable
  }
}

public struct ModelLibrarySection: Codable, Equatable, Identifiable, Sendable {
  public let id: ModelLibrarySectionID
  public let title: String
  public let entries: [ModelLibraryEntry]

  public init(id: ModelLibrarySectionID, title: String, entries: [ModelLibraryEntry]) {
    self.id = id
    self.title = title
    self.entries = entries
  }
}

public enum ModelLibraryCatalog {
  public static let entries: [ModelLibraryEntry] =
    localDictationEntries
    + cloudDictationEntries
    + streamingPreviewEntries
    + cloudTextEntries
    + supportEntries

  public static let sections: [ModelLibrarySection] = ModelLibrarySectionID.allCases.map { sectionID in
    ModelLibrarySection(
      id: sectionID,
      title: sectionID.title,
      entries: entries.filter { $0.sectionID == sectionID }
    )
  }

  public static func entry(id: String) -> ModelLibraryEntry? {
    entries.first { $0.id == id }
  }

  public static func entries(in sectionID: ModelLibrarySectionID) -> [ModelLibraryEntry] {
    entries.filter { $0.sectionID == sectionID }
  }

  private static let localDictationEntries: [ModelLibraryEntry] = FluidAudioModels.all
    .filter { $0.runtimeSection == .localDictation }
    .map { entry(for: $0, sectionID: .localDictation, kind: .transcription, selectable: true) }

  private static let streamingPreviewEntries: [ModelLibraryEntry] = FluidAudioModels.all
    .filter { $0.runtimeSection == .streamingPreview }
    .map { entry(for: $0, sectionID: .streamingPreview, kind: .transcription, selectable: true) }

  private static let supportEntries: [ModelLibraryEntry] = FluidAudioModels.all
    .filter { $0.runtimeSection == .supportAssets }
    .map { entry(for: $0, sectionID: .supportAssets, kind: .supportAsset, selectable: false) }

  private static let cloudDictationEntries: [ModelLibraryEntry] = CloudTranscriptionModels.all.map { model in
    entry(for: model, sectionID: .cloudDictation)
  }

  private static let cloudTextEntries: [ModelLibraryEntry] = CloudLanguageModels.all.map { model in
    let profile = CloudModelMetrics.profile(for: model.id)
    return ModelLibraryEntry(
      id: model.id,
      displayName: model.displayName,
      providerName: model.provider.rawValue,
      sectionID: .cloudText,
      kind: .textGeneration,
      runtime: .cloud,
      assetRole: nil,
      supportedLanguages: [],
      storageSizeText: nil,
      approximateSizeMB: nil,
      metricSummary: metricSummary(for: profile),
      metricProfile: profile,
      isSelectable: true,
      isDownloadable: false
    )
  }

  private static func entry(
    for model: FluidAudioModel,
    sectionID: ModelLibrarySectionID,
    kind: ModelLibraryEntryKind,
    selectable: Bool
  ) -> ModelLibraryEntry {
    let profile = model.metricProfile
    return ModelLibraryEntry(
      id: model.id,
      displayName: model.displayName,
      providerName: "FluidAudio",
      sectionID: sectionID,
      kind: kind,
      runtime: .local,
      assetRole: model.assetRole,
      supportedLanguages: model.supportedLanguages,
      storageSizeText: model.storageSize,
      approximateSizeMB: profile.download?.approximateSizeMB,
      metricSummary: metricSummary(for: profile),
      metricProfile: profile,
      isSelectable: selectable,
      isDownloadable: model.isDownloadableAsset
    )
  }

  private static func entry(
    for model: TranscriptionModelSpec,
    sectionID: ModelLibrarySectionID
  ) -> ModelLibraryEntry {
    let profile = CloudModelMetrics.profile(for: model.id)
    return ModelLibraryEntry(
      id: model.id,
      displayName: model.displayName,
      providerName: model.provider.rawValue,
      sectionID: sectionID,
      kind: .transcription,
      runtime: model.runtime,
      assetRole: model.assetRole,
      supportedLanguages: model.supportedLanguages,
      storageSizeText: nil,
      approximateSizeMB: nil,
      metricSummary: metricSummary(for: profile),
      metricProfile: profile,
      isSelectable: true,
      isDownloadable: false
    )
  }

  private static func metricSummary(for profile: ModelMetricProfile?) -> ModelLibraryMetricSummary {
    guard let profile else {
      return ModelLibraryMetricSummary(primaryLabel: nil, primaryValue: nil, speedLabel: nil, speedValue: nil)
    }

    let primary = firstMetric(
      in: profile,
      named: [
        .wordErrorRatePercent,
        .latencyMilliseconds,
        .diarizationErrorRatePercent,
        .vadF1Percent,
        .vocabularyFScorePercent,
      ]
    )
    let speed = firstMetric(in: profile, named: [.realTimeFactor, .medianRealTimeFactor, .latencyMilliseconds])

    return ModelLibraryMetricSummary(
      primaryLabel: primary?.label,
      primaryValue: primary?.value,
      speedLabel: speed?.label,
      speedValue: speed?.value
    )
  }

  private static func firstMetric(
    in profile: ModelMetricProfile,
    named names: [PublishedMetricName]
  ) -> (label: String, value: String)? {
    for name in names {
      if let metric = profile.metrics(named: name).first {
        return (metric.displayLabel, metric.displayValue)
      }
    }
    return nil
  }
}

private extension FluidAudioModel {
  var runtimeSection: ModelLibrarySectionID {
    switch role {
    case .slidingWindowASR:
      .localDictation
    case .streamingASR:
      .streamingPreview
    case .vad, .diarization, .keywordSpotting:
      .supportAssets
    }
  }
}

private extension PublishedModelMetric {
  var displayLabel: String {
    switch name {
    case .wordErrorRatePercent:
      "WER"
    case .characterErrorRatePercent:
      "CER"
    case .diarizationErrorRatePercent:
      "DER"
    case .jaccardErrorRatePercent:
      "JER"
    case .vadAccuracyPercent:
      "VAD accuracy"
    case .vadPrecisionPercent:
      "VAD precision"
    case .vadRecallPercent:
      "VAD recall"
    case .vadF1Percent:
      "VAD F1"
    case .vocabularyPrecisionPercent:
      "Vocabulary precision"
    case .vocabularyRecallPercent:
      "Vocabulary recall"
    case .vocabularyFScorePercent:
      "Vocabulary F-score"
    case .realTimeFactor, .medianRealTimeFactor:
      "Speed"
    case .latencyMilliseconds:
      "Latency"
    case .maxAudioSeconds:
      "Max audio"
    case .maxSpeakers:
      "Speakers"
    case .parameterCountMillions:
      "Parameters"
    }
  }

  var displayValue: String {
    switch name {
    case .wordErrorRatePercent, .characterErrorRatePercent, .diarizationErrorRatePercent, .jaccardErrorRatePercent,
      .vadAccuracyPercent, .vadPrecisionPercent, .vadRecallPercent, .vadF1Percent, .vocabularyPrecisionPercent,
      .vocabularyRecallPercent, .vocabularyFScorePercent:
      "\(trimmed(value))%"
    case .realTimeFactor, .medianRealTimeFactor:
      "\(trimmed(value))x"
    case .latencyMilliseconds:
      "\(trimmed(value)) ms"
    case .maxAudioSeconds:
      "\(trimmed(value))s"
    case .maxSpeakers:
      trimmed(value)
    case .parameterCountMillions:
      "\(trimmed(value))M"
    }
  }

  private func trimmed(_ value: Double) -> String {
    if value.rounded() == value {
      return String(Int(value))
    }
    return String(format: "%.2f", value)
  }
}
