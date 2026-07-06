import Foundation

/// A normalized event from a TimberVox Cloud realtime session. The worker forwards provider
/// events verbatim (Deepgram `Results`, Mistral `transcription.*`) alongside its own control
/// envelopes, so the parser understands both.
public enum RealtimeTranscriptionEvent: Equatable, Sendable {
  case sessionStarted(sessionID: String)
  case audioReceived(totalBytes: Int)
  case partialTranscript(String)
  case finalTranscript(String)
  case transcriptionDone(String)
  case sessionEnded
  case pong
  case providerError(String)
  case unrecognized(type: String)
}

public enum RealtimeEventParser {
  public static func parse(_ text: String) -> RealtimeTranscriptionEvent? {
    guard let data = text.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }

    if let error = object["error"] {
      return .providerError(describeError(error))
    }

    guard let type = object["type"] as? String else { return nil }

    switch type {
    case "session.started":
      return .sessionStarted(sessionID: object["session_id"] as? String ?? "")
    case "audio.received":
      return .audioReceived(totalBytes: object["audio_bytes"] as? Int ?? 0)
    case "session.ended":
      return .sessionEnded
    case "pong":
      return .pong
    case "Results":
      return parseDeepgramResults(object)
    case "transcription.text.delta":
      return .partialTranscript(object["text"] as? String ?? "")
    case "transcription.segment":
      return .finalTranscript(object["text"] as? String ?? "")
    case "transcription.done":
      return .transcriptionDone(object["text"] as? String ?? "")
    case "error", "Error":
      return .providerError(describeError(object))
    default:
      return .unrecognized(type: type)
    }
  }

  private static func parseDeepgramResults(_ object: [String: Any]) -> RealtimeTranscriptionEvent {
    let channel = object["channel"] as? [String: Any]
    let alternatives = channel?["alternatives"] as? [[String: Any]]
    let transcript = alternatives?.first?["transcript"] as? String ?? ""
    let isFinal = object["is_final"] as? Bool ?? false
    return isFinal ? .finalTranscript(transcript) : .partialTranscript(transcript)
  }

  private static func describeError(_ error: Any) -> String {
    if let text = error as? String {
      return text
    }
    if let dictionary = error as? [String: Any] {
      if let message = dictionary["message"] as? String {
        return message
      }
      if let data = try? JSONSerialization.data(withJSONObject: dictionary),
        let text = String(data: data, encoding: .utf8)
      {
        return text
      }
    }
    return String(describing: error)
  }
}
