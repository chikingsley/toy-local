@preconcurrency import AVFoundation
import TimberVoxCore
import Foundation

#if canImport(FluidAudio)
  @preconcurrency import FluidAudio

  actor StreamingNemotronClient {
    private var englishManager: StreamingNemotronAsrManager?
    private var multilingualManager: StreamingNemotronMultilingualAsrManager?
    private var multilingualShared: SharedNemotronMultilingualModels?
    private var currentVariant: NemotronVariant?
    private var partialContinuation: AsyncStream<String>.Continuation?

    func isModelAvailable(modelName: String) -> Bool {
      guard let variant = NemotronVariant(modelName: modelName) else { return false }
      return FileManager.default.fileExists(atPath: variant.cacheDirectory.path)
    }

    func ensureLoaded(
      modelName: String,
      languageCode: String = "auto",
      progress: @Sendable @escaping (Progress) -> Void
    ) async throws {
      guard let variant = NemotronVariant(modelName: modelName) else {
        throw unsupported(modelName)
      }
      if currentVariant == variant, englishManager != nil || multilingualManager != nil { return }

      let p = Progress(totalUnitCount: 100)
      p.completedUnitCount = 1
      progress(p)

      switch variant {
      case .english(let chunk):
        let manager = StreamingNemotronAsrManager(requestedChunkSize: chunk)
        try await manager.loadModels { downloadProgress in
          p.completedUnitCount = Int64(5 + min(90.0, downloadProgress.fractionCompleted * 90.0))
          progress(p)
        }
        englishManager = manager
        multilingualManager = nil
        multilingualShared = nil
      case .multilingual(let chunkMs):
        let shared = try await StreamingNemotronMultilingualAsrManager.downloadAndPreloadShared(
          languageCode: languageCode,
          chunkMs: chunkMs
        ) { downloadProgress in
          p.completedUnitCount = Int64(5 + min(90.0, downloadProgress.fractionCompleted * 90.0))
          progress(p)
        }
        let manager = StreamingNemotronMultilingualAsrManager()
        try await manager.loadFromShared(shared)
        multilingualShared = shared
        multilingualManager = manager
        englishManager = nil
      }

      currentVariant = variant
      p.completedUnitCount = 100
      progress(p)
    }

    func setupCallbacks() async -> AsyncStream<String> {
      partialContinuation?.finish()
      let (stream, continuation) = AsyncStream.makeStream(of: String.self)
      partialContinuation = continuation

      if let englishManager {
        await englishManager.setPartialCallback { partial in
          continuation.yield(partial)
        }
      } else if let multilingualManager {
        await multilingualManager.setPartialCallback { partial in
          continuation.yield(partial)
        }
      } else {
        continuation.finish()
      }

      return stream
    }

    func processBuffer(_ buffer: AVAudioPCMBuffer) async throws -> String {
      if let englishManager {
        return try await englishManager.process(audioBuffer: buffer)
      }
      if let multilingualManager {
        return try await multilingualManager.process(audioBuffer: buffer)
      }
      throw NSError(domain: "StreamingNemotron", code: -1, userInfo: [NSLocalizedDescriptionKey: "Nemotron streaming model not initialized"])
    }

    func finish() async throws -> String {
      if let englishManager {
        return try await englishManager.finish()
      }
      if let multilingualManager {
        return try await multilingualManager.finish()
      }
      return ""
    }

    func reset() async {
      await englishManager?.reset()
      await multilingualManager?.reset()
    }

    func teardown() async {
      partialContinuation?.finish()
      partialContinuation = nil
      await englishManager?.cleanup()
      await multilingualManager?.cleanup()
      englishManager = nil
      multilingualManager = nil
      multilingualShared = nil
      currentVariant = nil
    }

    func deleteCaches(modelName: String) throws {
      guard let variant = NemotronVariant(modelName: modelName) else { return }
      let dir = variant.cacheDirectory
      if FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.removeItem(at: dir)
      }
      englishManager = nil
      multilingualManager = nil
      multilingualShared = nil
      currentVariant = nil
    }

    private func unsupported(_ modelName: String) -> NSError {
      NSError(domain: "StreamingNemotron", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported Nemotron model: \(modelName)"])
    }
  }

  private enum NemotronVariant: Equatable {
    case english(NemotronChunkSize)
    case multilingual(Int)

    init?(modelName: String) {
      switch modelName {
      case FluidAudioModels.nemotron560.id:
        self = .english(.ms560)
      case FluidAudioModels.nemotron1120.id:
        self = .english(.ms1120)
      case FluidAudioModels.nemotron2240.id:
        self = .english(.ms2240)
      case FluidAudioModels.nemotronMultilingual560.id:
        self = .multilingual(560)
      case FluidAudioModels.nemotronMultilingual1120.id:
        self = .multilingual(1120)
      case FluidAudioModels.nemotronMultilingual2240.id:
        self = .multilingual(2240)
      default:
        return nil
      }
    }

    var cacheDirectory: URL {
      let base =
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true))
        .appendingPathComponent("FluidAudio", isDirectory: true)
        .appendingPathComponent("Models", isDirectory: true)
      switch self {
      case .english(let chunk):
        return base.appendingPathComponent(chunk.repo.folderName, isDirectory: true)
      case .multilingual(let chunkMs):
        return base.appendingPathComponent(Repo.nemotronMultilingual.folderName, isDirectory: true)
          .appendingPathComponent("multilingual", isDirectory: true)
          .appendingPathComponent("\(chunkMs)ms", isDirectory: true)
      }
    }
  }

#else

  actor StreamingNemotronClient {
    func isModelAvailable(modelName: String) -> Bool { false }
    func ensureLoaded(modelName: String, languageCode: String = "auto", progress: @Sendable @escaping (Progress) -> Void) async throws {
      throw NSError(domain: "StreamingNemotron", code: -3, userInfo: [NSLocalizedDescriptionKey: "FluidAudio not linked."])
    }
    func setupCallbacks() async -> AsyncStream<String> { .finished }
    func processBuffer(_ buffer: Any) async throws -> String { "" }
    func finish() async throws -> String { "" }
    func reset() async {}
    func teardown() async {}
    func deleteCaches(modelName: String) throws {}
  }

#endif
