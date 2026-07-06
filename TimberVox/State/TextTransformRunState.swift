import TimberVoxCore
import Foundation

struct TextTransformRunState: Equatable {
  enum Phase: String, Equatable {
    case idle
    case skipped
    case running
    case succeeded
    case emptyResult = "empty_result"
    case failed
  }

  var phase: Phase
  var mode: TextTransformMode?
  var requestedModelID: String?
  var responseModelID: String?
  var providerID: String?
  var inputCharacterCount: Int?
  var outputCharacterCount: Int?
  var outputPreview: String?
  var error: String?

  var isRunning: Bool {
    phase == .running
  }

  static let idle = TextTransformRunState(phase: .idle)

  static func skipped(reason: String? = nil) -> TextTransformRunState {
    TextTransformRunState(phase: .skipped, error: reason)
  }

  static func running(
    mode: TextTransformMode,
    request: TranscriptTransformRequest,
    input: String
  ) -> TextTransformRunState {
    TextTransformRunState(
      phase: .running,
      mode: mode,
      requestedModelID: request.modelID,
      inputCharacterCount: input.count
    )
  }

  static func succeeded(
    mode: TextTransformMode,
    request: TranscriptTransformRequest,
    completion: TextCompletion,
    input: String
  ) -> TextTransformRunState {
    TextTransformRunState(
      phase: .succeeded,
      mode: mode,
      requestedModelID: request.modelID,
      responseModelID: completion.modelID,
      providerID: completion.providerID.rawValue,
      inputCharacterCount: input.count,
      outputCharacterCount: completion.text.count,
      outputPreview: preview(completion.text)
    )
  }

  static func emptyResult(
    mode: TextTransformMode,
    request: TranscriptTransformRequest,
    completion: TextCompletion?,
    input: String
  ) -> TextTransformRunState {
    TextTransformRunState(
      phase: .emptyResult,
      mode: mode,
      requestedModelID: request.modelID,
      responseModelID: completion?.modelID,
      providerID: completion?.providerID.rawValue,
      inputCharacterCount: input.count,
      outputCharacterCount: completion?.text.count,
      outputPreview: preview(completion?.text ?? ""),
      error: "Text transform returned no text."
    )
  }

  static func failed(
    mode: TextTransformMode?,
    modelID: String?,
    inputCharacterCount: Int? = nil,
    message: String
  ) -> TextTransformRunState {
    TextTransformRunState(
      phase: .failed,
      mode: mode,
      requestedModelID: modelID,
      inputCharacterCount: inputCharacterCount,
      error: message
    )
  }

  private static func preview(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.count > 240 else { return trimmed }
    return String(trimmed.prefix(240)) + "..."
  }
}
