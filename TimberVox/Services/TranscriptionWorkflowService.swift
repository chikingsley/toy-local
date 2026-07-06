import TimberVoxCore
import Foundation

@MainActor
final class TranscriptionWorkflowService {
  typealias ProgressCallback = @Sendable (Progress) -> Void

  private let transcription: TranscriptionClientLive
  private let cloud: TimberVoxCloudClient
  private let cloudJobPollInterval: TimeInterval
  private let cloudJobTimeout: TimeInterval

  init(
    transcription: TranscriptionClientLive,
    cloud: TimberVoxCloudClient,
    cloudJobPollInterval: TimeInterval = 0.75,
    cloudJobTimeout: TimeInterval = 120
  ) {
    self.transcription = transcription
    self.cloud = cloud
    self.cloudJobPollInterval = cloudJobPollInterval
    self.cloudJobTimeout = cloudJobTimeout
  }

  func run(
    source: AudioSource,
    workflow: TranscriptionWorkflowRequest,
    progressCallback: @escaping ProgressCallback = { _ in }
  ) async throws -> FinalTranscript {
    let draft = try await transcribe(source: source, workflow: workflow, progressCallback: progressCallback)
    guard let completion = try await complete(transcript: draft.text, transformRequest: workflow.textTransform) else {
      return FinalTranscript(text: draft.text, draft: draft)
    }
    return FinalTranscript(text: completion.text, draft: draft, transform: completion)
  }

  func transcribe(
    source: AudioSource,
    workflow: TranscriptionWorkflowRequest,
    progressCallback: @escaping ProgressCallback = { _ in }
  ) async throws -> TranscriptionDraft {
    try validate(workflow)
    try validateProductionSupport(workflow)

    guard let model = TranscriptionModelCatalog.model(id: workflow.asrModelID) else {
      throw TranscriptionWorkflowServiceError.missingModel(workflow.asrModelID)
    }

    switch model.runtime {
    case .local:
      return try await transcribeLocal(
        source: source,
        workflow: workflow,
        model: model,
        progressCallback: progressCallback
      )
    case .cloud:
      return try await transcribeCloud(source: source, workflow: workflow, model: model)
    }
  }

  func complete(
    transcript: String,
    transformRequest: TranscriptTransformRequest?
  ) async throws -> TextCompletion? {
    guard let transformRequest else { return nil }

    let response = try await cloud.textTransform(
      model: transformRequest.modelID,
      messages: TextTransformPromptBuilder.messages(
        preset: transformRequest.preset,
        transcript: transcript,
        context: transformRequest.context,
        contextOptions: transformRequest.contextOptions
      ),
      temperature: 0
    )
    return TextCompletion(
      text: TextTransformOutputNormalizer.normalize(response.text),
      providerID: LanguageModelProviderID(rawValue: response.provider),
      modelID: response.model
    )
  }

  private func transcribeLocal(
    source: AudioSource,
    workflow: TranscriptionWorkflowRequest,
    model: TranscriptionModelSpec,
    progressCallback: @escaping ProgressCallback
  ) async throws -> TranscriptionDraft {
    guard model.provider == .fluidAudio else {
      throw TranscriptionWorkflowServiceError.unsupportedWorkflowComponent(
        "Local ASR provider is not wired in production: \(model.provider.rawValue)."
      )
    }
    guard model.capabilities.fileInput, model.capabilities.batch else {
      throw TranscriptionWorkflowServiceError.unsupportedWorkflowComponent(
        "Selected model does not support file dictation: \(model.id)."
      )
    }

    let text = try await transcription.transcribe(
      url: source.url,
      model: workflow.asrModelID,
      progressCallback: progressCallback
    )
    return TranscriptionDraft(
      text: text,
      language: workflow.language,
      providerID: model.provider,
      modelID: model.id
    )
  }

  private func transcribeCloud(
    source: AudioSource,
    workflow: TranscriptionWorkflowRequest,
    model: TranscriptionModelSpec
  ) async throws -> TranscriptionDraft {
    guard model.capabilities.fileInput, model.capabilities.batch else {
      throw TranscriptionWorkflowServiceError.unsupportedWorkflowComponent(
        "Selected cloud model does not support batch file dictation: \(model.id)."
      )
    }

    let upload = try await cloud.createUpload(
      filename: source.filename,
      contentType: source.contentType ?? contentType(for: source.url)
    )
    try await cloud.upload(
      fileURL: source.url,
      uploadID: upload.uploadID,
      contentType: source.contentType ?? contentType(for: source.url)
    )

    let job = try await cloud.createTranscription(
      inputKey: upload.inputKey,
      asrModel: workflow.asrModelID,
      diarize: workflow.diarization.mode == .native ? true : nil,
      language: workflow.language,
      transform: nil
    )
    let status = try await waitForCloudJob(jobID: job.jobID)
    guard let result = status.result else {
      throw TranscriptionWorkflowServiceError.missingCloudResult(job.jobID)
    }

    let transcript = result.rawTranscript ?? result.transcript
    return TranscriptionDraft(
      text: transcript,
      segments: result.asr.segments?.map(\.transcriptionSegment) ?? [],
      duration: result.asr.durationSeconds,
      language: result.asr.language,
      providerID: TranscriptionProviderID(rawValue: result.asr.provider),
      modelID: result.asr.model
    )
  }

  private func waitForCloudJob(jobID: String) async throws -> TimberVoxCloudJobStatus {
    let deadline = Date().addingTimeInterval(cloudJobTimeout)
    while Date() < deadline {
      let status = try await cloud.job(id: jobID)
      switch status.status {
      case "succeeded":
        return status
      case "failed":
        throw TranscriptionWorkflowServiceError.cloudJobFailed(jobID: jobID, message: status.error)
      case "pending", "queued", "running":
        try await Task.sleep(nanoseconds: UInt64(cloudJobPollInterval * 1_000_000_000))
      default:
        throw TranscriptionWorkflowServiceError.cloudJobFailed(
          jobID: jobID,
          message: "Unexpected status: \(status.status)"
        )
      }
    }
    throw TranscriptionWorkflowServiceError.cloudJobTimedOut(jobID: jobID)
  }

  private func validate(_ workflow: TranscriptionWorkflowRequest) throws {
    let issues = TranscriptionWorkflowValidator.validate(workflow)
    if !issues.isEmpty {
      throw TranscriptionWorkflowServiceError.validationFailed(issues)
    }
  }

  private func validateProductionSupport(_ workflow: TranscriptionWorkflowRequest) throws {
    if workflow.vad.mode == .local {
      throw TranscriptionWorkflowServiceError.unsupportedWorkflowComponent(
        "Local VAD composition is only proven in the backend prototype; it is not wired into production dictation yet."
      )
    }
    if workflow.diarization.mode == .local {
      throw TranscriptionWorkflowServiceError.unsupportedWorkflowComponent(
        "Local diarization composition is only proven in the backend prototype; it is not wired into production dictation yet."
      )
    }
    if workflow.vocabulary.mode == .native || workflow.vocabulary.mode == .localKeywordSpotting {
      throw TranscriptionWorkflowServiceError.unsupportedWorkflowComponent(
        "Native vocabulary and local keyword spotting are not wired into production dictation yet."
      )
    }
  }

  private func contentType(for url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "wav":
      "audio/wav"
    case "m4a", "mp4":
      "audio/mp4"
    case "mp3":
      "audio/mpeg"
    case "flac":
      "audio/flac"
    default:
      "application/octet-stream"
    }
  }
}

enum TranscriptionWorkflowServiceError: LocalizedError {
  case validationFailed([TranscriptionWorkflowValidationIssue])
  case missingModel(String)
  case unsupportedWorkflowComponent(String)
  case missingCloudResult(String)
  case cloudJobFailed(jobID: String, message: String?)
  case cloudJobTimedOut(jobID: String)

  var errorDescription: String? {
    switch self {
    case .validationFailed(let issues):
      issues.map(\.message).joined(separator: "\n")
    case .missingModel(let modelID):
      "Transcription model is not in the catalog: \(modelID)."
    case .unsupportedWorkflowComponent(let message):
      message
    case .missingCloudResult(let jobID):
      "Cloud transcription job completed without a result: \(jobID)."
    case .cloudJobFailed(let jobID, let message):
      "Cloud transcription job failed: \(jobID)\(message.map { " - \($0)" } ?? "")."
    case .cloudJobTimedOut(let jobID):
      "Cloud transcription job timed out: \(jobID)."
    }
  }
}

private extension TimberVoxCloudTranscriptSegment {
  var transcriptionSegment: TranscriptionSegment {
    TranscriptionSegment(
      text: text,
      startTime: startSeconds,
      endTime: endSeconds,
      speakerID: speaker
    )
  }
}
