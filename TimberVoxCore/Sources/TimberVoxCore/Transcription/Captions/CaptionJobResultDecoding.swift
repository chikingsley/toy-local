import Foundation

struct CloudJobResult: Decodable {
  let transcript: String?
  let rawTranscript: String?
  let asr: CloudASRResult?
  let metadata: [String: String]

  private enum CodingKeys: String, CodingKey {
    case asr
    case language
    case metadata
    case mode
    case rawTranscript = "raw_transcript"
    case timing
    case transcript
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
    rawTranscript = try container.decodeIfPresent(String.self, forKey: .rawTranscript)
    asr = try container.decodeIfPresent(CloudASRResult.self, forKey: .asr)

    var values: [String: String] = [:]
    if let metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) {
      values.merge(metadata) { current, _ in current }
    }
    if let language = try container.decodeIfPresent(String.self, forKey: .language) {
      values["language"] = language
    }
    if let mode = try container.decodeIfPresent(String.self, forKey: .mode) {
      values["mode"] = mode
    }
    if let timing = try? container.decodeIfPresent(String.self, forKey: .timing) {
      values["timing"] = timing
    }
    self.metadata = values
  }
}

struct CloudASRResult: Decodable {
  let model: String?
  let provider: String?
  let segments: [CaptionTurn]
  let words: [CaptionWord]

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
    model = try container.decodeIfPresent(String.self, forKey: FlexibleCodingKey("model"))
    provider = try container.decodeIfPresent(String.self, forKey: FlexibleCodingKey("provider"))
    segments = try container.decodeIfPresent([CaptionTurn].self, forKey: FlexibleCodingKey("segments")) ?? []
    words = try container.decodeIfPresent([CaptionWord].self, forKey: FlexibleCodingKey("words")) ?? []
  }
}

struct FlexibleCodingKey: CodingKey, Hashable {
  let stringValue: String
  let intValue: Int? = nil

  init(_ stringValue: String) {
    self.stringValue = stringValue
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue _: Int) {
    return nil
  }
}

extension KeyedDecodingContainer where Key == FlexibleCodingKey {
  func decodeFlexibleString(keys: [String]) throws -> String {
    for key in keys {
      if let value = try decodeIfPresent(String.self, forKey: FlexibleCodingKey(key)), !value.isEmpty {
        return value
      }
    }
    throw DecodingError.keyNotFound(
      FlexibleCodingKey(keys[0]),
      DecodingError.Context(codingPath: codingPath, debugDescription: "Expected one of \(keys)")
    )
  }

  func decodeFlexibleDouble(keys: [String], default defaultValue: Double? = nil) throws -> Double {
    if let value = try decodeFlexibleDoubleIfPresent(keys: keys) {
      return value
    }
    if let defaultValue {
      return defaultValue
    }
    throw DecodingError.keyNotFound(
      FlexibleCodingKey(keys[0]),
      DecodingError.Context(codingPath: codingPath, debugDescription: "Expected one of \(keys)")
    )
  }

  func decodeFlexibleDoubleIfPresent(keys: [String]) throws -> Double? {
    for key in keys {
      if let value = try decodeIfPresent(Double.self, forKey: FlexibleCodingKey(key)) {
        return value
      }
      if let value = try decodeIfPresent(Int.self, forKey: FlexibleCodingKey(key)) {
        return Double(value)
      }
    }
    return nil
  }

  func decodeOptionalSpeakerID() -> String? {
    for key in ["speaker_id", "speaker"] {
      if let value = try? decodeIfPresent(String.self, forKey: FlexibleCodingKey(key)), !value.isEmpty {
        return value.hasPrefix("speaker_") ? value : "speaker_\(value)"
      }
      if let value = try? decodeIfPresent(Int.self, forKey: FlexibleCodingKey(key)) {
        return "speaker_\(value)"
      }
    }
    return nil
  }
}
