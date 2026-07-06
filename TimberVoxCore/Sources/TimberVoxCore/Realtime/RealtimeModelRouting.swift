import Foundation

/// Maps a selected transcription model to the worker's realtime route ID, when one exists.
/// Deepgram batch and realtime route IDs match; Voxtral uses a dedicated realtime model.
public enum RealtimeModelRouting {
  public static func realtimeRouteID(forModelID modelID: String) -> String? {
    switch modelID {
    case "deepgram-nova-3", "deepgram-nova-2":
      modelID
    case "mistral-voxtral-mini-latest":
      "mistral-voxtral-mini-transcribe-realtime-2602"
    default:
      nil
    }
  }
}

/// Accumulates realtime events into preview text (finals + trailing partial) and a final
/// transcript once the session ends.
public struct RealtimeTranscriptAssembler: Sendable {
  private var finals: [String] = []
  private var lastPartial = ""
  private var doneText: String?

  public init() {}

  public mutating func consume(_ event: RealtimeTranscriptionEvent) {
    switch event {
    case .partialTranscript(let text):
      if !text.isEmpty {
        lastPartial = text
      }
    case .finalTranscript(let text):
      if !text.isEmpty {
        finals.append(text)
        lastPartial = ""
      }
    case .transcriptionDone(let text):
      if !text.isEmpty {
        doneText = text
      }
    default:
      break
    }
  }

  public var previewText: String {
    let base = finals.joined(separator: " ")
    if lastPartial.isEmpty {
      return base
    }
    return base.isEmpty ? lastPartial : "\(base) \(lastPartial)"
  }

  public var finalText: String? {
    if let doneText {
      return doneText
    }
    let preview = previewText
    return preview.isEmpty ? nil : preview
  }
}
