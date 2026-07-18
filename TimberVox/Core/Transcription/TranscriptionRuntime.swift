import Foundation

/// Executes speech-to-text without exposing provider or runtime selection to callers.
@MainActor
final class TranscriptionRuntime {
  static let shared = TranscriptionRuntime()

  private let cloudBatch: CloudBatchTranscriber
  private let cloudRealtime: CloudRealtimeTranscriptionSession
  private let fluidAudioBatch: FluidAudioBatchTranscriber
  private let fluidAudioRealtime: FluidAudioRealtimeTranscriptionSession

  private var activeRealtimeExecutor: TranscriptionRouteExecutor?
  private var onRealtimeError: (@Sendable (String) -> Void)?

  init(
    baseURL: URL = APIConnector.defaultBaseURL,
    session: URLSession = .shared,
    fluidAudioBatch: FluidAudioBatchTranscriber = .shared,
    fluidAudioRealtime: FluidAudioRealtimeTranscriptionSession = .shared
  ) {
    cloudBatch = CloudBatchTranscriber(baseURL: baseURL, session: session)
    cloudRealtime = CloudRealtimeTranscriptionSession {
      CloudRealtimeTranscriptionClient(baseURL: baseURL, session: session)
    }
    self.fluidAudioBatch = fluidAudioBatch
    self.fluidAudioRealtime = fluidAudioRealtime
  }

  func startRealtime(
    route: TranscriptionRouteSpec,
    language: String?,
    diarize: Bool,
    onTranscript: @escaping @Sendable (String) -> Void,
    onError: @escaping @Sendable (String) -> Void
  ) async throws {
    await cancelRealtime()
    onRealtimeError = onError

    do {
      switch route.executor {
      case .cloud:
        try await cloudRealtime.start(
          model: route.model,
          language: language,
          diarize: diarize,
          onTranscript: onTranscript,
          onError: onError
        )
      case .local(let localRoute):
        guard !diarize else {
          throw TranscriptionRuntimeError.configuration(
            "Local realtime speaker identification is not supported."
          )
        }
        await fluidAudioBatch.releaseLoadedModel()
        try await fluidAudioRealtime.start(
          route: localRoute,
          language: language,
          onTranscript: onTranscript
        )
      }
      activeRealtimeExecutor = route.executor
    } catch {
      await cancelRealtime()
      throw error
    }
  }

  func sendRealtimePCM(_ samples: [Float]) async {
    guard let activeRealtimeExecutor else { return }
    switch activeRealtimeExecutor {
    case .cloud:
      await cloudRealtime.sendPCM(samples)
    case .local:
      do {
        try await fluidAudioRealtime.sendPCM(samples)
      } catch {
        onRealtimeError?(error.localizedDescription)
      }
    }
  }

  func finishRealtime() async throws -> TranscriptionArtifact {
    guard let activeRealtimeExecutor else {
      throw TranscriptionRuntimeError.realtimeFailed("Realtime transcription was not active.")
    }
    self.activeRealtimeExecutor = nil
    onRealtimeError = nil

    switch activeRealtimeExecutor {
    case .cloud:
      return try await cloudRealtime.finish()
    case .local:
      return try await fluidAudioRealtime.finish()
    }
  }

  func transcribeBatch(
    audioURL: URL,
    route: TranscriptionRouteSpec,
    language: String? = nil,
    diarize: Bool = false
  ) async throws -> TranscriptionArtifact {
    switch route.executor {
    case .cloud:
      return try await cloudBatch.transcribe(
        wavAt: audioURL,
        model: route.model,
        language: language,
        diarize: diarize
      )
    case .local(let localRoute):
      await fluidAudioRealtime.releaseLoadedModel()
      return try await fluidAudioBatch.transcribe(
        wavAt: audioURL,
        route: localRoute,
        requestedLanguage: language
      )
    }
  }

  func cancelRealtime() async {
    await cloudRealtime.cancel()
    await fluidAudioRealtime.cancel()
    activeRealtimeExecutor = nil
    onRealtimeError = nil
  }
}
