import TimberVoxCore
import Foundation

private let textTransformLogger = TimberVoxLog.transcription

struct TextTransformApplicationResult {
  let text: String
  let state: TextTransformRunState
}

extension TranscriptionStore {
  func applyTextTransformIfNeeded(
    to transcript: String,
    settings timberVoxSettings: TimberVoxSettings,
    contextSnapshot: DictationContextSnapshot?
  ) async throws -> TextTransformApplicationResult {
    guard timberVoxSettings.textTransformMode.usesTextTransform else {
      return TextTransformApplicationResult(text: transcript, state: .skipped(reason: "Text transform mode is disabled."))
    }
    guard let transformRequest = textTransformRequest(for: timberVoxSettings, contextSnapshot: contextSnapshot) else {
      return TextTransformApplicationResult(text: transcript, state: .skipped(reason: "No text transform request could be built."))
    }

    textTransformState = .running(
      mode: timberVoxSettings.textTransformMode,
      request: transformRequest,
      input: transcript
    )

    let completion = try await transcriptionWorkflow.complete(
      transcript: transcript,
      transformRequest: transformRequest
    )
    guard let completion else {
      return TextTransformApplicationResult(
        text: transcript,
        state: .emptyResult(
          mode: timberVoxSettings.textTransformMode,
          request: transformRequest,
          completion: nil,
          input: transcript
        )
      )
    }

    guard !completion.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return TextTransformApplicationResult(
        text: transcript,
        state: .emptyResult(
          mode: timberVoxSettings.textTransformMode,
          request: transformRequest,
          completion: completion,
          input: transcript
        )
      )
    }

    return TextTransformApplicationResult(
      text: completion.text,
      state: .succeeded(
        mode: timberVoxSettings.textTransformMode,
        request: transformRequest,
        completion: completion,
        input: transcript
      )
    )
  }

  func transcriptionWorkflowRequest(
    for timberVoxSettings: TimberVoxSettings,
    contextSnapshot: DictationContextSnapshot?
  ) -> TranscriptionWorkflowRequest {
    let vocabularyTerms = contextSnapshot?.context.vocabulary ?? []
    let vocabulary: TranscriptionVocabularySelection
    if timberVoxSettings.textTransformMode.usesTextTransform, !vocabularyTerms.isEmpty {
      vocabulary = .textTransformContext(terms: vocabularyTerms)
    } else {
      vocabulary = .disabled
    }

    return TranscriptionWorkflowRequest(
      asrModelID: timberVoxSettings.selectedModel,
      language: timberVoxSettings.outputLanguage,
      vocabulary: vocabulary,
      textTransform: textTransformRequest(for: timberVoxSettings, contextSnapshot: contextSnapshot)
    )
  }

  func textTransformRequest(
    for timberVoxSettings: TimberVoxSettings,
    contextSnapshot: DictationContextSnapshot?
  ) -> TranscriptTransformRequest? {
    guard timberVoxSettings.textTransformMode.usesTextTransform,
      let preset = textTransformPreset(for: timberVoxSettings)
    else {
      return nil
    }

    return TranscriptTransformRequest(
      modelID: timberVoxSettings.textTransformModel,
      preset: preset,
      context: contextSnapshot?.context,
      contextOptions: timberVoxSettings.textTransformContextOptions
    )
  }

  func textTransformPreset(for timberVoxSettings: TimberVoxSettings) -> TextTransformPreset? {
    guard let presetID = timberVoxSettings.textTransformMode.presetID else {
      return nil
    }
    if presetID == .customPrompt {
      return .custom(timberVoxSettings.customTextTransformInstructions)
    }
    return TextTransformPreset.builtIn(id: presetID)
  }

  func applyTranscriptModifications(
    _ result: String,
    settings timberVoxSettings: TimberVoxSettings
  ) -> String {
    guard !settings.isRemappingScratchpadFocused else {
      textTransformLogger.info("Scratchpad focused; skipping word modifications")
      return result
    }

    var output = result
    if timberVoxSettings.wordRemovalsEnabled {
      let removedResult = WordRemovalApplier.apply(output, removals: timberVoxSettings.wordRemovals)
      if removedResult != output {
        let enabledRemovalCount = timberVoxSettings.wordRemovals.filter(\.isEnabled).count
        textTransformLogger.info("Applied \(enabledRemovalCount) word removal(s)")
      }
      output = removedResult
    }

    let remappedResult = WordRemappingApplier.apply(output, remappings: timberVoxSettings.wordRemappings)
    if remappedResult != output {
      textTransformLogger.info("Applied \(timberVoxSettings.wordRemappings.count) word remapping(s)")
    }
    return remappedResult
  }
}
