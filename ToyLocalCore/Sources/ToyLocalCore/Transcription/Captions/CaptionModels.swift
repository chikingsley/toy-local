import Foundation

public struct CaptionWord: Codable, Equatable, Sendable {
  public let text: String
  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let speakerID: String?
  public let confidence: Double?

  public init(
    text: String,
    startTime: TimeInterval,
    endTime: TimeInterval,
    speakerID: String? = nil,
    confidence: Double? = nil
  ) {
    self.text = text
    self.startTime = startTime
    self.endTime = max(endTime, startTime)
    self.speakerID = speakerID
    self.confidence = confidence
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
    let text = try container.decodeFlexibleString(keys: ["text", "punctuated_word", "word"])
    let start = try container.decodeFlexibleDouble(keys: ["start", "start_seconds"])
    let end = try container.decodeFlexibleDouble(keys: ["end", "end_seconds"], default: start)
    self.init(
      text: text,
      startTime: start,
      endTime: end,
      speakerID: container.decodeOptionalSpeakerID(),
      confidence: try container.decodeFlexibleDoubleIfPresent(keys: ["confidence"])
    )
  }
}

public struct CaptionTurn: Codable, Equatable, Sendable {
  public let text: String
  public let startTime: TimeInterval
  public let endTime: TimeInterval
  public let speakerID: String?
  public let words: [CaptionWord]

  public init(
    text: String,
    startTime: TimeInterval,
    endTime: TimeInterval,
    speakerID: String? = nil,
    words: [CaptionWord] = []
  ) {
    self.text = text
    self.startTime = startTime
    self.endTime = max(endTime, startTime)
    self.speakerID = speakerID
    self.words = words
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
    let text = try container.decodeFlexibleString(keys: ["text"])
    let start = try container.decodeFlexibleDouble(keys: ["start", "start_seconds"])
    let end = try container.decodeFlexibleDouble(keys: ["end", "end_seconds"], default: start)
    let words = try container.decodeIfPresent([CaptionWord].self, forKey: FlexibleCodingKey("words")) ?? []
    self.init(
      text: text,
      startTime: start,
      endTime: end,
      speakerID: container.decodeOptionalSpeakerID() ?? CaptionDocument.speakerID(from: words),
      words: words
    )
  }
}

public struct CaptionDocument: Equatable, Sendable {
  public let transcript: String
  public let words: [CaptionWord]
  public let turns: [CaptionTurn]
  public let provider: String?
  public let model: String?
  public let metadata: [String: String]

  public init(
    transcript: String,
    words: [CaptionWord] = [],
    turns: [CaptionTurn] = [],
    provider: String? = nil,
    model: String? = nil,
    metadata: [String: String] = [:]
  ) {
    self.transcript = transcript
    self.words = words
    self.turns = turns
    self.provider = provider
    self.model = model
    self.metadata = metadata
  }

  public init(jobResultData data: Data, decoder: JSONDecoder = JSONDecoder()) throws {
    let result = try decoder.decode(CloudJobResult.self, from: data)
    let asr = result.asr
    let turns = asr?.segments ?? []
    let decodedWords = asr?.words ?? []
    let words = decodedWords.isEmpty ? turns.flatMap(\.words) : decodedWords
    self.init(
      transcript: result.transcript ?? result.rawTranscript ?? words.map(\.text).joined(separator: " "),
      words: words,
      turns: turns.isEmpty && !words.isEmpty ? CaptionDocument.turns(from: words) : turns,
      provider: asr?.provider,
      model: asr?.model,
      metadata: result.metadata
    )
  }

  static func speakerID(from words: [CaptionWord]) -> String? {
    guard let first = words.first?.speakerID else {
      return nil
    }
    return words.allSatisfy { $0.speakerID == first } ? first : nil
  }

  private static func turns(from words: [CaptionWord]) -> [CaptionTurn] {
    guard let first = words.first else {
      return []
    }
    var turns: [CaptionTurn] = []
    var active: [CaptionWord] = []
    var currentSpeaker = first.speakerID
    var previousEnd = first.startTime

    func flush() {
      guard let start = active.first?.startTime, let end = active.last?.endTime else {
        return
      }
      let text = active.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty {
        turns.append(
          CaptionTurn(text: text, startTime: start, endTime: end, speakerID: currentSpeaker, words: active)
        )
      }
      active.removeAll(keepingCapacity: true)
    }

    for word in words {
      let gap = word.startTime - previousEnd
      if !active.isEmpty && (word.speakerID != currentSpeaker || gap > 3) {
        flush()
        currentSpeaker = word.speakerID
      }
      active.append(word)
      previousEnd = word.endTime
    }
    flush()
    return turns
  }
}

public enum CaptionRenderFormat: Sendable {
  case html(includeTimestamps: Bool = false, includeSpeakers: Bool = false, title: String = "Transcript")
  case json(includeTimestamps: Bool = true, includeSpeakers: Bool = true)
  case md(includeTimestamps: Bool = false, includeSpeakers: Bool = false, title: String = "Transcript")
  case srt
  case txt(includeTimestamps: Bool = false, includeSpeakers: Bool = false)
  case vtt(includeCueIDs: Bool = false)
}

public enum CaptionStrategy: String, Codable, Equatable, Sendable {
  case speakerSegments = "speaker-segments"
  case bestFit = "best-fit"
}

public struct CaptionRenderOptions: Equatable, Sendable {
  public let includeSpeakers: Bool
  public let maxCharsPerLine: Int
  public let maxLinesPerCue: Int
  public let maxSecondsPerCue: TimeInterval
  public let strategy: CaptionStrategy

  public init(
    includeSpeakers: Bool = false,
    maxCharsPerLine: Int = 42,
    maxLinesPerCue: Int = 2,
    maxSecondsPerCue: TimeInterval = 7,
    strategy: CaptionStrategy = .speakerSegments
  ) {
    self.includeSpeakers = includeSpeakers
    self.maxCharsPerLine = maxCharsPerLine
    self.maxLinesPerCue = maxLinesPerCue
    self.maxSecondsPerCue = maxSecondsPerCue
    self.strategy = strategy
  }
}

public enum CaptionRenderingError: Error, Equatable {
  case missingTimedTranscript
  case invalidArtifactBody
}

public enum CaptionArtifactFormat: String, CaseIterable, Sendable {
  case docx
  case html
  case json
  case md
  case pdf
  case srt
  case txt
  case vtt
}

public enum CaptionArtifactEncoding: String, Sendable {
  case base64
  case utf8 = "utf-8"
}

public struct CaptionArtifact: Equatable, Sendable {
  public let name: String
  public let contentType: String
  public let encoding: CaptionArtifactEncoding
  public let data: Data

  public var text: String? {
    guard encoding == .utf8 else { return nil }
    return String(data: data, encoding: .utf8)
  }

  public init(
    name: String,
    contentType: String,
    encoding: CaptionArtifactEncoding,
    data: Data
  ) {
    self.name = name
    self.contentType = contentType
    self.encoding = encoding
    self.data = data
  }
}

struct TranscriptBlock {
  let header: String?
  let text: String
}
