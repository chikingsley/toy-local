import Foundation

struct ArtifactReportOutput: Codable {
  let generatedAt: Date
  let outputRoot: String
  let runCount: Int
  let statusCounts: [String: Int]
  let runs: [ArtifactRunReport]
}

struct ArtifactRunReport: Codable {
  let name: String
  let path: String
  let command: String?
  let modelID: String?
  let status: String?
  let audioPath: String?
  let hasRaw: Bool
  let hasDiagnostics: Bool
  let hasProgressLog: Bool
  let outputShape: [String]
  let asr: ASRArtifactStats?
  let vad: VADArtifactStats?
  let diarization: DiarizationArtifactStats?
  let keyword: KeywordArtifactStats?
  let deepgram: DeepgramArtifactStats?
  let interruptionOrFailure: [String: String]?
  let decodeWarning: String?
}

struct ASRArtifactStats: Codable {
  let textLength: Int
  let audioDurationSeconds: Double
  let loadSeconds: Double?
  let inferenceSeconds: Double?
  let totalWallSeconds: Double
  let rtfx: Double?
  let confidence: Float?
  let tokenTimingCount: Int?
  let producesText: Bool
  let producesTokenTimings: Bool
  let producesWordTimings: Bool
  let producesSpeakerLabels: Bool
  let producesLanguage: Bool
}

struct VADArtifactStats: Codable {
  let chunkCount: Int
  let activeChunkCount: Int
  let speechSegmentCount: Int
  let speechSeconds: Double
  let processingSeconds: Double
  let rtfx: Double?
}

struct DiarizationArtifactStats: Codable {
  let segmentCount: Int
  let speakerCount: Int
  let totalSpeechSeconds: Float
  let overlapSeconds: Float
  let maxConcurrentSpeakers: Int
  let averageSegmentSeconds: Float
  let processingSeconds: Double
  let rtfx: Double?
  let speakerStats: [DiarizationSpeakerStats]
}

struct KeywordArtifactStats: Codable {
  let requestedTermCount: Int
  let detectedTermCount: Int
  let uniqueDetectedTermCount: Int
  let bestScore: Float?
  let frameDuration: Double
  let totalFrames: Int
  let logProbabilityShape: [Int]
  let processingSeconds: Double
  let rtfx: Double?
}

struct DeepgramArtifactStats: Codable {
  let diarize: Bool
  let transcriptLength: Int
  let wordCount: Int
  let speakerCount: Int
  let segmentCount: Int
  let durationSeconds: Double?
  let providerDurationSeconds: Double?
  let averageWordConfidence: Double?
  let processingSeconds: Double
  let requestID: String?
}

enum ArtifactReport {
  static func build(outputRoot: URL) throws -> ArtifactReportOutput {
    let index = try RunIndex.build(outputRoot: outputRoot)
    let reports = index.runs.map { run in
      report(for: run)
    }
    let statusCounts = Dictionary(grouping: reports, by: { $0.status ?? "unknown" })
      .mapValues(\.count)

    return ArtifactReportOutput(
      generatedAt: Date(),
      outputRoot: outputRoot.path,
      runCount: reports.count,
      statusCounts: statusCounts,
      runs: reports
    )
  }

  private static func report(for run: RunIndexEntry) -> ArtifactRunReport {
    let resultURL = URL(fileURLWithPath: run.path).appendingPathComponent("result.json")
    let data = try? Data(contentsOf: resultURL)
    var outputShape: [String] = []
    var asr: ASRArtifactStats?
    var vad: VADArtifactStats?
    var diarization: DiarizationArtifactStats?
    var keyword: KeywordArtifactStats?
    var deepgram: DeepgramArtifactStats?
    var interruptionOrFailure: [String: String]?
    var decodeWarning: String?

    if let data {
      if run.status != "ok" {
        interruptionOrFailure = scalarObject(from: data)
      } else {
        do {
        switch run.command {
        case "asr":
          let output = try decode(ASRProbeOutput.self, from: data)
          outputShape = output.outputShape.notes
          asr = ASRArtifactStats(
            textLength: output.text.count,
            audioDurationSeconds: output.audio.durationSeconds,
            loadSeconds: output.timings.loadSeconds,
            inferenceSeconds: output.timings.inferenceSeconds,
            totalWallSeconds: output.timings.totalWallSeconds,
            rtfx: output.rtfx,
            confidence: output.confidence,
            tokenTimingCount: output.tokenTimings?.count,
            producesText: output.outputShape.producesText,
            producesTokenTimings: output.outputShape.producesTokenTimings,
            producesWordTimings: output.outputShape.producesWordTimings,
            producesSpeakerLabels: output.outputShape.producesSpeakerLabels,
            producesLanguage: output.outputShape.producesLanguage
          )
        case "vad":
          let output = try decode(VADProbeOutput.self, from: data)
          outputShape = output.outputShape
          vad = VADArtifactStats(
            chunkCount: output.stats.chunkCount,
            activeChunkCount: output.stats.activeChunkCount,
            speechSegmentCount: output.stats.speechSegmentCount,
            speechSeconds: output.stats.speechSeconds,
            processingSeconds: output.stats.processingSeconds,
            rtfx: output.stats.rtfx
          )
        case "diarize":
          let output = try decode(DiarizationProbeOutput.self, from: data)
          outputShape = output.outputShape
          diarization = DiarizationArtifactStats(
            segmentCount: output.stats.segmentCount,
            speakerCount: output.stats.speakerCount,
            totalSpeechSeconds: output.stats.totalSpeechSeconds,
            overlapSeconds: output.stats.overlapSeconds,
            maxConcurrentSpeakers: output.stats.maxConcurrentSpeakers,
            averageSegmentSeconds: output.stats.averageSegmentSeconds,
            processingSeconds: output.stats.processingSeconds,
            rtfx: output.stats.rtfx,
            speakerStats: output.speakerStats
          )
        case "keyword":
          let output = try decode(KeywordProbeOutput.self, from: data)
          outputShape = output.outputShape
          keyword = KeywordArtifactStats(
            requestedTermCount: output.stats.requestedTermCount,
            detectedTermCount: output.stats.detectedTermCount,
            uniqueDetectedTermCount: output.stats.uniqueDetectedTermCount,
            bestScore: output.stats.bestScore,
            frameDuration: output.frameDuration,
            totalFrames: output.totalFrames,
            logProbabilityShape: output.logProbabilityShape,
            processingSeconds: output.processingSeconds,
            rtfx: output.rtfx
          )
        case "deepgram":
          let output = try decode(DeepgramNormalizedOutput.self, from: data)
          outputShape = output.outputShape
          deepgram = DeepgramArtifactStats(
            diarize: output.diarize,
            transcriptLength: output.transcript.count,
            wordCount: output.stats.wordCount,
            speakerCount: output.stats.speakerCount,
            segmentCount: output.segments.count,
            durationSeconds: output.stats.durationSeconds,
            providerDurationSeconds: output.stats.providerDurationSeconds,
            averageWordConfidence: output.stats.averageWordConfidence,
            processingSeconds: output.stats.processingSeconds,
            requestID: output.requestID
          )
        default:
          break
        }
        } catch {
          if let legacy = legacyReport(command: run.command, data: data) {
            outputShape = legacy.outputShape
            asr = legacy.asr
            keyword = legacy.keyword
            deepgram = legacy.deepgram
          } else {
            interruptionOrFailure = scalarObject(from: data)
            decodeWarning = String(describing: error)
          }
        }
      }
    }

    return ArtifactRunReport(
      name: run.name,
      path: run.path,
      command: run.command,
      modelID: run.modelID,
      status: run.status,
      audioPath: run.audioPath,
      hasRaw: run.hasRaw,
      hasDiagnostics: run.hasDiagnostics,
      hasProgressLog: run.hasProgressLog,
      outputShape: outputShape,
      asr: asr,
      vad: vad,
      diarization: diarization,
      keyword: keyword,
      deepgram: deepgram,
      interruptionOrFailure: interruptionOrFailure,
      decodeWarning: decodeWarning
    )
  }

  private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    try JSONDecoder().decode(type, from: data)
  }

  private static func legacyReport(command: String?, data: Data) -> LegacyArtifactReport? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    switch command {
    case "asr":
      guard let text = object["text"] as? String else { return nil }
      let duration = number(object["durationSeconds"]) ?? 0
      let processing = number(object["processingSeconds"]) ?? 0
      return LegacyArtifactReport(
        outputShape: ["legacy ASR result: text, durationSeconds, processingSeconds, RTFx, optional confidence/token timings"],
        asr: ASRArtifactStats(
          textLength: text.count,
          audioDurationSeconds: duration,
          loadSeconds: nil,
          inferenceSeconds: nil,
          totalWallSeconds: processing,
          rtfx: number(object["rtfx"]),
          confidence: number(object["confidence"]).map(Float.init),
          tokenTimingCount: (object["tokenTimings"] as? [Any])?.count,
          producesText: true,
          producesTokenTimings: (object["tokenTimings"] as? [Any])?.isEmpty == false,
          producesWordTimings: false,
          producesSpeakerLabels: false,
          producesLanguage: false
        )
      )
    case "keyword":
      guard let detections = object["detections"] as? [[String: Any]] else { return nil }
      let scores = detections.compactMap { number($0["score"]).map(Float.init) }
      let terms = object["terms"] as? [String] ?? []
      return LegacyArtifactReport(
        outputShape: ["legacy keyword result: detections, frameDuration, totalFrames, logProbabilityShape"],
        keyword: KeywordArtifactStats(
          requestedTermCount: terms.count,
          detectedTermCount: detections.count,
          uniqueDetectedTermCount: Set(detections.compactMap { $0["term"] as? String }).count,
          bestScore: scores.max(),
          frameDuration: number(object["frameDuration"]) ?? 0,
          totalFrames: int(object["totalFrames"]) ?? 0,
          logProbabilityShape: object["logProbabilityShape"] as? [Int] ?? [],
          processingSeconds: number(object["processingSeconds"]) ?? 0,
          rtfx: number(object["rtfx"])
        )
      )
    case "deepgram":
      guard let transcript = object["transcript"] as? String else { return nil }
      let stats = object["stats"] as? [String: Any] ?? [:]
      let words = object["words"] as? [[String: Any]] ?? []
      let segments = object["segments"] as? [[String: Any]] ?? []
      let confidences = words.compactMap { number($0["confidence"]) }
      return LegacyArtifactReport(
        outputShape: ["legacy Deepgram result: transcript, words, optional speaker segments, normalized stats"],
        deepgram: DeepgramArtifactStats(
          diarize: bool(object["diarize"]) ?? false,
          transcriptLength: transcript.count,
          wordCount: int(stats["wordCount"]) ?? words.count,
          speakerCount: int(stats["speakerCount"]) ?? Set(words.compactMap { int($0["speaker"]) }).count,
          segmentCount: segments.count,
          durationSeconds: number(stats["durationSeconds"]),
          providerDurationSeconds: number(stats["providerDurationSeconds"]),
          averageWordConfidence: confidences.isEmpty ? nil : confidences.reduce(0, +) / Double(confidences.count),
          processingSeconds: number(stats["processingSeconds"]) ?? 0,
          requestID: object["requestID"] as? String
        )
      )
    default:
      return nil
    }
  }

  private static func scalarObject(from data: Data) -> [String: String]? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return object.compactMapValues { value in
      switch value {
      case let string as String: return string
      case let number as NSNumber: return number.stringValue
      default: return nil
      }
    }
  }

  private static func number(_ value: Any?) -> Double? {
    switch value {
    case let double as Double: return double
    case let float as Float: return Double(float)
    case let int as Int: return Double(int)
    case let number as NSNumber: return number.doubleValue
    case let string as String: return Double(string)
    default: return nil
    }
  }

  private static func int(_ value: Any?) -> Int? {
    switch value {
    case let int as Int: return int
    case let number as NSNumber: return number.intValue
    case let string as String: return Int(string)
    default: return nil
    }
  }

  private static func bool(_ value: Any?) -> Bool? {
    switch value {
    case let bool as Bool: return bool
    case let number as NSNumber: return number.boolValue
    case let string as String:
      switch string.lowercased() {
      case "true", "1", "yes", "y": return true
      case "false", "0", "no", "n": return false
      default: return nil
      }
    default:
      return nil
    }
  }
}

private struct LegacyArtifactReport {
  var outputShape: [String]
  var asr: ASRArtifactStats?
  var keyword: KeywordArtifactStats?
  var deepgram: DeepgramArtifactStats?

  init(
    outputShape: [String],
    asr: ASRArtifactStats? = nil,
    keyword: KeywordArtifactStats? = nil,
    deepgram: DeepgramArtifactStats? = nil
  ) {
    self.outputShape = outputShape
    self.asr = asr
    self.keyword = keyword
    self.deepgram = deepgram
  }
}
