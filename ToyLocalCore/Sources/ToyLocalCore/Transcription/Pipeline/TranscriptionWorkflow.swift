import Foundation

public enum TranscriptionVADMode: String, Codable, Equatable, Sendable {
  case disabled
  case native
  case local
}

public struct TranscriptionVADSelection: Codable, Equatable, Sendable {
  public let mode: TranscriptionVADMode
  public let modelID: String?

  public init(mode: TranscriptionVADMode = .disabled, modelID: String? = nil) {
    self.mode = mode
    self.modelID = modelID
  }

  public static let disabled = TranscriptionVADSelection()
  public static let native = TranscriptionVADSelection(mode: .native)

  public static func local(modelID: String) -> TranscriptionVADSelection {
    TranscriptionVADSelection(mode: .local, modelID: modelID)
  }
}

public enum TranscriptionDiarizationMode: String, Codable, Equatable, Sendable {
  case disabled
  case native
  case local
}

public struct TranscriptionDiarizationSelection: Codable, Equatable, Sendable {
  public let mode: TranscriptionDiarizationMode
  public let modelID: String?

  public init(mode: TranscriptionDiarizationMode = .disabled, modelID: String? = nil) {
    self.mode = mode
    self.modelID = modelID
  }

  public static let disabled = TranscriptionDiarizationSelection()
  public static let native = TranscriptionDiarizationSelection(mode: .native)

  public static func local(modelID: String) -> TranscriptionDiarizationSelection {
    TranscriptionDiarizationSelection(mode: .local, modelID: modelID)
  }
}

public enum TranscriptionVocabularyMode: String, Codable, Equatable, Sendable {
  case disabled
  case native
  case localKeywordSpotting
  case textTransformContext
}

public struct TranscriptionVocabularySelection: Codable, Equatable, Sendable {
  public let mode: TranscriptionVocabularyMode
  public let modelID: String?
  public let terms: [String]

  public init(mode: TranscriptionVocabularyMode = .disabled, modelID: String? = nil, terms: [String] = []) {
    self.mode = mode
    self.modelID = modelID
    self.terms = terms
  }

  public static let disabled = TranscriptionVocabularySelection()

  public static func native(terms: [String]) -> TranscriptionVocabularySelection {
    TranscriptionVocabularySelection(mode: .native, terms: terms)
  }

  public static func localKeywordSpotting(modelID: String, terms: [String]) -> TranscriptionVocabularySelection {
    TranscriptionVocabularySelection(mode: .localKeywordSpotting, modelID: modelID, terms: terms)
  }

  public static func textTransformContext(terms: [String]) -> TranscriptionVocabularySelection {
    TranscriptionVocabularySelection(mode: .textTransformContext, terms: terms)
  }
}

public enum TranscriptionOutputFormat: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
  case text
  case words
  case segments
  case speakerSegments
  case srt
  case webvtt
  case json
}

public struct TranscriptionWorkflowRequest: Codable, Equatable, Sendable {
  public let asrModelID: String
  public let language: String?
  public let vad: TranscriptionVADSelection
  public let diarization: TranscriptionDiarizationSelection
  public let vocabulary: TranscriptionVocabularySelection
  public let textTransform: TranscriptTransformRequest?
  public let outputFormats: Set<TranscriptionOutputFormat>

  public init(
    asrModelID: String,
    language: String? = nil,
    vad: TranscriptionVADSelection = .disabled,
    diarization: TranscriptionDiarizationSelection = .disabled,
    vocabulary: TranscriptionVocabularySelection = .disabled,
    textTransform: TranscriptTransformRequest? = nil,
    outputFormats: Set<TranscriptionOutputFormat> = [.text]
  ) {
    self.asrModelID = asrModelID
    self.language = language
    self.vad = vad
    self.diarization = diarization
    self.vocabulary = vocabulary
    self.textTransform = textTransform
    self.outputFormats = outputFormats
  }
}

public enum TranscriptionWorkflowValidationCode: String, Codable, Equatable, Sendable {
  case missingASRModel
  case primaryModelRequired
  case nativeVADUnsupported
  case localVADModelRequired
  case localVADModelMissing
  case localVADModelWrongRole
  case nativeDiarizationUnsupported
  case localDiarizationModelRequired
  case localDiarizationModelMissing
  case localDiarizationModelWrongRole
  case nativeVocabularyUnsupported
  case localKeywordModelRequired
  case localKeywordModelMissing
  case localKeywordModelWrongRole
  case speakerOutputNeedsDiarization
}

public struct TranscriptionWorkflowValidationIssue: Codable, Equatable, Sendable {
  public let code: TranscriptionWorkflowValidationCode
  public let modelID: String?
  public let message: String

  public init(code: TranscriptionWorkflowValidationCode, modelID: String? = nil, message: String) {
    self.code = code
    self.modelID = modelID
    self.message = message
  }
}

public enum TranscriptionWorkflowValidator {
  public static func validate(
    _ request: TranscriptionWorkflowRequest,
    catalog: [TranscriptionModelSpec] = TranscriptionModelCatalog.all
  ) -> [TranscriptionWorkflowValidationIssue] {
    let modelsByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    var issues: [TranscriptionWorkflowValidationIssue] = []

    guard let asr = modelsByID[request.asrModelID] else {
      return [
        issue(.missingASRModel, modelID: request.asrModelID, "ASR model is not in the transcription catalog.")
      ]
    }

    if asr.assetRole != .primaryASR {
      issues.append(issue(.primaryModelRequired, modelID: asr.id, "Workflow ASR model must be a primary ASR model, not a support asset."))
    }

    validateVAD(request.vad, asr: asr, modelsByID: modelsByID, issues: &issues)
    validateDiarization(request.diarization, asr: asr, modelsByID: modelsByID, issues: &issues)
    validateVocabulary(request.vocabulary, asr: asr, modelsByID: modelsByID, issues: &issues)

    if request.outputFormats.contains(.speakerSegments),
      request.diarization.mode == .disabled,
      !asr.capabilities.diarization
    {
      issues.append(issue(.speakerOutputNeedsDiarization, modelID: asr.id, "Speaker segment output requires native or local diarization."))
    }

    return issues
  }

  private static func validateVAD(
    _ selection: TranscriptionVADSelection,
    asr: TranscriptionModelSpec,
    modelsByID: [String: TranscriptionModelSpec],
    issues: inout [TranscriptionWorkflowValidationIssue]
  ) {
    switch selection.mode {
    case .disabled:
      return
    case .native:
      if !asr.capabilities.voiceActivityDetection {
        issues.append(issue(.nativeVADUnsupported, modelID: asr.id, "Selected ASR model does not advertise native VAD events."))
      }
    case .local:
      guard let modelID = selection.modelID, !modelID.isEmpty else {
        issues.append(issue(.localVADModelRequired, "Local VAD requires a VAD model ID."))
        return
      }
      guard let model = modelsByID[modelID] else {
        issues.append(issue(.localVADModelMissing, modelID: modelID, "Local VAD model is not in the transcription catalog."))
        return
      }
      if model.assetRole != .vad {
        issues.append(issue(.localVADModelWrongRole, modelID: modelID, "Local VAD model must have the vad asset role."))
      }
    }
  }

  private static func validateDiarization(
    _ selection: TranscriptionDiarizationSelection,
    asr: TranscriptionModelSpec,
    modelsByID: [String: TranscriptionModelSpec],
    issues: inout [TranscriptionWorkflowValidationIssue]
  ) {
    switch selection.mode {
    case .disabled:
      return
    case .native:
      if !asr.capabilities.diarization {
        issues.append(issue(.nativeDiarizationUnsupported, modelID: asr.id, "Selected ASR model does not advertise native diarization."))
      }
    case .local:
      guard let modelID = selection.modelID, !modelID.isEmpty else {
        issues.append(issue(.localDiarizationModelRequired, "Local diarization requires a diarization model ID."))
        return
      }
      guard let model = modelsByID[modelID] else {
        issues.append(issue(.localDiarizationModelMissing, modelID: modelID, "Local diarization model is not in the transcription catalog."))
        return
      }
      if model.assetRole != .diarization {
        issues.append(issue(.localDiarizationModelWrongRole, modelID: modelID, "Local diarization model must have the diarization asset role."))
      }
    }
  }

  private static func validateVocabulary(
    _ selection: TranscriptionVocabularySelection,
    asr: TranscriptionModelSpec,
    modelsByID: [String: TranscriptionModelSpec],
    issues: inout [TranscriptionWorkflowValidationIssue]
  ) {
    switch selection.mode {
    case .disabled, .textTransformContext:
      return
    case .native:
      if !asr.capabilities.contextBiasing {
        issues.append(
          issue(
            .nativeVocabularyUnsupported,
            modelID: asr.id,
            "Selected ASR model does not advertise native vocabulary/context biasing."
          )
        )
      }
    case .localKeywordSpotting:
      guard let modelID = selection.modelID, !modelID.isEmpty else {
        issues.append(issue(.localKeywordModelRequired, "Local keyword spotting requires a keyword model ID."))
        return
      }
      guard let model = modelsByID[modelID] else {
        issues.append(issue(.localKeywordModelMissing, modelID: modelID, "Local keyword model is not in the transcription catalog."))
        return
      }
      if model.assetRole != .keywordSpotting {
        issues.append(issue(.localKeywordModelWrongRole, modelID: modelID, "Local keyword model must have the keywordSpotting asset role."))
      }
    }
  }

  private static func issue(
    _ code: TranscriptionWorkflowValidationCode,
    modelID: String? = nil,
    _ message: String
  ) -> TranscriptionWorkflowValidationIssue {
    TranscriptionWorkflowValidationIssue(code: code, modelID: modelID, message: message)
  }
}
