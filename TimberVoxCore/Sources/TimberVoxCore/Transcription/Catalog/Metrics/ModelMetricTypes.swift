import Foundation

public enum ModelMetricRuntime: String, Codable, Sendable {
  case localCoreML
  case localPathOnly
  case cloud
}

public enum ModelMetricSourceType: String, Codable, Sendable {
  case fluidAudioDocumentation
  case huggingFaceModelCard
  case upstreamPaper
  case timberVoxCloudRegistry
  case localDiagnostic
}

public enum ModelMetricProvenance: String, Codable, Sendable {
  case fluidAudioBenchmark
  case upstreamBenchmark
  case modelCard
  case modelConfiguration
  case measuredLocally
  case unknown
}

public enum PublishedMetricName: String, Codable, Sendable {
  case wordErrorRatePercent
  case characterErrorRatePercent
  case diarizationErrorRatePercent
  case jaccardErrorRatePercent
  case vadAccuracyPercent
  case vadPrecisionPercent
  case vadRecallPercent
  case vadF1Percent
  case vocabularyPrecisionPercent
  case vocabularyRecallPercent
  case vocabularyFScorePercent
  case realTimeFactor
  case medianRealTimeFactor
  case latencyMilliseconds
  case maxAudioSeconds
  case maxSpeakers
  case parameterCountMillions
}

public struct ModelMetricSource: Equatable, Codable, Sendable {
  public let title: String
  public let url: String
  public let sourceType: ModelMetricSourceType
  public let accessedOn: String

  public init(
    title: String,
    url: String,
    sourceType: ModelMetricSourceType,
    accessedOn: String = "2026-07-03"
  ) {
    self.title = title
    self.url = url
    self.sourceType = sourceType
    self.accessedOn = accessedOn
  }
}

public struct PublishedModelMetric: Equatable, Codable, Sendable {
  public let name: PublishedMetricName
  public let value: Double
  public let unit: String
  public let dataset: String?
  public let hardware: String?
  public let provenance: ModelMetricProvenance
  public let source: ModelMetricSource
  public let note: String?

  public init(
    name: PublishedMetricName,
    value: Double,
    unit: String,
    dataset: String? = nil,
    hardware: String? = nil,
    provenance: ModelMetricProvenance,
    source: ModelMetricSource,
    note: String? = nil
  ) {
    self.name = name
    self.value = value
    self.unit = unit
    self.dataset = dataset
    self.hardware = hardware
    self.provenance = provenance
    self.source = source
    self.note = note
  }
}

public struct ModelDownloadProfile: Equatable, Codable, Sendable {
  public let repository: String?
  public let subdirectory: String?
  public let requiresHuggingFaceToken: Bool
  public let approximateSizeMB: Double?
  public let cacheDirectory: String?
  public let source: ModelMetricSource?
  public let note: String?

  public init(
    repository: String?,
    subdirectory: String? = nil,
    requiresHuggingFaceToken: Bool = false,
    approximateSizeMB: Double? = nil,
    cacheDirectory: String? = nil,
    source: ModelMetricSource? = nil,
    note: String? = nil
  ) {
    self.repository = repository
    self.subdirectory = subdirectory
    self.requiresHuggingFaceToken = requiresHuggingFaceToken
    self.approximateSizeMB = approximateSizeMB
    self.cacheDirectory = cacheDirectory
    self.source = source
    self.note = note
  }
}

public struct ModelMetricProfile: Equatable, Codable, Sendable {
  public let modelID: String
  public let runtime: ModelMetricRuntime
  public let provider: String
  public let clientName: String?
  public let download: ModelDownloadProfile?
  public let officialMetrics: [PublishedModelMetric]
  public let sources: [ModelMetricSource]
  public let notes: [String]

  public init(
    modelID: String,
    runtime: ModelMetricRuntime,
    provider: String,
    clientName: String? = nil,
    download: ModelDownloadProfile? = nil,
    officialMetrics: [PublishedModelMetric] = [],
    sources: [ModelMetricSource],
    notes: [String] = []
  ) {
    self.modelID = modelID
    self.runtime = runtime
    self.provider = provider
    self.clientName = clientName
    self.download = download
    self.officialMetrics = officialMetrics
    self.sources = sources
    self.notes = notes
  }

  public static func unknown(modelID: String) -> ModelMetricProfile {
    ModelMetricProfile(
      modelID: modelID,
      runtime: .localCoreML,
      provider: "Unknown",
      sources: [],
      notes: ["No source-backed metric profile has been recorded for this model."]
    )
  }

  public func metrics(named name: PublishedMetricName) -> [PublishedModelMetric] {
    officialMetrics.filter { $0.name == name }
  }
}

public struct ModelDiagnosticMachineProfile: Equatable, Codable, Sendable {
  public let hardwareModel: String?
  public let chip: String?
  public let physicalMemoryGB: Double?
  public let operatingSystem: String
  public let appVersion: String?

  public init(
    hardwareModel: String?,
    chip: String?,
    physicalMemoryGB: Double?,
    operatingSystem: String,
    appVersion: String?
  ) {
    self.hardwareModel = hardwareModel
    self.chip = chip
    self.physicalMemoryGB = physicalMemoryGB
    self.operatingSystem = operatingSystem
    self.appVersion = appVersion
  }
}

public struct ModelDiagnosticFixture: Equatable, Codable, Sendable {
  public let id: String
  public let role: FluidAudioModelRole
  public let durationSeconds: Double?
  public let referenceText: String?
  public let source: String?

  public init(
    id: String,
    role: FluidAudioModelRole,
    durationSeconds: Double?,
    referenceText: String?,
    source: String?
  ) {
    self.id = id
    self.role = role
    self.durationSeconds = durationSeconds
    self.referenceText = referenceText
    self.source = source
  }
}

public enum ModelDiagnosticStatus: String, Codable, Sendable {
  case succeeded
  case failed
  case skipped
}

public struct ModelDiagnosticResult: Equatable, Codable, Sendable {
  public let id: UUID
  public let modelID: String
  public let status: ModelDiagnosticStatus
  public let fixture: ModelDiagnosticFixture
  public let machine: ModelDiagnosticMachineProfile
  public let measuredAt: Date
  public let coldLoadSeconds: Double?
  public let warmLoadSeconds: Double?
  public let transcriptionSeconds: Double?
  public let realTimeFactor: Double?
  public let peakDiskBytes: Int64?
  public let wordErrorRatePercent: Double?
  public let characterErrorRatePercent: Double?
  public let errorDescription: String?

  public init(
    id: UUID = UUID(),
    modelID: String,
    status: ModelDiagnosticStatus,
    fixture: ModelDiagnosticFixture,
    machine: ModelDiagnosticMachineProfile,
    measuredAt: Date = Date(),
    coldLoadSeconds: Double? = nil,
    warmLoadSeconds: Double? = nil,
    transcriptionSeconds: Double? = nil,
    realTimeFactor: Double? = nil,
    peakDiskBytes: Int64? = nil,
    wordErrorRatePercent: Double? = nil,
    characterErrorRatePercent: Double? = nil,
    errorDescription: String? = nil
  ) {
    self.id = id
    self.modelID = modelID
    self.status = status
    self.fixture = fixture
    self.machine = machine
    self.measuredAt = measuredAt
    self.coldLoadSeconds = coldLoadSeconds
    self.warmLoadSeconds = warmLoadSeconds
    self.transcriptionSeconds = transcriptionSeconds
    self.realTimeFactor = realTimeFactor
    self.peakDiskBytes = peakDiskBytes
    self.wordErrorRatePercent = wordErrorRatePercent
    self.characterErrorRatePercent = characterErrorRatePercent
    self.errorDescription = errorDescription
  }
}

public extension FluidAudioModel {
  var metricProfile: ModelMetricProfile {
    FluidAudioModelMetrics.profile(for: id) ?? .unknown(modelID: id)
  }
}
