import Foundation

public enum TranscriptionRuntime: String, Codable, Equatable, Sendable {
  case local
  case cloud
}

public struct TranscriptionProviderID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public extension TranscriptionProviderID {
  static let fluidAudio = TranscriptionProviderID(rawValue: "fluidaudio")
  static let assemblyAI = TranscriptionProviderID(rawValue: "assemblyai")
  static let deepgram = TranscriptionProviderID(rawValue: "deepgram")
  static let elevenLabs = TranscriptionProviderID(rawValue: "elevenlabs")
  static let groq = TranscriptionProviderID(rawValue: "groq")
  static let mistral = TranscriptionProviderID(rawValue: "mistral")
  static let soniox = TranscriptionProviderID(rawValue: "soniox")
  static let speechmatics = TranscriptionProviderID(rawValue: "speechmatics")
}

public struct TranscriptionCapabilities: Codable, Equatable, Sendable {
  public let audioEventTags: Bool
  public let batch: Bool
  public let contextBiasing: Bool
  public let diarization: Bool
  public let entityDetection: Bool
  public let fileInput: Bool
  public let languageDetection: Bool
  public let languageHint: Bool
  public let keywordSpotting: Bool
  public let multiChannel: Bool
  public let partialResults: Bool
  public let realtime: Bool
  public let segmentTimestamps: Bool
  public let streamingInput: Bool
  public let translation: Bool
  public let urlInput: Bool
  public let voiceActivityDetection: Bool
  public let webhook: Bool
  public let wordTimestamps: Bool

  public init(
    audioEventTags: Bool = false,
    batch: Bool = false,
    contextBiasing: Bool = false,
    diarization: Bool = false,
    entityDetection: Bool = false,
    fileInput: Bool = false,
    languageDetection: Bool = false,
    languageHint: Bool = false,
    keywordSpotting: Bool = false,
    multiChannel: Bool = false,
    partialResults: Bool = false,
    realtime: Bool = false,
    segmentTimestamps: Bool = false,
    streamingInput: Bool = false,
    translation: Bool = false,
    urlInput: Bool = false,
    voiceActivityDetection: Bool = false,
    webhook: Bool = false,
    wordTimestamps: Bool = false
  ) {
    self.audioEventTags = audioEventTags
    self.batch = batch
    self.contextBiasing = contextBiasing
    self.diarization = diarization
    self.entityDetection = entityDetection
    self.fileInput = fileInput
    self.languageDetection = languageDetection
    self.languageHint = languageHint
    self.keywordSpotting = keywordSpotting
    self.multiChannel = multiChannel
    self.partialResults = partialResults
    self.realtime = realtime
    self.segmentTimestamps = segmentTimestamps
    self.streamingInput = streamingInput
    self.translation = translation
    self.urlInput = urlInput
    self.voiceActivityDetection = voiceActivityDetection
    self.webhook = webhook
    self.wordTimestamps = wordTimestamps
  }
}

public enum TranscriptionAssetRole: String, Codable, Equatable, Sendable {
  case primaryASR
  case vad
  case diarization
  case keywordSpotting
}

public struct TranscriptionModelSpec: Codable, Equatable, Sendable {
  public let id: String
  public let displayName: String
  public let provider: TranscriptionProviderID
  public let runtime: TranscriptionRuntime
  public let upstreamModel: String?
  public let docsURL: URL?
  public let capabilities: TranscriptionCapabilities
  public let assetRole: TranscriptionAssetRole
  public let supportedLanguages: Set<String>

  public init(
    id: String,
    displayName: String,
    provider: TranscriptionProviderID,
    runtime: TranscriptionRuntime,
    upstreamModel: String? = nil,
    docsURL: URL? = nil,
    capabilities: TranscriptionCapabilities,
    assetRole: TranscriptionAssetRole = .primaryASR,
    supportedLanguages: Set<String> = []
  ) {
    self.id = id
    self.displayName = displayName
    self.provider = provider
    self.runtime = runtime
    self.upstreamModel = upstreamModel
    self.docsURL = docsURL
    self.capabilities = capabilities
    self.assetRole = assetRole
    self.supportedLanguages = supportedLanguages
  }
}

public struct AudioSource: Equatable, Sendable {
  public let url: URL
  public let filename: String
  public let contentType: String?

  public init(url: URL, filename: String? = nil, contentType: String? = nil) {
    self.url = url
    self.filename = filename ?? url.lastPathComponent
    self.contentType = contentType
  }
}

public struct TranscriptionRequest: Equatable, Sendable {
  public let modelID: String
  public let language: String?
  public let diarize: Bool
  public let vocabulary: [String]

  public init(
    modelID: String,
    language: String? = nil,
    diarize: Bool = false,
    vocabulary: [String] = []
  ) {
    self.modelID = modelID
    self.language = language
    self.diarize = diarize
    self.vocabulary = vocabulary
  }
}

public struct TranscriptionWord: Codable, Equatable, Sendable {
  public let text: String
  public let startTime: TimeInterval?
  public let endTime: TimeInterval?
  public let confidence: Double?
  public let speakerID: String?

  public init(
    text: String,
    startTime: TimeInterval? = nil,
    endTime: TimeInterval? = nil,
    confidence: Double? = nil,
    speakerID: String? = nil
  ) {
    self.text = text
    self.startTime = startTime
    self.endTime = endTime
    self.confidence = confidence
    self.speakerID = speakerID
  }
}

public struct TranscriptionSegment: Codable, Equatable, Sendable {
  public let text: String
  public let startTime: TimeInterval?
  public let endTime: TimeInterval?
  public let speakerID: String?
  public let words: [TranscriptionWord]

  public init(
    text: String,
    startTime: TimeInterval? = nil,
    endTime: TimeInterval? = nil,
    speakerID: String? = nil,
    words: [TranscriptionWord] = []
  ) {
    self.text = text
    self.startTime = startTime
    self.endTime = endTime
    self.speakerID = speakerID
    self.words = words
  }
}

public struct TranscriptionDraft: Codable, Equatable, Sendable {
  public let text: String
  public let words: [TranscriptionWord]
  public let segments: [TranscriptionSegment]
  public let duration: TimeInterval?
  public let language: String?
  public let providerID: TranscriptionProviderID
  public let modelID: String

  public init(
    text: String,
    words: [TranscriptionWord] = [],
    segments: [TranscriptionSegment] = [],
    duration: TimeInterval? = nil,
    language: String? = nil,
    providerID: TranscriptionProviderID,
    modelID: String
  ) {
    self.text = text
    self.words = words
    self.segments = segments
    self.duration = duration
    self.language = language
    self.providerID = providerID
    self.modelID = modelID
  }
}

public protocol TranscriptionProvider: Sendable {
  var providerID: TranscriptionProviderID { get }
  var models: [TranscriptionModelSpec] { get }

  func transcribe(_ source: AudioSource, request: TranscriptionRequest) async throws -> TranscriptionDraft
}
