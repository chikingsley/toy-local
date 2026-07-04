import Foundation

public struct TranscriptTransformRequest: Codable, Equatable, Sendable {
  public let modelID: String
  public let preset: TextTransformPreset
  public let context: DictationContext?
  public let contextOptions: DictationContextOptions

  public init(
    modelID: String,
    preset: TextTransformPreset,
    context: DictationContext? = nil,
    contextOptions: DictationContextOptions = .init()
  ) {
    self.modelID = modelID
    self.preset = preset
    self.context = context
    self.contextOptions = contextOptions
  }
}

public struct FinalTranscript: Equatable, Sendable {
  public let text: String
  public let draft: TranscriptionDraft
  public let transform: TextCompletion?

  public init(text: String, draft: TranscriptionDraft, transform: TextCompletion? = nil) {
    self.text = text
    self.draft = draft
    self.transform = transform
  }
}

public struct TranscriptionPipeline: Sendable {
  private let transcribe: @Sendable (AudioSource, TranscriptionRequest) async throws -> TranscriptionDraft
  private let complete: (@Sendable (TextCompletionRequest) async throws -> TextCompletion)?

  public init(
    transcribe: @escaping @Sendable (AudioSource, TranscriptionRequest) async throws -> TranscriptionDraft,
    complete: (@Sendable (TextCompletionRequest) async throws -> TextCompletion)? = nil
  ) {
    self.transcribe = transcribe
    self.complete = complete
  }

  public func run(
    source: AudioSource,
    transcriptionRequest: TranscriptionRequest,
    transformRequest: TranscriptTransformRequest? = nil
  ) async throws -> FinalTranscript {
    let draft = try await transcribe(source, transcriptionRequest)
    guard let transformRequest else {
      return FinalTranscript(text: draft.text, draft: draft)
    }

    guard let complete else {
      throw TranscriptionPipelineError.textProviderRequired
    }

    let completion = try await complete(
      TextCompletionRequest(
        modelID: transformRequest.modelID,
        messages: TextTransformPromptBuilder.messages(
          preset: transformRequest.preset,
          transcript: draft.text,
          context: transformRequest.context,
          contextOptions: transformRequest.contextOptions
        ),
        temperature: 0
      )
    )
    return FinalTranscript(text: completion.text, draft: draft, transform: completion)
  }
}

public enum TranscriptionPipelineError: Error, Equatable {
  case textProviderRequired
}
