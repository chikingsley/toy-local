import Foundation

public enum FluidAudioModelRole: String, Codable, Sendable {
  case slidingWindowASR
  case streamingASR
  case vad
  case diarization
  case keywordSpotting
}

public enum FluidAudioLanguageSupport: Equatable, Sendable {
  case english
  case multilingual([String])
  case languageDetection([String])
  case support

  public var label: String {
    switch self {
    case .english:
      return "English"
    case .multilingual(let languages):
      return "\(languages.count) languages"
    case .languageDetection(let languages):
      return "\(languages.count) languages · Auto"
    case .support:
      return "Support"
    }
  }

  public var isEnglishOnly: Bool {
    if case .english = self { return true }
    return false
  }
}

public struct FluidAudioModel: Identifiable, Equatable, Sendable {
  public let id: String
  public let displayName: String
  public let role: FluidAudioModelRole
  public let languageSupport: FluidAudioLanguageSupport
  public let storageSize: String
  public let accuracyStars: Int
  public let speedStars: Int
  public let isUserSelectableASR: Bool
  public let isDownloadableAsset: Bool
  public let badge: String?

  public init(
    id: String,
    displayName: String,
    role: FluidAudioModelRole,
    languageSupport: FluidAudioLanguageSupport,
    storageSize: String,
    accuracyStars: Int,
    speedStars: Int,
    isUserSelectableASR: Bool,
    isDownloadableAsset: Bool = true,
    badge: String? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.role = role
    self.languageSupport = languageSupport
    self.storageSize = storageSize
    self.accuracyStars = accuracyStars
    self.speedStars = speedStars
    self.isUserSelectableASR = isUserSelectableASR
    self.isDownloadableAsset = isDownloadableAsset
    self.badge = badge
  }

  public var isStreamingASR: Bool {
    role == .streamingASR
  }

  public var assetRole: TranscriptionAssetRole {
    switch role {
    case .slidingWindowASR, .streamingASR:
      return .primaryASR
    case .vad:
      return .vad
    case .diarization:
      return .diarization
    case .keywordSpotting:
      return .keywordSpotting
    }
  }

  public var supportedLanguages: Set<String> {
    switch languageSupport {
    case .english:
      return ["en"]
    case .multilingual(let languages), .languageDetection(let languages):
      return Set(languages)
    case .support:
      return []
    }
  }

  public var capabilities: TranscriptionCapabilities {
    switch role {
    case .slidingWindowASR:
      return TranscriptionCapabilities(
        batch: true,
        fileInput: true,
        languageDetection: languageSupport.isAutoDetecting,
        languageHint: true,
        segmentTimestamps: true,
        wordTimestamps: true
      )
    case .streamingASR:
      return TranscriptionCapabilities(
        languageDetection: languageSupport.isAutoDetecting,
        languageHint: true,
        partialResults: true,
        realtime: true,
        streamingInput: true,
        voiceActivityDetection: id.hasPrefix("parakeet-eou-")
      )
    case .vad:
      return TranscriptionCapabilities(
        fileInput: true,
        voiceActivityDetection: true
      )
    case .keywordSpotting:
      return TranscriptionCapabilities(
        fileInput: true,
        keywordSpotting: true
      )
    case .diarization:
      return TranscriptionCapabilities()
    }
  }

  public var transcriptionModelSpec: TranscriptionModelSpec {
    TranscriptionModelSpec(
      id: id,
      displayName: displayName,
      provider: .fluidAudio,
      runtime: .local,
      upstreamModel: id,
      capabilities: capabilities,
      assetRole: assetRole,
      supportedLanguages: supportedLanguages
    )
  }
}

private extension FluidAudioLanguageSupport {
  var isAutoDetecting: Bool {
    if case .languageDetection = self { return true }
    return false
  }
}

public enum FluidAudioModels {
  public static let parakeetTdtV3 = FluidAudioModel(
    id: "parakeet-tdt-0.6b-v3-coreml",
    displayName: "Parakeet TDT v3",
    role: .slidingWindowASR,
    languageSupport: .multilingual([
      "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "it", "lt", "lv", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "sv", "tr",
      "uk",
    ]),
    storageSize: "650 MB",
    accuracyStars: 5,
    speedStars: 5,
    isUserSelectableASR: true,
    badge: "DEFAULT"
  )

  public static let parakeetTdtCtc110m = FluidAudioModel(
    id: "parakeet-tdt-ctc-110m-coreml",
    displayName: "Parakeet TDT-CTC 110M",
    role: .slidingWindowASR,
    languageSupport: .english,
    storageSize: "350 MB",
    accuracyStars: 4,
    speedStars: 5,
    isUserSelectableASR: true,
    badge: "FAST"
  )

  public static let cohereTranscribe = FluidAudioModel(
    id: "cohere-transcribe-03-2026-coreml",
    displayName: "Cohere Transcribe",
    role: .slidingWindowASR,
    languageSupport: .multilingual(["ar", "de", "el", "en", "es", "fr", "it", "ja", "ko", "nl", "pl", "pt", "vi", "zh"]),
    storageSize: "2.2 GB",
    accuracyStars: 5,
    speedStars: 3,
    isUserSelectableASR: true
  )

  public static let parakeetEou160 = streaming(
    id: "parakeet-eou-160ms",
    name: "Parakeet EOU 160 ms",
    storage: "200 MB",
    badge: "LOWEST LATENCY"
  )
  public static let parakeetEou320 = streaming(id: "parakeet-eou-320ms", name: "Parakeet EOU 320 ms", storage: "200 MB")
  public static let parakeetEou1280 = streaming(id: "parakeet-eou-1280ms", name: "Parakeet EOU 1280 ms", storage: "200 MB")

  public static let nemotron560 = streaming(id: "nemotron-560ms", name: "Nemotron Streaming 560 ms", storage: "1.4 GB")
  public static let nemotron1120 = streaming(id: "nemotron-1120ms", name: "Nemotron Streaming 1120 ms", storage: "1.4 GB")
  public static let nemotron2240 = streaming(
    id: "nemotron-2240ms",
    name: "Nemotron Streaming 2240 ms",
    storage: "1.4 GB",
    badge: "RECOMMENDED STREAMING"
  )

  public static let nemotronMultilingual560 = FluidAudioModel(
    id: "nemotron-multilingual-560ms",
    displayName: "Nemotron Multilingual 560 ms",
    role: .streamingASR,
    languageSupport: .languageDetection(["de", "en", "es", "fr", "it", "ja", "pt", "zh"]),
    storageSize: "1.4 GB",
    accuracyStars: 4,
    speedStars: 4,
    isUserSelectableASR: true
  )

  public static let nemotronMultilingual1120 = FluidAudioModel(
    id: "nemotron-multilingual-1120ms",
    displayName: "Nemotron Multilingual 1120 ms",
    role: .streamingASR,
    languageSupport: .languageDetection(["de", "en", "es", "fr", "it", "ja", "pt", "zh"]),
    storageSize: "1.4 GB",
    accuracyStars: 4,
    speedStars: 4,
    isUserSelectableASR: true
  )

  public static let nemotronMultilingual2240 = FluidAudioModel(
    id: "nemotron-multilingual-2240ms",
    displayName: "Nemotron Multilingual 2240 ms",
    role: .streamingASR,
    languageSupport: .languageDetection(["de", "en", "es", "fr", "it", "ja", "pt", "zh"]),
    storageSize: "1.4 GB",
    accuracyStars: 5,
    speedStars: 3,
    isUserSelectableASR: true,
    badge: "MULTILINGUAL STREAMING"
  )

  public static let customVocabularyCtc110m = FluidAudioModel(
    id: "parakeet-ctc-110m-keyword-spotting",
    displayName: "Custom Vocabulary / Keyword Spotting",
    role: .keywordSpotting,
    languageSupport: .english,
    storageSize: "120 MB",
    accuracyStars: 4,
    speedStars: 5,
    isUserSelectableASR: false
  )

  public static let sileroVad = FluidAudioModel(
    id: "silero-vad-coreml",
    displayName: "Silero VAD",
    role: .vad,
    languageSupport: .support,
    storageSize: "5 MB",
    accuracyStars: 5,
    speedStars: 5,
    isUserSelectableASR: false
  )

  public static let sortformer = FluidAudioModel(
    id: "sortformer",
    displayName: "Sortformer Diarization",
    role: .diarization,
    languageSupport: .support,
    storageSize: "300 MB",
    accuracyStars: 5,
    speedStars: 4,
    isUserSelectableASR: false,
    badge: "DIARIZATION"
  )

  public static let lsEendAmi = diarization(id: "ls-eend-ami", name: "LS-EEND AMI")
  public static let lsEendCallhome = diarization(id: "ls-eend-callhome", name: "LS-EEND CallHome")
  public static let lsEendDihard2 = diarization(id: "ls-eend-dihard2", name: "LS-EEND DIHARD II")
  public static let lsEendDihard3 = diarization(id: "ls-eend-dihard3", name: "LS-EEND DIHARD III")

  public static let all: [FluidAudioModel] = [
    parakeetTdtV3,
    parakeetTdtCtc110m,
    cohereTranscribe,
    parakeetEou160,
    parakeetEou320,
    parakeetEou1280,
    nemotron560,
    nemotron1120,
    nemotron2240,
    nemotronMultilingual560,
    nemotronMultilingual1120,
    nemotronMultilingual2240,
    customVocabularyCtc110m,
    sileroVad,
    sortformer,
    lsEendAmi,
    lsEendCallhome,
    lsEendDihard2,
    lsEendDihard3,
  ]

  public static let userSelectableASR: [FluidAudioModel] = all.filter(\.isUserSelectableASR)
  public static let primaryASR: [FluidAudioModel] = all.filter { $0.assetRole == .primaryASR }
  public static let supportAssets: [FluidAudioModel] = all.filter { $0.assetRole != .primaryASR }
  public static let downloadableAssets: [FluidAudioModel] = all.filter(\.isDownloadableAsset)
  public static let transcriptionModels: [TranscriptionModelSpec] = all.map(\.transcriptionModelSpec)

  public static func model(id: String) -> FluidAudioModel? {
    all.first { $0.id == id }
  }

  public static func isSupportedModel(_ id: String) -> Bool {
    model(id: id) != nil
  }

  private static func streaming(id: String, name: String, storage: String, badge: String? = nil) -> FluidAudioModel {
    FluidAudioModel(
      id: id,
      displayName: name,
      role: .streamingASR,
      languageSupport: .english,
      storageSize: storage,
      accuracyStars: 4,
      speedStars: 5,
      isUserSelectableASR: true,
      badge: badge
    )
  }

  private static func diarization(id: String, name: String) -> FluidAudioModel {
    FluidAudioModel(
      id: id,
      displayName: name,
      role: .diarization,
      languageSupport: .support,
      storageSize: "120 MB",
      accuracyStars: 4,
      speedStars: 4,
      isUserSelectableASR: false
    )
  }
}
