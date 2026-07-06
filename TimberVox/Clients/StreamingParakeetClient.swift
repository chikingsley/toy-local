@preconcurrency import AVFoundation
import TimberVoxCore
import CoreML
import Foundation

#if canImport(FluidAudio)
  import FluidAudio

  actor StreamingParakeetClient {
    private var manager: StreamingEouAsrManager?
    private var currentChunkSize: StreamingChunkSize?
    private let logger = TimberVoxLog.streaming

    private var partialContinuation: AsyncStream<String>.Continuation?
    private var utteranceContinuation: AsyncStream<String>.Continuation?

    func isModelAvailable(modelName: String = FluidAudioModels.parakeetEou160.id) async -> Bool {
      if manager != nil { return true }
      guard let variant = StreamingEouVariant(modelName: modelName) else { return false }
      // Check if model files exist on disk even if not loaded in memory
      let fm = FileManager.default
      guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
        return false
      }
      let modelDir = appSupport.appendingPathComponent("FluidAudio/Models/parakeet-eou-streaming/\(variant.subdirectory)", isDirectory: true)
      let vocabPath = modelDir.appendingPathComponent("vocab.json").path
      let encoderPath = modelDir.appendingPathComponent("streaming_encoder.mlmodelc").path
      return fm.fileExists(atPath: vocabPath) && fm.fileExists(atPath: encoderPath)
    }

    func ensureLoaded(modelName: String = FluidAudioModels.parakeetEou160.id, progress: @Sendable @escaping (Progress) -> Void) async throws {
      guard let variant = StreamingEouVariant(modelName: modelName) else {
        throw NSError(
          domain: "StreamingParakeet",
          code: -4,
          userInfo: [NSLocalizedDescriptionKey: "Unsupported streaming model runtime: \(modelName)"]
        )
      }
      let chunkSize = variant.chunkSize
      if currentChunkSize == chunkSize, manager != nil { return }

      // Reset if switching chunk size
      if currentChunkSize != chunkSize {
        manager = nil
      }

      let t0 = Date()
      logger.notice("Starting streaming EOU model load chunkSize=\(String(describing: chunkSize))")

      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      let modelDir = try await ensureModelFiles(variant: variant, progressState: p, progress: progress)

      // Initialize manager
      let config = MLModelConfiguration()
      config.computeUnits = .all

      let mgr = StreamingEouAsrManager(
        configuration: config,
        chunkSize: chunkSize,
        eouDebounceMs: 1280
      )
      try await mgr.loadModels(from: modelDir)

      self.manager = mgr
      self.currentChunkSize = chunkSize

      p.completedUnitCount = 100
      progress(p)
      logger.notice("Streaming EOU model loaded in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
    }

    private func ensureModelFiles(
      variant: StreamingEouVariant,
      progressState: Progress,
      progress: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
      let fm = FileManager.default
      guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
        throw NSError(domain: "StreamingParakeet", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot locate Application Support directory"])
      }
      let baseDir = appSupport.appendingPathComponent("FluidAudio/Models", isDirectory: true)
      let modelDir = baseDir.appendingPathComponent("parakeet-eou-streaming/\(variant.subdirectory)", isDirectory: true)

      guard !hasRequiredStreamingFiles(modelDir) else {
        logger.notice("Streaming model files already on disk, skipping download")
        progressState.completedUnitCount = 90
        progress(progressState)
        return modelDir
      }

      let pollTask = Task {
        while progressState.completedUnitCount < 90 {
          try? await Task.sleep(nanoseconds: 500_000_000)
          if let size = directorySize(modelDir) {
            let target: Double = 200 * 1024 * 1024
            let frac = max(0.0, min(1.0, Double(size) / target))
            progressState.completedUnitCount = Int64(5 + frac * 85)
            progress(progressState)
          }
          if Task.isCancelled { break }
        }
      }
      defer { pollTask.cancel() }

      try await DownloadUtils.downloadRepo(variant.repo, to: baseDir)
      progressState.completedUnitCount = 90
      progress(progressState)
      return modelDir
    }

    private func hasRequiredStreamingFiles(_ modelDir: URL) -> Bool {
      let fm = FileManager.default
      let vocabExists = fm.fileExists(atPath: modelDir.appendingPathComponent("vocab.json").path)
      let encoderExists = fm.fileExists(atPath: modelDir.appendingPathComponent("streaming_encoder.mlmodelc").path)
      return vocabExists && encoderExists
    }

    func setupCallbacks() async -> (partials: AsyncStream<String>, utterances: AsyncStream<String>) {
      guard let manager else {
        return (AsyncStream { $0.finish() }, AsyncStream { $0.finish() })
      }

      // Finish any previous continuations
      partialContinuation?.finish()
      utteranceContinuation?.finish()

      let (partialStream, partialCont) = AsyncStream.makeStream(of: String.self)
      let (utteranceStream, utteranceCont) = AsyncStream.makeStream(of: String.self)

      self.partialContinuation = partialCont
      self.utteranceContinuation = utteranceCont

      // Callbacks are @Sendable (String) -> Void — capture continuations directly
      await manager.setPartialCallback { partial in
        partialCont.yield(partial)
      }

      await manager.setEouCallback { utterance in
        utteranceCont.yield(utterance)
      }

      return (partialStream, utteranceStream)
    }

    func processBuffer(_ buffer: AVAudioPCMBuffer) async throws {
      guard let manager else {
        throw NSError(domain: "StreamingParakeet", code: -2, userInfo: [NSLocalizedDescriptionKey: "Streaming model not initialized"])
      }
      _ = try await manager.process(audioBuffer: buffer)
    }

    func finish() async throws -> String {
      guard let manager else { return "" }
      return try await manager.finish()
    }

    func reset() async {
      await manager?.reset()
    }

    func teardown() {
      partialContinuation?.finish()
      utteranceContinuation?.finish()
      partialContinuation = nil
      utteranceContinuation = nil
      manager = nil
      currentChunkSize = nil
      logger.notice("Streaming client torn down")
    }

    func deleteCaches() throws {
      let fm = FileManager.default
      guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
      let streamingDir = appSupport.appendingPathComponent("FluidAudio/Models/parakeet-eou-streaming", isDirectory: true)
      if fm.fileExists(atPath: streamingDir.path) {
        try fm.removeItem(at: streamingDir)
      }
      manager = nil
      currentChunkSize = nil
    }

    private func directorySize(_ dir: URL) -> UInt64? {
      let fm = FileManager.default
      guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: .skipsHiddenFiles) else {
        return nil
      }
      var total: UInt64 = 0
      for case let url as URL in en {
        if let vals = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), vals.isRegularFile == true {
          total &+= UInt64(vals.fileSize ?? 0)
        }
      }
      return total
    }
  }

  private struct StreamingEouVariant {
    let repo: Repo
    let subdirectory: String
    let chunkSize: StreamingChunkSize

    init?(modelName: String) {
      switch modelName {
      case FluidAudioModels.parakeetEou160.id:
        repo = .parakeetEou160
        subdirectory = "160ms"
        chunkSize = .ms160
      case FluidAudioModels.parakeetEou320.id:
        repo = .parakeetEou320
        subdirectory = "320ms"
        chunkSize = .ms320
      case FluidAudioModels.parakeetEou1280.id:
        repo = .parakeetEou1280
        subdirectory = "1280ms"
        chunkSize = .ms1280
      default:
        return nil
      }
    }
  }

#else

  actor StreamingParakeetClient {
    func isModelAvailable(modelName: String = "") async -> Bool { false }
    func ensureLoaded(modelName: String = "", progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(
        domain: "StreamingParakeet",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked. Streaming ASR unavailable."]
      )
    }
    func setupCallbacks() async -> (partials: AsyncStream<String>, utterances: AsyncStream<String>) { (.finished, .finished) }
    func processBuffer(_ buffer: Any) async throws {}
    func finish() async throws -> String { "" }
    func reset() async {}
    func teardown() {}
    func deleteCaches() throws {}
  }

#endif
