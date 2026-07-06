import Foundation

struct DeepgramProbeResult {
  let normalized: DeepgramNormalizedOutput
  let rawJSON: Data
}

struct DeepgramNormalizedOutput: Codable {
  let modelID: String
  let diarize: Bool
  let requestURL: String
  let requestID: String?
  let providerModels: [String: DeepgramProviderModel]
  let transcript: String
  let confidence: Double?
  let words: [DeepgramWord]
  let segments: [DeepgramSpeakerSegment]
  let stats: DeepgramStats
  let outputShape: [String]
}

struct DeepgramProviderModel: Codable {
  let name: String?
  let version: String?
  let arch: String?
}

struct DeepgramWord: Codable {
  let word: String
  let punctuatedWord: String?
  let start: Double?
  let end: Double?
  let confidence: Double?
  let speaker: Int?
  let speakerConfidence: Double?
}

struct DeepgramSpeakerSegment: Codable {
  let speaker: Int
  let start: Double
  let end: Double
  let text: String
}

struct DeepgramStats: Codable {
  let wordCount: Int
  let speakerCount: Int
  let durationSeconds: Double?
  let providerDurationSeconds: Double?
  let averageWordConfidence: Double?
  let processingSeconds: Double
}

struct DeepgramProbe {
  let apiKey: String

  func run(model: String, diarize: Bool, audioURL: URL) async throws -> DeepgramProbeResult {
    var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
    components.queryItems = [
      URLQueryItem(name: "model", value: model),
      URLQueryItem(name: "smart_format", value: "true"),
      URLQueryItem(name: "diarize", value: diarize ? "true" : "false"),
    ]
    let url = components.url!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(contentType(for: audioURL), forHTTPHeaderField: "Content-Type")
    request.httpBody = try Data(contentsOf: audioURL)

    let start = Date()
    let (data, response) = try await URLSession.shared.data(for: request)
    let elapsed = Date().timeIntervalSince(start)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      let body = String(data: data, encoding: .utf8) ?? ""
      throw CLIError("Deepgram request failed status=\(status) body=\(body)")
    }

    let normalized = try normalize(data: data, model: model, diarize: diarize, requestURL: url.absoluteString, processingSeconds: elapsed)
    return DeepgramProbeResult(normalized: normalized, rawJSON: data)
  }

  private func normalize(data: Data, model: String, diarize: Bool, requestURL: String, processingSeconds: Double) throws -> DeepgramNormalizedOutput {
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let metadata = object?["metadata"] as? [String: Any]
    let results = object?["results"] as? [String: Any]
    let channels = results?["channels"] as? [[String: Any]]
    let alternatives = channels?.first?["alternatives"] as? [[String: Any]]
    let alternative = alternatives?.first
    let transcript = alternative?["transcript"] as? String ?? ""
    let confidence = alternative?["confidence"] as? Double
    let rawWords = alternative?["words"] as? [[String: Any]] ?? []
    let words = rawWords.map {
      DeepgramWord(
        word: $0["word"] as? String ?? "",
        punctuatedWord: $0["punctuated_word"] as? String,
        start: $0["start"] as? Double,
        end: $0["end"] as? Double,
        confidence: $0["confidence"] as? Double,
        speaker: $0["speaker"] as? Int,
        speakerConfidence: $0["speaker_confidence"] as? Double
      )
    }
    let segments = makeSpeakerSegments(words: words)
    let duration = words.compactMap(\.end).max()
    let confidences = words.compactMap(\.confidence)
    return DeepgramNormalizedOutput(
      modelID: model,
      diarize: diarize,
      requestURL: requestURL,
      requestID: metadata?["request_id"] as? String,
      providerModels: providerModels(from: metadata?["model_info"] as? [String: Any] ?? [:]),
      transcript: transcript,
      confidence: confidence,
      words: words,
      segments: segments,
      stats: DeepgramStats(
        wordCount: words.count,
        speakerCount: Set(words.compactMap(\.speaker)).count,
        durationSeconds: duration,
        providerDurationSeconds: metadata?["duration"] as? Double,
        averageWordConfidence: confidences.isEmpty ? nil : confidences.reduce(0, +) / Double(confidences.count),
        processingSeconds: processingSeconds
      ),
      outputShape: [
        "channel[0].alternatives[0].transcript and confidence",
        "word timings with start/end seconds and confidence",
        "speaker fields only when diarize=true",
        "speaker segments synthesized from contiguous word speaker labels",
        "raw Deepgram JSON persisted separately as raw.json",
      ]
    )
  }

  private func providerModels(from raw: [String: Any]) -> [String: DeepgramProviderModel] {
    raw.reduce(into: [:]) { partial, item in
      let value = item.value as? [String: Any] ?? [:]
      partial[item.key] = DeepgramProviderModel(
        name: value["name"] as? String,
        version: value["version"] as? String,
        arch: value["arch"] as? String
      )
    }
  }

  private func makeSpeakerSegments(words: [DeepgramWord]) -> [DeepgramSpeakerSegment] {
    guard words.contains(where: { $0.speaker != nil }) else { return [] }

    var segments: [DeepgramSpeakerSegment] = []
    var currentSpeaker: Int?
    var currentWords: [String] = []
    var start: Double?
    var end: Double?

    func flush() {
      guard let speaker = currentSpeaker, let startTime = start, let endTime = end, !currentWords.isEmpty else { return }
      segments.append(DeepgramSpeakerSegment(speaker: speaker, start: startTime, end: endTime, text: currentWords.joined(separator: " ")))
    }

    for word in words {
      let speaker = word.speaker ?? -1
      if currentSpeaker != speaker {
        flush()
        currentSpeaker = speaker
        currentWords = []
        start = word.start
      }
      currentWords.append(word.word)
      end = word.end
    }
    flush()
    return segments
  }

  private func contentType(for url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "wav": return "audio/wav"
    case "mp3": return "audio/mpeg"
    case "m4a": return "audio/mp4"
    case "flac": return "audio/flac"
    default: return "application/octet-stream"
    }
  }
}
