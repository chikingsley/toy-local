import Foundation

struct DiagnosticsInput: Codable {
  let audioPath: String
  let scope: String
  let requestedModels: [String]
  let keywordTerms: [String]
  let includeCloud: Bool
}

struct DiagnosticsReport: Codable {
  let generatedAt: Date
  let audioPath: String
  let scope: String
  let machine: DiagnosticsMachine
  let selectedModelCount: Int
  let statusCounts: [String: Int]
  let results: [DiagnosticsModelResult]
}

struct DiagnosticsMachine: Codable {
  let hostName: String
  let operatingSystem: String
  let architecture: String
  let processorCount: Int
  let activeProcessorCount: Int
  let physicalMemoryGB: Double

  static var current: DiagnosticsMachine {
    DiagnosticsMachine(
      hostName: ProcessInfo.processInfo.hostName,
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: architecture,
      processorCount: ProcessInfo.processInfo.processorCount,
      activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
      physicalMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    )
  }

  private static var architecture: String {
    #if arch(arm64)
      "arm64"
    #elseif arch(x86_64)
      "x86_64"
    #else
      "unknown"
    #endif
  }
}

struct DiagnosticsModelResult: Codable {
  let modelID: String
  let displayName: String
  let family: String
  let runtime: String
  let command: String
  let status: String
  let error: String?
  let metrics: DiagnosticsMetrics
  let outputShape: [String]
}

struct DiagnosticsMetrics: Codable {
  let audioDurationSeconds: Double?
  let loadSeconds: Double?
  let inferenceSeconds: Double?
  let totalWallSeconds: Double?
  let processingSeconds: Double?
  let realTimeFactor: Double?
  let textLength: Int?
  let tokenTimingCount: Int?
  let speechSeconds: Double?
  let segmentCount: Int?
  let speakerCount: Int?
  let detectedTermCount: Int?
  let requestedTermCount: Int?
  let wordCount: Int?
  let averageWordConfidence: Double?

  static let empty = DiagnosticsMetrics(
    audioDurationSeconds: nil,
    loadSeconds: nil,
    inferenceSeconds: nil,
    totalWallSeconds: nil,
    processingSeconds: nil,
    realTimeFactor: nil,
    textLength: nil,
    tokenTimingCount: nil,
    speechSeconds: nil,
    segmentCount: nil,
    speakerCount: nil,
    detectedTermCount: nil,
    requestedTermCount: nil,
    wordCount: nil,
    averageWordConfidence: nil
  )
}

enum DiagnosticsScope: String {
  case quick
  case supportedLocal = "supported-local"
  case asr
  case support
  case cloud
}

enum DiagnosticsRunner {
  static func selectedModels(scope: String, explicitModels: [String]) throws -> [PrototypeModel] {
    let models = ModelInventory.all
    if !explicitModels.isEmpty {
      return try explicitModels.map { id in
        guard let model = models.first(where: { $0.id == id }) else {
          throw CLIError("unsupported diagnostics model: \(id)")
        }
        return model
      }
    }

    let parsedScope = DiagnosticsScope(rawValue: scope) ?? .quick
    switch parsedScope {
    case .quick:
      return models.filter { ["silero-vad", "parakeet-tdt-ctc-110m-coreml", "sortformer-fast-v2.1", "ctc110m"].contains($0.id) }
    case .supportedLocal:
      return models.filter { $0.runtime == "local" && $0.runnable }
    case .asr:
      return models.filter { $0.runtime == "local" && $0.family.contains("asr") && $0.runnable }
    case .support:
      return models.filter { $0.runtime == "local" && !$0.family.contains("asr") && $0.runnable }
    case .cloud:
      return models.filter { $0.runtime == "cloud" && $0.runnable }
    }
  }

  static func run(
    audioURL: URL,
    scope: String,
    models: [PrototypeModel],
    keywordTerms: [String],
    deepgramApiKey: String?
  ) async -> DiagnosticsReport {
    var results: [DiagnosticsModelResult] = []

    for model in models {
      results.append(await run(model: model, audioURL: audioURL, keywordTerms: keywordTerms, deepgramApiKey: deepgramApiKey))
    }

    let statusCounts = Dictionary(grouping: results, by: \.status).mapValues(\.count)
    return DiagnosticsReport(
      generatedAt: Date(),
      audioPath: audioURL.path,
      scope: scope,
      machine: .current,
      selectedModelCount: models.count,
      statusCounts: statusCounts,
      results: results
    )
  }

  private static func run(
    model: PrototypeModel,
    audioURL: URL,
    keywordTerms: [String],
    deepgramApiKey: String?
  ) async -> DiagnosticsModelResult {
    guard let command = model.probeCommand else {
      return failure(model: model, command: "unknown", error: "model has no probe command")
    }

    do {
      switch command {
      case "asr":
        let output = try await LocalASRProbe.run(modelID: model.id, audioURL: audioURL)
        return success(model: model, command: command, output: output)
      case "vad":
        let output = try await VADProbe.run(audioURL: audioURL)
        return success(model: model, command: command, output: output)
      case "diarize":
        let output = try await DiarizationProbe.run(modelID: model.id, audioURL: audioURL)
        return success(model: model, command: command, output: output)
      case "keyword":
        let output = try await KeywordProbe.run(modelID: model.id, audioURL: audioURL, terms: keywordTerms)
        return success(model: model, command: command, output: output)
      case "deepgram":
        guard let deepgramApiKey, !deepgramApiKey.isEmpty else {
          return failure(model: model, command: command, error: "missing Deepgram key")
        }
        let diarize = model.id == "deepgram-nova-3-diarized"
        let output = try await DeepgramProbe(apiKey: deepgramApiKey).run(model: "nova-3", diarize: diarize, audioURL: audioURL)
        return success(model: model, command: command, output: output.normalized)
      default:
        return failure(model: model, command: command, error: "unsupported diagnostics command: \(command)")
      }
    } catch {
      return failure(model: model, command: command, error: error.localizedDescription)
    }
  }

  private static func success(model: PrototypeModel, command: String, output: ASRProbeOutput) -> DiagnosticsModelResult {
    DiagnosticsModelResult(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: command,
      status: "ok",
      error: nil,
      metrics: DiagnosticsMetrics(
        audioDurationSeconds: output.audio.durationSeconds,
        loadSeconds: output.timings.loadSeconds,
        inferenceSeconds: output.timings.inferenceSeconds,
        totalWallSeconds: output.timings.totalWallSeconds,
        processingSeconds: output.processingSeconds,
        realTimeFactor: output.rtfx,
        textLength: output.text.count,
        tokenTimingCount: output.tokenTimings?.count,
        speechSeconds: nil,
        segmentCount: nil,
        speakerCount: nil,
        detectedTermCount: nil,
        requestedTermCount: nil,
        wordCount: nil,
        averageWordConfidence: output.confidence.map(Double.init)
      ),
      outputShape: output.outputShape.notes
    )
  }

  private static func success(model: PrototypeModel, command: String, output: VADProbeOutput) -> DiagnosticsModelResult {
    DiagnosticsModelResult(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: command,
      status: "ok",
      error: nil,
      metrics: DiagnosticsMetrics(
        audioDurationSeconds: nil,
        loadSeconds: nil,
        inferenceSeconds: nil,
        totalWallSeconds: output.stats.processingSeconds,
        processingSeconds: output.stats.processingSeconds,
        realTimeFactor: output.stats.rtfx,
        textLength: nil,
        tokenTimingCount: nil,
        speechSeconds: output.stats.speechSeconds,
        segmentCount: output.stats.speechSegmentCount,
        speakerCount: nil,
        detectedTermCount: nil,
        requestedTermCount: nil,
        wordCount: nil,
        averageWordConfidence: nil
      ),
      outputShape: output.outputShape
    )
  }

  private static func success(model: PrototypeModel, command: String, output: DiarizationProbeOutput) -> DiagnosticsModelResult {
    DiagnosticsModelResult(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: command,
      status: "ok",
      error: nil,
      metrics: DiagnosticsMetrics(
        audioDurationSeconds: nil,
        loadSeconds: nil,
        inferenceSeconds: nil,
        totalWallSeconds: output.stats.processingSeconds,
        processingSeconds: output.stats.processingSeconds,
        realTimeFactor: output.stats.rtfx,
        textLength: nil,
        tokenTimingCount: nil,
        speechSeconds: Double(output.stats.totalSpeechSeconds),
        segmentCount: output.stats.segmentCount,
        speakerCount: output.stats.speakerCount,
        detectedTermCount: nil,
        requestedTermCount: nil,
        wordCount: nil,
        averageWordConfidence: nil
      ),
      outputShape: output.outputShape
    )
  }

  private static func success(model: PrototypeModel, command: String, output: KeywordProbeOutput) -> DiagnosticsModelResult {
    DiagnosticsModelResult(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: command,
      status: "ok",
      error: nil,
      metrics: DiagnosticsMetrics(
        audioDurationSeconds: nil,
        loadSeconds: nil,
        inferenceSeconds: nil,
        totalWallSeconds: output.processingSeconds,
        processingSeconds: output.processingSeconds,
        realTimeFactor: output.rtfx,
        textLength: nil,
        tokenTimingCount: nil,
        speechSeconds: nil,
        segmentCount: nil,
        speakerCount: nil,
        detectedTermCount: output.stats.detectedTermCount,
        requestedTermCount: output.stats.requestedTermCount,
        wordCount: nil,
        averageWordConfidence: nil
      ),
      outputShape: output.outputShape
    )
  }

  private static func success(model: PrototypeModel, command: String, output: DeepgramNormalizedOutput) -> DiagnosticsModelResult {
    DiagnosticsModelResult(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: command,
      status: "ok",
      error: nil,
      metrics: DiagnosticsMetrics(
        audioDurationSeconds: output.stats.durationSeconds,
        loadSeconds: nil,
        inferenceSeconds: nil,
        totalWallSeconds: output.stats.processingSeconds,
        processingSeconds: output.stats.processingSeconds,
        realTimeFactor: nil,
        textLength: output.transcript.count,
        tokenTimingCount: nil,
        speechSeconds: nil,
        segmentCount: output.segments.count,
        speakerCount: output.stats.speakerCount,
        detectedTermCount: nil,
        requestedTermCount: nil,
        wordCount: output.stats.wordCount,
        averageWordConfidence: output.stats.averageWordConfidence
      ),
      outputShape: output.outputShape
    )
  }

  private static func failure(model: PrototypeModel, command: String, error: String) -> DiagnosticsModelResult {
    DiagnosticsModelResult(
      modelID: model.id,
      displayName: model.displayName,
      family: model.family,
      runtime: model.runtime,
      command: command,
      status: "failed",
      error: error,
      metrics: .empty,
      outputShape: []
    )
  }
}
