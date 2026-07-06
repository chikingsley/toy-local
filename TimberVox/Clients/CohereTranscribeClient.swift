@preconcurrency import AVFoundation
import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio

  private struct SendableCohereModels: @unchecked Sendable {
    let value: CoherePipeline.LoadedModels
  }

  actor CohereTranscribeClient {
    private var pipeline: CoherePipeline?
    private var models: SendableCohereModels?
    private let logger = TimberVoxLog.transcription

    func isModelAvailable() -> Bool {
      let dir = modelDirectory()
      return FileManager.default.fileExists(
        atPath: dir.appendingPathComponent(ModelNames.CohereTranscribe.encoderCompiledFile).path
      )
    }

    func ensureLoaded(progress: @Sendable @escaping (Progress) -> Void) async throws {
      if pipeline != nil, models != nil { return }

      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      let baseDir = modelsBaseDirectory()
      try await DownloadUtils.downloadRepo(.cohereTranscribeCoreml, to: baseDir) { downloadProgress in
        p.completedUnitCount = Int64(5 + min(90.0, downloadProgress.fractionCompleted * 90.0))
        progress(p)
      }

      let dir = modelDirectory()
      let loaded = try await CoherePipeline.loadModels(
        encoderDir: dir,
        decoderDir: dir,
        vocabDir: dir
      )
      self.pipeline = CoherePipeline()
      self.models = SendableCohereModels(value: loaded)

      p.completedUnitCount = 100
      progress(p)
      logger.notice("Cohere Transcribe loaded from \(dir.path)")
    }

    func transcribe(_ url: URL, language: CohereAsrConfig.Language = .english) async throws -> String {
      guard let pipeline, let models else {
        throw NSError(domain: "CohereTranscribe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cohere Transcribe not initialized"])
      }

      let samples = try AudioConverter().resampleAudioFile(url)
      let result = try await pipeline.transcribeLong(audio: samples, models: models.value, language: language)
      return result.text
    }

    func deleteCaches() throws {
      let dir = modelDirectory()
      if FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.removeItem(at: dir)
      }
      pipeline = nil
      models = nil
    }

    private func modelDirectory() -> URL {
      modelsBaseDirectory().appendingPathComponent(Repo.cohereTranscribeCoreml.folderName, isDirectory: true)
    }

    private func modelsBaseDirectory() -> URL {
      (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true))
        .appendingPathComponent("FluidAudio", isDirectory: true)
        .appendingPathComponent("Models", isDirectory: true)
    }
  }

#else

  actor CohereTranscribeClient {
    func isModelAvailable() -> Bool { false }
    func ensureLoaded(progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(domain: "CohereTranscribe", code: -2, userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked."])
    }
    func transcribe(_ url: URL) async throws -> String {
      throw NSError(domain: "CohereTranscribe", code: -3, userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked."])
    }
    func deleteCaches() throws {}
  }

#endif
