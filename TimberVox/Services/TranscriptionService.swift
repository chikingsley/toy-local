@preconcurrency import AVFoundation
import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio
#endif

private let transcriptionLogger = TimberVoxLog.transcription
private let parakeetLogger = TimberVoxLog.parakeet

/// An actor that manages FluidAudio-backed transcription models.
actor TranscriptionClientLive {
  // MARK: - Stored Properties

  /// The name of the currently loaded model, if any.
  private var currentModelName: String?
  private var parakeet: ParakeetClient = ParakeetClient()
  private var streamingParakeet: StreamingParakeetClient = StreamingParakeetClient()
  private var cohere: CohereTranscribeClient = CohereTranscribeClient()
  private var streamingNemotron: StreamingNemotronClient = StreamingNemotronClient()
  private var vad: FluidAudioVadClient = FluidAudioVadClient()
  private var diarization: FluidAudioDiarizationClient = FluidAudioDiarizationClient()
  private var keywordSpotting: FluidAudioKeywordSpottingClient = FluidAudioKeywordSpottingClient()

  // MARK: - Public Methods

  /// Ensures the given `variant` model is downloaded and loaded, reporting
  /// overall progress.
  func downloadAndLoadModel(variant: String, progressCallback: @Sendable @escaping (Progress) -> Void) async throws {
    // Streaming Parakeet models use StreamingParakeetClient
    if isStreamingParakeet(variant) {
      try await streamingParakeet.ensureLoaded(modelName: variant, progress: progressCallback)
      return
    }
    if isStreamingNemotron(variant) {
      try await streamingNemotron.ensureLoaded(modelName: variant, progress: progressCallback)
      return
    }
    // If batch Parakeet, use ParakeetClient path
    if isParakeet(variant) {
      try await parakeet.ensureLoaded(modelName: variant, progress: progressCallback)
      currentModelName = variant
      return
    }
    if isCohere(variant) {
      try await cohere.ensureLoaded(progress: progressCallback)
      currentModelName = variant
      return
    }
    if isVad(variant) {
      try await vad.ensureLoaded(progress: progressCallback)
      return
    }
    if isDiarization(variant) {
      try await diarization.ensureLoaded(modelName: variant, progress: progressCallback)
      return
    }
    if isKeywordSpotting(variant) {
      try await keywordSpotting.ensureLoaded(progress: progressCallback)
      return
    }
    throw unsupportedModelError(variant)
  }

  /// Deletes a model from disk if it exists
  func deleteModel(variant: String) async throws {
    if isStreamingParakeet(variant) {
      try await streamingParakeet.deleteCaches()
      return
    }
    if isStreamingNemotron(variant) {
      try await streamingNemotron.deleteCaches(modelName: variant)
      return
    }
    if isParakeet(variant) {
      try await parakeet.deleteCaches(modelName: variant)
      if currentModelName == variant { unloadCurrentModel() }
      return
    }
    if isCohere(variant) {
      try await cohere.deleteCaches()
      if currentModelName == variant { unloadCurrentModel() }
      return
    }
    if isVad(variant) {
      try await vad.deleteCaches()
      return
    }
    if isDiarization(variant) {
      try await diarization.deleteCaches(modelName: variant)
      return
    }
    if isKeywordSpotting(variant) {
      try await keywordSpotting.deleteCaches()
      return
    }
    throw unsupportedModelError(variant)
  }

  /// Returns `true` if the model is already downloaded to the local folder.
  func isModelDownloaded(_ modelName: String) async -> Bool {
    if isStreamingParakeet(modelName) {
      let available = await streamingParakeet.isModelAvailable(modelName: modelName)
      parakeetLogger.debug("Streaming Parakeet available? \(available)")
      return available
    }
    if isStreamingNemotron(modelName) {
      let available = await streamingNemotron.isModelAvailable(modelName: modelName)
      parakeetLogger.debug("Streaming Nemotron available? \(available)")
      return available
    }
    if isParakeet(modelName) {
      let available = await parakeet.isModelAvailable(modelName)
      parakeetLogger.debug("Parakeet available? \(available)")
      return available
    }
    if isCohere(modelName) {
      return await cohere.isModelAvailable()
    }
    if isVad(modelName) {
      return await vad.isModelAvailable()
    }
    if isDiarization(modelName) {
      return await diarization.isModelAvailable(modelName: modelName)
    }
    if isKeywordSpotting(modelName) {
      return await keywordSpotting.isModelAvailable()
    }
    return false
  }

  /// Returns the app's current recommended FluidAudio batch model.
  func getRecommendedModel() async -> String {
    FluidAudioModels.parakeetTdtV3.id
  }

  /// Lists all model variants currently supported by TimberVox's FluidAudio integration.
  func getAvailableModels() async throws -> [String] {
    FluidAudioModels.userSelectableASR.map(\.id)
  }

  /// Transcribes the audio file at `url` using a `model` name.
  func transcribe(
    url: URL,
    model: String,
    progressCallback: @Sendable @escaping (Progress) -> Void
  ) async throws -> String {
    let startAll = Date()
    if isParakeet(model) {
      transcriptionLogger.notice("Transcribing with Parakeet model=\(model) file=\(url.lastPathComponent)")
      let startLoad = Date()
      try await downloadAndLoadModel(variant: model) { p in
        progressCallback(p)
      }
      transcriptionLogger.info("Parakeet ensureLoaded took \(String(format: "%.2f", Date().timeIntervalSince(startLoad)))s")
      let preparedClip = try ParakeetClipPreparer.ensureMinimumDuration(url: url, logger: parakeetLogger)
      defer { preparedClip.cleanup() }
      let startTx = Date()
      let text = try await parakeet.transcribe(preparedClip.url)
      transcriptionLogger.info("Parakeet transcription took \(String(format: "%.2f", Date().timeIntervalSince(startTx)))s")
      transcriptionLogger.info("Parakeet request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")
      return text
    }
    if isCohere(model) {
      transcriptionLogger.notice("Transcribing with Cohere model=\(model) file=\(url.lastPathComponent)")
      try await downloadAndLoadModel(variant: model, progressCallback: progressCallback)
      let text = try await cohere.transcribe(url)
      transcriptionLogger.info("Cohere request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")
      return text
    }
    throw unsupportedModelError(model)
  }

  func setupStreamingCallbacks(
    modelName: String
  ) async throws -> (partials: AsyncStream<String>, utterances: AsyncStream<String>) {
    if isStreamingParakeet(modelName) {
      return await streamingParakeet.setupCallbacks()
    }
    if isStreamingNemotron(modelName) {
      let partials = await streamingNemotron.setupCallbacks()
      return (partials, AsyncStream { $0.finish() })
    }
    throw unsupportedModelError(modelName)
  }

  func processStreamingBuffer(_ buffer: AVAudioPCMBuffer, modelName: String) async throws -> String {
    if isStreamingParakeet(modelName) {
      try await streamingParakeet.processBuffer(buffer)
      return ""
    }
    if isStreamingNemotron(modelName) {
      return try await streamingNemotron.processBuffer(buffer)
    }
    throw unsupportedModelError(modelName)
  }

  func finishStreaming(modelName: String) async throws -> String {
    if isStreamingParakeet(modelName) {
      return try await streamingParakeet.finish()
    }
    if isStreamingNemotron(modelName) {
      return try await streamingNemotron.finish()
    }
    throw unsupportedModelError(modelName)
  }

  func resetStreaming(modelName: String) async {
    if isStreamingParakeet(modelName) {
      await streamingParakeet.reset()
    } else if isStreamingNemotron(modelName) {
      await streamingNemotron.reset()
    }
  }

  func teardownStreaming(modelName: String) async {
    if isStreamingParakeet(modelName) {
      await streamingParakeet.teardown()
    } else if isStreamingNemotron(modelName) {
      await streamingNemotron.teardown()
    }
  }

  #if canImport(FluidAudio)
    func detectSpeech(in url: URL, progressCallback: @Sendable @escaping (Progress) -> Void = { _ in }) async throws -> [VadResult] {
      try await vad.ensureLoaded(progress: progressCallback)
      return try await vad.process(url)
    }

    func processDiarization(
      samples: [Float],
      modelName: String,
      sourceSampleRate: Double = 16_000,
      progressCallback: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> DiarizerTimelineUpdate? {
      try await diarization.ensureLoaded(modelName: modelName, progress: progressCallback)
      return try await diarization.process(samples: samples, modelName: modelName, sourceSampleRate: sourceSampleRate)
    }

    func finalizeDiarization(modelName: String) async throws -> DiarizerTimelineUpdate? {
      try await diarization.finalize(modelName: modelName)
    }

    func spotKeywords(
      audioSamples: [Float],
      vocabulary: CustomVocabularyContext,
      progressCallback: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> CtcKeywordSpotter.SpotKeywordsResult {
      try await keywordSpotting.ensureLoaded(progress: progressCallback)
      return try await keywordSpotting.spotKeywords(audioSamples: audioSamples, vocabulary: vocabulary)
    }
  #endif

  // MARK: - Private Helpers

  private func isParakeet(_ name: String) -> Bool {
    name == FluidAudioModels.parakeetTdtV3.id || name == FluidAudioModels.parakeetTdtCtc110m.id
  }

  private func isStreamingParakeet(_ name: String) -> Bool {
    guard let model = FluidAudioModels.model(id: name) else { return false }
    return model.role == .streamingASR && name.hasPrefix("parakeet-eou-")
  }

  private func isStreamingNemotron(_ name: String) -> Bool {
    guard let model = FluidAudioModels.model(id: name) else { return false }
    return model.role == .streamingASR && name.hasPrefix("nemotron")
  }

  private func isCohere(_ name: String) -> Bool {
    name == FluidAudioModels.cohereTranscribe.id
  }

  private func isVad(_ name: String) -> Bool {
    guard let model = FluidAudioModels.model(id: name) else { return false }
    return model.role == .vad
  }

  private func isDiarization(_ name: String) -> Bool {
    guard let model = FluidAudioModels.model(id: name) else { return false }
    return model.role == .diarization
  }

  private func isKeywordSpotting(_ name: String) -> Bool {
    guard let model = FluidAudioModels.model(id: name) else { return false }
    return model.role == .keywordSpotting
  }

  private func unloadCurrentModel() {
    currentModelName = nil
  }

  private func unsupportedModelError(_ modelName: String) -> NSError {
    NSError(
      domain: "TranscriptionClient",
      code: -10,
      userInfo: [
        NSLocalizedDescriptionKey: "Unsupported FluidAudio model: \(modelName)."
      ]
    )
  }
}
